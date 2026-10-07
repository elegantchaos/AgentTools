// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Reads events and reminders, and the permission to do so.
///
/// `EventKitCalendarStore` reads the user's real calendars; tests use an in-memory store.
protocol CalendarStore {
  /// Returns the current access to one kind of item.
  func access(to kind: CalendarItemKind) -> CalendarAccess

  /// Asks for full access to one kind of item, prompting the user, and returns the resulting access.
  func requestAccess(to kind: CalendarItemKind) async throws -> CalendarAccess

  /// Returns the events that overlap `window`.
  func events(in window: CalendarWindow) -> [CalendarEvent]

  /// Returns the incomplete reminders due before `end`, including overdue ones.
  func incompleteReminders(dueBefore end: Date) async -> [CalendarReminder]
}
