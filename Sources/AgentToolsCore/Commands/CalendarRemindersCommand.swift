// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation

/// Lists incomplete reminders that are overdue or due soon.
struct CalendarRemindersCommand: AsyncParsableCommand {
  /// Command metadata.
  static let configuration = CommandConfiguration(
    commandName: "reminders",
    abstract: "List incomplete reminders due from today, including overdue ones.",
    discussion: "Lists incomplete reminders that are overdue or due within the given number of days."
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
      return try await queries.reminders(in: window)
    }
  }
}
