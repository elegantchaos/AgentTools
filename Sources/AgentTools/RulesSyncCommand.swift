// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 23/07/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser

/// Synchronizes shared rules with regular runtime copies.
struct RulesSyncCommand: ParsableCommand {
  /// Command metadata.
  static let configuration = CommandConfiguration(
    commandName: "sync",
    abstract: "Synchronize shared and runtime rule files."
  )

  /// Executes the sync command.
  mutating func run() throws {
    let report = try RulesPublicTool().synchronize()
    for entry in report.entries {
      print("\(entry.name): \(entry.status.rawValue)")
    }
  }
}
