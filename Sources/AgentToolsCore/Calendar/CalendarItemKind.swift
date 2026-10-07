// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// The two kinds of item `agt calendar` reads, each with its own macOS privacy permission.
enum CalendarItemKind: Hashable, Sendable, CaseIterable {
  /// Calendar events.
  case events

  /// Reminders.
  case reminders

  /// The name used in messages, such as "calendars".
  var label: String {
    switch self {
      case .events: "calendars"
      case .reminders: "reminders"
    }
  }

  /// The name of the privacy pane in System Settings, such as "Calendars".
  var settingsPane: String {
    switch self {
      case .events: "Calendars"
      case .reminders: "Reminders"
    }
  }
}
