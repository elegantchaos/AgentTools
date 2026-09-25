// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 23/04/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser

/// Root command for shared agent maintenance and repository validation commands.
///
/// Handles the `--version` flag, or shows the help when no subcommand is given.
/// The `agt` executable runs it from its `@main` entry point, which stays outside this library so that
/// tests never link an executable's `main`.
public struct AgentToolsCommand: AsyncParsableCommand {
  /// Top-level command configuration.
  public static let configuration = CommandConfiguration(
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

  /// Creates the command with its default options.
  public init() {}

  /// Prints the version, or the help when no subcommand is given.
  public mutating func run() async throws {
    guard version else { throw CleanExit.helpRequest(self) }
    print(ToolVersion.current)
  }
}
