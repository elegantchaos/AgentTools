// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Finds which packages live in git submodules, and which submodules have changed.
enum SubmoduleStatus {
  /// Returns the paths reported by `git status --porcelain -z`, including submodules with new commits or local
  /// changes, and the new path of a rename or copy.
  static func changedPaths(fromPorcelainZ output: String) -> [String] {
    var paths: [String] = []
    var entries = output.split(separator: "\0", omittingEmptySubsequences: true).makeIterator()
    while let entry = entries.next() {
      guard entry.count > 3 else { continue }
      paths.append(String(entry.dropFirst(3)))
      if entry.first == "R" || entry.first == "C" {
        _ = entries.next()
      }
    }
    return paths
  }

  /// Returns the repository-relative path of the nearest nested git repository containing `directory`, or `nil`
  /// when `directory` belongs to the repository itself.
  static func enclosingSubmodule(of directory: String, repoPath: String) -> String? {
    let repo = URL(fileURLWithPath: repoPath).standardizedFileURL.path
    var candidate = URL(fileURLWithPath: directory).standardizedFileURL
    while candidate.path.hasPrefix("\(repo)/") {
      if FileManager.default.fileExists(atPath: candidate.appendingPathComponent(".git").path) {
        return String(candidate.path.dropFirst(repo.count + 1))
      }
      candidate.deleteLastPathComponent()
    }
    return nil
  }
}
