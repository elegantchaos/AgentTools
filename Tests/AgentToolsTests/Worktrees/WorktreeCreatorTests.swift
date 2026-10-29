// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

@testable import AgentToolsCore

/// Exercises Git setup and recovery with independent, network-free repository fixtures.
struct WorktreeCreatorTests {
  /// The prospective directory is checked correctly even before it exists, without editing ignore rules.
  @Test(arguments: [true, false])
  func ignoredDirectoriesDoNotProduceFalseWarnings(ignored: Bool) async throws {
    let repo = try makeRepository()
    defer { removeFixture(repo) }
    let ignore = ignored ? ".build/\n.worktrees/\n" : ".build/\n"
    try ignore.write(to: repo.appendingPathComponent(".gitignore"), atomically: true, encoding: .utf8)
    var messages: [String] = []
    _ = try await WorktreeCreator(repoPath: repo.path, outputMode: .quiet, report: { messages.append($0) }).create(name: "ignore-probe", base: "HEAD") { _ in }
    let warned = messages.contains { $0.hasPrefix("Warning: .worktrees/ is not ignored") }
    let expectedWarning = !ignored
    #expect(warned == expectedWarning)
    #expect(try String(contentsOf: repo.appendingPathComponent(".gitignore"), encoding: .utf8) == ignore)
  }

  /// Creating from a linked checkout still locates new worktrees under the main checkout.
  @Test func creationUsesTheMainCheckoutAndPreparesTheDestination() async throws {
    let repo = try makeRepository()
    defer { removeFixture(repo) }
    var prepared: [String] = []
    let first = try await WorktreeCreator(repoPath: repo.path, outputMode: .quiet).create(name: "first", base: "HEAD") { prepared.append($0) }
    let second = try await WorktreeCreator(repoPath: first, outputMode: .quiet).create(name: "second", base: "HEAD") { prepared.append($0) }
    #expect(first == repo.appendingPathComponent(".worktrees/first").path)
    #expect(second == repo.appendingPathComponent(".worktrees/second").path)
    #expect(prepared == [first, second])
    #expect(try git(["branch", "--show-current"], in: URL(fileURLWithPath: second)) == "feature/second")
  }

  /// Neither a directory nor a pre-existing branch can be overwritten during creation.
  @Test(arguments: [true, false])
  func collisionsAreRejected(destinationExists: Bool) async throws {
    let repo = try makeRepository()
    defer { removeFixture(repo) }
    if destinationExists {
      try FileManager.default.createDirectory(at: repo.appendingPathComponent(".worktrees/taken"), withIntermediateDirectories: true)
    } else {
      _ = try git(["branch", "feature/taken"], in: repo)
    }
    try await expectFailure(containing: destinationExists ? "destination already exists" : "Branch already exists") {
      try await WorktreeCreator(repoPath: repo.path).create(name: "taken", base: "HEAD") { _ in Issue.record("Preparation must not run after a collision.") }
    }
  }

  /// A symbolic link cannot redirect setup out of the main checkout's worktree directory.
  @Test func redirectedWorktreeDirectoryIsRejected() async throws {
    let repo = try makeRepository()
    defer { removeFixture(repo) }
    let outside = repo.deletingLastPathComponent().appendingPathComponent("Outside")
    try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: repo.appendingPathComponent(".worktrees"), withDestinationURL: outside)
    try await expectFailure(containing: "symbolic link") {
      try await WorktreeCreator(repoPath: repo.path).create(name: "redirected", base: "HEAD") { _ in Issue.record("Preparation must not run after a redirected path.") }
    }
    #expect(FileManager.default.fileExists(atPath: outside.appendingPathComponent("redirected").path) == false)
  }

  /// Both a bare main repository and its non-bare linked checkout are unsupported setup roots.
  @Test(arguments: [true, false])
  func bareMainRepositoriesAreRejected(invokeFromBare: Bool) async throws {
    let repo = try makeRepository()
    defer { removeFixture(repo) }
    let bare = repo.deletingLastPathComponent().appendingPathComponent("Bare")
    let linked = repo.deletingLastPathComponent().appendingPathComponent("Linked")
    _ = try git(["clone", "--bare", repo.path, bare.path], in: repo)
    _ = try git(["worktree", "add", "--detach", linked.path, "HEAD"], in: bare)
    try await expectFailure(containing: "bare") {
      try await WorktreeCreator(repoPath: invokeFromBare ? bare.path : linked.path).create(name: "unsupported", base: "HEAD") { _ in }
    }
    #expect(FileManager.default.fileExists(atPath: bare.appendingPathComponent(".worktrees/unsupported").path) == false)
  }

  /// Failed preparation retains the checkout and branch and names the standalone resume command.
  @Test func preparationFailureRetainsTheWorktree() async throws {
    let repo = try makeRepository()
    defer { removeFixture(repo) }
    try await expectFailure(containing: "Resume there with `agt prepare`") {
      try await WorktreeCreator(repoPath: repo.path, outputMode: .quiet).create(name: "resume", base: "HEAD") { _ in throw ToolError("Deliberate preparation failure") }
    }
    let destination = repo.appendingPathComponent(".worktrees/resume")
    #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent(".git").path))
    #expect(try git(["branch", "--show-current"], in: destination) == "feature/resume")
  }

  /// A missing local submodule exercises recovery without depending on network failures.
  @Test func submoduleFailureRetainsTheWorktree() async throws {
    let repo = try makeRepository()
    defer { removeFixture(repo) }
    let revision = try git(["rev-parse", "HEAD"], in: repo)
    try """
    [submodule "Missing"]
      path = Modules/Missing
      url = \(repo.appendingPathComponent("missing-local-source").path)
    """.write(to: repo.appendingPathComponent(".gitmodules"), atomically: true, encoding: .utf8)
    _ = try git(["add", ".gitmodules"], in: repo)
    _ = try git(["update-index", "--add", "--cacheinfo", "160000,\(revision),Modules/Missing"], in: repo)
    try commit(in: repo)
    try await expectFailure(containing: "git submodule update --init --recursive") {
      try await WorktreeCreator(repoPath: repo.path, outputMode: .quiet).create(name: "submodule-resume", base: "HEAD") { _ in Issue.record("Preparation must not run after submodule failure.") }
    }
    #expect(FileManager.default.fileExists(atPath: repo.appendingPathComponent(".worktrees/submodule-resume/.git").path))
  }

  /// Returns an independent repository whose worktrees and build output are ignored.
  private func makeRepository() throws -> URL {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent(".build/tmp/worktree-\(UUID().uuidString)/Main")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    _ = try git(["init", "--quiet"], in: root)
    try ".build/\n.worktrees/\n".write(to: root.appendingPathComponent(".gitignore"), atomically: true, encoding: .utf8)
    _ = try git(["add", ".gitignore"], in: root)
    try commit(in: root)
    return root
  }

  /// Fixture commits use the required user identity as both author and committer.
  private func commit(in repo: URL) throws {
    try #require(try git(["var", "GIT_AUTHOR_IDENT"], in: repo).hasPrefix("Sam Deane <sam@elegantchaos.com>"))
    try #require(try git(["var", "GIT_COMMITTER_IDENT"], in: repo).hasPrefix("Sam Deane <sam@elegantchaos.com>"))
    _ = try git(["commit", "--quiet", "-m", "Fixture"], in: repo)
  }

  /// Runs Git with explicit fixture identities and preserves unexpected diagnostics.
  private func git(_ arguments: [String], in repo: URL) throws -> String {
    let result = try ValidationProcess(workingDirectory: repo.path).capture(
      ["git"] + arguments,
      environment: [
        "GIT_AUTHOR_NAME": "Sam Deane", "GIT_AUTHOR_EMAIL": "sam@elegantchaos.com",
        "GIT_COMMITTER_NAME": "Sam Deane", "GIT_COMMITTER_EMAIL": "sam@elegantchaos.com",
      ])
    guard result.status == 0 else { throw ToolError("Fixture Git failed: \(result.stderr)") }
    return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Checks a specific setup failure while allowing unrelated error types to fail the test.
  private func expectFailure(containing fragment: String, operation: () async throws -> String, sourceLocation: SourceLocation = #_sourceLocation) async throws {
    do {
      _ = try await operation()
      Issue.record("Expected setup to fail with \(fragment)", sourceLocation: sourceLocation)
    } catch let error as ToolError {
      #expect(error.description.contains(fragment), sourceLocation: sourceLocation)
    }
  }

  /// Removes the checkout and any sibling bare/linked fixtures after Git processes exit.
  private func removeFixture(_ repo: URL) {
    try? FileManager.default.removeItem(at: repo.deletingLastPathComponent())
  }
}
