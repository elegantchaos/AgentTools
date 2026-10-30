// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// The calendar commands' work, once `agt` is running as its own responsible process: checking access, reading
/// items from a store, and formatting them.
struct CalendarQueries {
  /// The most days overdue a reminder can be and still be listed.
  static let overdueDays = 7

  /// Where events and reminders are read from.
  let store: any CalendarStore

  /// The calendars and reminder lists to include.
  let settings: CalendarSettings

  /// How items are formatted.
  let report: CalendarReport

  /// Returns the lines for the events in `window`, or throws `AccessMissing` without reading anything.
  func events(in window: CalendarWindow) async throws -> [String] {
    try requireAccess(to: .events)
    return report.eventLines(store.events(in: window), calendars: settings.calendars)
  }

  /// Returns the lines for the incomplete reminders due in `window`, or overdue by up to `overdueDays`, or throws
  /// `AccessMissing` without reading anything.
  ///
  /// Older overdue reminders are left out, so a long tail of forgotten ones does not crowd out what is due now.
  func reminders(in window: CalendarWindow) async throws -> [String] {
    try requireAccess(to: .reminders)
    let start = report.calendar.date(byAdding: .day, value: -Self.overdueDays, to: window.start) ?? window.start
    return report.reminderLines(await store.incompleteReminders(due: start..<window.end), lists: settings.reminderLists)
  }

  /// Asks for access to each kind of item that has not been decided yet, and returns a line describing the access to
  /// each.
  ///
  /// macOS shows its prompt only for an undecided kind, so a denied kind is reported with where to change it.
  func authorize() async throws -> [String] {
    var lines: [String] = []
    for kind in CalendarItemKind.allCases {
      var access = store.access(to: kind)
      if access == .notDetermined {
        do {
          access = try await store.requestAccess(to: kind)
        } catch is CancellationError {
          throw CancellationError()
        } catch {
          throw AuthorizationFailed(kind: kind, underlying: error as NSError)
        }
      }
      lines.append(Self.line(for: kind, access: access))
    }
    return lines
  }
}

extension CalendarQueries {
  /// Thrown when `agt` may not read one kind of item.
  struct AccessMissing: Error, Equatable, CustomStringConvertible {
    /// The kind of item that could not be read.
    let kind: CalendarItemKind

    /// The access `agt` has to it.
    let access: CalendarAccess

    /// Explains the reported state without treating an inaccessible permission service as a refused grant.
    var description: String {
      let reason = "agt cannot read \(kind.label) (\(access))."
      switch access {
        case .notDetermined:
          return "\(reason) An agent sandbox can hide permission already granted to agt. Retry this query outside the sandbox using the agent's approval flow. If access is still not determined there, run `agt calendar authorize` outside the sandbox."
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
      "Could not request access to \(kind.label): \(underlying.localizedDescription) (\(underlying.domain), code \(underlying.code)). This failure does not confirm a permission denial. If running in an agent sandbox, retry `agt calendar authorize` outside the sandbox using the agent's approval flow."
    }
  }

  /// Throws `AccessMissing` unless `agt` has full access to `kind`.
  private func requireAccess(to kind: CalendarItemKind) throws {
    let access = store.access(to: kind)
    guard access == .granted else { throw AccessMissing(kind: kind, access: access) }
  }

  /// Describes the access to one kind, such as `Calendars: granted`.
  private static func line(for kind: CalendarItemKind, access: CalendarAccess) -> String {
    switch access {
      case .denied, .writeOnly:
        "\(kind.settingsPane): \(access) (change this in System Settings > Privacy & Security > \(kind.settingsPane))"
      default:
        "\(kind.settingsPane): \(access)"
    }
  }
}
