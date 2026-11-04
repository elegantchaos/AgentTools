// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser

/// The only root command `agt` accepts when it is its own responsible process.
///
/// That process holds the permissions granted to `agt` itself: calendars and reminders, Accessibility and Screen
/// Recording. Any process it starts would inherit them, so it runs only the commands that need them, and none that
/// start other processes. `AgentToolsLauncher` selects this root in place of `AgentToolsCommand` in that case.
struct SelfResponsibleCommand: AsyncParsableCommand {
  /// Root configuration, offering only the commands that need agt's own permissions.
  static let configuration = CommandConfiguration(
    commandName: "agt",
    abstract: "Commands that run as agt's own responsible process.",
    subcommands: [
      CalendarCommand.self,
      SelfResponsibleUICommand.self,
    ]
  )

  /// Shows the help, since a subcommand is required.
  mutating func run() async throws {
    throw CleanExit.helpRequest(self)
  }
}
