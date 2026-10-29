// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Creates worktrees using Git, then initialises submodules and invokes dependency preparation in the new checkout.
/// Failed setup retains the worktree and branch so the user can resume without repeating creation.
struct WorktreeCreator {
  /// Checkout from which Git resolves the starting revision.
  let repoPath: String

  /// Output mode for Git setup steps.
  var outputMode: ValidateOutputMode = .filtered

  /// Creates the worktree and returns its absolute path after preparation succeeds.
  func create(name: String, base: String, prepare: (String) async throws -> Void) async throws -> String {
    let process = ValidationProcess(workingDirectory: repoPath)
    guard try git(["rev-parse", "--is-bare-repository"], using: process) == "false" else {
      throw ToolError("Worktree creation requires a non-bare Git checkout.")
    }
    let worktrees = try git(["worktree", "list", "--porcelain"], using: process)
    guard let main = worktrees.split(separator: "\n").first, main.hasPrefix("worktree ") else {
      throw ToolError("Cannot locate the main Git checkout.")
    }
    let mainCheckout = String(main.dropFirst("worktree ".count))
    let location = try WorktreeLocation(name: name, mainCheckout: mainCheckout)
    let fileManager = FileManager.default
    guard !fileManager.fileExists(atPath: location.path), (try? fileManager.destinationOfSymbolicLink(atPath: location.path)) == nil else {
      throw ToolError("Worktree destination already exists: \(location.path)")
    }
    let parent = URL(fileURLWithPath: location.path).deletingLastPathComponent().resolvingSymlinksInPath().path
    guard parent == URL(fileURLWithPath: "\(mainCheckout)/.worktrees").standardizedFileURL.path else {
      throw ToolError("The .worktrees directory must not redirect setup through a symbolic link: \(parent)")
    }
    let branch = try process.capture(["git", "show-ref", "--verify", "--quiet", "refs/heads/\(location.branch)"])
    guard branch.status == 1 else {
      throw ToolError(branch.status == 0 ? "Branch already exists: \(location.branch)" : "Cannot check branch availability: \(branch.stderr)")
    }
    let revision = try git(["rev-parse", "--verify", "--end-of-options", "\(base)^{commit}"], using: process)
    let runner = StepRunner(repoPath: repoPath, outputMode: outputMode)
    let paths = try ValidationPaths.prepare(repoPath: repoPath, clean: false)
    try runner.run(
      title: "Create \(location.branch)", summary: "create worktree \(location.path)",
      arguments: ["git", "worktree", "add", "-b", location.branch, location.path, revision], logPath: paths.logPath("worktree_create_\(name)")
    )
    print("Worktree: \(location.path)")
    do {
      try runner.run(
        title: "Initialise submodules", summary: "initialise worktree submodules",
        arguments: ["git", "submodule", "update", "--init", "--recursive"], workingDirectory: location.path,
        logPath: paths.logPath("worktree_submodules_\(name)")
      )
    } catch {
      throw ToolError("Worktree retained at \(location.path).\nResume there with `git submodule update --init --recursive`, then `agt prepare`.\n\(error)")
    }
    do {
      try await prepare(location.path)
    } catch {
      throw ToolError("Worktree retained at \(location.path).\nResume there with `agt prepare`.\n\(error)")
    }
    print("Ready: \(location.path) (\(location.branch)). Preparation completed; validation has not run.")
    return location.path
  }

  /// Runs a read-only Git query and preserves the diagnostic on failure.
  private func git(_ arguments: [String], using process: ValidationProcess) throws -> String {
    let result = try process.capture(["git"] + arguments)
    guard result.status == 0 else {
      throw ToolError("Git query failed: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
    return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
