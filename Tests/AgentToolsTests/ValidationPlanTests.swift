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
    let status = " M Dependencies/Logger\0?? Notes.txt\0M  Sources/App.swift\0 M Dependencies/Commands\0"
    #expect(SubmoduleStatus.changedPaths(fromPorcelainZ: status) == ["Dependencies/Logger", "Notes.txt", "Sources/App.swift", "Dependencies/Commands"])
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

  @Test func productPackagesWithoutAContainerSchemeUseTheirOwnDirectory() {
    let project = ValidationProject(
      container: ["-project", "/repo/App.xcodeproj"],
      productSchemes: ["App"],
      schemesWithTests: [],
      buildPlatforms: [.macOS],
      testPlatforms: [.macOS, .iOS],
      testDestinations: [.macOS: "platform=macOS", .iOS: "platform=iOS Simulator,name=iPhone,OS=27.0"],
      packages: [
        LocalPackage(directory: "/repo/Dependencies/Kit", name: "Kit", hasTests: true, scheme: nil, submodule: nil, submoduleChanged: false, packageScheme: "Kit-Package"),
        LocalPackage(directory: "/repo/Dependencies/Tool", name: "Tool", hasTests: true, scheme: nil, submodule: nil, submoduleChanged: false),
      ]
    )

    let steps = ValidationPlan.steps(
      for: project,
      testSubmodules: .changed,
      excludedPackages: [],
      paths: ValidationPaths(repoPath: "/repo"),
      sandbox: EnclosingSandbox(isNested: false),
      disableSwiftPMSandbox: false,
      quiet: true
    )

    #expect(steps.map(\.summary) == ["build App (macOS)", "test Kit (macOS)", "test Tool (macOS)", "test Kit (iOS)", "test Tool (iOS) (no Xcode scheme for the package)"])
    #expect(steps[1].arguments == ["swift", "test", "--package-path", "/repo/Dependencies/Kit", "--scratch-path", "/repo/.build/agt/swiftpm/packages/Dependencies/Kit"])
    #expect(steps[3].workingDirectory == "/repo/Dependencies/Kit")
    #expect(
      steps[3].arguments == [
        "xcodebuild", "-scheme", "Kit-Package", "-destination", "platform=iOS Simulator,name=iPhone,OS=27.0",
        "-derivedDataPath", "/repo/.build/agt/packages/Dependencies/Kit/DerivedData", "-skipPackagePluginValidation", "-skipMacroValidation",
        "-quiet", "CODE_SIGNING_ALLOWED=NO", "test",
      ]
    )
    #expect(steps[4].skipped)
  }

  @Test func localPackageReferencesComeFromProjectsAndWorkspaces() {
    let project = """
      2247C4EC2F91215F00B04B6D /* XCLocalSwiftPackageReference "Dependencies/ClockSyncKit" */ = {
        isa = XCLocalSwiftPackageReference;
        relativePath = Dependencies/ClockSyncKit;
      };
      3347C4EC /* XCLocalSwiftPackageReference "../Shared Kit" */ = {
        isa = XCLocalSwiftPackageReference;
        relativePath = "../Shared Kit";
      };
      """
    #expect(XcodeSchemes.localPackagePaths(fromProjectFile: project) == ["Dependencies/ClockSyncKit", "../Shared Kit"])

    let workspace = #"<Workspace version = "1.0"><FileRef location = "group:App.xcodeproj"></FileRef><FileRef location = "container:Dependencies/Core"></FileRef></Workspace>"#
    #expect(XcodeSchemes.memberPaths(fromWorkspaceData: workspace) == ["App.xcodeproj", "Dependencies/Core"])
  }

  @Test func planListsEveryPackageWithItsReason() {
    let project = ValidationProject(
      container: ["-workspace", "/repo/App.xcworkspace"],
      productSchemes: ["App"],
      schemesWithTests: [],
      buildPlatforms: [.macOS],
      testPlatforms: [.macOS],
      testDestinations: [.macOS: "platform=macOS"],
      packages: examplePackages + [
        LocalPackage(directory: "/repo/Dependencies/Kit", name: "Kit", hasTests: true, scheme: nil, submodule: nil, submoduleChanged: false)
      ],
      unexaminedSubmodulePackages: ["/repo/Dependencies/Slack"]
    )

    #expect(
      ValidationPlan.packageSummaries(for: project, testSubmodules: .changed, excludedPackages: ["Keychain"], repoPath: "/repo") == [
        "Dependencies/Commands (Commands): tested, with scheme Commands-Package",
        "Dependencies/Core (Core): tested, with scheme Core",
        "Dependencies/Icons (Icons): not tested, has no tests",
        "Dependencies/Keychain (Keychain): not tested, excluded by configuration",
        "Dependencies/Kit (Kit): tested, in its own directory",
        "Dependencies/Logger (Logger): not tested, in an unchanged submodule",
        "Dependencies/Slack: not tested, in an unchanged submodule",
        "Examples/Demo (Demo): not tested, not part of the product",
      ]
    )
    #expect(
      ValidationPlan.packageSummaries(for: project, testSubmodules: .never, excludedPackages: [], repoPath: "/repo")
        .contains("Dependencies/Slack: not tested, in a submodule, and testSubmodules is never")
    )
  }

  @Test func workspaceMembersWithAbsolutePathsAreResolved() throws {
    let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AgentTools-Workspace-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let project = root.appendingPathComponent("App.xcodeproj")
    let workspace = root.appendingPathComponent("App.xcworkspace")
    try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
    try "isa = XCLocalSwiftPackageReference;\n relativePath = Dependencies/Kit;".write(
      to: project.appendingPathComponent("project.pbxproj"), atomically: true, encoding: .utf8)
    try #"<Workspace><FileRef location = "container:\#(project.path)"></FileRef><FileRef location = "absolute:\#(root.path)/Shared"></FileRef><FileRef location = "group:Dependencies/Core"></FileRef></Workspace>"#.write(
      to: workspace.appendingPathComponent("contents.xcworkspacedata"), atomically: true, encoding: .utf8)

    let packages = ValidationDiscovery.referencedPackages(container: ["-workspace", workspace.path]).map(ValidationPaths.canonical)

    #expect(packages == ["Dependencies/Kit", "Shared", "Dependencies/Core"].map { ValidationPaths.canonical(root.appendingPathComponent($0).path) })
  }

  @Test func productPackagesIncludeLocalDependenciesTransitively() {
    let dependencies = ["/repo/App": ["/repo/Core"], "/repo/Core": ["/repo/Logger", "/repo/Core"], "/repo/Logger": []]
    #expect(ValidationDiscovery.productPackages(roots: ["/repo/App"], localDependencies: dependencies) == ["/repo/App", "/repo/Core", "/repo/Logger"])
  }

  @Test func packageDescriptionsListLocalDependencies() throws {
    let json = #"{"name": "Core", "targets": [], "dependencies": [{"identity": "feedback", "type": "fileSystem", "path": "/repo/Feedback"}, {"identity": "files", "type": "sourceControl", "url": "https://example.com/files.git"}]}"#
    let package = try JSONDecoder().decode(SwiftPackageDescription.self, from: Data(json.utf8))
    #expect(package.localDependencyPaths == ["/repo/Feedback"])
  }

  /// Local packages in an app workspace: in-repo packages, changed and unchanged submodules, and packages
  /// without tests, outside the product, or excluded by configuration.
  private let examplePackages = [
    LocalPackage(directory: "/repo/Dependencies/Core", name: "Core", hasTests: true, scheme: "Core", submodule: nil, submoduleChanged: false),
    LocalPackage(directory: "/repo/Dependencies/Logger", name: "Logger", hasTests: true, scheme: "Logger-Package", submodule: "Dependencies/Logger", submoduleChanged: false),
    LocalPackage(directory: "/repo/Dependencies/Commands", name: "Commands", hasTests: true, scheme: "Commands-Package", submodule: "Dependencies/Commands", submoduleChanged: true),
    LocalPackage(directory: "/repo/Dependencies/Icons", name: "Icons", hasTests: false, scheme: "Icons", submodule: nil, submoduleChanged: false),
    LocalPackage(directory: "/repo/Examples/Demo", name: "Demo", hasTests: true, scheme: nil, submodule: nil, submoduleChanged: false, inProduct: false),
    LocalPackage(directory: "/repo/Dependencies/Keychain", name: "Keychain", hasTests: true, scheme: "Keychain", submodule: nil, submoduleChanged: false),
  ]
}
