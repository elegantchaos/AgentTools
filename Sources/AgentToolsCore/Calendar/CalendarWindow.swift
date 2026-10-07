// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// The span of time a calendar query covers: whole days, starting at midnight today.
struct CalendarWindow: Equatable, Sendable {
  /// The most days a query may cover.
  static let maximumDays = 14

  /// The day counts a query may cover.
  static let allowedDays = 1...maximumDays

  /// The start of the window, at midnight today.
  let start: Date

  /// The end of the window, exclusive.
  let end: Date

  /// Creates a window from explicit dates.
  init(start: Date, end: Date) {
    self.start = start
    self.end = end
  }

  /// Creates a window covering `days` whole days from midnight on the day containing `now`.
  ///
  /// Throws `InvalidDays` when `days` is not between one and `maximumDays`.
  init(days: Int, now: Date, calendar: Calendar) throws {
    guard Self.allowedDays.contains(days) else { throw InvalidDays(days: days) }
    let start = calendar.startOfDay(for: now)
    guard let end = calendar.date(byAdding: .day, value: days, to: start) else { throw InvalidDays(days: days) }
    self.init(start: start, end: end)
  }
}

extension CalendarWindow {
  /// A day count outside the range a query may cover.
  struct InvalidDays: Error, Equatable, CustomStringConvertible {
    /// The rejected day count.
    let days: Int

    /// Explains the limit.
    var description: String {
      "Days must be between 1 and \(CalendarWindow.maximumDays), not \(days)."
    }
  }
}
