// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation

/// Creates a named feature worktree, initialises submodules and prepares dependencies.
struct WorktreeCreateCommand: AsyncParsableCommand {
  /// Command metadata.
  static let configuration = CommandConfiguration(
    commandName: "create",
    abstract: "Create .worktrees/<name> on feature/<name>, initialise submodules and prepare dependencies.",
    discussion: """
      Run from a Git checkout. Creates the worktree under the main checkout, even when invoked in another worktree. \
      The base defaults to the invoking checkout's HEAD; uncommitted edits and machine-local configuration are not copied. \
      Names use lowercase letters, digits and single hyphens between words, up to 64 characters. \
      Existing paths or branches are never reused or overwritten. Bare main repositories, including their linked \
      checkouts, are rejected. Warns if .worktrees/ is not ignored, without changing ignore rules. \
      If setup fails after creation, the worktree is retained \
      and a resume command is printed. Dependency preparation evaluates manifests. In sandboxes that protect Git metadata, \
      obtain user approval to run this command outside the sandbox, or ask the user to run it. Never escalates itself.
      """
  )

  /// Semantic name used for the directory and feature branch.
  @Argument(help: "Semantic name, for example dependency-preparation.")
  var name: String

  /// Revision to check out before applying changes.
  @Option(help: "Starting revision (default: HEAD of the invoking checkout).")
  var base = "HEAD"

  /// Terminal output options.
  @OptionGroup var output: OutputOptions

  /// Creates and prepares the worktree without changing this process's working directory.
  mutating func run() async throws {
    setvbuf(stdout, nil, _IOLBF, 0)
    _ = try await WorktreeCreator(repoPath: FileManager.default.currentDirectoryPath, outputMode: output.mode).create(name: name, base: base) { destination in
      try await PrepareCommand.prepare(repoPath: destination, output: output)
    }
  }
}
