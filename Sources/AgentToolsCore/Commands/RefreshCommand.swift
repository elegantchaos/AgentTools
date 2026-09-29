// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser

/// Brings this machine's agent runtimes up to date with the shared Agents repository.
struct RefreshCommand: ParsableCommand {
  /// Command metadata.
  static let configuration = CommandConfiguration(
    commandName: "refresh",
    abstract: "Sync and link skills, configure sandboxes, and install the shared plugins in Claude Code and Codex.",
    discussion: """
      Warns about plugin copies of `ensure-agt.sh` that differ from the `baseline` plugin's, runs `agt skills sync \
      --all`, `agt skills link` and `agt sandbox configure`, then installs or refreshes every plugin in the \
      repository's marketplace files. Claude Code and Codex are found on `PATH`, or else in their usual install \
      locations, including the copies bundled with the Claude and ChatGPT apps; a runtime that is not installed is \
      skipped. Every step is safe to repeat. It does not update `agt` itself; run `ensure-agt.sh --update` for that.
      """
  )

  /// Executes the refresh command.
  mutating func run() throws {
    try RefreshTool.current().run()
  }
}
