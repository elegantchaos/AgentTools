// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 23/04/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Resolves the shared Agents repository root for maintenance commands.
struct RepoRootLocator {
  /// Error thrown when root resolution fails.
  static let missingRootError =
    "Could not locate agents repository root. Run from the repo root or set AGENTS_REPO_ROOT."

  /// Locates the repository root using environment override first, then marker scanning.
  static func locateRepoRoot(
    environment: [String: String],
    currentDirectoryPath: String,
    fileExistsAtPath: (String) -> Bool
  ) throws -> URL {
    if let explicitRoot = environment["AGENTS_REPO_ROOT"], !explicitRoot.isEmpty {
      return URL(fileURLWithPath: explicitRoot).standardizedFileURL
    }

    var candidate = URL(fileURLWithPath: currentDirectoryPath).standardizedFileURL

    while true {
      if isRepositoryRoot(candidate, fileExistsAtPath: fileExistsAtPath) {
        return candidate
      }

      let parent = candidate.deletingLastPathComponent()
      if parent.path == candidate.path {
        throw ToolError(missingRootError)
      }
      candidate = parent
    }
  }

  /// Returns true when the directory has the expected root markers.
  private static func isRepositoryRoot(_ directory: URL, fileExistsAtPath: (String) -> Bool) -> Bool {
    let hasSkills = fileExistsAtPath(directory.appendingPathComponent("skills").path)
    let hasCodex = fileExistsAtPath(directory.appendingPathComponent("codex").path)
    let hasSharedGuidance = fileExistsAtPath(directory.appendingPathComponent("COMMON.md").path)

    return hasSkills && hasCodex && hasSharedGuidance
  }
}
