// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 23/04/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser

/// Parent command for all skill-related operations.
struct Skills: ParsableCommand {
  /// Command metadata and available subcommands.
  static let configuration = CommandConfiguration(
    commandName: "skills",
    abstract: "Maintain shared agent skills.",
    subcommands: [
      SkillsAuditCommand.self,
      SkillsLinkCommand.self,
      SkillsStatusCommand.self,
      SkillsSyncCommand.self,
    ]
  )
}
