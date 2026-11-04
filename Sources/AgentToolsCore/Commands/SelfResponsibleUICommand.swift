// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser

/// The `ui` commands a self-responsible `agt` accepts: those that need Accessibility or Screen Recording.
///
/// `launch` and `quit` are left out because they need no permission and start or stop other processes.
struct SelfResponsibleUICommand: AsyncParsableCommand {
  /// Command metadata, offering the permission-holding `ui` subcommands.
  static let configuration = CommandConfiguration(
    commandName: "ui",
    abstract: UICommand.configuration.abstract,
    subcommands: UICommand.permissionSubcommands
  )
}
