// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

@testable import AgentTools

/// Tests reading validation settings from `.agt/config.json` and `.agt/local/config.json`.
struct ProjectConfigurationTests {
  @Test func missingFilesGiveEmptySettings() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let settings = try await ProjectConfiguration.load(repoPath: root.path).validate

    #expect(settings == ValidateFileSettings())
  }

  @Test func localSettingsOverrideProjectSettings() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    try write(
      #"{"validate": {"schemes": ["App"], "platforms": ["macOS", "iOS"], "testSubmodules": "always", "excludePackages": ["Slow"]}}"#,
      to: root.appendingPathComponent(".agt/config.json")
    )
    try write(#"{"validate": {"testPlatforms": ["macOS"], "testSubmodules": "never"}}"#, to: root.appendingPathComponent(".agt/local/config.json"))

    let settings = try await ProjectConfiguration.load(repoPath: root.path).validate

    #expect(settings.schemes == ["App"])
    #expect(settings.platforms == ["macOS", "iOS"])
    #expect(settings.testPlatforms == ["macOS"])
    #expect(settings.testSubmodules == "never")
    #expect(settings.excludePackages == ["Slow"])
  }

  @Test func commandLineOptionsOverrideTheConfigurationFile() throws {
    let file = ValidateFileSettings(schemes: ["App"], platforms: ["macOS", "iOS"], testPlatforms: ["iOS"], testSubmodules: "always", excludePackages: ["Slow"])

    let fromFile = try ValidateCommand.parse([]).config(repoPath: "/work/Example", file: file)
    #expect(fromFile.schemes == ["App"])
    #expect(fromFile.platforms == [.macOS, .iOS])
    #expect(fromFile.testPlatforms == [.iOS])
    #expect(fromFile.testSubmodules == .always)
    #expect(fromFile.excludedPackages == ["Slow"])

    let overridden = try ValidateCommand.parse(["--schemes", "Other", "--platforms", "tvOS", "--test-platforms", "macOS", "--test-submodules", "never"]).config(repoPath: "/work/Example", file: file)
    #expect(overridden.schemes == ["Other"])
    #expect(overridden.platforms == [.tvOS])
    #expect(overridden.testPlatforms == [.macOS])
    #expect(overridden.testSubmodules == .never)
  }

  @Test func invalidValuesAreReported() {
    #expect(throws: ToolError.self) {
      _ = try ValidateCommand.parse([]).config(repoPath: "/work/Example", file: ValidateFileSettings(platforms: ["Android"]))
    }
    #expect(throws: ToolError.self) {
      _ = try ValidateCommand.parse([]).config(repoPath: "/work/Example", file: ValidateFileSettings(testSubmodules: "sometimes"))
    }
  }

  /// Creates an empty temporary directory.
  private func makeTemporaryDirectory() throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AgentTools-Config-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  /// Writes UTF-8 content, creating the parent directory when needed.
  private func write(_ contents: String, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try contents.write(to: url, atomically: true, encoding: .utf8)
  }
}
