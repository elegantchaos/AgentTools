// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

@testable import AgentTools

/// Tests how the fast phase finds what a change touched and what to build and test.
struct FastScopeTests {
  @Test func changedPathsComeFromPorcelainStatus() {
    let status = " M Sources/App.swift\0?? Notes.md\0R  New.swift\0Old.swift\0 D Gone.swift\0 M Dependencies/Logger\0"
    #expect(SubmoduleStatus.changedPaths(fromPorcelainZ: status) == ["Sources/App.swift", "Notes.md", "New.swift", "Gone.swift", "Dependencies/Logger"])
  }

  @Test func changedFilesMapToTargetsAndTheirTests() {
    let scope = FastScope(
      changedFiles: [
        "Dependencies/Core/Sources/Core/Repo.swift",
        "Dependencies/Core/Sources/Core/Model/State.swift",
        "Dependencies/Core/Tests/CoreTests/RepoTests.swift",
        "Dependencies/Kit/Package.swift",
        "Dependencies/Logger",
        "Sources/App/AppDelegate.swift",
        "Sources/App/Resources/Localizable.xcstrings",
        "README.md",
        "Dependencies/Core/README.md",
      ],
      packages: examplePackages,
      repoPath: "/repo"
    )

    #expect(scope.builds == [PackageTarget(packageDirectory: "/repo/Dependencies/Core", name: "Core")])
    #expect(
      scope.tests == [
        PackageTarget(packageDirectory: "/repo/Dependencies/Core", name: "CoreTests"),
        PackageTarget(packageDirectory: "/repo/Dependencies/Core", name: "ModelTests"),
      ]
    )
    #expect(scope.wholePackages == ["/repo/Dependencies/Kit", "/repo/Dependencies/Logger"])
    #expect(scope.productSources == ["Sources/App/AppDelegate.swift", "Sources/App/Resources/Localizable.xcstrings"])
    #expect(
      scope.assignments == [
        "Dependencies/Core/Sources/Core/Repo.swift: target Core in Dependencies/Core",
        "Dependencies/Core/Sources/Core/Model/State.swift: target Core in Dependencies/Core",
        "Dependencies/Core/Tests/CoreTests/RepoTests.swift: target CoreTests in Dependencies/Core",
        "Dependencies/Kit/Package.swift: package Kit",
        "Dependencies/Logger: package Logger",
        "Sources/App/AppDelegate.swift: the product",
        "Sources/App/Resources/Localizable.xcstrings: the product",
        "README.md: ignored",
        "Dependencies/Core/README.md: ignored",
      ]
    )
  }

  @Test func buildInputsOutsideEveryTargetNeedTheProduct() {
    let rootPackage = ("/repo", SwiftPackageDescription(name: "Root", targets: [.init(name: "Tool", type: "executable", path: "Sources/Tool")]))
    let scope = FastScope(
      changedFiles: ["App.xcodeproj/xcshareddata/xcschemes/App.xcscheme", "Sources/Tool/main.swift", "Notes.md"],
      packages: [rootPackage],
      repoPath: "/repo"
    )

    #expect(scope.productSources == ["App.xcodeproj/xcshareddata/xcschemes/App.xcscheme"])
    #expect(scope.builds == [PackageTarget(packageDirectory: "/repo", name: "Tool")])
    #expect(scope.assignments.last == "Notes.md: ignored")
  }

  @Test func namedTargetsResolveToTheirPackages() {
    let scope = FastScope(targets: ["Core", "KitTests", "App"], packages: examplePackages)

    #expect(scope.builds == [PackageTarget(packageDirectory: "/repo/Dependencies/Core", name: "Core")])
    #expect(
      scope.tests == [
        PackageTarget(packageDirectory: "/repo/Dependencies/Core", name: "CoreTests"),
        PackageTarget(packageDirectory: "/repo/Dependencies/Core", name: "ModelTests"),
        PackageTarget(packageDirectory: "/repo/Dependencies/Kit", name: "KitTests"),
      ]
    )
    #expect(scope.unmatchedTargets == ["App"])
  }

  @Test func fastStepsBuildBeforeTesting() {
    let scope = FastScope(
      changedFiles: ["Dependencies/Core/Sources/Core/Repo.swift", "Dependencies/Kit/Package.swift", "Sources/App/AppDelegate.swift"],
      packages: examplePackages,
      repoPath: "/repo"
    )

    let steps = ValidationPlan.fastSteps(
      for: scope,
      packages: examplePackages,
      container: ["-workspace", "/repo/App.xcworkspace"],
      productSchemes: ["App"],
      paths: ValidationPaths(repoPath: "/repo"),
      sandbox: EnclosingSandbox(isNested: false),
      disableSwiftPMSandbox: false,
      quiet: true
    )

    #expect(steps.map(\.summary) == ["build Kit package", "build Core", "build App (macOS)", "test Kit package", "test CoreTests", "test ModelTests"])
    #expect(steps[1].arguments == ["swift", "build", "--package-path", "/repo/Dependencies/Core", "--scratch-path", "/repo/.build/agt/swiftpm/packages/Dependencies/Core", "--target", "Core"])
    #expect(steps[4].arguments.suffix(2) == ["--filter", "CoreTests"])
    #expect(steps[2].arguments.prefix(6) == ["xcodebuild", "-workspace", "/repo/App.xcworkspace", "-scheme", "App", "-destination"])
  }

  @Test func productSourcesNeedAnXcodeContainer() {
    let scope = FastScope(changedFiles: ["Sources/Tool/main.swift"], packages: [], repoPath: "/repo")
    let steps = ValidationPlan.fastSteps(
      for: scope,
      packages: [],
      container: [],
      productSchemes: [],
      paths: ValidationPaths(repoPath: "/repo"),
      sandbox: EnclosingSandbox(isNested: false),
      disableSwiftPMSandbox: false,
      quiet: true
    )
    #expect(steps.isEmpty)
  }

  /// Packages in a repository at `/repo`: `Core` with a model test target that depends on it, `Kit` with its own
  /// tests, and `Logger` in a submodule.
  private let examplePackages: [(directory: String, description: SwiftPackageDescription)] = [
    (
      "/repo/Dependencies/Core",
      SwiftPackageDescription(
        name: "Core",
        targets: [
          .init(name: "Core", type: "library", path: "Sources/Core"),
          .init(name: "CoreUI", type: "library", path: "Sources/CoreUI", targetDependencies: ["Core"]),
          .init(name: "CoreTests", type: "test", path: "Tests/CoreTests", targetDependencies: ["Core", "CoreUI"]),
          .init(name: "ModelTests", type: "test", path: "Tests/ModelTests", targetDependencies: ["Core"]),
          .init(name: "UITests", type: "test", path: "Tests/UITests", targetDependencies: ["CoreUI"]),
        ]
      )
    ),
    (
      "/repo/Dependencies/Kit",
      SwiftPackageDescription(
        name: "Kit",
        targets: [
          .init(name: "Kit", type: "library", path: "Sources/Kit"),
          .init(name: "KitTests", type: "test", path: "Tests/KitTests", targetDependencies: ["Kit"]),
        ]
      )
    ),
    ("/repo/Dependencies/Logger", SwiftPackageDescription(name: "Logger", targets: [.init(name: "Logger", type: "library", path: "Sources/Logger")])),
  ]
}
