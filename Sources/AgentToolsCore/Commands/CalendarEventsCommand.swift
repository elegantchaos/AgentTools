// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation

/// Lists upcoming events.
struct CalendarEventsCommand: AsyncParsableCommand {
  /// Command metadata.
  static let configuration = CommandConfiguration(
    commandName: "events",
    abstract: "List events from today.",
    discussion: "Lists the events from midnight today, for the given number of days."
  )

  /// The number of whole days to cover, starting today.
  @Option(help: "Days to cover, starting today (1 to \(CalendarWindow.maximumDays)).")
  var days = 1

  /// Rejects a day count outside the allowed range.
  func validate() throws {
    guard CalendarWindow.allowedDays.contains(days) else {
      throw ValidationError(CalendarWindow.InvalidDays(days: days).description)
    }
  }

  /// Prints the matching items.
  mutating func run() async throws {
    let days = days
    try await CalendarRunner.run { queries in
      let window = try CalendarWindow(days: days, now: .now, calendar: .current)
      return try await queries.events(in: window)
    }
  }
}
