// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 23/04/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser

/// Synchronizes skill submodules to recorded revisions.
struct SkillsSyncCommand: ParsableCommand {
  /// Command metadata.
  static let configuration = CommandConfiguration(
    commandName: "sync",
    abstract: "Initialize or update public skill submodules to recorded revisions."
  )

  /// Syncs all registered public skill submodules.
  @Flag(name: .long, help: "Sync all registered public skill submodules.")
  var all = false

  /// Skill names, submodule paths, or submodule directory names to sync.
  @Argument(help: "Skill names, submodule paths, or submodule directory names to sync.")
  var skills: [String] = []

  /// Executes the sync command.
  mutating func run() throws {
    try SkillsPublicTool().runSync(selection: selection)
  }

  /// Converts CLI arguments into a selection.
  private var selection: SkillSelection {
    all ? .all : .some(skills)
  }
}
