// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser

/// Parent command for agent sandbox operations.
struct Sandbox: ParsableCommand {
  /// Command metadata and available subcommands.
  static let configuration = CommandConfiguration(
    commandName: "sandbox",
    abstract: "Configure agent sandboxes.",
    subcommands: [
      SandboxConfigureCommand.self
    ]
  )
}
