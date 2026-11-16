// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 16/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Runs read-only Git commands in one checkout and returns their standard output unmodified, so NUL-separated
/// listings and file contents survive intact.
struct GitQuery {
  /// Checkout the commands run in.
  let workingDirectory: String

  /// Returns the command's output, or throws with Git's diagnostic when it fails.
  func output(_ arguments: [String]) throws -> String {
    let result = try run(arguments)
    guard result.status == 0 else {
      throw ToolError("Git query failed: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
    return result.stdout
  }

  /// Returns the command's output, or `nil` when Git reports failure, for queries where failure is an answer.
  func outputIfSuccessful(_ arguments: [String]) throws -> String? {
    let result = try run(arguments)
    return result.status == 0 ? result.stdout : nil
  }

  /// Runs Git with pathspecs taken literally, so file names containing glob characters name only themselves.
  private func run(_ arguments: [String]) throws -> CommandResult {
    try ValidationProcess(workingDirectory: workingDirectory).capture(["git", "--literal-pathspecs"] + arguments)
  }
}
