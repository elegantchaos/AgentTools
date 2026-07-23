// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 23/04/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

@testable import AgentTools

/// Tests for repository root detection in different runtime layouts.
struct RepoRootLocatorTests {
  /// Prefers AGENTS_REPO_ROOT when it is set.
  @Test func locatesRepoRootFromEnvironmentOverride() throws {
    let root = try RepoRootLocator.locateRepoRoot(
      environment: ["AGENTS_REPO_ROOT": "/tmp/custom-root"],
      currentDirectoryPath: "/tmp/ignored",
      fileExistsAtPath: { _ in false }
    )

    #expect(root.path == "/tmp/custom-root")
  }

  /// Finds the root using markers owned by the shared Agents repository.
  @Test func locatesRootUsingSharedRepositoryMarkers() throws {
    let candidateRoot = "/repo"
    let paths = Set([
      "\(candidateRoot)/skills",
      "\(candidateRoot)/codex",
      "\(candidateRoot)/COMMON.md",
    ])

    let root = try RepoRootLocator.locateRepoRoot(
      environment: [:],
      currentDirectoryPath: "/repo/skills/refresh-skill",
      fileExistsAtPath: { paths.contains($0) }
    )

    #expect(root.path == candidateRoot)
  }

  /// Throws a clear error when no marker combination is present.
  @Test func throwsWhenNoRepositoryRootMarkersFound() throws {
    let error = try #require(throws: ToolError.self) {
      try RepoRootLocator.locateRepoRoot(
        environment: [:],
        currentDirectoryPath: "/",
        fileExistsAtPath: { _ in false }
      )
    }

    #expect(error.description == RepoRootLocator.missingRootError)
  }
}
