// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

@testable import AgentToolsCore

/// Tests configuring both runtimes' sandboxes on disk.
struct SandboxConfiguratorTests {
  /// Computes the SwiftPM cache under the home directory and the clang cache under the user cache directory.
  @Test func computesCachePaths() {
    let paths = SandboxConfigurator.cachePaths(
      homeDirectory: URL(fileURLWithPath: "/Users/someone"),
      userCacheDirectory: "/var/folders/xy/abc/C/"
    )
    #expect(paths == ["/Users/someone/Library/Caches/org.swift.swiftpm", "/var/folders/xy/abc/C/clang/ModuleCache"])
  }

  /// Finds a user cache directory for the current user.
  @Test func findsUserCacheDirectory() throws {
    let directory = try SandboxConfigurator.userCacheDirectory()
    #expect(directory.hasPrefix("/"))
  }

  /// Uses the runtime home overrides for the configuration files.
  @Test func honoursRuntimeHomes() {
    let configurator = SandboxConfigurator(
      environment: ["CLAUDE_CONFIG_DIR": "/claude", "CODEX_HOME": "/codex"],
      homeDirectory: URL(fileURLWithPath: "/home"),
      paths: []
    )
    #expect(configurator.claudeSettings.path == "/claude/settings.json")
    #expect(configurator.codexConfig.path == "/codex/config.toml")
  }

  /// Creates both files, then reports them unchanged on a second run without making backups.
  @Test func configuresThenReportsUnchanged() throws {
    try withTemporaryHomes { configurator in
      let first = try configurator.configure()
      #expect(first.map(\.status) == [.updated, .updated])
      #expect(try String(contentsOf: configurator.codexConfig, encoding: .utf8).contains("\"/cache/clang\""))
      #expect(try Data(contentsOf: configurator.claudeSettings).isEmpty == false)

      let second = try configurator.configure()
      #expect(second.map(\.status) == [.unchanged, .unchanged])
      #expect(!FileManager.default.fileExists(atPath: configurator.codexConfig.path + ".bak"))
    }
  }

  /// Backs up an existing file before changing it.
  @Test func backsUpExistingFile() throws {
    try withTemporaryHomes { configurator in
      try FileManager.default.createDirectory(at: configurator.codexConfig.deletingLastPathComponent(), withIntermediateDirectories: true)
      try "model = \"gpt\"\n".write(to: configurator.codexConfig, atomically: true, encoding: .utf8)

      _ = try configurator.configure()

      let backup = try String(contentsOfFile: configurator.codexConfig.path + ".bak", encoding: .utf8)
      #expect(backup == "model = \"gpt\"\n")
    }
  }

  /// Edits and backs up the destination of a symlinked file, leaving the link in place.
  @Test func preservesSymlinkedFile() throws {
    try withTemporaryHomes { configurator in
      let fileManager = FileManager.default
      let real = configurator.codexConfig.deletingLastPathComponent().appendingPathComponent("real.toml")
      try fileManager.createDirectory(at: real.deletingLastPathComponent(), withIntermediateDirectories: true)
      try "model = \"gpt\"\n".write(to: real, atomically: true, encoding: .utf8)
      try fileManager.createSymbolicLink(at: configurator.codexConfig, withDestinationURL: real)

      _ = try configurator.configure()

      #expect(try fileManager.destinationOfSymbolicLink(atPath: configurator.codexConfig.path) == real.path)
      #expect(try String(contentsOf: real, encoding: .utf8).contains("\"/cache/clang\""))
      #expect(try String(contentsOfFile: real.path + ".bak", encoding: .utf8) == "model = \"gpt\"\n")
    }
  }

  /// Runs `body` with a configurator whose runtime homes are in a temporary directory.
  private func withTemporaryHomes(_ body: (SandboxConfigurator) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let configurator = SandboxConfigurator(
      environment: [
        "CLAUDE_CONFIG_DIR": root.appendingPathComponent("claude").path,
        "CODEX_HOME": root.appendingPathComponent("codex").path,
      ],
      homeDirectory: root,
      paths: ["/cache/swiftpm", "/cache/clang"]
    )
    try body(configurator)
  }
}
