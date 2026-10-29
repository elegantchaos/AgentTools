// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation

/// Resolves dependencies into validation's checkout directories before development starts.
struct PrepareCommand: AsyncParsableCommand {
  /// Command metadata.
  static let configuration = CommandConfiguration(
    commandName: "prepare",
    abstract: "Prepare dependencies for sandboxed validation without building or testing.",
    discussion: """
      Run once in a new checkout, and again after dependency changes or agt validate --clean. Uses the project's \
      validation configuration and the same SwiftPM scratch and Xcode DerivedData paths as agt validate. \
      Resolves dependencies and evaluates manifests; does not build targets, run tests, or boot simulators. \
      Sandboxes such as Claude Code's may forbid creating dependency Git config or hooks. In those environments, \
      run this command once outside the sandbox with explicit user approval, or ask the user to run it. \
      This command never leaves its enclosing sandbox automatically. Successful preparation is not validation.
      """
  )

  /// Whether to list resolution commands instead of executing them.
  @Flag(help: "List resolution steps. Discovery may evaluate manifests and resolve Xcode packages.")
  var plan = false

  /// Package and container selection shared with validation.
  @OptionGroup var selection: RepositorySelectionOptions

  /// Terminal output options.
  @OptionGroup var output: OutputOptions

  /// Prepares the repository in the current directory.
  mutating func run() async throws {
    try await Self.prepare(repoPath: FileManager.default.currentDirectoryPath, selection: selection, plan: plan, output: output)
  }

  /// Loads the destination checkout's own configuration before preparing it.
  static func prepare(repoPath: String, selection: RepositorySelectionOptions? = nil, plan: Bool = false, output: OutputOptions? = nil) async throws {
    let file = try await ProjectConfiguration.load(repoPath: repoPath).validate
    var command = try ValidateCommand.parse([])
    if let selection { command.selection = selection }
    command.plan = plan
    if let output { command.output = output }
    try ValidationTool(config: command.config(repoPath: repoPath, file: file), repoPath: repoPath).prepare()
  }
}
