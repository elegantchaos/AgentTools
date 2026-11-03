// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation

/// Runs a calendar command's work in the process that holds the calendar permission.
///
/// Started normally, `agt` relaunches itself as its own responsible process with the same arguments, passes its
/// output through, and exits with its status. The relaunched `agt` reads the calendar. Decision 0007 in
/// `Extras/Decisions` records why.
enum CalendarRunner {
  /// Environment variable that marks a relaunched `agt`, so a failed disclaim cannot relaunch forever.
  static let relaunchVariable = "AGT_CALENDAR_RELAUNCHED"

  /// Runs `work` with the real calendar store and prints its lines, relaunching first when this process does not hold
  /// the permission.
  static func run(_ work: (CalendarQueries) async throws -> [String]) async throws {
    let environment = ProcessInfo.processInfo.environment
    switch CalendarExecution.plan(selfResponsible: ResponsibleProcess.isSelfResponsible(), relaunched: environment[relaunchVariable] != nil) {
      case .query:
        let parentWatch = environment[relaunchVariable] == nil ? nil : exitWhenParentExits()
        defer { parentWatch?.cancel() }
        let settings = try await CalendarSettings.load(path: CalendarSettings.defaultPath(homeDirectory: .homeDirectory))
        let queries = CalendarQueries(store: EventKitCalendarStore(), settings: settings, report: CalendarReport(calendar: .current))
        for line in try await work(queries) {
          print(line)
        }
      case .relaunch:
        guard let executable = Bundle.main.executablePath else {
          throw ToolError("Cannot find the agt executable to read calendars.")
        }
        let status = try ResponsibleProcess.runDisclaimed(
          executable: executable,
          arguments: Array(CommandLine.arguments.dropFirst()),
          environment: environment.merging([relaunchVariable: "1"]) { _, new in new }
        )
        guard status == 0 else { throw ExitCode(status) }
      case .unavailable:
        throw ToolError("This version of macOS does not provide the private functions agt needs to read calendars safely.")
      case .disclaimFailed:
        throw ToolError("agt could not run as its own responsible process, so it will not read calendars or reminders.")
    }
  }

  /// Ends this process when the `agt` that relaunched it ends, so that a cancelled query cannot read or print later.
  private static func exitWhenParentExits() -> any DispatchSourceProcess {
    let parent = getppid()
    let source = DispatchSource.makeProcessSource(identifier: parent, eventMask: .exit, queue: .global())
    source.setEventHandler { exit(EXIT_FAILURE) }
    source.resume()
    if getppid() != parent { exit(EXIT_FAILURE) }
    return source
  }
}
