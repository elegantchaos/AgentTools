// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 06/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Pins the source and change-selection inputs for a committed validation request.
struct ValidationSnapshot: Codable {
  /// Commit to build.
  let commit: String

  /// Baseline for change-scoped validation.
  let baseline: String?

  /// Resolved options, including machine-local settings from the development worktree.
  let config: ValidationConfig

  /// Captures the commit before checking cleanliness, and refuses a checkout that moves during admission.
  init(process: ValidationProcess, config: ValidationConfig) throws {
    let commit = try Self.git(["rev-parse", "HEAD"], using: process)
    guard try Self.currentCleanCommit(using: process) == commit else {
      throw ToolError("Commit your changes, including submodule changes, before validation. Use --target to check live edits.")
    }
    self.commit = commit
    self.config = config
    if config.full {
      baseline = nil
    } else {
      let candidates = ["refs/heads/main", "refs/remotes/origin/main"]
      guard let ref = try candidates.first(where: { try process.capture(["git", "rev-parse", "--verify", "--quiet", $0]).status == 0 }) else {
        throw ToolError("Change-scoped validation needs a local main or origin/main branch to compare against. Use --full or --target instead.")
      }
      baseline = try Self.git(["merge-base", ref, commit], using: process)
    }
  }

  /// Returns the currently applicable commit, or nil when there are local changes.
  static func currentCleanCommit(using process: ValidationProcess) throws -> String? {
    let changes = try git(["--no-optional-locks", "status", "--porcelain", "--untracked-files=all", "--ignore-submodules=none"], using: process)
    guard changes.isEmpty else { return nil }
    return try git(["rev-parse", "HEAD"], using: process)
  }

  /// Returns changed paths, including both sides of renames as deletion and addition.
  func changedPaths(using process: ValidationProcess) throws -> [String] {
    guard let baseline else { return [] }
    return try Self.git(["diff", "--no-renames", "--name-only", "-z", baseline, commit, "--"], using: process)
      .split(separator: "\0").map(String.init)
  }

  /// Runs a Git command and preserves its diagnostic on failure.
  static func git(_ arguments: [String], using process: ValidationProcess) throws -> String {
    let result = try process.capture(["git"] + arguments)
    guard result.status == 0 else {
      throw ToolError("git \(arguments.joined(separator: " ")) failed in \(process.workingDirectory): \(result.stderr)")
    }
    // NUL-delimited file names may begin or end with whitespace.
    return result.stdout.contains("\0") ? result.stdout : result.stdout.trimmingCharacters(in: .newlines)
  }
}
