// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

@testable import AgentToolsCore

/// Tests checking access and producing output for the calendar commands, against an in-memory store.
struct CalendarQueriesTests {
  /// A report that formats dates in UTC.
  private let report: CalendarReport = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return CalendarReport(calendar: calendar)
  }()

  /// A one-day window starting at midnight UTC on 7 October 2026.
  private let window = CalendarWindow(start: Date(timeIntervalSince1970: 1_791_331_200), end: Date(timeIntervalSince1970: 1_791_417_600))

  /// Lists events in the window when access is granted, filtered by the configured calendars.
  @Test func listsEventsWhenGranted() async throws {
    let store = FakeCalendarStore(
      access: [.events: .granted],
      events: [
        CalendarEvent(start: window.start.addingTimeInterval(9 * 3600), end: window.start.addingTimeInterval(10 * 3600), isAllDay: false, title: "Standup", location: nil, calendar: "Work"),
        CalendarEvent(start: window.start.addingTimeInterval(12 * 3600), end: window.start.addingTimeInterval(13 * 3600), isAllDay: false, title: "Other", location: nil, calendar: "Shared"),
      ]
    )
    let queries = CalendarQueries(store: store, settings: CalendarSettings(calendars: ["Work"], reminderLists: nil), report: report)

    #expect(try await queries.events(in: window) == ["2026-10-07 09:00–10:00  Standup [Work]"])
    #expect(store.requestedEventWindows == [window])
  }

  /// Lists reminders due before the end of the window when access is granted, filtered by the configured lists.
  @Test func listsRemindersWhenGranted() async throws {
    let store = FakeCalendarStore(
      access: [.reminders: .granted],
      reminders: [
        CalendarReminder(title: "Overdue", due: window.start.addingTimeInterval(-86_400), hasDueTime: false, list: "Home"),
        CalendarReminder(title: "Other", due: window.start, hasDueTime: false, list: "Shopping"),
      ]
    )
    let queries = CalendarQueries(store: store, settings: CalendarSettings(calendars: nil, reminderLists: ["Home"]), report: report)

    #expect(try await queries.reminders(in: window) == ["2026-10-06  Overdue [Home]"])
    #expect(store.requestedReminderEnds == [window.end])
  }

  /// Without access, the queries read nothing and point at `agt calendar authorize`.
  @Test(arguments: [CalendarAccess.notDetermined, .denied, .restricted, .writeOnly])
  func refusesWithoutAccess(access: CalendarAccess) async throws {
    let store = FakeCalendarStore(access: [.events: access, .reminders: access])
    let queries = CalendarQueries(store: store, settings: CalendarSettings(calendars: nil, reminderLists: nil), report: report)

    await #expect(throws: CalendarQueries.AccessMissing(kind: .events, access: access)) {
      try await queries.events(in: window)
    }
    await #expect(throws: CalendarQueries.AccessMissing(kind: .reminders, access: access)) {
      try await queries.reminders(in: window)
    }
    #expect(store.requestedEventWindows.isEmpty)
    #expect(store.requestedReminderEnds.isEmpty)
  }

  /// The missing-access error tells the user what to run.
  @Test func missingAccessNamesTheAuthorizeCommand() {
    let error = CalendarQueries.AccessMissing(kind: .reminders, access: .denied)
    #expect(error.description.contains("agt calendar authorize"))
    #expect(error.description.contains("reminders"))
  }

  /// Authorizing asks for access to both kinds when undecided, and reports the outcome of each.
  @Test func authorizeRequestsUndecidedAccess() async throws {
    let store = FakeCalendarStore(access: [.events: .notDetermined, .reminders: .granted], grants: [.events: .granted])
    let queries = CalendarQueries(store: store, settings: CalendarSettings(calendars: nil, reminderLists: nil), report: report)

    #expect(try await queries.authorize() == ["Calendars: granted", "Reminders: granted"])
    #expect(store.requestedAccess == [.events])
  }

  /// Authorizing does not ask again once access has been denied, since macOS would not show the prompt.
  @Test func authorizeReportsDeniedAccess() async throws {
    let store = FakeCalendarStore(access: [.events: .denied, .reminders: .notDetermined], grants: [.reminders: .denied])
    let queries = CalendarQueries(store: store, settings: CalendarSettings(calendars: nil, reminderLists: nil), report: report)

    #expect(
      try await queries.authorize() == [
        "Calendars: denied (change this in System Settings > Privacy & Security > Calendars)",
        "Reminders: denied (change this in System Settings > Privacy & Security > Reminders)",
      ]
    )
    #expect(store.requestedAccess == [.reminders])
  }
}

/// An in-memory calendar store that records what it was asked for.
private final class FakeCalendarStore: CalendarStore {
  /// The access currently reported for each kind; missing kinds are undecided.
  private var currentAccess: [CalendarItemKind: CalendarAccess]

  /// The access that a request for each kind results in; missing kinds stay as they were.
  private let grants: [CalendarItemKind: CalendarAccess]

  /// The events the store holds.
  private let storedEvents: [CalendarEvent]

  /// The reminders the store holds.
  private let storedReminders: [CalendarReminder]

  /// The kinds access was requested for, in order.
  private(set) var requestedAccess: [CalendarItemKind] = []

  /// The windows events were read for, in order.
  private(set) var requestedEventWindows: [CalendarWindow] = []

  /// The end dates reminders were read for, in order.
  private(set) var requestedReminderEnds: [Date] = []

  /// Creates a store with the given access, request outcomes and contents.
  init(access: [CalendarItemKind: CalendarAccess], grants: [CalendarItemKind: CalendarAccess] = [:], events: [CalendarEvent] = [], reminders: [CalendarReminder] = []) {
    currentAccess = access
    self.grants = grants
    storedEvents = events
    storedReminders = reminders
  }

  /// Returns the current access for a kind.
  func access(to kind: CalendarItemKind) -> CalendarAccess {
    currentAccess[kind] ?? .notDetermined
  }

  /// Records the request and applies its configured outcome.
  func requestAccess(to kind: CalendarItemKind) async throws -> CalendarAccess {
    requestedAccess.append(kind)
    if let grant = grants[kind] {
      currentAccess[kind] = grant
    }
    return access(to: kind)
  }

  /// Records the window and returns every stored event.
  func events(in window: CalendarWindow) -> [CalendarEvent] {
    requestedEventWindows.append(window)
    return storedEvents
  }

  /// Records the end date and returns every stored reminder.
  func incompleteReminders(dueBefore end: Date) async -> [CalendarReminder] {
    requestedReminderEnds.append(end)
    return storedReminders
  }
}
