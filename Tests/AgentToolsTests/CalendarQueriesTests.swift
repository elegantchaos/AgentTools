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

  /// Lists reminders due in the window, or overdue by up to a week, when access is granted, filtered by the configured
  /// lists.
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
    #expect(store.requestedReminderRanges == [window.start.addingTimeInterval(-7 * 86_400)..<window.end])
  }

  /// Without access, the queries read nothing.
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
    #expect(store.requestedReminderRanges.isEmpty)
    #expect(store.requestedAccess == (access == .notDetermined ? [.events, .reminders] : []))
  }

  /// An undetermined status explains sandbox ambiguity before suggesting another permission request.
  @Test(arguments: CalendarItemKind.allCases)
  func undeterminedAccessExplainsSandbox(kind: CalendarItemKind) {
    let message = CalendarQueries.AccessMissing(kind: kind, access: .notDetermined).description
    #expect(message.contains(kind.label))
    #expect(message.contains("outside the sandbox"))
    #expect(message.contains("already granted"))
    #expect(message.contains("--no-prompt") == false)
  }

  /// A suppressed request says so, and does not tell the caller to remove the suppression.
  @Test(arguments: CalendarItemKind.allCases)
  func suppressedRequestIsReported(kind: CalendarItemKind) {
    let message = CalendarQueries.AccessMissing(kind: kind, access: .notDetermined, requestSuppressed: true).description
    #expect(message.contains(kind.label))
    #expect(message.contains("--no-prompt suppressed"))
    #expect(message.contains("omit") == false)
    #expect(message.contains("already granted"))
  }

  /// Refused grants point to Settings, while restrictions do not promise that authorization can override policy.
  @Test(arguments: [CalendarAccess.denied, .writeOnly, .restricted])
  func accessAdviceMatchesStatus(access: CalendarAccess) {
    let message = CalendarQueries.AccessMissing(kind: .reminders, access: access).description
    #expect(message.contains("agt calendar authorize") == false)
    if access == .restricted {
      #expect(message.contains("policy"))
    } else {
      #expect(message.contains("System Settings > Privacy & Security > Reminders"))
    }
  }

  /// Failed requests name the resource and preserve the service error with actionable sandbox advice.
  @Test(arguments: CalendarItemKind.allCases)
  func authorizationFailureExplainsServiceAccess(kind: CalendarItemKind) async throws {
    let store = FakeCalendarStore(access: [.events: .granted, .reminders: .granted].merging([kind: .notDetermined]) { _, new in new }, requestError: NSError(domain: "NSMachErrorDomain", code: 4099))
    let queries = CalendarQueries(store: store, settings: CalendarSettings(calendars: nil, reminderLists: nil), report: report)
    do {
      _ = try await query(kind, using: queries)
      Issue.record("Authorization should fail")
    } catch {
      let message = String(describing: error)
      #expect(message.contains(kind.label))
      #expect(message.contains("NSMachErrorDomain"))
      #expect(message.contains("4099"))
      #expect(message.contains("outside the sandbox"))
      #expect(message.contains("does not confirm a permission denial"))
    }
  }

  /// Cancellation remains cancellation rather than becoming a permission diagnostic.
  @Test func authorizationPreservesCancellation() async throws {
    let store = FakeCalendarStore(access: [.events: .notDetermined], requestError: CancellationError())
    let queries = CalendarQueries(store: store, settings: CalendarSettings(calendars: nil, reminderLists: nil), report: report)
    await #expect(throws: CancellationError.self) { try await queries.events(in: window) }
  }

  /// A dialog nobody answers ends the query with advice, without reading anything.
  @Test(arguments: CalendarItemKind.allCases)
  func unansweredRequestTimesOut(kind: CalendarItemKind) async throws {
    let store = FakeCalendarStore(access: [:], requestHangs: true)
    var queries = CalendarQueries(store: store, settings: CalendarSettings(calendars: nil, reminderLists: nil), report: report)
    queries.requestTimeout = .milliseconds(10)
    let probe = queries
    await #expect(throws: CalendarQueries.AuthorizationTimedOut(kind: kind, seconds: 0)) {
      try await query(kind, using: probe)
    }
    #expect(store.requestedEventWindows.isEmpty)
    #expect(store.requestedReminderRanges.isEmpty)
  }

  /// The timeout message says the dialog may still be open and how to avoid waiting.
  @Test func timeoutExplainsRecovery() {
    let message = CalendarQueries.AuthorizationTimedOut(kind: .reminders, seconds: 120).description
    #expect(message.contains("reminders"))
    #expect(message.contains("120 seconds"))
    #expect(message.contains("still be on screen"))
    #expect(message.contains("--no-prompt"))
  }

  /// Queries request only their own permission and continue after approval.
  @Test(arguments: CalendarItemKind.allCases)
  func requestsUndecidedAccess(kind: CalendarItemKind) async throws {
    let store = FakeCalendarStore(access: [:], grants: [kind: .granted])
    let queries = CalendarQueries(store: store, settings: CalendarSettings(calendars: nil, reminderLists: nil), report: report)
    _ = try await query(kind, using: queries)
    #expect(store.requestedAccess == [kind])
    #expect(store.requestedEventWindows.count == (kind == .events ? 1 : 0))
    #expect(store.requestedReminderRanges.count == (kind == .reminders ? 1 : 0))
    _ = try await query(kind, using: queries)
    #expect(store.requestedAccess == [kind])
  }

  /// No-prompt queries never request permission, even when a request could succeed.
  @Test(arguments: CalendarItemKind.allCases)
  func noPromptSuppressesRequest(kind: CalendarItemKind) async throws {
    let store = FakeCalendarStore(access: [:], grants: [kind: .granted])
    let queries = CalendarQueries(store: store, settings: CalendarSettings(calendars: nil, reminderLists: nil), report: report)
    await #expect(throws: CalendarQueries.AccessMissing(kind: kind, access: .notDetermined, requestSuppressed: true)) {
      try await query(kind, using: queries, noPrompt: true)
    }
    #expect(store.requestedAccess.isEmpty)
    #expect(store.requestedEventWindows.isEmpty)
    #expect(store.requestedReminderRanges.isEmpty)
  }

  /// No-prompt mode still reads data when access is already granted.
  @Test(arguments: CalendarItemKind.allCases)
  func noPromptUsesGrantedAccess(kind: CalendarItemKind) async throws {
    let store = FakeCalendarStore(access: [kind: .granted])
    let queries = CalendarQueries(store: store, settings: CalendarSettings(calendars: nil, reminderLists: nil), report: report)
    _ = try await query(kind, using: queries, noPrompt: true)
    #expect(store.requestedAccess.isEmpty)
    #expect(store.requestedEventWindows.count + store.requestedReminderRanges.count == 1)
  }

  /// A refused request reads nothing and is not repeated.
  @Test(arguments: CalendarItemKind.allCases)
  func requestDenied(kind: CalendarItemKind) async throws {
    let store = FakeCalendarStore(access: [:], grants: [kind: .denied])
    let queries = CalendarQueries(store: store, settings: CalendarSettings(calendars: nil, reminderLists: nil), report: report)
    for _ in 0..<2 {
      await #expect(throws: CalendarQueries.AccessMissing(kind: kind, access: .denied)) {
        try await query(kind, using: queries)
      }
    }
    #expect(store.requestedAccess == [kind])
    #expect(store.requestedEventWindows.isEmpty)
    #expect(store.requestedReminderRanges.isEmpty)
  }

  /// Invokes the query for one resource without requesting the other.
  private func query(_ kind: CalendarItemKind, using queries: CalendarQueries, noPrompt: Bool = false) async throws -> [String] {
    switch kind {
      case .events: try await queries.events(in: window, noPrompt: noPrompt)
      case .reminders: try await queries.reminders(in: window, noPrompt: noPrompt)
    }
  }

}

/// An in-memory calendar store that records what it was asked for.
private final class FakeCalendarStore: CalendarStore {
  /// The access currently reported for each kind; missing kinds are undecided.
  private var currentAccess: [CalendarItemKind: CalendarAccess]

  /// The access that a request for each kind results in; missing kinds stay as they were.
  private let grants: [CalendarItemKind: CalendarAccess]

  /// An error returned by permission requests, when supplied.
  private let requestError: (any Error)?

  /// Whether permission requests wait as an unanswered dialog does.
  private let requestHangs: Bool

  /// The events the store holds.
  private let storedEvents: [CalendarEvent]

  /// The reminders the store holds.
  private let storedReminders: [CalendarReminder]

  /// The kinds access was requested for, in order.
  private(set) var requestedAccess: [CalendarItemKind] = []

  /// The windows events were read for, in order.
  private(set) var requestedEventWindows: [CalendarWindow] = []

  /// The due-date ranges reminders were read for, in order.
  private(set) var requestedReminderRanges: [Range<Date>] = []

  /// Creates a store with the given access, request outcomes and contents.
  init(access: [CalendarItemKind: CalendarAccess], grants: [CalendarItemKind: CalendarAccess] = [:], events: [CalendarEvent] = [], reminders: [CalendarReminder] = [], requestError: (any Error)? = nil, requestHangs: Bool = false) {
    self.requestHangs = requestHangs
    currentAccess = access
    self.grants = grants
    storedEvents = events
    storedReminders = reminders
    self.requestError = requestError
  }

  /// Returns the current access for a kind.
  func access(to kind: CalendarItemKind) -> CalendarAccess {
    currentAccess[kind] ?? .notDetermined
  }

  /// Records the request and applies its configured outcome.
  func requestAccess(to kind: CalendarItemKind) async throws -> CalendarAccess {
    requestedAccess.append(kind)
    if requestHangs { try await Task.sleep(for: .seconds(3600)) }
    if let requestError { throw requestError }
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

  /// Records the range and returns every stored reminder.
  func incompleteReminders(due range: Range<Date>) async -> [CalendarReminder] {
    requestedReminderRanges.append(range)
    return storedReminders
  }
}
