// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Testing

@testable import AgentToolsCore

/// Tests that `agt` runs only the commands that need its own permissions when it is its own responsible process.
struct SelfResponsibleGuardTests {
  /// What to do for each combination of responsibility and relaunch state.
  @Test(arguments: [
    (Bool?.none, false, SelfResponsibleExecution.unavailable),
    (Bool?.none, true, SelfResponsibleExecution.unavailable),
    (true, false, SelfResponsibleExecution.run),
    (true, true, SelfResponsibleExecution.run),
    (false, false, SelfResponsibleExecution.relaunch),
    (false, true, SelfResponsibleExecution.disclaimFailed),
  ])
  func plansExecution(selfResponsible: Bool?, relaunched: Bool, expected: SelfResponsibleExecution) {
    #expect(SelfResponsibleExecution.plan(selfResponsible: selfResponsible, relaunched: relaunched) == expected)
  }

  /// A self-responsible `agt` parses only the restricted root.
  @Test func selfResponsibleRootIsRestricted() {
    #expect(ObjectIdentifier(AgentToolsLauncher.rootCommand(selfResponsible: true)) == ObjectIdentifier(SelfResponsibleCommand.self))
    #expect(ObjectIdentifier(AgentToolsLauncher.rootCommand(selfResponsible: false)) == ObjectIdentifier(AgentToolsCommand.self))
    #expect(ObjectIdentifier(AgentToolsLauncher.rootCommand(selfResponsible: nil)) == ObjectIdentifier(AgentToolsCommand.self))
  }

  /// The restricted root rejects every other command, including the ui commands that start or stop processes.
  @Test(arguments: [["validate"], ["refresh"], ["format"], ["sandbox", "configure"], ["skills", "link"], ["rules", "sync"], ["ui", "launch", "com.apple.TextEdit"], ["ui", "quit", "com.apple.TextEdit"]])
  func restrictedRootRejectsOtherCommands(arguments: [String]) {
    #expect(throws: (any Error).self) {
      _ = try SelfResponsibleCommand.parseAsRoot(arguments)
    }
  }

  /// The restricted root accepts the calendar commands.
  @Test func restrictedRootAcceptsCalendarCommands() throws {
    let command = try SelfResponsibleCommand.parseAsRoot(["calendar", "events", "--days", "3"])
    let events = try #require(command as? CalendarEventsCommand)
    #expect(events.days == 3)
    #expect(try SelfResponsibleCommand.parseAsRoot(["calendar", "reminders"]) is CalendarRemindersCommand)
    #expect(throws: (any Error).self) { _ = try SelfResponsibleCommand.parseAsRoot(["calendar", "authorize"]) }
    #expect(throws: (any Error).self) { _ = try AgentToolsCommand.parseAsRoot(["calendar", "authorize"]) }
  }

  /// The restricted root accepts the ui commands that need agt's own permissions.
  @Test(arguments: [
    ["ui", "screenshot", "shot.png"], ["ui", "tree"], ["ui", "press", "OK"], ["ui", "click", "1", "2"], ["ui", "drag", "1", "2", "3", "4"],
    ["ui", "scroll", "1", "2"], ["ui", "type", "text"], ["ui", "key", "cmd+n"],
  ])
  func restrictedRootAcceptsPermissionCommands(arguments: [String]) throws {
    let restricted = try SelfResponsibleCommand.parseAsRoot(arguments)
    let normal = try AgentToolsCommand.parseAsRoot(arguments)
    #expect(type(of: restricted) == type(of: normal))
  }

  /// Both roots expose noPrompt mode for both queries, defaulting to interactive.
  @Test(arguments: [false, true])
  func parsesNoPrompt(restricted: Bool) throws {
    let root: any ParsableCommand.Type = restricted ? SelfResponsibleCommand.self : AgentToolsCommand.self
    let events = try #require(root.parseAsRoot(["calendar", "events", "--no-prompt"]) as? CalendarEventsCommand)
    let reminders = try #require(root.parseAsRoot(["calendar", "reminders", "--no-prompt"]) as? CalendarRemindersCommand)
    #expect(events.noPrompt)
    #expect(reminders.noPrompt)
    #expect(try #require(root.parseAsRoot(["calendar", "events"]) as? CalendarEventsCommand).noPrompt == false)
    #expect(try #require(root.parseAsRoot(["calendar", "reminders"]) as? CalendarRemindersCommand).noPrompt == false)
  }

  /// The normal root offers the calendar commands too, and rejects day counts over the limit.
  @Test func normalRootValidatesDays() throws {
    #expect(try AgentToolsCommand.parseAsRoot(["calendar", "events"]) is CalendarEventsCommand)
    #expect(throws: (any Error).self) {
      _ = try AgentToolsCommand.parseAsRoot(["calendar", "reminders", "--days", "15"])
    }
  }
}
