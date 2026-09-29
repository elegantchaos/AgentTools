// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Brings this machine's agent runtimes up to date with the shared Agents repository.
///
/// It warns about plugin copies of `ensure-agt.sh` that have drifted, syncs and links the public skills, configures
/// both runtimes' sandboxes with ``SandboxConfigurator``, then installs or refreshes every marketplace plugin in each
/// runtime whose command ``RuntimeCommandLocator`` finds. Every step is idempotent.
struct RefreshTool {
  /// Root of the Agents repository.
  let repoRoot: URL

  /// Finds each runtime's command.
  let locator: RuntimeCommandLocator

  /// Creates the tool for the Agents repository that contains the working directory, or `AGENTS_REPO_ROOT`.
  static func current() throws -> RefreshTool {
    let fileManager = FileManager.default
    let repoRoot = try RepoRootLocator.locateRepoRoot(
      environment: ProcessInfo.processInfo.environment,
      currentDirectoryPath: fileManager.currentDirectoryPath,
      fileExistsAtPath: fileManager.fileExists(atPath:)
    )
    return RefreshTool(repoRoot: repoRoot, locator: .current)
  }

  /// Runs every step, stopping at the first failure.
  func run() throws {
    for path in try HelperCopies.drifted(in: repoRoot) {
      printError("warning: \(path) differs from \(HelperCopies.canonicalPath)")
    }

    let skills = SkillsPublicTool(
      repoRoot: repoRoot,
      linkDestinations: SkillLinkDestination.defaults(
        environment: ProcessInfo.processInfo.environment,
        homeDirectory: FileManager.default.homeDirectoryForCurrentUser
      )
    )
    try skills.runSync(selection: .all)
    try skills.runLink()

    for entry in try SandboxConfigurator.current().configure() {
      print(entry.summary)
    }

    for runtime in [AgentRuntime.claude, .codex] {
      try installPlugins(in: runtime)
    }
  }

  /// Installs or refreshes the marketplace's plugins in one runtime, or reports that the runtime is missing.
  private func installPlugins(in runtime: AgentRuntime) throws {
    guard let command = locator.locate(runtime) else {
      print("\(runtime.rawValue): not found on PATH or in the usual install locations; skipping its plugins")
      return
    }

    let marketplace = try Data(contentsOf: repoRoot.appendingPathComponent(PluginInstallPlan.marketplacePath(for: runtime)))
    for arguments in try PluginInstallPlan.commands(for: runtime, marketplace: marketplace, repoRoot: repoRoot.path) {
      try runPassingThrough(command, arguments)
    }
  }

  /// Runs a command with the terminal as its output, throwing when it fails.
  private func runPassingThrough(_ command: URL, _ arguments: [String]) throws {
    fflush(stdout)
    let process = Process()
    process.executableURL = command
    process.arguments = arguments
    process.currentDirectoryURL = repoRoot
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
      throw ToolError("\(([command.path] + arguments).joined(separator: " ")) failed with status \(process.terminationStatus)")
    }
  }

  /// Writes a line to standard error.
  private func printError(_ line: String) {
    FileHandle.standardError.write(Data((line + "\n").utf8))
  }
}
