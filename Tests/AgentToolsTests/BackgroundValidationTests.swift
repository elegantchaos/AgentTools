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

  @Test(
    arguments: [
      (BackgroundStatus.State.passed, true, "abc", false, true),
      (.passed, true, "abc", true, true),
      (.passed, false, "abc", false, true),
      (.passed, false, "abc", true, false),
      (.passed, true, "xyz", false, false),
      (.passed, true, nil, false, false),
      (.empty, false, "abc", false, false),
      (.failed, true, "abc", false, false),
      (.cancelled, true, "abc", false, false),
    ] as [(BackgroundStatus.State, Bool, String?, Bool, Bool)])
  func waitAcceptsOnlyAPassOfTheRequiredScopeForTheCurrentCommit(
    state: BackgroundStatus.State, full: Bool, current: String?, requireFull: Bool, satisfied: Bool
  ) {
    let status = BackgroundStatus(state: state, pid: 1, commit: "abc", started: .now, full: full)
    #expect((status.waitFailure(currentCommit: current, requireFull: requireFull) == nil) == satisfied)
  }

  @Test func anEmptyChangeScopeIsReportedAsNothingValidated() {
    let status = BackgroundStatus(state: .empty, pid: 1, commit: "abc", started: .now, full: false)
    #expect(status.headline(currentCommit: "abc") == "Change-scoped validation found nothing to build or test, for the current clean commit.")
    #expect(!status.isCurrentPass(currentCommit: "abc"))
    #expect(status.waitFailure(currentCommit: "abc", requireFull: false)?.contains("nothing to build or test") == true)
  }

  @Test(arguments: [["--full"], ["--background"]])
  func targetedValidationRejectsCommittedOptions(options: [String]) throws {
    let root = try makeRepo()
    defer { try? FileManager.default.removeItem(at: root) }
    let config = try ValidateCommand.parse(["--target", "Core"] + options).config(repoPath: root.path)
    #expect(throws: ToolError.self) { try ValidationTool(config: config, repoPath: root.path).run() }
  }

  @Test func changeScopeFallsBackToOriginMainAndFailsClearlyWithoutEither() throws {
    let root = try makeRepo()
    defer { try? FileManager.default.removeItem(at: root) }
    let source = ValidationProcess(workingDirectory: root.path)
    let config = try ValidateCommand.parse([]).config(repoPath: root.path)
    let initial = try git(["rev-parse", "HEAD"], in: root).trimmingCharacters(in: .newlines)
    _ = try git(["branch", "-m", "main", "feature/test"], in: root)
    _ = try git(["update-ref", "refs/remotes/origin/main", initial], in: root)
    try "let a = 2\n".write(to: root.appendingPathComponent("Tracked.swift"), atomically: true, encoding: .utf8)
    _ = try git(["-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-qam", "Change source"], in: root)
    #expect(try ValidationSnapshot(process: source, config: config).baseline == initial)

    _ = try git(["update-ref", "-d", "refs/remotes/origin/main"], in: root)
    let error = #expect(throws: ToolError.self) { try ValidationSnapshot(process: source, config: config) }
    #expect(error?.description.contains("local main or origin/main") == true)
  }

  @Test func pairedCheckoutRefusesACheckoutItDidNotCreate() throws {
    let root = try makeRepo()
    defer { try? FileManager.default.removeItem(at: root) }
    let paired = ValidationCheckout(source: ValidationProcess(workingDirectory: root.path))
    let foreign = URL(fileURLWithPath: paired.path)
    try FileManager.default.createDirectory(at: foreign, withIntermediateDirectories: true)
    _ = try git(["init", "--quiet"], in: foreign)
    let precious = foreign.appendingPathComponent("precious.txt")
    try "keep\n".write(to: precious, atomically: true, encoding: .utf8)
    let commit = try git(["rev-parse", "HEAD"], in: root).trimmingCharacters(in: .newlines)

    #expect(throws: ToolError.self) { try paired.materialise(commit: commit) }
    #expect(FileManager.default.fileExists(atPath: precious.path))
  }

  @Test func pairedCheckoutRefusesACheckoutMovedOntoABranch() throws {
    let root = try makeRepo()
    defer { try? FileManager.default.removeItem(at: root) }
    let paired = ValidationCheckout(source: ValidationProcess(workingDirectory: root.path))
    let commit = try git(["rev-parse", "HEAD"], in: root).trimmingCharacters(in: .newlines)
    try paired.materialise(commit: commit)
    _ = try git(["switch", "--quiet", "-c", "someone-elses-work"], in: URL(fileURLWithPath: paired.path))

    #expect(throws: ToolError.self) { try paired.materialise(commit: commit) }
  }

  @Test func pairedCheckoutRefusesRedirectedState() throws {
    let root = try makeRepo()
    let elsewhere = try makeRepo()
    defer {
      try? FileManager.default.removeItem(at: root)
      try? FileManager.default.removeItem(at: elsewhere)
    }
    let paired = ValidationCheckout(source: ValidationProcess(workingDirectory: root.path))
    try FileManager.default.createDirectory(at: root.appendingPathComponent(".build"), withIntermediateDirectories: true)
    try paired.checkLocation()

    try FileManager.default.createSymbolicLink(atPath: paired.directory, withDestinationPath: elsewhere.path)
    #expect(throws: ToolError.self) { try paired.checkLocation() }
  }

  @Test func pairedCheckoutAcceptsASourceUnderPrivate() throws {
    let root = try makeRepo()
    defer { try? FileManager.default.removeItem(at: root) }
    // The shell reports temporary directories as /private/var, while Foundation strips /private from existing paths.
    let real = try #require(realpath(root.path, nil))
    defer { free(real) }
    let source = ValidationProcess(workingDirectory: String(cString: real))
    let paired = ValidationCheckout(source: source)
    let commit = try git(["rev-parse", "HEAD"], in: root).trimmingCharacters(in: .newlines)

    try paired.checkLocation()
    try paired.materialise(commit: commit)
    #expect(try paired.snapshotPath("Tracked.swift").hasSuffix("/.build/agt-validation/checkout/Tracked.swift"))
  }

  @Test func snapshotPathsMapIntoTheCheckoutAndCannotEscapeIt() throws {
    let root = try makeRepo()
    defer { try? FileManager.default.removeItem(at: root) }
    let paired = ValidationCheckout(source: ValidationProcess(workingDirectory: root.path))
    try paired.materialise(commit: try git(["rev-parse", "HEAD"], in: root).trimmingCharacters(in: .newlines))
    let checkout = URL(fileURLWithPath: paired.path).resolvingSymlinksInPath()

    #expect(try paired.snapshotPath("Tracked.swift") == checkout.appendingPathComponent("Tracked.swift").path)
    #expect(try paired.snapshotPath(root.appendingPathComponent("Tracked.swift").path) == checkout.appendingPathComponent("Tracked.swift").path)
    #expect(throws: ToolError.self) { try paired.snapshotPath("../outside") }
    #expect(throws: ToolError.self) { try paired.snapshotPath("/usr/bin") }
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

  @Test func committedValidationRefusesDirtyAndUnpushedSubmodules() throws {
    let (root, remote) = try makeRepoWithSubmodule()
    defer {
      try? FileManager.default.removeItem(at: root)
      try? FileManager.default.removeItem(at: remote)
    }
    let source = ValidationProcess(workingDirectory: root.path)
    let config = try ValidateCommand.parse(["--full"]).config(repoPath: root.path)
    let sub = root.appendingPathComponent("Sub")
    #expect(throws: Never.self) { try ValidationSnapshot(process: source, config: config) }

    try "dirty\n".write(to: sub.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
    #expect(throws: ToolError.self) { try ValidationSnapshot(process: source, config: config) }

    _ = try git(["-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-qam", "Local only"], in: sub)
    _ = try git(["-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-qam", "Bump"], in: root)
    let unpushed = #expect(throws: ToolError.self) { try ValidationSnapshot(process: source, config: config) }
    #expect(unpushed?.description.contains("Push the committed changes in these submodules") == true)
    #expect(unpushed?.description.contains("Sub") == true)

    _ = try git(["push", "--quiet", "origin", "HEAD:refs/heads/integration/app"], in: sub)
    #expect(throws: Never.self) { try ValidationSnapshot(process: source, config: config) }
  }

  @Test func fullValidationFindsSubmodulesTheBranchMoved() throws {
    let (root, remote) = try makeRepoWithSubmodule()
    defer {
      try? FileManager.default.removeItem(at: root)
      try? FileManager.default.removeItem(at: remote)
    }
    let source = ValidationProcess(workingDirectory: root.path)
    let config = try ValidateCommand.parse(["--full"]).config(repoPath: root.path)
    _ = try git(["switch", "--quiet", "-c", "feature/test"], in: root)
    #expect(try ValidationSnapshot(process: source, config: config).changedPaths(using: source).isEmpty)

    let sub = root.appendingPathComponent("Sub")
    try "two\n".write(to: sub.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
    _ = try git(["-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-qam", "Change"], in: sub)
    _ = try git(["push", "--quiet", "origin", "HEAD:refs/heads/main"], in: sub)
    _ = try git(["-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-qam", "Bump"], in: root)
    #expect(try ValidationSnapshot(process: source, config: config).changedPaths(using: source) == ["Sub"])
  }

  /// Creates a repository with a submodule `Sub` cloned from a bare remote, both at a pushed commit.
  private func makeRepoWithSubmodule() throws -> (root: URL, remote: URL) {
    let remote = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AgentTools-SubRemote-\(UUID().uuidString).git")
    _ = try git(["init", "--quiet", "--bare", "--initial-branch=main", remote.path], in: URL(fileURLWithPath: NSTemporaryDirectory()))
    let seed = try makeRepo()
    defer { try? FileManager.default.removeItem(at: seed) }
    try "one\n".write(to: seed.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
    _ = try git(["add", "file.txt"], in: seed)
    _ = try git(["-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-qm", "Seed"], in: seed)
    _ = try git(["push", "--quiet", remote.path, "HEAD:refs/heads/main"], in: seed)

    let root = try makeRepo()
    _ = try git(["-c", "protocol.file.allow=always", "submodule", "--quiet", "add", remote.path, "Sub"], in: root)
    _ = try git(["-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-qm", "Add submodule"], in: root)
    return (root, remote)
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
