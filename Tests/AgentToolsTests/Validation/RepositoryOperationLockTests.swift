// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

@testable import AgentToolsCore

/// Verifies that validation and preparation cannot concurrently own dependency directories.
struct RepositoryOperationLockTests {
  /// Exercises ownership turnover while other test cases launch real subprocesses.
  @Test(arguments: 0..<8)
  func repeatedOwnershipReleaseDuringProcessLaunch(worker: Int) throws {
    for iteration in 0..<100 {
      let process = Process()
      process.executableURL = URL(filePath: "/usr/bin/true")
      try process.run()
      defer { process.waitUntilExit() }
      do {
        try ownershipIsExclusiveAndReleased()
      } catch {
        Issue.record("Worker \(worker), iteration \(iteration): \(error)")
        return
      }
    }
  }

  /// Planning reports the owner, waits for release, and replaces the diagnostic metadata only after acquisition.
  @Test func planningWaitsForTheNamedBackgroundOwner() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent(".build/tmp/lock-wait-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    var owner: RepositoryOperationLock? = try RepositoryOperationLock(repoPath: root.path, operation: "background validation", background: true)
    var message = ""
    let next = try RepositoryOperationLock(repoPath: root.path, operation: "preparation planning", wait: true) { waiting in
      message = waiting
      owner = nil
    }
    defer { withExtendedLifetime(next) {} }
    #expect(owner == nil)
    #expect(message.contains("background validation"))
    #expect(message.contains("PID \(ProcessInfo.processInfo.processIdentifier)"))
    #expect(message.contains("agt validate --status"))
    #expect(message.contains("agt validate --wait"))
    let data = try Data(contentsOf: URL(fileURLWithPath: ValidationPaths(repoPath: root.path).lockPath))
    let metadata = try JSONDecoder().decode(RepositoryOperationOwner.self, from: data)
    #expect(metadata.operation == "preparation planning")
    #expect(metadata.background == false)
    #expect(metadata.pid == ProcessInfo.processInfo.processIdentifier)
  }

  /// Lock contention fails promptly, and releasing ownership allows the next operation.
  @Test func ownershipIsExclusiveAndReleased() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent(".build/tmp/lock-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    weak let releasedOwner: RepositoryOperationLock?
    do {
      let lock = try RepositoryOperationLock(repoPath: root.path)
      releasedOwner = lock
      defer { withExtendedLifetime(lock) {} }
      #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent(".build/agt/lock").path))
      #expect(throws: ToolError.self) {
        _ = try RepositoryOperationLock(repoPath: root.path)
      }
      _ = try ValidationPaths.prepare(repoPath: root.path, clean: true)
      #expect(throws: ToolError.self) {
        _ = try RepositoryOperationLock(repoPath: root.path)
      }
    }
    try #require(releasedOwner == nil)
    do {
      let next = try RepositoryOperationLock(repoPath: root.path)
      withExtendedLifetime(next) {}
    } catch {
      throw ToolError("Reacquiring after the owner's deinit: \(error)")
    }
  }
}
