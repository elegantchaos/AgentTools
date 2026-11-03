// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 30/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

/// Checks the sources so that tests cannot reach the user's real calendars and `agt` cannot change them.
///
/// These read source text only. Nothing here touches EventKit.
struct CalendarIsolationTests {
  /// The package root, found from this file's location.
  private let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

  /// Tests never name anything that leads to the real store, or run a parsed calendar command.
  @Test func testsCannotReachRealCalendars() throws {
    let forbidden = ["import EventKit", "EKEventStore", "EventKitCalendarStore", "CalendarRunner", "AgentToolsLauncher.main", ".main("]
    for file in try swiftFiles(in: "Tests") where file.lastPathComponent != URL(fileURLWithPath: #filePath).lastPathComponent {
      let source = try String(contentsOf: file, encoding: .utf8)
      for term in forbidden {
        #expect(source.contains(term) == false, "\(file.lastPathComponent) must not use \(term)")
      }
      if source.contains("Calendar") {
        #expect(source.contains(".run()") == false, "\(file.lastPathComponent) must not run a command")
      }
    }
  }

  /// EventKit is used by one source file, and only `CalendarRunner` creates the real store.
  @Test func realStoreIsConfined() throws {
    for file in try swiftFiles(in: "Sources") {
      let source = try String(contentsOf: file, encoding: .utf8)
      if file.lastPathComponent != "EventKitCalendarStore.swift" {
        #expect(source.contains("import EventKit") == false, "\(file.lastPathComponent) must not import EventKit")
      }
      if file.lastPathComponent != "CalendarRunner.swift" {
        #expect(source.contains("EventKitCalendarStore(") == false, "\(file.lastPathComponent) must not create the real store")
      }
    }
  }

  /// The real store uses no EventKit API that writes, discards changes, or creates items.
  @Test func realStoreIsReadOnly() throws {
    let file = root.appendingPathComponent("Sources/AgentToolsCore/Calendar/EventKitCalendarStore.swift")
    let source = try String(contentsOf: file, encoding: .utf8)
    for term in [".save", ".remove", ".commit", ".reset", ".refreshSourcesIfNecessary", "EKEvent(", "EKReminder(", "EKCalendar(", "EKAlarm(", "EKSource"] {
      #expect(source.contains(term) == false, "The real store must not use \(term)")
    }
  }

  /// Returns the Swift files under a top-level directory of the package.
  private func swiftFiles(in directory: String) throws -> [URL] {
    let top = root.appendingPathComponent(directory)
    let enumerator = try #require(FileManager.default.enumerator(at: top, includingPropertiesForKeys: nil))
    let files = enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    try #require(files.isEmpty == false)
    return files
  }
}
