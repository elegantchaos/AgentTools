// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 23/04/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser

/// Entry point for shared agent maintenance and repository validation commands.
///
/// Handles the `--version` flag, or shows the help when no subcommand is given.
@main
struct AgentTools: ParsableCommand {
  /// Top-level command configuration.
  static let configuration = CommandConfiguration(
    commandName: "agt",
    abstract: "Maintenance and validation tools for agent-driven development.",
    subcommands: [
      FormatCommand.self,
      Rules.self,
      Skills.self,
      ValidateCommand.self,
    ]
  )

  /// Whether to show the version.
  @Flag(help: "Show the version.")
  var version = false

  /// Prints the version, or the help when no subcommand is given.
  mutating func run() throws {
    guard version else { throw CleanExit.helpRequest(self) }
    print(ToolVersion.current)
  }
}
