// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Darwin
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

  /// Announces and runs plugin maintenance in this process's group, with inherited output and EOF on input.
  func runPassingThrough(_ command: URL, _ arguments: [String], report: (String) -> Void = { print($0) }) throws {
    let description = ([command.path] + arguments).joined(separator: " ")
    report("refresh: \(description)")
    fflush(stdout)

    var actions: posix_spawn_file_actions_t?
    let initializeStatus = posix_spawn_file_actions_init(&actions)
    guard initializeStatus == 0 else {
      throw ToolError("Could not prepare \(command.path): \(String(cString: strerror(initializeStatus))).")
    }
    defer { posix_spawn_file_actions_destroy(&actions) }
    let directoryStatus = posix_spawn_file_actions_addchdir(&actions, repoRoot.path)
    guard directoryStatus == 0 else {
      throw ToolError("Could not set the working directory for \(command.path): \(String(cString: strerror(directoryStatus))).")
    }
    let inputStatus = posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0)
    guard inputStatus == 0 else {
      throw ToolError("Could not redirect input for \(command.path): \(String(cString: strerror(inputStatus))).")
    }

    let argv = ([command.path] + arguments).map { strdup($0) } + [nil]
    let envp = ProcessInfo.processInfo.environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
    defer {
      for string in argv + envp {
        free(string)
      }
    }
    var pid = pid_t()
    let spawnStatus = posix_spawn(&pid, command.path, &actions, nil, argv, envp)
    guard spawnStatus == 0 else {
      throw ToolError("Could not start \(command.path): \(String(cString: strerror(spawnStatus))).")
    }

    var status: Int32 = 0
    while waitpid(pid, &status, 0) == -1 {
      guard errno == EINTR else {
        throw ToolError("Lost track of \(command.path): \(String(cString: strerror(errno))).")
      }
    }
    let signal = status & 0x7f
    let exitStatus = signal == 0 ? (status >> 8) & 0xff : 128 + signal
    guard exitStatus == 0 else {
      throw ToolError("\(description) failed with status \(exitStatus)")
    }
  }

  /// Writes a line to standard error.
  private func printError(_ line: String) {
    FileHandle.standardError.write(Data((line + "\n").utf8))
  }
}
