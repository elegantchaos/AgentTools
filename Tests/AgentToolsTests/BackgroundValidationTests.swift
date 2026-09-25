// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 25/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

@testable import AgentTools

/// Tests the working-tree fingerprint, the background status record, and the background options.
struct BackgroundValidationTests {
  @Test func fingerprintFollowsTrackedUntrackedAndIgnoredFiles() throws {
    let repo = try makeRepo()
    defer { try? FileManager.default.removeItem(at: repo) }
    let process = ValidationProcess(workingDirectory: repo.path)

    let initial = try WorkingTreeFingerprint.current(using: process)
    #expect(try WorkingTreeFingerprint.current(using: process) == initial)

    try "let a = 2\n".write(to: repo.appendingPathComponent("Tracked.swift"), atomically: true, encoding: .utf8)
    let edited = try WorkingTreeFingerprint.current(using: process)
    #expect(edited != initial)

    try "let b = 1\n".write(to: repo.appendingPathComponent("New.swift"), atomically: true, encoding: .utf8)
    let untracked = try WorkingTreeFingerprint.current(using: process)
    #expect(untracked != edited)

    try "ignored\n".write(to: repo.appendingPathComponent("build.log"), atomically: true, encoding: .utf8)
    #expect(try WorkingTreeFingerprint.current(using: process) == untracked)

    #expect(try git(["status", "--porcelain"], in: repo).contains("?? New.swift"))
  }

  @Test func statusRecordsRoundTripAndDescribeThemselves() throws {
    let root = try makeRepo()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = BackgroundStatusStore(directory: root.appendingPathComponent(".build/agt/background").path)
    #expect(store.load() == nil)

    let started = Date(timeIntervalSinceReferenceDate: 800_000_000)
    var status = BackgroundStatus(state: .running, pid: 123, fingerprint: "abc", started: started)
    try store.save(status)
    #expect(store.load() == status)

    status.state = .failed
    status.finished = started.addingTimeInterval(95)
    status.steps = ["PASS build App (macOS)", "FAIL test App (macOS)"]
    try store.save(status)

    #expect(store.load()?.state == .failed)
    #expect(status.headline(currentFingerprint: "abc") == "Full validation failed after 1m 35s, for the current working tree.")
    #expect(status.headline(currentFingerprint: "xyz") == "Full validation failed after 1m 35s, for an earlier working tree.")
    #expect(BackgroundStatus(state: .running, pid: 1, fingerprint: "abc", started: started).headline(currentFingerprint: "abc") == "Full validation is running.")
    #expect(BackgroundStatus(state: .stale, pid: 1, fingerprint: "abc", started: started).headline(currentFingerprint: "abc") == "Full validation finished, but the working tree changed while it ran, so its result does not apply.")
  }

  @Test(arguments: [
    (BackgroundStatus.State.passed, "abc", true),
    (.passed, "xyz", false),
    (.failed, "abc", false),
    (.running, "abc", false),
    (.stale, "abc", false),
  ])
  func onlyAPassForTheCurrentTreeCanBeReused(state: BackgroundStatus.State, current: String, expected: Bool) {
    let status = BackgroundStatus(state: state, pid: 1, fingerprint: "abc", started: .now)
    #expect(status.isCurrentPass(currentFingerprint: current) == expected)
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

  @Test func onlyTheTokenHolderOwnsARunningValidation() {
    var status = BackgroundStatus(state: .running, pid: 1, fingerprint: "abc", started: .now, token: "mine")
    #expect(status.isOwned(byToken: "mine"))
    #expect(!status.isOwned(byToken: "theirs"))
    status.state = .cancelled
    #expect(!status.isOwned(byToken: "mine"))
  }

  @Test func backgroundOptionsParse() throws {
    let command = try ValidateCommand.parse(["--fast", "--background"])
    #expect(command.fast)
    #expect(command.background)
    #expect(try ValidateCommand.parse(["--status"]).status)
    #expect(try ValidateCommand.parse(["--wait"]).wait)
    #expect(try ValidateCommand.parse(["--background-worker"]).backgroundWorker)
  }

  @Test func workerArgumentsReplaceBackgroundWithTheWorkerFlag() {
    #expect(
      BackgroundLauncher.workerArguments(from: ["validate", "--fast", "--background", "--platforms", "macOS"])
        == ["validate", "--platforms", "macOS", "--background-worker"]
    )
  }

  /// Creates a git repository with one committed file and an ignore rule for logs.
  private func makeRepo() throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AgentTools-Background-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    _ = try git(["init", "--quiet"], in: url)
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
