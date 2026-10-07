// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Formats events and reminders as the lines `agt calendar` prints.
///
/// Each item is one line. Every field from the calendar passes through `CalendarText.singleLine`, so stored text
/// cannot add lines or control sequences of its own.
struct CalendarReport {
  /// The calendar and time zone used to show dates.
  let calendar: Calendar

  /// Returns one line per event in `events`, sorted by start, keeping only those in `calendars` when names are given.
  func eventLines(_ events: [CalendarEvent], calendars: [String]?) -> [String] {
    let included = Self.filter(events, by: \.calendar, names: calendars)
    guard !included.isEmpty else { return ["No events."] }
    return included.sorted { ($0.start, $0.title) < ($1.start, $1.title) }.map(line(for:))
  }

  /// Returns one line per reminder in `reminders`, sorted by due date, keeping only those in `lists` when names are
  /// given.
  func reminderLines(_ reminders: [CalendarReminder], lists: [String]?) -> [String] {
    let included = Self.filter(reminders, by: \.list, names: lists)
    guard !included.isEmpty else { return ["No reminders."] }
    return included.sorted { ($0.due, $0.title) < ($1.due, $1.title) }.map(line(for:))
  }
}

extension CalendarReport {
  /// Formats one event, such as `2026-10-07 09:30–10:00  Standup @ Room 1 [Work]`.
  private func line(for event: CalendarEvent) -> String {
    let start = day(event.start)
    let times: String
    if event.isAllDay {
      // EventKit's end is exclusive; the preceding instant is on the final occupied day, including across DST.
      let lastDay = day(event.end.addingTimeInterval(-1))
      times = lastDay == start ? "all day" : "all day through \(lastDay)"
    } else if day(event.end) == start {
      times = "\(time(event.start))–\(time(event.end))"
    } else {
      times = "\(time(event.start))–\(day(event.end)) \(time(event.end))"
    }
    let location = CalendarText.singleLine(event.location ?? "")
    let place = location.isEmpty ? "" : " @ \(location)"
    return "\(start) \(times)  \(title(event.title))\(place) [\(CalendarText.singleLine(event.calendar))]"
  }

  /// Formats one reminder, such as `2026-10-07 16:15  Call plumber [Home]`.
  private func line(for reminder: CalendarReminder) -> String {
    let due = reminder.hasDueTime ? "\(day(reminder.due)) \(time(reminder.due))" : day(reminder.due)
    return "\(due)  \(title(reminder.title)) [\(CalendarText.singleLine(reminder.list))]"
  }

  /// Returns a title on one line, or a placeholder when it is empty.
  private func title(_ text: String) -> String {
    let title = CalendarText.singleLine(text)
    return title.isEmpty ? "(untitled)" : title
  }

  /// Formats the day of `date`, such as `2026-10-07`.
  private func day(_ date: Date) -> String {
    date.formatted(Date.VerbatimFormatStyle(format: "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits)", timeZone: calendar.timeZone, calendar: calendar))
  }

  /// Formats the time of `date` on a 24-hour clock, such as `09:30`.
  private func time(_ date: Date) -> String {
    date.formatted(Date.VerbatimFormatStyle(format: "\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)", timeZone: calendar.timeZone, calendar: calendar))
  }

  /// Returns the items whose name at `key` is in `names`, or every item when `names` is `nil` or empty.
  private static func filter<Item>(_ items: [Item], by key: KeyPath<Item, String>, names: [String]?) -> [Item] {
    guard let names, !names.isEmpty else { return items }
    let included = Set(names)
    return items.filter { included.contains($0[keyPath: key]) }
  }
}
