// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

@testable import AgentToolsCore

/// Tests reading the calendars and reminder lists to include from the user's configuration file.
struct CalendarSettingsTests {
  /// A missing file includes everything.
  @Test func missingFileIncludesEverything() async throws {
    let settings = try await CalendarSettings.load(path: "/nonexistent/config.json")
    #expect(settings == CalendarSettings(calendars: nil, reminderLists: nil))
  }

  /// The file names the calendars and reminder lists to include.
  @Test func readsNamedCalendarsAndLists() async throws {
    let file = FileManager.default.temporaryDirectory.appending(path: "agt-calendar-settings-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: file) }
    try #"{"calendar": {"calendars": ["Home", "Work"], "reminderLists": ["Reminders"]}}"#.write(to: file, atomically: true, encoding: .utf8)

    let settings = try await CalendarSettings.load(path: file.path)

    #expect(settings == CalendarSettings(calendars: ["Home", "Work"], reminderLists: ["Reminders"]))
  }

  /// The default file is `.agt/config.json` in the home directory.
  @Test func defaultPathIsInTheHomeDirectory() {
    #expect(CalendarSettings.defaultPath(homeDirectory: URL(fileURLWithPath: "/Users/someone")) == "/Users/someone/.agt/config.json")
  }
}
