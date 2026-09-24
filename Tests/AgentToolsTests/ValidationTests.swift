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

    let buildPackageURL = repoURL.appendingPathComponent(".build/agt-validate/DerivedData/BuildArtifact")
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

  @Test func swiftPMValidationUsesSwiftBuildSystem() {
    #expect(
      ValidationTool.swiftPMArguments(["swift", "test", "--filter", "ExampleTests"]) == [
        "swift",
        "test",
        "--filter",
        "ExampleTests",
        "--build-system",
        "swiftbuild",
        "-Xswiftc",
        "-DVALIDATING",
      ]
    )
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

  @Test func invalidOutputModeThrows() {
    #expect(throws: (any Error).self) {
      _ = try ValidateCommand.parse(["--output", "loud"])
    }
  }

  @Test func defaultsUseRepoNameSchemeAndMacOSTests() throws {
    let config = try parseConfig([])
    #expect(config.target == nil)
    #expect(config.clean == false)
    #expect(config.schemes == ["Example"])
    #expect(config.destinations.isEmpty)
    #expect(config.testDestinations == ["platform=macOS"])
    #expect(config.packageDirsOverride == nil)
    #expect(config.recursivePackageDiscovery)
    #expect(config.swiftPMDisableSandbox == false)
    #expect(config.runXcodeTests == false)
  }

  @Test func explicitOptionsArePreserved() throws {
    let config = try parseConfig([
      "--target", "Core",
      "-c",
      "--workspace", "App.xcworkspace",
      "--project", "App.xcodeproj",
      "--schemes", "App, Widget",
      "--destinations", "generic/platform=macOS,generic/platform=watchOS",
      "--run-xcode-tests",
      "--test-destinations", "platform=macOS,platform=visionOS Simulator",
      "--package-dirs", "Dependencies/Core,,Tools",
      "--no-recursive-packages",
      "--swiftpm-disable-sandbox",
    ])

    #expect(config.target == "Core")
    #expect(config.clean)
    #expect(config.workspaceOverride == "App.xcworkspace")
    #expect(config.projectOverride == "App.xcodeproj")
    #expect(config.schemes == ["App", "Widget"])
    #expect(config.destinations == ["generic/platform=macOS", "generic/platform=watchOS"])
    #expect(config.runXcodeTests)
    #expect(config.testDestinations == ["platform=macOS", "platform=visionOS Simulator"])
    #expect(config.packageDirsOverride == ["Dependencies/Core", "Tools"])
    #expect(config.recursivePackageDiscovery == false)
    #expect(config.swiftPMDisableSandbox)
  }

  @Test func buildSettingsDiscoveryUsesRepoLocalDerivedData() {
    #expect(
      XcodeDestinations.showBuildSettingsArguments(
        workspace: "App.xcworkspace",
        project: nil,
        scheme: "App",
        derivedDataPath: ".build/agt-validate/DerivedData"
      ) == [
        "xcodebuild",
        "-workspace", "App.xcworkspace",
        "-scheme", "App",
        "-derivedDataPath", ".build/agt-validate/DerivedData",
        "-showBuildSettings",
        "-json",
      ]
    )
  }

  @Test func validationPathsUseRepoLocalDerivedData() throws {
    let repoURL = try makeTemporaryRepo()
    defer { try? FileManager.default.removeItem(at: repoURL) }

    let staleLogURL = repoURL.appendingPathComponent(".build/validation-logs/stale.log")
    let staleDerivedDataURL = repoURL.appendingPathComponent(".build/agt-validate/DerivedData/stale")
    try FileManager.default.createDirectory(at: staleLogURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: staleDerivedDataURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try "old log".write(to: staleLogURL, atomically: true, encoding: .utf8)
    try "old derived data".write(to: staleDerivedDataURL, atomically: true, encoding: .utf8)

    let paths = try ValidationPaths.prepare(repoPath: repoURL.path, clean: true)

    #expect(paths.logRoot == repoURL.appendingPathComponent(".build/validation-logs").path)
    #expect(paths.derivedDataPath == repoURL.appendingPathComponent(".build/agt-validate/DerivedData").path)
    #expect(FileManager.default.fileExists(atPath: paths.logRoot))
    #expect(FileManager.default.fileExists(atPath: paths.derivedDataPath))
    #expect(!FileManager.default.fileExists(atPath: staleLogURL.path))
    #expect(!FileManager.default.fileExists(atPath: staleDerivedDataURL.path))
  }

  @Test func logPathsAreSanitized() {
    let paths = ValidationPaths(logRoot: "/repo/.build/validation-logs", derivedDataPath: "/repo/.build/agt-validate/DerivedData")
    #expect(paths.logPath("swift_build_/repo/Sub Package") == "/repo/.build/validation-logs/swift_build_repo_Sub_Package.log")
  }

  @Test(arguments: [
    ("error: cannot find type 'Foo' in scope", "error: cannot find type 'Foo' in scope"),
    ("warning: deprecated API", "warning: deprecated API"),
    ("note: expanded from macro", "note: expanded from macro"),
    ("** BUILD FAILED **", "** BUILD FAILED **"),
    ("remark: compiled module was created by a different version of the compiler", nil),
    ("CompileSwift normal arm64 MyFile.swift", nil),
  ])
  func filteredValidationLineBehavior(line: String, expected: String?) {
    #expect(ValidationOutput.filteredLine(line) == expected)
  }

  @Test func warningDetectionUsesFilteredLines() {
    #expect(ValidationOutput.containsWarnings("Compiling\n/tmp/A.swift:1:1: warning: unused\n"))
    #expect(ValidationOutput.containsWarnings("Compiling\nBUILD SUCCEEDED\n") == false)
  }

  @Test func buildDestinationMapsSupportedSDKPlatforms() {
    #expect(XcodeDestinations.destination(forSupportedPlatform: "macosx") == "generic/platform=macOS")
    #expect(XcodeDestinations.destination(forSupportedPlatform: "iphoneos") == "generic/platform=iOS")
    #expect(XcodeDestinations.destination(forSupportedPlatform: "iphonesimulator") == "generic/platform=iOS")
    #expect(XcodeDestinations.destination(forSupportedPlatform: "appletvos") == "generic/platform=tvOS")
    #expect(XcodeDestinations.destination(forSupportedPlatform: "appletvsimulator") == "generic/platform=tvOS")
    #expect(XcodeDestinations.destination(forSupportedPlatform: "watchos") == "generic/platform=watchOS")
    #expect(XcodeDestinations.destination(forSupportedPlatform: "watchsimulator") == "generic/platform=watchOS")
    #expect(XcodeDestinations.destination(forSupportedPlatform: "xros") == "generic/platform=visionOS")
    #expect(XcodeDestinations.destination(forSupportedPlatform: "xrsimulator") == "generic/platform=visionOS")
    #expect(XcodeDestinations.destination(forSupportedPlatform: "driverkit") == nil)
  }

  @Test func buildDestinationsDecodeSupportedPlatformsFromBuildSettings() throws {
    let output = """
      [
        {
          "buildSettings": {
            "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator"
          }
        },
        {
          "buildSettings": {
            "SUPPORTED_PLATFORMS": "macosx watchos watchsimulator"
          }
        }
      ]
      """

    #expect(
      try XcodeDestinations.destinations(fromBuildSettingsJSON: output) == [
        "generic/platform=iOS",
        "generic/platform=macOS",
        "generic/platform=watchOS",
      ]
    )
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
