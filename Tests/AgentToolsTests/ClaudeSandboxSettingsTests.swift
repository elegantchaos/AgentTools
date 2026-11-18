// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

@testable import AgentToolsCore

/// Tests adding writable paths and sandbox-excluded commands to Claude Code's JSON settings.
struct ClaudeSandboxSettingsTests {
  /// Paths added in every test.
  let paths = ["/cache/swiftpm", "/cache/clang"]

  /// Commands excluded from the sandbox in every test.
  let commands = ["agt *", "rt *"]

  /// Creates the nested keys when there are no settings yet.
  @Test func createsSettings() throws {
    let updated = try #require(try ClaudeSandboxSettings.adding(paths, excludedCommands: commands, to: nil))
    #expect(try allowWrite(in: updated) == paths)
    #expect(try excludedCommands(in: updated) == commands)
  }

  /// Appends missing paths after existing ones and keeps unrelated settings.
  @Test func mergesIntoExistingSettings() throws {
    let text = #"{"model": "opus", "sandbox": {"enabled": true, "filesystem": {"allowWrite": ["/other", "/cache/clang"]}}}"#
    let updated = try #require(try ClaudeSandboxSettings.adding(paths, excludedCommands: commands, to: Data(text.utf8)))
    #expect(try allowWrite(in: updated) == ["/other", "/cache/clang", "/cache/swiftpm"])
    let settings = try #require(try JSONSerialization.jsonObject(with: updated) as? [String: Any])
    #expect(settings["model"] as? String == "opus")
    #expect((settings["sandbox"] as? [String: Any])?["enabled"] as? Bool == true)
  }

  /// Writes readable JSON without escaped slashes, ending with a newline.
  @Test func writesReadableJSON() throws {
    let updated = try #require(try ClaudeSandboxSettings.adding(paths, excludedCommands: commands, to: Data("{}".utf8)))
    let text = String(decoding: updated, as: UTF8.self)
    #expect(text.contains("\"/cache/swiftpm\""))
    #expect(text.hasSuffix("}\n"))
  }

  /// Appends missing excluded commands after existing ones, leaving the paths alone when they are all allowed.
  @Test func mergesExcludedCommands() throws {
    let text = #"{"sandbox": {"excludedCommands": ["docker *", "rt *"], "filesystem": {"allowWrite": ["/cache/clang", "/cache/swiftpm"]}}}"#
    let updated = try #require(try ClaudeSandboxSettings.adding(paths, excludedCommands: commands, to: Data(text.utf8)))
    #expect(try excludedCommands(in: updated) == ["docker *", "rt *", "agt *"])
    #expect(try allowWrite(in: updated) == ["/cache/clang", "/cache/swiftpm"])
  }

  /// Leaves settings alone when every path is already allowed and every command already excluded.
  @Test func unchangedWhenAlreadyAllowed() throws {
    let text = #"{"sandbox": {"excludedCommands": ["agt *", "rt *"], "filesystem": {"allowWrite": ["/cache/clang", "/cache/swiftpm"]}}}"#
    #expect(try ClaudeSandboxSettings.adding(paths, excludedCommands: commands, to: Data(text.utf8)) == nil)
  }

  /// Refuses settings whose shape it would have to overwrite.
  @Test(arguments: [
    "[]",
    #"{"sandbox": true}"#,
    #"{"sandbox": {"filesystem": []}}"#,
    #"{"sandbox": {"filesystem": {"allowWrite": "/x"}}}"#,
    #"{"sandbox": {"excludedCommands": "agt *"}}"#,
    "not json",
  ])
  func refusesUnexpectedShapes(text: String) {
    #expect(throws: (any Error).self) {
      try ClaudeSandboxSettings.adding(paths, excludedCommands: commands, to: Data(text.utf8))
    }
  }

  /// Returns `sandbox.excludedCommands` from encoded settings.
  private func excludedCommands(in data: Data) throws -> [String]? {
    let settings = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    return (settings?["sandbox"] as? [String: Any])?["excludedCommands"] as? [String]
  }

  /// Returns `sandbox.filesystem.allowWrite` from encoded settings.
  private func allowWrite(in data: Data) throws -> [String]? {
    let settings = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    let sandbox = settings?["sandbox"] as? [String: Any]
    let filesystem = sandbox?["filesystem"] as? [String: Any]
    return filesystem?["allowWrite"] as? [String]
  }
}
