// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

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
  /// Swift packages in the repository.
  let packages: [LocalPackage]
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
      ["xcodebuild"] + project.container + ["-scheme", scheme, "-destination", destination, "-derivedDataPath", paths.derivedDataPath]
        + XcodeDestinations.trustArguments + sandbox.xcodebuildDefaults + (quiet ? ["-quiet"] : []) + ["CODE_SIGNING_ALLOWED=NO"] + sandbox.xcodebuildBuildSettings + [action]
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
          let arguments =
            ["xcodebuild", "-scheme", scheme, "-destination", destination, "-derivedDataPath", paths.packageDerivedDataPath(forPackage: package.directory)]
            + XcodeDestinations.trustArguments + sandbox.xcodebuildDefaults + (quiet ? ["-quiet"] : []) + ["CODE_SIGNING_ALLOWED=NO"]
            + sandbox.xcodebuildBuildSettings + ["test"]
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
}
