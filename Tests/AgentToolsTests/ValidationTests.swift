// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

@testable import AgentTools

/// Tests option parsing, package discovery, and output shaping used by `agt validate`.
struct ValidationTests {
  @Test func recursiveDiscoveryFindsSiblingPackagesAfterBuildArtifacts() throws {
    let repoURL = try makeTemporaryRepo()
    defer { try? FileManager.default.removeItem(at: repoURL) }

    try writePackage(at: repoURL)
    _ = try ValidationPaths.prepare(repoPath: repoURL.path, clean: false)

    let buildPackageURL = repoURL.appendingPathComponent(".build/agt/DerivedData/BuildArtifact")
    try writePackage(at: buildPackageURL)

    let nestedPackageURL = repoURL.appendingPathComponent("Dependencies/ExamplePackage")
    try writePackage(at: nestedPackageURL)

    let packages = Set(ValidationDiscovery.packageDirectories(repoPath: repoURL.path, overrides: nil, recursive: true))

    #expect(packages.contains(repoURL.path))
    #expect(packages.contains(nestedPackageURL.path))
    #expect(packages.contains(buildPackageURL.path) == false)
  }

  @Test func recursiveDiscoverySkipsPackagesUnderTestResources() throws {
    let repoURL = try makeTemporaryRepo()
    defer { try? FileManager.default.removeItem(at: repoURL) }

    try writePackage(at: repoURL)

    let nestedURL = repoURL.appendingPathComponent("Examples/NestedPackage")
    try writePackage(at: nestedURL)

    let fixtureURL = repoURL.appendingPathComponent("Tests/ExampleTests/Resources/Example-old.package")
    try writePackage(at: fixtureURL)

    let indexBuildPackageURL = repoURL.appendingPathComponent(".index-build/checkouts/Dependency")
    try writePackage(at: indexBuildPackageURL)

    let packages = Set(ValidationDiscovery.packageDirectories(repoPath: repoURL.path, overrides: nil, recursive: true))

    #expect(packages.contains(repoURL.path))
    #expect(packages.contains(nestedURL.path))
    #expect(!packages.contains(fixtureURL.path))
    #expect(!packages.contains(indexBuildPackageURL.path))
  }

  @Test func packageDirOverridesCanIncludeFixturePackages() throws {
    let repoURL = try makeTemporaryRepo()
    defer { try? FileManager.default.removeItem(at: repoURL) }

    try writePackage(at: repoURL)

    let fixtureRelativePath = "Tests/ExampleTests/Resources/Example-old.package"
    let fixtureURL = repoURL.appendingPathComponent(fixtureRelativePath)
    try writePackage(at: fixtureURL)

    let packages = ValidationDiscovery.packageDirectories(
      repoPath: repoURL.path,
      overrides: [fixtureRelativePath],
      recursive: true
    )

    #expect(packages == [fixtureURL.path])
  }

  @Test(arguments: [
    ("Tests/FooTests/Resources/Example.package", true),
    ("Tests/Fixtures/Resources/Nested/FixturePackage", true),
    ("Examples/Resources/NestedPackage", false),
    ("Tests/FooTests/Support/HelperPackage", false),
  ])
  func ignoredDiscoveryPaths(path: String, expected: Bool) {
    #expect(ValidationDiscovery.isInTestResources(path) == expected)
  }

  @Test(arguments: [
    (SwiftPackageDescription(targets: [.init(name: "Library", type: "regular")]), false),
    (SwiftPackageDescription(targets: [.init(name: "Library", type: "regular"), .init(name: "LibraryTests", type: "test")]), true),
  ])
  func packageTestTargetDetection(package: SwiftPackageDescription, expected: Bool) {
    #expect(package.hasTestTargets == expected)
  }

  @Test func swiftPMArgumentsUseAPrivateBuildDirectory() {
    #expect(
      ValidationTool.swiftPMArguments(["build"], packageDir: "/repo/Dependencies/Core", paths: examplePaths, disableSandbox: false) == [
        "swift", "build",
        "--package-path", "/repo/Dependencies/Core",
        "--scratch-path", "/repo/.build/agt/swiftpm/packages/Dependencies/Core",
      ]
    )
  }

  @Test func rootPackageScratchPathIsSeparateFromNestedPackages() {
    #expect(examplePaths.swiftPMScratchPath(forPackage: "/repo") == "/repo/.build/agt/swiftpm/root")
    #expect(examplePaths.swiftPMScratchPath(forPackage: "/repo/Tools") == "/repo/.build/agt/swiftpm/packages/Tools")
  }

  @Test func scratchPathsMatchSymlinkedSpellingsOfTheRepository() {
    let paths = ValidationPaths(repoPath: "/private/var/folders/repo")
    #expect(paths.swiftPMScratchPath(forPackage: "/var/folders/repo") == "/private/var/folders/repo/.build/agt/swiftpm/root")
    #expect(paths.swiftPMScratchPath(forPackage: "/var/folders/repo/Tools") == "/private/var/folders/repo/.build/agt/swiftpm/packages/Tools")
  }

  @Test func swiftPMArgumentsCanDisableSandbox() {
    #expect(
      ValidationTool.swiftPMArguments(["package"], packageDir: "/repo", paths: examplePaths, disableSandbox: true).last == "--disable-sandbox"
    )
  }

  @Test(arguments: [
    (Int32(71), "sandbox-exec: sandbox_apply: Operation not permitted", true),
    (Int32(0), "", false),
    (Int32(1), "sandbox-exec: invalid profile", false),
  ])
  func nestedSandboxDetection(status: Int32, stderr: String, expected: Bool) {
    #expect(EnclosingSandbox.isNestedFailure(status: status, stderr: stderr) == expected)
  }

  @Test func nestedSandboxTurnsOffXcodeSandboxes() {
    let nested = EnclosingSandbox(isNested: true)
    #expect(nested.xcodebuildDefaults == ["-IDEPackageSupportDisableManifestSandbox=YES", "-IDEPackageSupportDisablePluginExecutionSandbox=YES"])
    #expect(nested.xcodebuildBuildSettings == ["SWIFTC_DISABLE_SANDBOX=YES", "ENABLE_USER_SCRIPT_SANDBOXING=NO"])
    #expect(EnclosingSandbox(isNested: false).xcodebuildDefaults.isEmpty)
    #expect(EnclosingSandbox(isNested: false).xcodebuildBuildSettings.isEmpty)
  }

  @Test(arguments: [
    (["--output", "filtered"], ValidateOutputMode.filtered),
    (["--output", "quiet"], ValidateOutputMode.quiet),
    (["--output", "raw"], ValidateOutputMode.raw),
    (["--raw"], ValidateOutputMode.raw),
    (["--quiet"], ValidateOutputMode.quiet),
    ([], ValidateOutputMode.filtered),
  ])
  func outputModeParsing(arguments: [String], expected: ValidateOutputMode) throws {
    let config = try parseConfig(arguments)
    #expect(config.outputMode == expected)
  }

  @Test func planDefaultsToOff() throws {
    #expect(try parseConfig([]).planOnly == false)
    #expect(try parseConfig(["--plan"]).planOnly)
  }

  @Test func planningRecordsStepsWithoutRunningThem() throws {
    let runner = StepRunner(repoPath: "/", outputMode: .quiet, planOnly: true)
    try runner.run(title: "Fail", summary: "fail", arguments: ["false"], logPath: "/nonexistent/fail.log")
    #expect(runner.plannedCommands == [["false"]])
  }

  @Test func invalidOutputModeThrows() {
    #expect(throws: (any Error).self) {
      _ = try ValidateCommand.parse(["--output", "loud"])
    }
  }

  @Test func defaultsLeaveSchemesAndPlatformsToDiscovery() throws {
    let config = try parseConfig([])
    #expect(config.target == nil)
    #expect(config.clean == false)
    #expect(config.schemes.isEmpty)
    #expect(config.platforms.isEmpty)
    #expect(config.testPlatforms.isEmpty)
    #expect(config.testSubmodules == .changed)
    #expect(config.excludedPackages.isEmpty)
    #expect(config.packageDirsOverride == nil)
    #expect(config.recursivePackageDiscovery)
    #expect(config.swiftPMDisableSandbox == false)
  }

  @Test func explicitOptionsArePreserved() throws {
    let config = try parseConfig([
      "--target", "Core",
      "-c",
      "--workspace", "App.xcworkspace",
      "--project", "App.xcodeproj",
      "--schemes", "App, Widget",
      "--platforms", "macOS,watchOS",
      "--test-platforms", "macOS",
      "--test-submodules", "always",
      "--package-dirs", "Dependencies/Core,,Tools",
      "--no-recursive-packages",
      "--swiftpm-disable-sandbox",
    ])

    #expect(config.target == "Core")
    #expect(config.clean)
    #expect(config.workspaceOverride == "App.xcworkspace")
    #expect(config.projectOverride == "App.xcodeproj")
    #expect(config.schemes == ["App", "Widget"])
    #expect(config.platforms == [.macOS, .watchOS])
    #expect(config.testPlatforms == [.macOS])
    #expect(config.testSubmodules == .always)
    #expect(config.packageDirsOverride == ["Dependencies/Core", "Tools"])
    #expect(config.recursivePackageDiscovery == false)
    #expect(config.swiftPMDisableSandbox)
  }

  @Test func buildSettingsDiscoveryUsesValidationDirectories() {
    #expect(
      XcodeDestinations.showBuildSettingsArguments(
        container: ["-workspace", "App.xcworkspace"],
        scheme: "App",
        paths: examplePaths,
        sandbox: EnclosingSandbox(isNested: true)
      ) == [
        "xcodebuild",
        "-workspace", "App.xcworkspace",
        "-scheme", "App",
        "-derivedDataPath", "/repo/.build/agt/DerivedData",
        "-skipPackagePluginValidation",
        "-skipMacroValidation",
        "-IDEPackageSupportDisableManifestSandbox=YES",
        "-IDEPackageSupportDisablePluginExecutionSandbox=YES",
        "-showBuildSettings",
        "-json",
      ]
    )
  }

  @Test func validationPathsLiveUnderBuildAgt() throws {
    let repoURL = try makeTemporaryRepo()
    defer { try? FileManager.default.removeItem(at: repoURL) }

    let staleURL = repoURL.appendingPathComponent(".build/agt/logs/stale.log")
    let userBuildURL = repoURL.appendingPathComponent(".build/debug/keep")
    let backgroundURL = repoURL.appendingPathComponent(".build/agt/background/status.json")
    for url in [staleURL, userBuildURL, backgroundURL] {
      try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      try "old".write(to: url, atomically: true, encoding: .utf8)
    }
    let paths = try ValidationPaths.prepare(repoPath: repoURL.path, clean: true)

    #expect(paths.logRoot == repoURL.appendingPathComponent(".build/agt/logs").path)
    #expect(paths.derivedDataPath == repoURL.appendingPathComponent(".build/agt/DerivedData").path)
    #expect(FileManager.default.fileExists(atPath: paths.logRoot))
    #expect(!FileManager.default.fileExists(atPath: staleURL.path))
    #expect(FileManager.default.fileExists(atPath: userBuildURL.path))
    #expect(FileManager.default.fileExists(atPath: backgroundURL.path))
  }

  @Test func logPathsAreSanitized() {
    #expect(examplePaths.logPath("swift_build_/repo/Sub Package") == "/repo/.build/agt/logs/swift_build_repo_Sub_Package.log")
  }

  @Test(arguments: [
    ("error: cannot find type 'Foo' in scope", "error: cannot find type 'Foo' in scope"),
    ("warning: deprecated API", "warning: deprecated API"),
    ("note: expanded from macro", "note: expanded from macro"),
    ("** BUILD FAILED **", "** BUILD FAILED **"),
    ("remark: compiled module was created by a different version of the compiler", nil),
    ("warning: /Users/me/Library/org.swift.swiftpm/configuration is not accessible or not writable, disabling user-level cache features.", nil),
    ("CompileSwift normal arm64 MyFile.swift", nil),
  ])
  func filteredValidationLineBehavior(line: String, expected: String?) {
    #expect(ValidationOutput.filteredLine(line) == expected)
  }

  @Test func warningDetectionUsesFilteredLines() {
    #expect(ValidationOutput.containsWarnings("Compiling\n/tmp/A.swift:1:1: warning: unused\n"))
    #expect(ValidationOutput.containsWarnings("Compiling\nBUILD SUCCEEDED\n") == false)
  }

  @Test(arguments: [
    ("/tmp/A.swift:1:1: warning: unused", true),
    ("warning: 'core': found 1 file(s) which are unhandled", true),
    ("ld: warning: object file was built for a newer macOS version", true),
    ("2026-09-25 appintentsmetadataprocessor[1:2] warning: Metadata extraction skipped.", true),
    ("􀟈  Test case passing 2 arguments line → \"warning: deprecated API\" started.", false),
    ("􀟈  Test warningDetection() started.", false),
    ("􀟈  Test case passing 2 arguments line → \"/tmp/A.swift:1:1: warning: unused\", expected → true started.", false),
    ("◇ Test case passing 1 argument line → \"ld: warning: old\" started.", false),
    ("--- xcodebuild: WARNING: Using the first of multiple matching destinations:", false),
  ])
  func onlyDiagnosticWarningsCount(line: String, expected: Bool) {
    #expect(ValidationOutput.containsWarnings(line) == expected)
  }

  @Test func extractedFailureDiagnosticsPreferErrorBlock() {
    let output = """
      CompileSwift normal arm64 One.swift
      note: candidate found here
      /tmp/One.swift:42:13: error: cannot convert value
      note: expected argument type 'String'
      warning: using deprecated conversion
      ** BUILD FAILED **
      """

    #expect(
      ValidationOutput.failureDiagnostics(output) == [
        "note: candidate found here",
        "/tmp/One.swift:42:13: error: cannot convert value",
        "note: expected argument type 'String'",
        "warning: using deprecated conversion",
      ]
    )
  }

  /// Validation paths for a repository at `/repo`.
  private let examplePaths = ValidationPaths(repoPath: "/repo")

  /// Parses command-line arguments into a configuration for a repository named `Example`.
  private func parseConfig(_ arguments: [String]) throws -> ValidationConfig {
    try ValidateCommand.parse(arguments).config(repoPath: "/work/Example")
  }

  /// Creates a temporary repository root for package discovery tests.
  private func makeTemporaryRepo() throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("AgentTools-Validation-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  /// Writes the smallest possible package manifest used by discovery tests.
  private func writePackage(at url: URL) throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    let manifest = url.appendingPathComponent("Package.swift")
    try """
    // swift-tools-version:6.2
    import PackageDescription
    let package = Package(name: "\(url.lastPathComponent)")
    """
    .write(to: manifest, atomically: true, encoding: .utf8)
  }
}
