// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

@testable import AgentToolsCore

/// Tests the range of days a calendar query covers.
struct CalendarWindowTests {
  /// A gregorian calendar in UTC, so dates in the tests are unambiguous.
  private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar
  }()

  /// One day covers the whole of today, from midnight.
  @Test func oneDayCoversToday() throws {
    let now = try Date("2026-10-07T15:30:00Z", strategy: .iso8601)
    let window = try CalendarWindow(days: 1, now: now, calendar: calendar)
    #expect(window.start == (try Date("2026-10-07T00:00:00Z", strategy: .iso8601)))
    #expect(window.end == (try Date("2026-10-08T00:00:00Z", strategy: .iso8601)))
  }

  /// The longest window covers fourteen days.
  @Test func allowsTheMaximumDays() throws {
    let now = try Date("2026-10-07T15:30:00Z", strategy: .iso8601)
    let window = try CalendarWindow(days: CalendarWindow.maximumDays, now: now, calendar: calendar)
    #expect(window.end == (try Date("2026-10-21T00:00:00Z", strategy: .iso8601)))
  }

  /// Day counts outside one to fourteen are rejected.
  @Test(arguments: [0, -1, 15, 365])
  func rejectsDaysOutsideTheLimit(days: Int) {
    #expect(throws: CalendarWindow.InvalidDays(days: days)) {
      try CalendarWindow(days: days, now: .now, calendar: calendar)
    }
  }
}
