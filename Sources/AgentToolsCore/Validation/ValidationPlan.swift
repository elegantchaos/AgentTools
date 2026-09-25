// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// What discovery found about a repository, in the form full validation needs.
struct ValidationProject {
  /// `xcodebuild` arguments that select the root container: a workspace, a project, or none for the package in the
  /// repository root.
  let container: [String]
  /// Schemes that build the product.
  let productSchemes: [String]
  /// Product schemes whose test action includes tests.
  let schemesWithTests: Set<String>
  /// Platforms to build for.
  let buildPlatforms: [ApplePlatform]
  /// Platforms to test on.
  let testPlatforms: [ApplePlatform]
  /// The destination that runs tests on each platform; platforms without one have no available simulator.
  let testDestinations: [ApplePlatform: String]
  /// Lines describing test simulators that are not a platform's test device on its newest OS.
  var simulatorNotes: [String] = []
  /// Swift packages in the repository.
  let packages: [LocalPackage]
  /// Directories of packages in submodules that the submodule policy excluded before they were examined.
  var unexaminedSubmodulePackages: [String] = []
}

/// One step of a validation plan.
struct PlannedStep: Equatable {
  /// Heading printed before the step runs.
  let title: String
  /// Short description used in the summary.
  let summary: String
  /// The command to run.
  let arguments: [String]
  /// Name of the step's log file.
  let logName: String
  /// Whether the step is recorded as skipped instead of run.
  var skipped = false
  /// The directory to run the command in, when not the repository.
  var workingDirectory: String?
}

/// Plans full validation: every product scheme built for every platform, then, platform by platform, the product
/// schemes' tests and the tests of the local packages in the product.
///
/// A product with no Xcode workspace or project builds and tests with SwiftPM on macOS, because Xcode runs a package's
/// build plugins only for its all-targets scheme, and uses `xcodebuild` only for other platforms. A package's tests run
/// through the root container's scheme for it when there is one, sharing the product's build; otherwise with SwiftPM on
/// macOS, and with `xcodebuild` in the package's own directory on other platforms.
enum ValidationPlan {
  /// Returns the packages whose tests run: those with tests that the product uses, in the repository or in a submodule
  /// the policy includes, and not excluded by name.
  static func testedPackages(_ packages: [LocalPackage], testSubmodules: TestSubmodules, excluded: [String]) -> [LocalPackage] {
    packages.filter { package in
      guard package.hasTests, package.inProduct, !excluded.contains(package.name) else { return false }
      guard package.submodule != nil else { return true }
      switch testSubmodules {
        case .always: return true
        case .never: return false
        case .changed: return package.submoduleChanged
      }
    }
  }

  /// Returns one line per local package, sorted by repository-relative path, with its name, saying how its tests run or
  /// why they do not.
  static func packageSummaries(for project: ValidationProject, testSubmodules: TestSubmodules, excludedPackages: [String], repoPath: String) -> [String] {
    let repo = ValidationPaths.canonical(repoPath)
    func relative(_ directory: String) -> String {
      let path = ValidationPaths.canonical(directory)
      return path == repo ? "." : path.hasPrefix("\(repo)/") ? String(path.dropFirst(repo.count + 1)) : path
    }
    let submoduleReason = testSubmodules == .never ? "in a submodule, and testSubmodules is never" : "in an unchanged submodule"
    let tested = testedPackages(project.packages, testSubmodules: testSubmodules, excluded: excludedPackages)

    let summaries = project.packages.map { package -> String in
      let outcome: String
      if tested.contains(package) {
        outcome = package.scheme.map { "tested, with scheme \($0)" } ?? "tested, in its own directory"
      } else if !package.inProduct {
        outcome = "not tested, not part of the product"
      } else if !package.hasTests {
        outcome = "not tested, has no tests"
      } else if excludedPackages.contains(package.name) {
        outcome = "not tested, excluded by configuration"
      } else {
        outcome = "not tested, \(submoduleReason)"
      }
      return "\(relative(package.directory)) (\(package.name)): \(outcome)"
    }
    return (summaries + project.unexaminedSubmodulePackages.map { "\(relative($0)): not tested, \(submoduleReason)" }).sorted()
  }

  /// Returns the steps of full validation, with macOS first among the platforms. The runner stops at the first failure.
  static func steps(
    for project: ValidationProject,
    testSubmodules: TestSubmodules,
    excludedPackages: [String],
    paths: ValidationPaths,
    sandbox: EnclosingSandbox,
    disableSwiftPMSandbox: Bool,
    quiet: Bool
  ) -> [PlannedStep] {
    func usesSwiftPM(_ platform: ApplePlatform) -> Bool {
      project.container.isEmpty && platform == .macOS
    }
    func swift(_ command: String, _ packageDir: String) -> [String] {
      ValidationTool.swiftPMArguments([command], packageDir: packageDir, paths: paths, disableSandbox: disableSwiftPMSandbox)
    }

    func xcodebuild(_ scheme: String, _ destination: String, _ action: String) -> [String] {
      xcodebuildArguments(container: project.container, scheme: scheme, destination: destination, action: action, paths: paths, sandbox: sandbox, quiet: quiet)
    }

    var steps: [PlannedStep] = []
    for platform in ApplePlatform.hostFirst(project.buildPlatforms) {
      if usesSwiftPM(platform) {
        let root = ValidationPaths.canonical(paths.repoPath)
        let name = project.packages.first { ValidationPaths.canonical($0.directory) == root }?.name ?? ValidationDiscovery.repoName(paths.repoPath)
        steps.append(
          PlannedStep(
            title: "Build \(name) for macOS",
            summary: "build \(name) (macOS)",
            arguments: swift("build", paths.repoPath),
            logName: "build_\(name)_macOS"
          )
        )
        continue
      }
      for scheme in project.productSchemes {
        steps.append(
          PlannedStep(
            title: "Build \(scheme) for \(platform.rawValue)",
            summary: "build \(scheme) (\(platform.rawValue))",
            arguments: xcodebuild(scheme, platform.buildDestination, "build"),
            logName: "build_\(scheme)_\(platform.rawValue)"
          )
        )
      }
    }

    let tested = testedPackages(project.packages, testSubmodules: testSubmodules, excluded: excludedPackages)
    let productTests = project.productSchemes.filter(project.schemesWithTests.contains)
    guard !productTests.isEmpty || !tested.isEmpty else { return steps }

    for platform in ApplePlatform.hostFirst(project.testPlatforms) {
      guard let destination = project.testDestinations[platform] else {
        steps.append(PlannedStep(title: "", summary: "test \(platform.rawValue) (no available simulator)", arguments: [], logName: "", skipped: true))
        continue
      }

      var containerSchemes: [String] = []
      for scheme in productTests where !containerSchemes.contains(scheme) {
        containerSchemes.append(scheme)
      }
      for package in tested where !usesSwiftPM(platform) {
        if let scheme = package.scheme, !containerSchemes.contains(scheme) {
          containerSchemes.append(scheme)
        }
      }
      for scheme in containerSchemes {
        steps.append(
          PlannedStep(
            title: "Test \(scheme) on \(platform.rawValue)",
            summary: "test \(scheme) (\(platform.rawValue))",
            arguments: xcodebuild(scheme, destination, "test"),
            logName: "test_\(scheme)_\(platform.rawValue)"
          )
        )
      }

      for package in tested where package.scheme == nil || usesSwiftPM(platform) {
        let summary = "test \(package.name) (\(platform.rawValue))"
        let logName = "test_\(package.name)_\(platform.rawValue)"
        if platform == .macOS {
          steps.append(PlannedStep(title: "Test \(package.name) on macOS", summary: summary, arguments: swift("test", package.directory), logName: logName))
        } else if let scheme = package.packageScheme {
          let arguments = xcodebuildArguments(
            container: [],
            scheme: scheme,
            destination: destination,
            action: "test",
            derivedDataPath: paths.packageDerivedDataPath(forPackage: package.directory),
            paths: paths,
            sandbox: sandbox,
            quiet: quiet
          )
          steps.append(
            PlannedStep(
              title: "Test \(package.name) on \(platform.rawValue)",
              summary: summary,
              arguments: arguments,
              logName: logName,
              workingDirectory: package.directory
            )
          )
        } else {
          steps.append(PlannedStep(title: "", summary: "\(summary) (no Xcode scheme for the package)", arguments: [], logName: "", skipped: true))
        }
      }
    }
    return steps
  }

  /// Returns the steps of the fast phase: whole packages, then changed targets, then the product for macOS when a
  /// change outside every package needs it, are built; then whole packages and the affected test targets are tested.
  /// Package steps use SwiftPM; the product builds with `xcodebuild`, and only when there is a workspace or project.
  static func fastSteps(
    for scope: FastScope,
    packages: [(directory: String, description: SwiftPackageDescription)],
    container: [String],
    productSchemes: [String],
    paths: ValidationPaths,
    sandbox: EnclosingSandbox,
    disableSwiftPMSandbox: Bool,
    quiet: Bool
  ) -> [PlannedStep] {
    func swift(_ command: String, _ packageDir: String, _ extra: [String] = []) -> [String] {
      ValidationTool.swiftPMArguments([command], packageDir: packageDir, paths: paths, disableSandbox: disableSwiftPMSandbox) + extra
    }
    func description(_ directory: String) -> SwiftPackageDescription? {
      packages.first { $0.directory == directory }?.description
    }
    func step(_ summary: String, _ arguments: [String], _ logName: String) -> PlannedStep {
      PlannedStep(title: summary.prefix(1).uppercased() + summary.dropFirst(), summary: summary, arguments: arguments, logName: "fast_\(logName)")
    }

    var steps: [PlannedStep] = []
    for directory in scope.wholePackages {
      let name = description(directory)?.name ?? URL(fileURLWithPath: directory).lastPathComponent
      steps.append(step("build \(name) package", swift("build", directory), "build_package_\(directory)"))
    }
    for target in scope.builds {
      steps.append(step("build \(target.name)", swift("build", target.packageDirectory, ["--target", target.name]), "build_\(target.name)_\(target.packageDirectory)"))
    }
    if !scope.productSources.isEmpty, !container.isEmpty {
      for scheme in productSchemes {
        let arguments = xcodebuildArguments(
          container: container,
          scheme: scheme,
          destination: ApplePlatform.macOS.buildDestination,
          action: "build",
          paths: paths,
          sandbox: sandbox,
          quiet: quiet
        )
        steps.append(step("build \(scheme) (macOS)", arguments, "build_\(scheme)_macOS"))
      }
    }
    for directory in scope.wholePackages where description(directory)?.hasTestTargets ?? false {
      let name = description(directory)?.name ?? URL(fileURLWithPath: directory).lastPathComponent
      steps.append(step("test \(name) package", swift("test", directory), "test_package_\(directory)"))
    }
    for target in scope.tests {
      steps.append(step("test \(target.name)", swift("test", target.packageDirectory, ["--filter", target.name]), "test_\(target.name)_\(target.packageDirectory)"))
    }
    return steps
  }

  /// Returns the `xcodebuild` arguments for one scheme, destination, and action, in validation's build directory unless
  /// `derivedDataPath` names another.
  static func xcodebuildArguments(
    container: [String],
    scheme: String,
    destination: String,
    action: String,
    derivedDataPath: String? = nil,
    paths: ValidationPaths,
    sandbox: EnclosingSandbox,
    quiet: Bool
  ) -> [String] {
    ["xcodebuild"] + container + ["-scheme", scheme, "-destination", destination, "-derivedDataPath", derivedDataPath ?? paths.derivedDataPath]
      + XcodeDestinations.trustArguments + sandbox.xcodebuildDefaults + (quiet ? ["-quiet"] : []) + ["CODE_SIGNING_ALLOWED=NO"]
      + sandbox.xcodebuildBuildSettings + [action]
  }
}
