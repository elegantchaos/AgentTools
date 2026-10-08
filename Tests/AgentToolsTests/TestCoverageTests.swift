// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Testing

@testable import AgentToolsCore

/// Tests checking that the product schemes run every local package's tests.
struct TestCoverageTests {
  /// A package in the repository with two test targets.
  private let core = LocalPackage(directory: "/repo/Dependencies/Core", name: "Core", hasTests: true, scheme: nil, submodule: nil, submoduleChanged: false, testTargets: ["CoreTests", "CoreUITests"])

  /// A package in an unchanged submodule, which the submodule policy does not test separately.
  private let keychain = LocalPackage(
    directory: "/repo/Dependencies/Keychain", name: "Keychain", hasTests: true, scheme: nil, submodule: "Dependencies/Keychain", submoduleChanged: false, testTargets: ["KeychainTests"])

  /// The workspace's package members.
  private let members: Set<String> = ["/repo/Dependencies/Core", "/repo/Dependencies/Keychain"]

  /// Returns the tests of the App scheme, listing the given targets.
  private func appTests(_ targets: [TestTarget]) -> [String: SchemeTests] {
    ["App": SchemeTests(testPlan: "Full Validation", source: "test plan Full Validation", targets: targets)]
  }

  /// Checks coverage of `core` and `keychain`, where only `core` would be tested separately.
  private func check(_ schemeTests: [String: SchemeTests], members: Set<String>? = nil, excluded: [String] = []) -> TestCoverage {
    TestCoverage.check(packages: [core, keychain], tested: [core], excluded: excluded, schemeTests: schemeTests, workspaceMembers: members ?? self.members, repoPath: "/repo")
  }

  /// A package whose every test target a scheme runs is covered by that scheme.
  @Test func coversPackagesWhoseTestsTheSchemeRuns() {
    let coverage = check(
      appTests([
        TestTarget(container: "/repo/Dependencies/Core", name: "CoreTests"), TestTarget(container: "/repo/Dependencies/Core", name: "CoreUITests"),
        TestTarget(container: "/repo/Dependencies/Keychain", name: "KeychainTests"),
      ]))
    #expect(coverage.schemes == ["/repo/Dependencies/Core": "App", "/repo/Dependencies/Keychain": "App"])
    #expect(coverage.warnings.isEmpty)
  }

  /// A package with a test target the scheme does not run is not covered. It is named in a warning when it will be
  /// tested separately; a package the submodule policy leaves untested is not.
  @Test func warnsAboutMissingTargets() {
    let coverage = check(appTests([TestTarget(container: "/repo/Dependencies/Core", name: "CoreTests")]))
    #expect(coverage.schemes.isEmpty)
    #expect(
      coverage.warnings == [
        "Dependencies/Core (Core): scheme App (test plan Full Validation) does not run CoreUITests; testing the package separately."
      ]
    )
  }

  /// A package whose test target the scheme filters is not covered, and the warning says which targets run only in part.
  @Test func warnsAboutFilteredTargets() {
    let coverage = check(
      appTests([TestTarget(container: "/repo/Dependencies/Core", name: "CoreTests", isFiltered: true), TestTarget(container: "/repo/Dependencies/Keychain", name: "KeychainTests")]))
    #expect(coverage.schemes == ["/repo/Dependencies/Keychain": "App"])
    #expect(
      coverage.warnings == [
        "Dependencies/Core (Core): scheme App (test plan Full Validation) does not run CoreUITests, and runs only some tests of CoreTests; testing the package separately."
      ]
    )
  }

  /// A listed package that is not a workspace member is skipped by Xcode, so it is not covered.
  @Test func warnsAboutPackagesOutsideTheWorkspace() {
    let coverage = check(
      appTests([TestTarget(container: "/repo/Dependencies/Core", name: "CoreTests"), TestTarget(container: "/repo/Dependencies/Core", name: "CoreUITests")]),
      members: ["/repo/Dependencies/Keychain"],
      excluded: ["Keychain"]
    )
    #expect(coverage.schemes.isEmpty)
    #expect(
      coverage.warnings == [
        "Dependencies/Core (Core): scheme App (test plan Full Validation) lists its tests, but Xcode skips them because the package is not a workspace member; testing the package separately."
      ]
    )
  }

  /// Excluded packages, packages outside the product, and packages without tests are not checked.
  @Test func ignoresPackagesThatAreNotTested() {
    let demo = LocalPackage(directory: "/repo/Examples/Demo", name: "Demo", hasTests: true, scheme: nil, submodule: nil, submoduleChanged: false, inProduct: false, testTargets: ["DemoTests"])
    let icons = LocalPackage(directory: "/repo/Dependencies/Icons", name: "Icons", hasTests: false, scheme: nil, submodule: nil, submoduleChanged: false)
    let coverage = TestCoverage.check(packages: [keychain, demo, icons], tested: [], excluded: ["Keychain"], schemeTests: appTests([]), workspaceMembers: members, repoPath: "/repo")
    #expect(coverage == TestCoverage(schemes: [:], warnings: []))
  }

  /// When no product scheme runs tests, packages are tested separately as before, without warnings.
  @Test func checksNothingWithoutSchemeTests() {
    #expect(check([:]) == TestCoverage(schemes: [:], warnings: []))
  }

  /// Packages are matched under either spelling of a path through a symbolic link.
  @Test func matchesCanonicalPaths() {
    let package = LocalPackage(directory: "/var/folders/repo/Core", name: "Core", hasTests: true, scheme: nil, submodule: nil, submoduleChanged: false, testTargets: ["CoreTests"])
    let coverage = TestCoverage.check(
      packages: [package], tested: [package], excluded: [],
      schemeTests: appTests([TestTarget(container: "/private/var/folders/repo/Core", name: "CoreTests")]),
      workspaceMembers: ["/private/var/folders/repo/Core"], repoPath: "/private/var/folders/repo")
    #expect(coverage.schemes == [ValidationPaths.canonical("/var/folders/repo/Core"): "App"])
  }
}
