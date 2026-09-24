// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

@testable import AgentTools

/// Tests how full validation chooses what to build and test.
struct ValidationPlanTests {
  @Test(arguments: [
    ("macosx", ApplePlatform.macOS),
    ("iphoneos", .iOS),
    ("iphonesimulator", .iOS),
    ("appletvsimulator", .tvOS),
    ("watchos", .watchOS),
    ("xrsimulator", .visionOS),
  ])
  func platformsFromSDKs(sdk: String, expected: ApplePlatform) {
    #expect(ApplePlatform(sdk: sdk) == expected)
  }

  @Test func unknownSDKsAndNamesAreIgnored() {
    #expect(ApplePlatform(sdk: "driverkit") == nil)
    #expect(ApplePlatform(name: "ios") == .iOS)
    #expect(ApplePlatform(name: "Android") == nil)
  }

  @Test func platformsDecodeFromBuildSettingsInOrder() throws {
    let output = #"[{"buildSettings": {"SUPPORTED_PLATFORMS": "iphoneos iphonesimulator"}}, {"buildSettings": {"SUPPORTED_PLATFORMS": "macosx watchos"}}]"#
    #expect(try XcodeDestinations.platforms(fromBuildSettingsJSON: output) == [.iOS, .macOS, .watchOS])
  }

  @Test func simulatorDestinationsPreferTheNewestOS() {
    let output = """
      Available destinations for the "App" scheme:
      		{ platform:macOS, arch:arm64, id:0000, name:My Mac }
      		{ platform:iOS Simulator, id:A, OS:26.5, name:iPhone 17 Pro }
      		{ platform:iOS Simulator, id:B, OS:27.0, name:iPhone 18 Pro }
      		{ platform:iOS Simulator, id:C, OS:27.0, name:iPhone 18 }
      		{ platform:tvOS Simulator, id:D, OS:27.0, name:Apple TV 4K (3rd generation) }
      		{ platform:iOS, id:dvtdevice-DVTiPhonePlaceholder-iphoneos:placeholder, name:Any iOS Device }
      """

    #expect(
      XcodeDestinations.testDestinations(fromShowDestinations: output) == [
        .macOS: "platform=macOS",
        .iOS: "platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0",
        .tvOS: "platform=tvOS Simulator,name=Apple TV 4K (3rd generation),OS=27.0",
      ]
    )
  }

  @Test(arguments: [
    (#"{"workspace": {"name": "App", "schemes": ["App", "Core"]}}"#, ["App", "Core"]),
    (#"{"project": {"name": "App", "schemes": ["App"], "targets": ["App"]}}"#, ["App"]),
  ])
  func schemesDecodeFromListOutput(json: String, expected: [String]) throws {
    #expect(try XcodeSchemes.schemes(fromListJSON: json) == expected)
  }

  @Test func schemeFilesWithTestableReferencesHaveTests() {
    #expect(XcodeSchemes.hasTests(schemeFile: "<TestAction><Testables><TestableReference skipped = \"NO\"></TestableReference></Testables></TestAction>"))
    #expect(!XcodeSchemes.hasTests(schemeFile: "<TestAction><Testables></Testables></TestAction>"))
  }

  @Test(arguments: [
    (["App", "Logger-Package", "Logger", "LoggerKit"], "Logger-Package"),
    (["App", "Logger", "LoggerKit"], "Logger"),
    (["App", "LoggerUI"], "LoggerUI"),
    (["App"], nil),
  ])
  func packageSchemesPreferTheAllTargetsScheme(schemes: [String], expected: String?) {
    let package = SwiftPackageDescription(name: "Logger", products: [.init(name: "Logger"), .init(name: "LoggerUI")], targets: [])
    #expect(LocalPackage.scheme(for: package, in: schemes) == expected)
  }

  @Test func changedSubmodulesComeFromGitStatus() {
    let status = " M Dependencies/Logger\n?? Notes.txt\nM  Sources/App.swift\n M Dependencies/Commands\n"
    #expect(SubmoduleStatus.changedPaths(fromPorcelain: status) == ["Dependencies/Logger", "Notes.txt", "Sources/App.swift", "Dependencies/Commands"])
  }

  @Test func enclosingSubmoduleIsTheNearestNestedRepository() throws {
    let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AgentTools-Plan-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    for path in [".git/HEAD", "Dependencies/Logger/.git", "Dependencies/Logger/Examples/CLI/Package.swift", "Dependencies/Core/Package.swift"] {
      let url = root.appendingPathComponent(path)
      try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      try "x".write(to: url, atomically: true, encoding: .utf8)
    }

    #expect(SubmoduleStatus.enclosingSubmodule(of: root.appendingPathComponent("Dependencies/Logger").path, repoPath: root.path) == "Dependencies/Logger")
    #expect(SubmoduleStatus.enclosingSubmodule(of: root.appendingPathComponent("Dependencies/Logger/Examples/CLI").path, repoPath: root.path) == "Dependencies/Logger")
    #expect(SubmoduleStatus.enclosingSubmodule(of: root.appendingPathComponent("Dependencies/Core").path, repoPath: root.path) == nil)
    #expect(SubmoduleStatus.enclosingSubmodule(of: root.path, repoPath: root.path) == nil)
  }

  @Test(arguments: [
    (TestSubmodules.changed, ["Core", "Commands"]),
    (.always, ["Core", "Logger", "Commands"]),
    (.never, ["Core"]),
  ])
  func testedPackagesFollowTheSubmodulePolicy(policy: TestSubmodules, expected: [String]) {
    let tested = ValidationPlan.testedPackages(examplePackages, testSubmodules: policy, excluded: ["Keychain"])
    #expect(tested.map(\.name) == expected)
  }

  @Test func buildsEveryPlatformBeforeTestingEachPlatform() {
    let project = ValidationProject(
      container: ["-workspace", "/repo/App.xcworkspace"],
      productSchemes: ["App"],
      schemesWithTests: ["App"],
      buildPlatforms: [.iOS, .macOS],
      testPlatforms: [.macOS, .iOS],
      testDestinations: [.macOS: "platform=macOS", .iOS: "platform=iOS Simulator,name=iPhone,OS=27.0"],
      packages: examplePackages
    )

    let steps = ValidationPlan.steps(
      for: project,
      testSubmodules: .changed,
      excludedPackages: ["Keychain"],
      paths: ValidationPaths(repoPath: "/repo"),
      sandbox: EnclosingSandbox(isNested: false),
      disableSwiftPMSandbox: false,
      quiet: true
    )

    #expect(
      steps.map(\.summary) == [
        "build App (macOS)",
        "build App (iOS)",
        "test App (macOS)",
        "test Core (macOS)",
        "test Commands-Package (macOS)",
        "test App (iOS)",
        "test Core (iOS)",
        "test Commands-Package (iOS)",
      ]
    )
    #expect(
      steps[2].arguments == [
        "xcodebuild", "-workspace", "/repo/App.xcworkspace", "-scheme", "App", "-destination", "platform=macOS",
        "-derivedDataPath", "/repo/.build/agt/DerivedData", "-skipPackagePluginValidation", "-skipMacroValidation",
        "-quiet", "CODE_SIGNING_ALLOWED=NO", "test",
      ]
    )
  }

  @Test func swiftPMProductsUseSwiftPMOnMacOSAndXcodeElsewhere() {
    let project = ValidationProject(
      container: [],
      productSchemes: ["Tool-Package"],
      schemesWithTests: [],
      buildPlatforms: [.macOS, .iOS],
      testPlatforms: [.macOS, .watchOS],
      testDestinations: [.macOS: "platform=macOS"],
      packages: [
        LocalPackage(directory: "/repo", name: "Tool", hasTests: true, scheme: "Tool-Package", submodule: nil, submoduleChanged: false),
        LocalPackage(directory: "/repo/Dependencies/Core", name: "Core", hasTests: true, scheme: "Core", submodule: nil, submoduleChanged: false),
      ]
    )

    let steps = ValidationPlan.steps(
      for: project,
      testSubmodules: .changed,
      excludedPackages: [],
      paths: ValidationPaths(repoPath: "/repo"),
      sandbox: EnclosingSandbox(isNested: false),
      disableSwiftPMSandbox: true,
      quiet: false
    )

    #expect(
      steps.map(\.summary) == [
        "build Tool (macOS)",
        "build Tool-Package (iOS)",
        "test Tool (macOS)",
        "test Core (macOS)",
        "test watchOS (no available simulator)",
      ]
    )
    #expect(steps[0].arguments == ["swift", "build", "--package-path", "/repo", "--scratch-path", "/repo/.build/agt/swiftpm/root", "--disable-sandbox"])
    #expect(steps[1].arguments.prefix(3) == ["xcodebuild", "-scheme", "Tool-Package"])
    #expect(
      steps[3].arguments == [
        "swift", "test", "--package-path", "/repo/Dependencies/Core", "--scratch-path", "/repo/.build/agt/swiftpm/packages/Dependencies/Core", "--disable-sandbox",
      ]
    )
    #expect(steps[4].skipped)
  }

  @Test func rootPackageIsFoundUnderEitherSpellingOfItsPath() {
    let project = ValidationProject(
      container: [],
      productSchemes: ["Tool"],
      schemesWithTests: [],
      buildPlatforms: [.macOS],
      testPlatforms: [.macOS],
      testDestinations: [.macOS: "platform=macOS"],
      packages: [LocalPackage(directory: "/var/folders/repo", name: "Tool", hasTests: false, scheme: "Tool", submodule: nil, submoduleChanged: false)]
    )

    let steps = ValidationPlan.steps(
      for: project,
      testSubmodules: .changed,
      excludedPackages: [],
      paths: ValidationPaths(repoPath: "/private/var/folders/repo"),
      sandbox: EnclosingSandbox(isNested: false),
      disableSwiftPMSandbox: false,
      quiet: true
    )

    #expect(steps.map(\.summary) == ["build Tool (macOS)"])
  }

  /// Local packages in an app workspace: in-repo packages, changed and unchanged submodules, and packages
  /// without tests, outside the product, or excluded by configuration.
  private let examplePackages = [
    LocalPackage(directory: "/repo/Dependencies/Core", name: "Core", hasTests: true, scheme: "Core", submodule: nil, submoduleChanged: false),
    LocalPackage(directory: "/repo/Dependencies/Logger", name: "Logger", hasTests: true, scheme: "Logger-Package", submodule: "Dependencies/Logger", submoduleChanged: false),
    LocalPackage(directory: "/repo/Dependencies/Commands", name: "Commands", hasTests: true, scheme: "Commands-Package", submodule: "Dependencies/Commands", submoduleChanged: true),
    LocalPackage(directory: "/repo/Dependencies/Icons", name: "Icons", hasTests: false, scheme: "Icons", submodule: nil, submoduleChanged: false),
    LocalPackage(directory: "/repo/Examples/Demo", name: "Demo", hasTests: true, scheme: nil, submodule: nil, submoduleChanged: false),
    LocalPackage(directory: "/repo/Dependencies/Keychain", name: "Keychain", hasTests: true, scheme: "Keychain", submodule: nil, submoduleChanged: false),
  ]
}
