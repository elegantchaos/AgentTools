// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser

/// Parent command for reading upcoming events and reminders.
struct CalendarCommand: ParsableCommand {
  /// Command metadata and available subcommands.
  static let configuration = CommandConfiguration(
    commandName: "calendar",
    abstract: "List upcoming events and reminders.",
    discussion: """
      agt reads calendars as its own responsible process, so macOS grants the permission to agt and not to the \
      terminal or app that runs it. Run `agt calendar authorize` once, and again after each agt update. Output is \
      limited to times, titles, locations, and calendar or list names, one short line per item, for at most \
      \(CalendarWindow.maximumDays) days. To include only some calendars or reminder lists, name them under \
      `calendar.calendars` and `calendar.reminderLists` in ~/.agt/config.json.
      """,
    subcommands: [
      CalendarAuthorizeCommand.self,
      CalendarEventsCommand.self,
      CalendarRemindersCommand.self,
    ]
  )
}
