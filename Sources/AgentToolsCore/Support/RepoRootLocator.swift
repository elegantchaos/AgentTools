// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 23/04/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Resolves the shared Agents repository root for maintenance commands.
struct RepoRootLocator {
  /// Uses an explicit environment override, or validates the shared checkout in the user's home directory.
  static func locateRepoRoot(
    environment: [String: String],
    homeDirectory: URL,
    fileExistsAtPath: (String) -> Bool
  ) throws -> URL {
    if let explicitRoot = environment["AGENTS_REPO_ROOT"], !explicitRoot.isEmpty {
      return URL(fileURLWithPath: explicitRoot).standardizedFileURL
    }

    let defaultRoot = homeDirectory.appendingPathComponent(".local/share/agents").standardizedFileURL
    guard isRepositoryRoot(defaultRoot, fileExistsAtPath: fileExistsAtPath) else {
      throw ToolError(
        "Agents repository not found at \(defaultRoot.path). Expected skills/, runtimes/, and COMMON.md. Set AGENTS_REPO_ROOT to use a different checkout."
      )
    }
    return defaultRoot
  }

  /// Returns true when the directory has the expected root markers.
  private static func isRepositoryRoot(_ directory: URL, fileExistsAtPath: (String) -> Bool) -> Bool {
    let hasSkills = fileExistsAtPath(directory.appendingPathComponent("skills").path)
    let hasRuntimes = fileExistsAtPath(directory.appendingPathComponent("runtimes").path)
    let hasSharedGuidance = fileExistsAtPath(directory.appendingPathComponent("COMMON.md").path)

    return hasSkills && hasRuntimes && hasSharedGuidance
  }
}
