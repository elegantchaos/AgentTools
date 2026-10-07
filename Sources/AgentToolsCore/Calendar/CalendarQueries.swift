// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// The calendar commands' work, once `agt` is running as its own responsible process: checking access, reading
/// items from a store, and formatting them.
struct CalendarQueries {
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

  /// Returns the lines for the incomplete reminders due before the end of `window`, including overdue ones, or throws
  /// `AccessMissing` without reading anything.
  func reminders(in window: CalendarWindow) async throws -> [String] {
    try requireAccess(to: .reminders)
    return report.reminderLines(await store.incompleteReminders(dueBefore: window.end), lists: settings.reminderLists)
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
        access = try await store.requestAccess(to: kind)
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

    /// Explains what to run.
    var description: String {
      "agt does not have access to \(kind.label) (\(access)). Run `agt calendar authorize`, then try again."
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
