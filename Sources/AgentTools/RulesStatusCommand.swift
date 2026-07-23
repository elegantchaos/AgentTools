// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 23/07/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser

/// Reports differences between shared and runtime rules without changing files.
struct RulesStatusCommand: ParsableCommand {
  /// Command metadata.
  static let configuration = CommandConfiguration(
    commandName: "status",
    abstract: "Report shared and runtime rule synchronization state."
  )

  /// Executes the status command.
  mutating func run() throws {
    printReport(try RulesPublicTool().inspect())
  }

  /// Prints a compact, deterministic report.
  private func printReport(_ report: RulesSyncReport) {
    for entry in report.entries {
      print("\(entry.name): \(entry.status.rawValue)")
    }
  }
}
