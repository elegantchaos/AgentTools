// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Testing

@testable import AgentToolsCore

/// Checks preparation coverage independently of installed SDKs and network dependencies.
struct PreparationPlanTests {
  /// Product-scheme test coverage must not leave a package's targeted SwiftPM directory cold.
  @Test func coveredPackagesStillResolveForTargetedValidation() throws {
    var package = localPackage()
    package.coveredBy = "App"
    let project = project(packages: [package])
    let config = try ValidateCommand.parse([]).config(repoPath: "/repo")
    let steps = PreparationPlan.steps(for: project, config: config, paths: ValidationPaths(repoPath: "/repo"), sandbox: EnclosingSandbox(isNested: true))
    #expect(steps.count == 2)
    #expect(steps[0].arguments == ["swift", "package", "--package-path", "/repo/Dependencies/Core", "--scratch-path", "/repo/.build/agt/swiftpm/packages/Dependencies/Core", "--disable-sandbox", "resolve"])
    #expect(steps[1].arguments.contains("/repo/.build/agt/DerivedData"))
    #expect(steps[1].arguments.last == "-resolvePackageDependencies")
    #expect(steps.allSatisfy { Set($0.arguments).intersection(["build", "test", "simctl"]).isEmpty })
  }

  /// Standalone package tests on other platforms need their independent Xcode checkout directory.
  @Test func standalonePackageXcodeResolutionMatchesValidation() throws {
    var package = localPackage()
    package.packageScheme = "Core-Package"
    let config = try ValidateCommand.parse([]).config(repoPath: "/repo")
    let project = project(packages: [package])
    let steps = PreparationPlan.steps(for: project, config: config, paths: ValidationPaths(repoPath: "/repo"), sandbox: EnclosingSandbox(isNested: false))
    let standalone = try #require(steps.first { $0.workingDirectory == package.directory })
    #expect(standalone.arguments.contains("/repo/.build/agt/packages/Dependencies/Core/DerivedData"))
    #expect(standalone.arguments.contains("Core-Package"))
    #expect(standalone.arguments.contains("-workspace") == false)
  }

  /// Swift-only macOS products can prepare without starting Xcode resolution steps.
  @Test func swiftOnlyProductHasOneResolutionStepPerPackage() throws {
    let config = try ValidateCommand.parse([]).config(repoPath: "/repo")
    var project = project(packages: [localPackage()])
    project = ValidationProject(container: [], productSchemes: ["Core"], schemesWithTests: [], buildPlatforms: [.macOS], testPlatforms: [.macOS], testDestinations: [:], packages: project.packages)
    let steps = PreparationPlan.steps(for: project, config: config, paths: ValidationPaths(repoPath: "/repo"), sandbox: EnclosingSandbox(isNested: false))
    #expect(steps.count == 1)
    #expect(steps[0].arguments.last == "resolve")
  }

  /// A local package eligible for targeted validation.
  private func localPackage() -> LocalPackage {
    LocalPackage(directory: "/repo/Dependencies/Core", name: "Core", hasTests: true, scheme: nil, submodule: nil, submoduleChanged: false)
  }

  /// A product building and testing on macOS and iOS.
  private func project(packages: [LocalPackage]) -> ValidationProject {
    ValidationProject(container: ["-workspace", "/repo/App.xcworkspace"], productSchemes: ["App"], schemesWithTests: ["App"], buildPlatforms: [.macOS, .iOS], testPlatforms: [.macOS, .iOS], testDestinations: [:], packages: packages)
  }
}
