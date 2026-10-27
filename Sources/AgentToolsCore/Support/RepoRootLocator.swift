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
    if let explicitRoot = explicitRoot(environment: environment) {
      return explicitRoot
    }

    let defaultRoot = sharedRoot(homeDirectory: homeDirectory)
    guard isRepositoryRoot(defaultRoot, fileExistsAtPath: fileExistsAtPath) else {
      throw ToolError(
        "Agents repository not found at \(defaultRoot.path). Expected skills/, runtimes/, and COMMON.md. Set AGENTS_REPO_ROOT to use a different checkout."
      )
    }
    return defaultRoot
  }

  /// Returns the root `locateRepoRoot` would use, without checking that it exists.
  static func configuredRoot(environment: [String: String], homeDirectory: URL) -> URL {
    explicitRoot(environment: environment) ?? sharedRoot(homeDirectory: homeDirectory)
  }

  /// Returns the root that `AGENTS_REPO_ROOT` names, when it is set and non-empty.
  private static func explicitRoot(environment: [String: String]) -> URL? {
    guard let explicitRoot = environment["AGENTS_REPO_ROOT"], !explicitRoot.isEmpty else { return nil }
    return URL(fileURLWithPath: explicitRoot).standardizedFileURL
  }

  /// Returns the shared checkout in the user's home directory.
  private static func sharedRoot(homeDirectory: URL) -> URL {
    homeDirectory.appendingPathComponent(".local/share/agents").standardizedFileURL
  }

  /// Returns true when the directory has the expected root markers.
  private static func isRepositoryRoot(_ directory: URL, fileExistsAtPath: (String) -> Bool) -> Bool {
    let hasSkills = fileExistsAtPath(directory.appendingPathComponent("skills").path)
    let hasRuntimes = fileExistsAtPath(directory.appendingPathComponent("runtimes").path)
    let hasSharedGuidance = fileExistsAtPath(directory.appendingPathComponent("COMMON.md").path)

    return hasSkills && hasRuntimes && hasSharedGuidance
  }
}
