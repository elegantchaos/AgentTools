// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 23/07/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser

/// Parent command for all shared-rules operations.
struct Rules: ParsableCommand {
  /// Command metadata and available subcommands.
  static let configuration = CommandConfiguration(
    commandName: "rules",
    abstract: "Maintain shared Codex rules.",
    subcommands: [
      RulesStatusCommand.self,
      RulesSyncCommand.self,
    ]
  )
}
