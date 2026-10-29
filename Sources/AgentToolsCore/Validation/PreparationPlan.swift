// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Plans dependency materialisation in the directories used by targeted and full validation.
enum PreparationPlan {
  /// Resolves each discovered package for targeted SwiftPM runs, even when the product scheme covers its tests.
  /// Xcode resolution covers product schemes and the independent package containers full validation uses.
  static func steps(for project: ValidationProject, config: ValidationConfig, paths: ValidationPaths, sandbox: EnclosingSandbox) -> [PlannedStep] {
    var steps = project.packages.map { package in
      PlannedStep(
        title: "Resolve \(package.name) with SwiftPM", summary: "resolve \(package.name) (SwiftPM)",
        arguments: ValidationTool.swiftPMArguments(["package"], packageDir: package.directory, paths: paths, disableSandbox: config.swiftPMDisableSandbox || sandbox.isNested) + ["resolve"],
        logName: "prepare_swiftpm_\(package.directory)"
      )
    }
    let tested = ValidationPlan.testedPackages(project.packages, testSubmodules: config.testSubmodules, excluded: config.excludedPackages).filter { $0.coveredBy == nil }
    let usesXcode = !project.container.isEmpty || (project.buildPlatforms + project.testPlatforms).contains { $0 != .macOS }
    if usesXcode {
      var schemes = project.productSchemes
      for scheme in tested.compactMap(\.scheme) where !schemes.contains(scheme) {
        schemes.append(scheme)
      }
      for scheme in schemes {
        steps.append(xcodeStep(container: project.container, scheme: scheme, directory: nil, derivedDataPath: paths.derivedDataPath, sandbox: sandbox))
      }
    }
    if project.testPlatforms.contains(where: { $0 != .macOS }) {
      for package in tested where package.scheme == nil {
        if let scheme = package.packageScheme {
          steps.append(xcodeStep(container: [], scheme: scheme, directory: package.directory, derivedDataPath: paths.packageDerivedDataPath(forPackage: package.directory), sandbox: sandbox))
        }
      }
    }
    return steps
  }

  /// Creates an Xcode resolution step without building targets or selecting a simulator.
  private static func xcodeStep(container: [String], scheme: String, directory: String?, derivedDataPath: String, sandbox: EnclosingSandbox) -> PlannedStep {
    PlannedStep(
      title: "Resolve \(scheme) with Xcode", summary: "resolve \(scheme) (Xcode)",
      arguments: ["xcodebuild"] + container + ["-scheme", scheme, "-derivedDataPath", derivedDataPath] + XcodeDestinations.trustArguments + sandbox.xcodebuildDefaults + ["-resolvePackageDependencies"],
      logName: "prepare_xcode_\(directory ?? "product")_\(scheme)", workingDirectory: directory
    )
  }
}
