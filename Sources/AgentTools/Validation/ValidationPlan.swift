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
}

/// Plans full validation: every product scheme built for every platform, then, platform by platform, the product
/// schemes' tests and the tests of the local packages in the product.
///
/// A product with no Xcode workspace or project builds and tests with SwiftPM on macOS, because Xcode runs a package's
/// build plugins only for its all-targets scheme, and uses `xcodebuild` only for other platforms.
enum ValidationPlan {
  /// Returns the packages whose tests run: those with tests that are part of the product, in the repository or in a
  /// submodule the policy includes, and not excluded by name.
  static func testedPackages(_ packages: [LocalPackage], testSubmodules: TestSubmodules, excluded: [String]) -> [LocalPackage] {
    packages.filter { package in
      guard package.hasTests, package.scheme != nil, !excluded.contains(package.name) else { return false }
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
    var testSchemes: [String] = []
    for scheme in project.productSchemes.filter(project.schemesWithTests.contains) + tested.compactMap(\.scheme) where !testSchemes.contains(scheme) {
      testSchemes.append(scheme)
    }
    guard !testSchemes.isEmpty else { return steps }

    for platform in ApplePlatform.hostFirst(project.testPlatforms) {
      if usesSwiftPM(platform) {
        for package in tested {
          steps.append(
            PlannedStep(
              title: "Test \(package.name) on macOS",
              summary: "test \(package.name) (macOS)",
              arguments: swift("test", package.directory),
              logName: "test_\(package.name)_macOS"
            )
          )
        }
        continue
      }
      guard let destination = project.testDestinations[platform] else {
        steps.append(PlannedStep(title: "", summary: "test \(platform.rawValue) (no available simulator)", arguments: [], logName: "", skipped: true))
        continue
      }
      for scheme in testSchemes {
        steps.append(
          PlannedStep(
            title: "Test \(scheme) on \(platform.rawValue)",
            summary: "test \(scheme) (\(platform.rawValue))",
            arguments: xcodebuild(scheme, destination, "test"),
            logName: "test_\(scheme)_\(platform.rawValue)"
          )
        )
      }
    }
    return steps
  }
}
