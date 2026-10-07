// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Testing

@testable import AgentToolsCore

/// Tests that `agt` runs only the calendar commands when it is its own responsible process.
struct CalendarGuardTests {
  /// What to do for each combination of responsibility and relaunch state.
  @Test(arguments: [
    (Bool?.none, false, CalendarExecution.unavailable),
    (Bool?.none, true, CalendarExecution.unavailable),
    (true, false, CalendarExecution.query),
    (true, true, CalendarExecution.query),
    (false, false, CalendarExecution.relaunch),
    (false, true, CalendarExecution.disclaimFailed),
  ])
  func plansExecution(selfResponsible: Bool?, relaunched: Bool, expected: CalendarExecution) {
    #expect(CalendarExecution.plan(selfResponsible: selfResponsible, relaunched: relaunched) == expected)
  }

  /// A self-responsible `agt` parses only calendar commands.
  @Test func selfResponsibleRootIsCalendarOnly() {
    #expect(ObjectIdentifier(AgentToolsLauncher.rootCommand(selfResponsible: true)) == ObjectIdentifier(CalendarOnlyCommand.self))
    #expect(ObjectIdentifier(AgentToolsLauncher.rootCommand(selfResponsible: false)) == ObjectIdentifier(AgentToolsCommand.self))
    #expect(ObjectIdentifier(AgentToolsLauncher.rootCommand(selfResponsible: nil)) == ObjectIdentifier(AgentToolsCommand.self))
  }

  /// The calendar-only root rejects every other command.
  @Test(arguments: [["validate"], ["refresh"], ["format"], ["sandbox", "configure"], ["skills", "link"], ["rules", "sync"]])
  func calendarOnlyRootRejectsOtherCommands(arguments: [String]) {
    #expect(throws: (any Error).self) {
      _ = try CalendarOnlyCommand.parseAsRoot(arguments)
    }
  }

  /// The calendar-only root accepts the calendar commands.
  @Test func calendarOnlyRootAcceptsCalendarCommands() throws {
    let command = try CalendarOnlyCommand.parseAsRoot(["calendar", "events", "--days", "3"])
    let events = try #require(command as? CalendarEventsCommand)
    #expect(events.days == 3)
    #expect(try CalendarOnlyCommand.parseAsRoot(["calendar", "reminders"]) is CalendarRemindersCommand)
    #expect(try CalendarOnlyCommand.parseAsRoot(["calendar", "authorize"]) is CalendarAuthorizeCommand)
  }

  /// The normal root offers the calendar commands too, and rejects day counts over the limit.
  @Test func normalRootValidatesDays() throws {
    #expect(try AgentToolsCommand.parseAsRoot(["calendar", "events"]) is CalendarEventsCommand)
    #expect(throws: (any Error).self) {
      _ = try AgentToolsCommand.parseAsRoot(["calendar", "reminders", "--days", "15"])
    }
  }
}
