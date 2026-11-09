// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 06/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Owns the persistent build checkout and run state for one development worktree.
struct ValidationCheckout {
  /// Process rooted in the development worktree.
  let source: ValidationProcess

  /// Dedicated state directory, separate from targeted validation's build outputs.
  var directory: String { "\(source.workingDirectory)/.build/agt-validation" }

  /// Stable location for incremental builds.
  var path: String { "\(directory)/checkout" }

  /// Operation and admission locks live outside the checkout being reset.
  var lockPaths: ValidationPaths { ValidationPaths(repoPath: source.workingDirectory, rootOverride: directory) }

  /// Ensures the state directory stays within the development checkout.
  func checkLocation() throws {
    guard Self.resolved(directory) == Self.resolved(source.workingDirectory) + "/.build/agt-validation" else {
      throw ToolError("Validation state must not be redirected by a symbolic link: \(directory)")
    }
  }

  /// Resolves symbolic links and canonicalises `/private`, which Foundation strips only from paths that exist.
  private static func resolved(_ path: String) -> String {
    ValidationPaths.canonical(URL(fileURLWithPath: path).resolvingSymlinksInPath().path)
  }

  /// Creates or resets the owned checkout. The caller holds the operation lock.
  func materialise(commit: String) throws {
    try checkLocation()
    let files = FileManager.default
    let marker = URL(fileURLWithPath: "\(directory)/owner")
    let checkout = ValidationProcess(workingDirectory: path)
    let git = ValidationSnapshot.git
    guard Self.resolved(path) == Self.resolved(directory) + "/checkout" else {
      throw ToolError("Refusing a validation checkout redirected by a symbolic link: \(path)")
    }
    if !files.fileExists(atPath: path) {
      _ = try git(["worktree", "add", "--detach", "--force", path, commit], source)
      let identity = try git(["rev-parse", "--absolute-git-dir"], checkout)
      try identity.write(to: marker, atomically: true, encoding: .utf8)
    }
    let expected = try? String(contentsOf: marker, encoding: .utf8)
    guard files.fileExists(atPath: "\(path)/.git"),
      let expected, try git(["rev-parse", "--absolute-git-dir"], checkout) == expected,
      try checkout.capture(["git", "symbolic-ref", "-q", "HEAD"]).status == 1
    else {
      throw ToolError("Refusing to reset an unowned or non-detached checkout at \(path).")
    }

    _ = try git(["reset", "--hard", commit], checkout)
    _ = try git(["clean", "-ffdx", "-e", "/.build/agt/"], checkout)
    _ = try git(["submodule", "sync", "--recursive"], checkout)
    _ = try git(["submodule", "update", "--init", "--recursive", "--checkout", "--force"], checkout)
    _ = try git(["submodule", "foreach", "--recursive", "git clean -ffdx"], checkout)
  }

  /// Translates a source-relative override into the snapshot and refuses references outside it.
  func snapshotPath(_ value: String) throws -> String {
    let sourcePath = Self.resolved(source.workingDirectory)
    let input = Self.resolved(ValidationDiscovery.resolvePath(value, repoPath: sourcePath))
    guard input == sourcePath || input.hasPrefix(sourcePath + "/") else {
      throw ToolError("Validation path '\(value)' must be inside the validation snapshot.")
    }
    let root = Self.resolved(path)
    let mapped = Self.resolved(root + String(input.dropFirst(sourcePath.count)))
    guard mapped == root || mapped.hasPrefix(root + "/") else {
      throw ToolError("Validation path '\(value)' must be inside the validation snapshot.")
    }
    return mapped
  }
}
