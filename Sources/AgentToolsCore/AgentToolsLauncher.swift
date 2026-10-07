// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser

/// Chooses the root command for the `agt` executable and runs it.
///
/// When `agt` is its own responsible process it may hold the calendar permission, so it accepts only the calendar
/// commands. Otherwise it accepts every command.
public enum AgentToolsLauncher {
  /// Parses the command line with the appropriate root command and runs it.
  public static func main() async {
    await run(rootCommand(selfResponsible: ResponsibleProcess.isSelfResponsible()))
  }

  /// Returns the root command for a process that is, is not, or might be (`nil`) its own responsible process.
  static func rootCommand(selfResponsible: Bool?) -> any AsyncParsableCommand.Type {
    selfResponsible == true ? CalendarOnlyCommand.self : AgentToolsCommand.self
  }

  /// Runs the root command `command`.
  private static func run<Command: AsyncParsableCommand>(_ command: Command.Type) async {
    await command.main()
  }
}
