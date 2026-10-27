// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser

/// Lets Claude Code's and Codex's sandboxes write the caches that Swift validation needs and the shared Agents checkout.
struct SandboxConfigureCommand: ParsableCommand {
  /// Command metadata.
  static let configuration = CommandConfiguration(
    commandName: "configure",
    abstract: "Allow Claude Code's and Codex's sandboxes to write the caches that Swift validation needs and the Agents checkout.",
    discussion: """
      Adds SwiftPM's cache, the per-user clang module cache, and the Agents checkout (`AGENTS_REPO_ROOT`, or \
      `~/.local/share/agents`) to `sandbox.filesystem.allowWrite` in Claude Code's \
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
