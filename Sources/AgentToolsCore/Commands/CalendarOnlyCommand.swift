// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser

/// The only root command `agt` accepts when it is its own responsible process.
///
/// That process holds the calendar permission, and any process it starts would inherit it, so it must not run any
/// other command. `AgentToolsLauncher` selects this root in place of `AgentToolsCommand` in that case.
struct CalendarOnlyCommand: AsyncParsableCommand {
  /// Root configuration, offering only the calendar commands.
  static let configuration = CommandConfiguration(
    commandName: "agt",
    abstract: "Calendar queries, run as agt's own responsible process.",
    subcommands: [
      CalendarCommand.self
    ]
  )

  /// Shows the help, since a subcommand is required.
  mutating func run() async throws {
    throw CleanExit.helpRequest(self)
  }
}
