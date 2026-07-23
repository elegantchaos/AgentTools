// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 23/04/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser

/// Entry point for agent repository maintenance commands.
@main
struct AgentTools: ParsableCommand {
  /// Top-level command configuration.
  static let configuration = CommandConfiguration(
    commandName: "agt",
    abstract: "Maintenance tools for the shared agents repository.",
    subcommands: [
      Rules.self,
      Skills.self,
    ]
  )
}
