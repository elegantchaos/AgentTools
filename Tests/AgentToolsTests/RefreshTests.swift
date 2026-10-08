// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Darwin
import Foundation
import Testing

@testable import AgentToolsCore

/// Tests the parts of `agt refresh` that find runtimes, plan plugin installs, and check helper copies.
struct RefreshTests {
  /// Terminal access and interrupt signals share the refresh process's foreground group.
  @Test func pluginCommandSharesProcessGroup() throws {
    try withTemporaryDirectory { root in
      let tool = RefreshTool(repoRoot: root, locator: RuntimeCommandLocator(environment: [:], homeDirectory: root, rootDirectory: root))
      try tool.runPassingThrough(
        URL(fileURLWithPath: "/bin/sh"),
        ["-c", "group=$(/bin/ps -o pgid= -p $$); [ \"$group\" -eq \"$1\" ] || exit 43", "plugin", String(getpgrp())]
      )
    }
  }

  /// Plugin maintenance receives EOF instead of inheriting terminal input.
  @Test func pluginCommandHasNoTerminalInput() throws {
    try withTemporaryDirectory { root in
      let tool = RefreshTool(repoRoot: root, locator: RuntimeCommandLocator(environment: [:], homeDirectory: root, rootDirectory: root))
      try tool.runPassingThrough(URL(fileURLWithPath: "/bin/sh"), ["-c", "[ /dev/fd/0 -ef /dev/null ] || exit 42"])
    }
  }

  /// Announces the executable and arguments before the child begins work.
  @Test func announcesPluginCommandBeforeLaunch() throws {
    try withTemporaryDirectory { root in
      let marker = root.appendingPathComponent("started")
      let tool = RefreshTool(repoRoot: root, locator: RuntimeCommandLocator(environment: [:], homeDirectory: root, rootDirectory: root))
      let arguments = ["-c", "touch started"]
      var messages: [String] = []
      try tool.runPassingThrough(URL(fileURLWithPath: "/bin/sh"), arguments) { message in
        #expect(FileManager.default.fileExists(atPath: marker.path) == false)
        messages.append(message)
      }
      #expect(messages == ["refresh: /bin/sh -c touch started"])
      #expect(FileManager.default.fileExists(atPath: marker.path))
    }
  }

  /// Preserves a failing child command's status and identity in its error.
  @Test func reportsPluginCommandFailure() throws {
    try withTemporaryDirectory { root in
      let tool = RefreshTool(repoRoot: root, locator: RuntimeCommandLocator(environment: [:], homeDirectory: root, rootDirectory: root))
      do {
        try tool.runPassingThrough(URL(fileURLWithPath: "/bin/sh"), ["-c", "exit 7"])
        Issue.record("Expected the failed plugin command to throw.")
      } catch let error as ToolError {
        #expect(error.description == "/bin/sh -c exit 7 failed with status 7")
      }
    }
  }

  /// Prefers a runtime command on `PATH`.
  @Test func locatesCommandOnPath() throws {
    try withTemporaryDirectory { root in
      let onPath = try makeExecutable(root.appendingPathComponent("bin/codex"))
      _ = try makeExecutable(root.appendingPathComponent("Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex"))
      let locator = RuntimeCommandLocator(environment: ["PATH": "/nowhere:\(root.path)/bin"], homeDirectory: root, rootDirectory: root)
      #expect(locator.locate(.codex) == onPath)
    }
  }

  /// Falls back to the newest command bundled with the Claude app.
  @Test func fallsBackToNewestBundledClaude() throws {
    try withTemporaryDirectory { root in
      let versions = root.appendingPathComponent("Library/Application Support/Claude/claude-code")
      for version in ["2.1.9", "2.1.281", "2.1.30"] {
        _ = try makeExecutable(versions.appendingPathComponent("\(version)/claude.app/Contents/MacOS/claude"))
      }
      let locator = RuntimeCommandLocator(environment: [:], homeDirectory: root, rootDirectory: root)
      #expect(locator.locate(.claude)?.path.contains("/2.1.281/") == true)
    }
  }

  /// Falls back to the command bundled with the ChatGPT app.
  @Test func fallsBackToBundledCodex() throws {
    try withTemporaryDirectory { root in
      let bundled = try makeExecutable(root.appendingPathComponent("Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex"))
      let locator = RuntimeCommandLocator(environment: ["PATH": ""], homeDirectory: root, rootDirectory: root)
      #expect(locator.locate(.codex) == bundled)
    }
  }

  /// Finds nothing when the runtime is not installed.
  @Test func locatesNothingWhenMissing() throws {
    try withTemporaryDirectory { root in
      let locator = RuntimeCommandLocator(environment: [:], homeDirectory: root, rootDirectory: root)
      #expect(locator.locate(.claude) == nil)
      #expect(locator.locate(.codex) == nil)
    }
  }

  /// Plans Claude Code's marketplace registration, then an install and update for each plugin.
  @Test func plansClaudePluginInstalls() throws {
    let marketplace = Data(#"{"name": "shop", "plugins": [{"name": "one"}, {"name": "two"}]}"#.utf8)
    let commands = try PluginInstallPlan.commands(for: .claude, marketplace: marketplace, repoRoot: "/repo")
    #expect(
      commands == [
        ["plugin", "marketplace", "add", "/repo"],
        ["plugin", "marketplace", "update", "shop"],
        ["plugin", "install", "one@shop"],
        ["plugin", "update", "one@shop"],
        ["plugin", "install", "two@shop"],
        ["plugin", "update", "two@shop"],
      ]
    )
  }

  /// Plans Codex's marketplace registration, then an add for each plugin, which refreshes its cached copy.
  @Test func plansCodexPluginInstalls() throws {
    let marketplace = Data(#"{"name": "shop", "plugins": [{"name": "one"}]}"#.utf8)
    let commands = try PluginInstallPlan.commands(for: .codex, marketplace: marketplace, repoRoot: "/repo")
    #expect(commands == [["plugin", "marketplace", "add", "/repo"], ["plugin", "add", "one@shop"]])
  }

  /// Rejects a marketplace file without a name or plugin list.
  @Test func rejectsMalformedMarketplace() {
    #expect(throws: (any Error).self) {
      try PluginInstallPlan.commands(for: .codex, marketplace: Data(#"{"plugins": []}"#.utf8), repoRoot: "/repo")
    }
  }

  /// Reads each runtime's marketplace file from the repository.
  @Test func marketplacePaths() {
    #expect(PluginInstallPlan.marketplacePath(for: .claude) == ".claude-plugin/marketplace.json")
    #expect(PluginInstallPlan.marketplacePath(for: .codex) == ".agents/plugins/marketplace.json")
  }

  /// Reports the plugin copies of `ensure-agt.sh` that differ from the canonical one.
  @Test func reportsDriftedHelperCopies() throws {
    try withTemporaryDirectory { root in
      try write("canonical", to: root.appendingPathComponent(HelperCopies.canonicalPath))
      try write("canonical", to: root.appendingPathComponent("plugins/swift/skills/validation/scripts/ensure-agt.sh"))
      try write("changed", to: root.appendingPathComponent("plugins/other/skills/tool/scripts/ensure-agt.sh"))
      #expect(try HelperCopies.drifted(in: root) == ["plugins/other/skills/tool/scripts/ensure-agt.sh"])
    }
  }

  /// Runs `body` with a temporary directory that is removed afterwards.
  private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true).resolvingSymlinksInPath()
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try body(root)
  }

  /// Creates an executable file at `url`, returning it.
  private func makeExecutable(_ url: URL) throws -> URL {
    try write("#!/bin/sh\n", to: url)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    return url
  }

  /// Writes `contents` to `url`, creating its directory.
  private func write(_ contents: String, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try contents.write(to: url, atomically: true, encoding: .utf8)
  }
}
