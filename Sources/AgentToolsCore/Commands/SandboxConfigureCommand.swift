// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser

/// Lets Claude Code's and Codex's sandboxes write the caches that Swift validation needs.
struct SandboxConfigureCommand: ParsableCommand {
  /// Command metadata.
  static let configuration = CommandConfiguration(
    commandName: "configure",
    abstract: "Allow Claude Code's and Codex's sandboxes to write the caches that Swift validation needs.",
    discussion: """
      Adds SwiftPM's cache and the per-user clang module cache to `sandbox.filesystem.allowWrite` in Claude Code's \
      `settings.json`, and to `sandbox_workspace_write.writable_roots` in Codex's `config.toml`, under \
      `CLAUDE_CONFIG_DIR` and `CODEX_HOME` when set. Other settings are kept, and a changed file is backed up with a \
      `.bak` suffix first. Running it again changes nothing.
      """
  )

  /// Executes the configure command.
  mutating func run() throws {
    for entry in try SandboxConfigurator.current().configure() {
      print(entry.summary)
    }
  }
}
