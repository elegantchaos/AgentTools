// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Configuration
import Foundation

/// The calendars and reminder lists `agt calendar` includes, from the `calendar` key of the user's `.agt/config.json`.
///
/// This filters out calendars the user does not want reported, such as subscriptions. It is not a security boundary:
/// anything running as the user can edit the file.
struct CalendarSettings: Equatable {
  /// Titles of the calendars to include; `nil` includes every calendar.
  var calendars: [String]?

  /// Titles of the reminder lists to include; `nil` includes every list.
  var reminderLists: [String]?

  /// Returns the path of the user's configuration file in `homeDirectory`.
  static func defaultPath(homeDirectory: URL) -> String {
    homeDirectory.appending(path: ".agt/config.json").path
  }

  /// Loads the settings from the file at `path`; a missing file includes everything.
  static func load(path: String) async throws -> CalendarSettings {
    let fileConfig = ConfigReader(
      provider: InMemoryProvider(values: [
        AbsoluteConfigKey(["filePath"]): ConfigValue(.string(path), isSecret: false),
        AbsoluteConfigKey(["allowMissing"]): ConfigValue(.bool(true), isSecret: false),
      ])
    )
    let provider: FileProvider<JSONSnapshot>
    do {
      provider = try await FileProvider<JSONSnapshot>(config: fileConfig)
    } catch {
      throw ToolError("Invalid configuration file \(path): \(error)")
    }
    let config = ConfigReader(provider: provider)
    return CalendarSettings(
      calendars: config.stringArray(forKey: "calendar.calendars"),
      reminderLists: config.stringArray(forKey: "calendar.reminderLists")
    )
  }
}
