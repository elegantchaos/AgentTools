// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// An incomplete reminder as `agt calendar` reports it: only the fields it is allowed to print.
struct CalendarReminder: Equatable, Sendable {
  /// The reminder's title, as stored.
  let title: String

  /// When the reminder is due.
  let due: Date

  /// Whether the due date includes a time of day.
  let hasDueTime: Bool

  /// The title of the list holding the reminder.
  let list: String
}
