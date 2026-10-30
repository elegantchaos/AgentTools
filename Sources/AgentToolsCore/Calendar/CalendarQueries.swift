// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// The calendar commands' work, once `agt` is running as its own responsible process: checking or requesting access,
/// reading items from a store, and formatting them.
struct CalendarQueries {
  /// The most days overdue a reminder can be and still be listed.
  static let overdueDays = 7

  /// Where events and reminders are read from.
  let store: any CalendarStore

  /// The calendars and reminder lists to include.
  let settings: CalendarSettings

  /// How items are formatted.
  let report: CalendarReport

  /// How long to wait for an answer to a permission request. macOS keeps its dialog open indefinitely.
  var requestTimeout: Duration = .seconds(120)

  /// Returns the lines for the events in `window`, requesting undecided permission unless `noPrompt` is set.
  ///
  /// Throws `AccessMissing`, `AuthorizationFailed` or `AuthorizationTimedOut` without reading anything.
  func events(in window: CalendarWindow, noPrompt: Bool = false) async throws -> [String] {
    try await requireAccess(to: .events, noPrompt: noPrompt)
    return report.eventLines(store.events(in: window), calendars: settings.calendars)
  }

  /// Returns the lines for the incomplete reminders due in `window`, or overdue by up to `overdueDays`, requesting
  /// undecided permission unless `noPrompt` is set.
  ///
  /// Throws `AccessMissing`, `AuthorizationFailed` or `AuthorizationTimedOut` without reading anything. Older overdue
  /// reminders are left out, so a long tail of forgotten ones does not crowd out what is due now.
  func reminders(in window: CalendarWindow, noPrompt: Bool = false) async throws -> [String] {
    try await requireAccess(to: .reminders, noPrompt: noPrompt)
    let start = report.calendar.date(byAdding: .day, value: -Self.overdueDays, to: window.start) ?? window.start
    return report.reminderLines(await store.incompleteReminders(due: start..<window.end), lists: settings.reminderLists)
  }

}

extension CalendarQueries {
  /// Thrown when `agt` may not read one kind of item.
  struct AccessMissing: Error, Equatable, CustomStringConvertible {
    /// The kind of item that could not be read.
    let kind: CalendarItemKind

    /// The access `agt` has to it.
    let access: CalendarAccess

    /// Whether `--no-prompt` stopped `agt` asking for undecided access.
    var requestSuppressed = false

    /// Explains the reported state without treating an inaccessible permission service as a refused grant.
    var description: String {
      let reason = "agt cannot read \(kind.label) (\(access))."
      switch access {
        case .notDetermined where requestSuppressed:
          return "\(reason) --no-prompt suppressed the permission request. An agent sandbox can also hide permission already granted to agt, so this does not show that access is missing."
        case .notDetermined:
          return "\(reason) An agent sandbox can hide permission already granted to agt. Retry this query outside the sandbox using the agent's approval flow."
        case .denied, .writeOnly:
          return "\(reason) Enable full access in System Settings > Privacy & Security > \(kind.settingsPane)."
        case .restricted:
          return "\(reason) A system policy restricts access; another authorization request cannot override that policy."
        case .granted:
          return reason
      }
    }
  }

  /// A permission request failed before its outcome could be reported.
  struct AuthorizationFailed: Error, CustomStringConvertible {
    /// The resource whose permission was being requested.
    let kind: CalendarItemKind

    /// The original macOS error, retained for diagnosis.
    let underlying: NSError

    /// Identifies the operation and service error without claiming that the user refused access.
    var description: String {
      "Could not request access to \(kind.label): \(underlying.localizedDescription) (\(underlying.domain), code \(underlying.code)). This failure does not confirm a permission denial. If running in an agent sandbox, retry this query outside the sandbox using the agent's approval flow."
    }
  }

  /// Carries the store into the task making a permission request.
  ///
  /// Only that task uses the store until a result arrives, and after a timeout the query throws without using it.
  private struct PermissionRequester: @unchecked Sendable {
    /// The store to ask.
    let store: any CalendarStore
  }

  /// Nobody answered a permission request in time.
  struct AuthorizationTimedOut: Error, Equatable, CustomStringConvertible {
    /// The resource whose permission was being requested.
    let kind: CalendarItemKind

    /// How long the request waited.
    let seconds: Int64

    /// Explains that the request is still open, and how to avoid waiting for one.
    var description: String {
      "Nobody answered the request for access to \(kind.label) within \(seconds) seconds, and nothing was read. The macOS dialog may still be on screen: answer it, then run this query again. Use --no-prompt where nobody can answer a dialog."
    }
  }

  /// Requests undecided access unless prompting is suppressed, then requires a full grant before reading.
  private func requireAccess(to kind: CalendarItemKind, noPrompt: Bool) async throws {
    var access = store.access(to: kind)
    if access == .notDetermined && !noPrompt {
      do {
        access = try await requestWithTimeout(to: kind)
      } catch is CancellationError {
        throw CancellationError()
      } catch let timedOut as AuthorizationTimedOut {
        throw timedOut
      } catch {
        throw AuthorizationFailed(kind: kind, underlying: error as NSError)
      }
    }
    guard access == .granted else {
      throw AccessMissing(kind: kind, access: access, requestSuppressed: noPrompt && access == .notDetermined)
    }
  }

  /// Returns the outcome of a permission request, or throws `AuthorizationTimedOut` when it takes too long.
  ///
  /// EventKit cannot cancel a request, so the two tasks race and the first result wins, leaving the request behind.
  private func requestWithTimeout(to kind: CalendarItemKind) async throws -> CalendarAccess {
    let requester = PermissionRequester(store: store)
    let timeout = requestTimeout
    let (results, continuation) = AsyncStream.makeStream(of: Result<CalendarAccess, any Error>.self)
    let request = Task {
      do {
        continuation.yield(.success(try await requester.store.requestAccess(to: kind)))
      } catch {
        continuation.yield(.failure(error))
      }
    }
    let timer = Task {
      try await Task.sleep(for: timeout)
      continuation.yield(.failure(AuthorizationTimedOut(kind: kind, seconds: timeout.components.seconds)))
    }
    defer {
      request.cancel()
      timer.cancel()
    }
    for await result in results {
      return try result.get()
    }
    throw CancellationError()
  }
}
