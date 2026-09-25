// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 23/04/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser

/// Audits one or more skills for publication blockers.
struct SkillsAuditCommand: ParsableCommand {
  /// Command metadata.
  static let configuration = CommandConfiguration(
    commandName: "audit",
    abstract: "Audit one skill or all skills for publication blockers."
  )

  /// Audits all discovered skills.
  @Flag(name: .long, help: "Audit all discovered skills.")
  var all = false

  /// Skill names, submodule paths, or submodule directory names to audit.
  @Argument(help: "Skill names, submodule paths, or submodule directory names to audit.")
  var skills: [String] = []

  /// Executes the audit command.
  mutating func run() throws {
    try SkillsPublicTool().runAudit(selection: selection)
  }

  /// Converts CLI arguments into a selection.
  private var selection: SkillSelection {
    all ? .all : .some(skills)
  }
}
