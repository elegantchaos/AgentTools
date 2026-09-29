// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Checks the copies of `ensure-agt.sh` that plugins carry.
///
/// Every plugin that needs `agt` installs it with its own copy of the script, since a plugin can only use files
/// inside it. The copies must stay identical to the one in the `baseline` plugin's `refresh` skill.
enum HelperCopies {
  /// Repository-relative path of the canonical script.
  static let canonicalPath = "plugins/baseline/skills/refresh/scripts/ensure-agt.sh"

  /// Returns the repository-relative paths of copies that differ from the canonical script.
  static func drifted(in repoRoot: URL) throws -> [String] {
    let canonical = try Data(contentsOf: repoRoot.appendingPathComponent(canonicalPath))
    return try copies(in: repoRoot).filter { path in
      try Data(contentsOf: repoRoot.appendingPathComponent(path)) != canonical
    }
  }

  /// Returns the repository-relative paths of every `plugins/*/skills/*/scripts/ensure-agt.sh`, sorted.
  private static func copies(in repoRoot: URL) -> [String] {
    let fileManager = FileManager.default
    /// Returns the names of the directories inside `path`.
    func directories(in path: String) -> [String] {
      let names = (try? fileManager.contentsOfDirectory(atPath: repoRoot.appendingPathComponent(path).path)) ?? []
      return names.filter { !$0.hasPrefix(".") }.sorted()
    }

    return directories(in: "plugins").flatMap { plugin in
      directories(in: "plugins/\(plugin)/skills").map { "plugins/\(plugin)/skills/\($0)/scripts/ensure-agt.sh" }
    }
    .filter { $0 != canonicalPath && fileManager.fileExists(atPath: repoRoot.appendingPathComponent($0).path) }
  }
}
