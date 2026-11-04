// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Runs a calendar command's work with the real calendar store, in the `agt` process that holds the calendar
/// permission.
///
/// `SelfResponsibleRunner` relaunches `agt` when needed; this type is the only place the real store is created.
enum CalendarRunner {
  /// Runs `work` with the real calendar store and prints its lines.
  static func run(_ work: (CalendarQueries) async throws -> [String]) async throws {
    try await SelfResponsibleRunner.run(task: "read calendars or reminders") {
      let settings = try await CalendarSettings.load(path: CalendarSettings.defaultPath(homeDirectory: .homeDirectory))
      let queries = CalendarQueries(store: EventKitCalendarStore(), settings: settings, report: CalendarReport(calendar: .current))
      for line in try await work(queries) {
        print(line)
      }
    }
  }
}
