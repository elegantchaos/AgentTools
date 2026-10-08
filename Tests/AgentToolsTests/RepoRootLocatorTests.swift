// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 23/04/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

@testable import AgentToolsCore

/// Tests explicit repository overrides and the shared checkout in the user's home directory.
struct RepoRootLocatorTests {
  /// Explicit test checkouts take precedence without requiring the default repository to exist.
  @Test func locatesRepoRootFromEnvironmentOverride() throws {
    let root = try RepoRootLocator.locateRepoRoot(
      environment: ["AGENTS_REPO_ROOT": "/fixtures/../custom-root"],
      homeDirectory: URL(fileURLWithPath: "/test-home"),
      fileExistsAtPath: { _ in
        Issue.record("An explicit root should not inspect the default checkout.")
        return false
      }
    )

    #expect(root.path == "/custom-root")
  }

  /// Unset and empty overrides use the fixed home-relative checkout, even when ancestors have repository markers.
  @Test(arguments: [[String: String](), ["AGENTS_REPO_ROOT": ""]])
  func defaultsToSharedCheckout(environment: [String: String]) throws {
    let expectedRoot = "/test-home/.local/share/agents"
    let paths = Set(
      [expectedRoot, "/test-home"].flatMap { root in
        ["skills", "runtimes", "COMMON.md"].map { "\(root)/\($0)" }
      }
    )
    let root = try RepoRootLocator.locateRepoRoot(
      environment: environment,
      homeDirectory: URL(fileURLWithPath: "/test-home"),
      fileExistsAtPath: paths.contains
    )

    #expect(root.path == expectedRoot)
  }

  /// Missing or incomplete default checkouts fail clearly instead of selecting an ancestor with repository markers.
  @Test(arguments: [["skills"], ["runtimes"], ["COMMON.md"], ["skills", "runtimes", "COMMON.md"]])
  func rejectsIncompleteDefaultCheckout(missingMarkers: [String]) throws {
    let expectedRoot = "/test-home/.local/share/agents"
    let paths = Set(
      ["skills", "runtimes", "COMMON.md"].flatMap { marker in
        ["/test-home/\(marker)"] + (missingMarkers.contains(marker) ? [] : ["\(expectedRoot)/\(marker)"])
      }
    )
    let error = try #require(throws: ToolError.self) {
      try RepoRootLocator.locateRepoRoot(
        environment: [:],
        homeDirectory: URL(fileURLWithPath: "/test-home"),
        fileExistsAtPath: paths.contains
      )
    }

    #expect(error.description.contains(expectedRoot))
    #expect(error.description.contains("AGENTS_REPO_ROOT"))
  }
}
