// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import EventKit
import Foundation

/// Reads the user's calendars and reminders through EventKit.
///
/// Only the fields in `CalendarEvent` and `CalendarReminder` are read from EventKit's items; notes, attendees, URLs
/// and attachments never leave this type. Create it only in a process that is its own responsible process, so that
/// the privacy permission belongs to `agt`.
final class EventKitCalendarStore: CalendarStore {
  /// The EventKit store.
  private let store = EKEventStore()

  /// Returns EventKit's authorization status for `kind`.
  func access(to kind: CalendarItemKind) -> CalendarAccess {
    switch EKEventStore.authorizationStatus(for: kind.entityType) {
      case .fullAccess: .granted
      case .denied: .denied
      case .restricted: .restricted
      case .writeOnly: .writeOnly
      default: .notDetermined
    }
  }

  /// Asks for full access to `kind`, prompting the user.
  func requestAccess(to kind: CalendarItemKind) async throws -> CalendarAccess {
    switch kind {
      case .events: _ = try await store.requestFullAccessToEvents()
      case .reminders: _ = try await store.requestFullAccessToReminders()
    }
    return access(to: kind)
  }

  /// Returns the events that overlap `window`, from every calendar.
  func events(in window: CalendarWindow) -> [CalendarEvent] {
    let predicate = store.predicateForEvents(withStart: window.start, end: window.end, calendars: nil)
    return store.events(matching: predicate).map { event in
      CalendarEvent(
        start: event.startDate,
        end: event.endDate,
        isAllDay: event.isAllDay,
        title: event.title ?? "",
        location: event.location,
        calendar: event.calendar?.title ?? ""
      )
    }
  }

  /// Returns the incomplete reminders due before `end`, from every list, including overdue ones.
  func incompleteReminders(dueBefore end: Date) async -> [CalendarReminder] {
    let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: end, calendars: nil)
    return await withCheckedContinuation { continuation in
      store.fetchReminders(matching: predicate) { reminders in
        continuation.resume(returning: (reminders ?? []).compactMap(Self.reminder(from:)))
      }
    }
  }
}

extension EventKitCalendarStore {
  /// Converts an EventKit reminder, or returns `nil` when it has no usable due date.
  private static func reminder(from reminder: EKReminder) -> CalendarReminder? {
    guard let components = reminder.dueDateComponents, let due = Calendar.current.date(from: components) else { return nil }
    return CalendarReminder(title: reminder.title ?? "", due: due, hasDueTime: components.hour != nil, list: reminder.calendar?.title ?? "")
  }
}

extension CalendarItemKind {
  /// The EventKit entity type for this kind.
  fileprivate var entityType: EKEntityType {
    switch self {
      case .events: .event
      case .reminders: .reminder
    }
  }
}
