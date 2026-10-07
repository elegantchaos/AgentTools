// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// An event as `agt calendar` reports it: only the fields it is allowed to print.
struct CalendarEvent: Equatable, Sendable {
  /// When the event starts.
  let start: Date

  /// When the event ends.
  let end: Date

  /// Whether the event lasts all day, with no times.
  let isAllDay: Bool

  /// The event's title, as stored.
  let title: String

  /// The event's location, as stored.
  let location: String?

  /// The title of the calendar holding the event.
  let calendar: String
}
