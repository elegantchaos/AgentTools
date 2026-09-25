// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 25/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import CryptoKit
import Foundation

/// Identifies the exact state of a working tree, so a validation result can be matched to the code it checked.
///
/// The fingerprint covers tracked and untracked files, but not ignored ones, and the working trees of submodules with
/// local changes. It stages everything into a temporary copy of git's index and writes a tree, which leaves the real
/// index and the working tree untouched and only adds git objects.
enum WorkingTreeFingerprint {
  /// Returns the fingerprint of the working tree that `process` runs in.
  static func current(using process: ValidationProcess) throws -> String {
    var parts = [try tree(using: process)]
    let submodules = try process.capture(["git", "submodule", "foreach", "--quiet", "--recursive", "echo $displaypath"])
    for path in submodules.stdout.split(separator: "\n").map(String.init) {
      let submodule = ValidationProcess(workingDirectory: "\(process.workingDirectory)/\(path)")
      let status = try submodule.capture(["git", "status", "--porcelain"])
      if !status.stdout.isEmpty {
        parts.append("\(path)=\(try tree(using: submodule))")
      }
    }
    let digest = SHA256.hash(data: Data(parts.joined(separator: "\n").utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
  }

  /// Writes the working tree, including untracked files, as a tree object using a temporary index.
  private static func tree(using process: ValidationProcess) throws -> String {
    let indexPath = try process.capture(["git", "rev-parse", "--path-format=absolute", "--git-path", "index"]).stdout
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("agt-index-\(UUID().uuidString)").path
    defer { try? FileManager.default.removeItem(atPath: temporary) }
    if FileManager.default.fileExists(atPath: indexPath) {
      try FileManager.default.copyItem(atPath: indexPath, toPath: temporary)
    }

    let environment = ["GIT_INDEX_FILE": temporary]
    let add = try process.capture(["git", "add", "--all"], environment: environment)
    guard add.status == 0 else {
      throw ToolError("Failed to read the working tree:\n\(add.stderr)")
    }
    let write = try process.capture(["git", "write-tree"], environment: environment)
    guard write.status == 0 else {
      throw ToolError("Failed to read the working tree:\n\(write.stderr)")
    }
    return write.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
