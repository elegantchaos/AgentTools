// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 25/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

@testable import AgentToolsCore

/// Tests the clean commit check, the background status record, and the background options.
struct BackgroundValidationTests {
  @Test func currentCommitRequiresAWorktreeWithoutLocalEdits() throws {
    let repo = try makeRepo()
    defer { try? FileManager.default.removeItem(at: repo) }
    let process = ValidationProcess(workingDirectory: repo.path)
    let tracked = repo.appendingPathComponent("Tracked.swift")
    let initial = try #require(try ValidationSnapshot.currentCleanCommit(using: process))

    try "ignored\n".write(to: repo.appendingPathComponent("build.log"), atomically: true, encoding: .utf8)
    #expect(try ValidationSnapshot.currentCleanCommit(using: process) == initial)

    try "let a = 2\n".write(to: tracked, atomically: true, encoding: .utf8)
    #expect(try ValidationSnapshot.currentCleanCommit(using: process) == nil)
    _ = try git(["restore", "Tracked.swift"], in: repo)

    try "let b = 1\n".write(to: repo.appendingPathComponent("New.swift"), atomically: true, encoding: .utf8)
    #expect(try ValidationSnapshot.currentCleanCommit(using: process) == nil)
    #expect(try git(["status", "--porcelain"], in: repo).contains("?? New.swift"))
  }

  @Test func statusRecordsRoundTripAndDescribeThemselves() throws {
    let root = try makeRepo()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = BackgroundStatusStore(directory: root.appendingPathComponent(".build/agt/background").path)
    #expect(store.load() == nil)

    let started = Date(timeIntervalSinceReferenceDate: 800_000_000)
    var status = BackgroundStatus(state: .running, pid: 123, commit: "abc", started: started)
    try store.save(status)
    #expect(store.load() == status)

    status.state = .failed
    status.finished = started.addingTimeInterval(95)
    status.steps = ["PASS build App (macOS)", "FAIL test App (macOS)"]
    try store.save(status)

    #expect(store.load()?.state == .failed)
    #expect(status.headline(currentCommit: "abc") == "Full validation failed after 1m 35s, for the current clean commit.")
    #expect(status.headline(currentCommit: "xyz") == "Full validation failed after 1m 35s, for a different checkout state.")
    #expect(BackgroundStatus(state: .running, pid: 1, commit: "abc", started: started).headline(currentCommit: "abc") == "Full validation is running.")
  }

  @Test(arguments: [
    (BackgroundStatus.State.passed, "abc", true),
    (.passed, "xyz", false),
    (.failed, "abc", false),
    (.running, "abc", false),
  ])
  func onlyAPassForTheCurrentTreeCanBeReused(state: BackgroundStatus.State, current: String, expected: Bool) {
    let status = BackgroundStatus(state: state, pid: 1, commit: "abc", started: .now)
    #expect(status.isCurrentPass(currentCommit: current) == expected)
  }

  @Test func aRunningStepStopsPromptlyWhenAsked() throws {
    let root = try makeRepo()
    defer { try? FileManager.default.removeItem(at: root) }
    let started = Date.now
    let result = try ValidationProcess(workingDirectory: root.path).runLogged(
      ["sleep", "30"],
      logPath: root.appendingPathComponent("sleep.log").path,
      outputMode: .quiet,
      shouldStop: { Date.now.timeIntervalSince(started) > 0.5 }
    )
    #expect(result.status != 0)
    #expect(Date.now.timeIntervalSince(started) < 5)
  }

  @Test func anInterruptedStepIsRecordedAsStopped() throws {
    let root = try makeRepo()
    defer { try? FileManager.default.removeItem(at: root) }
    let runner = StepRunner(repoPath: root.path, outputMode: .quiet)
    runner.shouldStop = { true }
    #expect(throws: (any Error).self) {
      try runner.run(title: "Sleep", summary: "sleep", arguments: ["sleep", "30"], logPath: root.appendingPathComponent("sleep.log").path)
    }
    #expect(runner.summaryLines == ["STOP sleep"])
  }

  @Test func onlyTheTokenHolderOwnsARunningValidation() {
    var status = BackgroundStatus(state: .running, pid: 1, commit: "abc", started: .now, token: "mine")
    #expect(status.isOwned(byToken: "mine"))
    #expect(!status.isOwned(byToken: "theirs"))
    status.state = .cancelled
    #expect(!status.isOwned(byToken: "mine"))
  }

  @Test func backgroundOptionsParse() throws {
    let command = try ValidateCommand.parse(["--full", "--background"])
    #expect(throws: (any Error).self) { try ValidateCommand.parse(["--fast"]) }
    #expect(command.background)
    #expect(try ValidateCommand.parse(["--status"]).status)
    #expect(try ValidateCommand.parse(["--wait"]).wait)
    #expect(try ValidateCommand.parse(["--background-worker"]).backgroundWorker)
  }

  @Test func workerArgumentsReplaceBackgroundWithTheWorkerFlag() {
    #expect(
      BackgroundLauncher.workerArguments(from: ["validate", "--full", "--background", "--platforms", "macOS"])
        == ["validate", "--full", "--platforms", "macOS", "--background-worker"]
    )
  }

  @Test func pairedCheckoutReusesBuildsAndTestsThePinnedCommit() throws {
    let root = try makeRepo()
    defer { try? FileManager.default.removeItem(at: root) }
    let source = ValidationProcess(workingDirectory: root.path)
    let paired = ValidationCheckout(source: source)
    let config = try ValidateCommand.parse([]).config(repoPath: root.path)
    let initial = try ValidationSnapshot(process: source, config: config)
    _ = try git(["switch", "-c", "feature/test"], in: root)
    let tracked = root.appendingPathComponent("Tracked.swift")
    try "let a = 2\n".write(to: tracked, atomically: true, encoding: .utf8)
    #expect(throws: ToolError.self) { try ValidationSnapshot(process: source, config: config) }
    _ = try git(["-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-qam", "Change source"], in: root)
    let updated = try ValidationSnapshot(process: source, config: config)
    #expect(updated.baseline == initial.commit)
    #expect(try updated.changedPaths(using: source) == ["Tracked.swift"])

    try paired.materialise(commit: initial.commit)
    let checkout = URL(fileURLWithPath: paired.path)
    let build = checkout.appendingPathComponent(".build/agt")
    try FileManager.default.createDirectory(at: build, withIntermediateDirectories: true)
    let cached = build.appendingPathComponent("cached")
    let generated = checkout.appendingPathComponent("generated.log")
    try Data().write(to: cached)
    try Data().write(to: generated)
    try paired.materialise(commit: updated.commit)
    #expect(FileManager.default.fileExists(atPath: cached.path))
    #expect(!FileManager.default.fileExists(atPath: generated.path))
    #expect(try String(contentsOf: checkout.appendingPathComponent("Tracked.swift"), encoding: .utf8) == "let a = 2\n")

    let other = root.appendingPathComponent(".build/other")
    _ = try git(["worktree", "add", "--detach", other.path, initial.commit], in: root)
    let otherPair = ValidationCheckout(source: ValidationProcess(workingDirectory: other.path))
    try otherPair.materialise(commit: initial.commit)
    try paired.materialise(commit: initial.commit)
    #expect(paired.path != otherPair.path)
    #expect(try git(["rev-parse", "HEAD"], in: other) == initial.commit + "\n")
    #expect(try git(["rev-parse", "HEAD"], in: root) == updated.commit + "\n")
    #expect(try String(contentsOf: checkout.appendingPathComponent("Tracked.swift"), encoding: .utf8) == "let a = 1\n")
  }

  /// Creates a git repository with one committed file and an ignore rule for logs.
  private func makeRepo() throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AgentTools-Background-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    _ = try git(["init", "--quiet", "--initial-branch=main"], in: url)
    try "*.log\n.build/\n".write(to: url.appendingPathComponent(".gitignore"), atomically: true, encoding: .utf8)
    try "let a = 1\n".write(to: url.appendingPathComponent("Tracked.swift"), atomically: true, encoding: .utf8)
    _ = try git(["add", "."], in: url)
    _ = try git(["-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "--quiet", "-m", "Initial"], in: url)
    return url
  }

  /// Runs a git command in a directory and returns its output.
  private func git(_ arguments: [String], in directory: URL) throws -> String {
    let result = try ValidationProcess(workingDirectory: directory.path).capture(["git"] + arguments)
    #expect(result.status == 0)
    return result.stdout
  }
}
