// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 23/04/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser

/// Entry point for shared agent maintenance and repository validation commands.
@main
struct AgentTools: ParsableCommand {
  /// Top-level command configuration.
  static let configuration = CommandConfiguration(
    commandName: "agt",
    abstract: "Maintenance and validation tools for agent-driven development.",
    subcommands: [
      Rules.self,
      Skills.self,
      ValidateCommand.self,
    ]
  )
}
