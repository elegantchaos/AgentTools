// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser

/// Asks macOS for access to calendars and reminders.
struct CalendarAuthorizeCommand: AsyncParsableCommand {
  /// Command metadata.
  static let configuration = CommandConfiguration(
    commandName: "authorize",
    abstract: "Ask for access to calendars and reminders.",
    discussion: "Shows macOS's prompt for each kind not yet decided, and reports the access to each."
  )

  /// Requests access and prints the outcome.
  mutating func run() async throws {
    try await CalendarRunner.run { try await $0.authorize() }
  }
}
