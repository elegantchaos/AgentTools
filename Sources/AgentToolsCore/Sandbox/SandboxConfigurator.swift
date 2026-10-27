// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Lets Claude Code's and Codex's sandboxes write where agents need to outside their project: the caches and the
/// user temporary directory Swift validation uses, and the shared Agents checkout.
///
/// `agt validate` runs inside the agents' sandboxes. Xcode writes package manifests to SwiftPM's cache, and compiles
/// manifests that import macro support with the per-user clang module cache, so both runtimes must allow writes
/// there. Swift Build saves its build manifest atomically, and Foundation stages atomic writes in the per-user
/// temporary directory whatever `TMPDIR` says, so that must be writable too. Agents also maintain the shared guidance from sessions in other projects, so the Agents checkout that
/// maintenance commands use must be writable too. The paths are machine-specific, so they are computed here and
/// merged into each runtime's user configuration by ``ClaudeSandboxSettings`` and ``CodexSandboxConfig``.
/// Configuring is idempotent and backs up a file with a `.bak` suffix before changing it.
struct SandboxConfigurator {
  /// Claude Code's user settings file.
  let claudeSettings: URL

  /// Codex's user configuration file.
  let codexConfig: URL

  /// Directories that must be writable.
  let paths: [String]

  /// Creates a configurator for the runtime homes in `environment`, or under `homeDirectory` by default.
  init(environment: [String: String], homeDirectory: URL, paths: [String]) {
    claudeSettings = AgentRuntime.claude.home(environment: environment, homeDirectory: homeDirectory).appendingPathComponent("settings.json")
    codexConfig = AgentRuntime.codex.home(environment: environment, homeDirectory: homeDirectory).appendingPathComponent("config.toml")
    self.paths = paths
  }

  /// Creates a configurator for the current user and machine.
  static func current() throws -> SandboxConfigurator {
    let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
    return SandboxConfigurator(
      environment: ProcessInfo.processInfo.environment,
      homeDirectory: homeDirectory,
      paths: writablePaths(
        environment: ProcessInfo.processInfo.environment, homeDirectory: homeDirectory,
        userCacheDirectory: try userCacheDirectory(), userTempDirectory: try userTempDirectory())
    )
  }

  /// Returns every directory the sandboxes must be able to write: the caches, the user temporary directory and the
  /// Agents checkout.
  ///
  /// Foundation stages atomic writes in the user temporary directory, whatever `TMPDIR` says, so Swift Build cannot
  /// save its build manifest, and `xcrun` cannot write its cache, without it. The checkout is the one maintenance
  /// commands use, whether or not it exists yet, so configuring before cloning still allows it.
  static func writablePaths(
    environment: [String: String], homeDirectory: URL, userCacheDirectory: String, userTempDirectory: String
  ) -> [String] {
    cachePaths(homeDirectory: homeDirectory, userCacheDirectory: userCacheDirectory)
      + [URL(fileURLWithPath: userTempDirectory, isDirectory: true).path]
      + [RepoRootLocator.configuredRoot(environment: environment, homeDirectory: homeDirectory).path]
  }

  /// Returns SwiftPM's cache and the per-user clang module cache.
  private static func cachePaths(homeDirectory: URL, userCacheDirectory: String) -> [String] {
    [
      homeDirectory.appendingPathComponent("Library/Caches/org.swift.swiftpm").path,
      URL(fileURLWithPath: userCacheDirectory, isDirectory: true).appendingPathComponent("clang/ModuleCache").path,
    ]
  }

  /// Returns the per-user cache directory, under `/var/folders`, that `getconf DARWIN_USER_CACHE_DIR` prints.
  static func userCacheDirectory() throws -> String {
    try userDirectory(_CS_DARWIN_USER_CACHE_DIR, named: "cache")
  }

  /// Returns the per-user temporary directory, under `/var/folders`, that `getconf DARWIN_USER_TEMP_DIR` prints.
  static func userTempDirectory() throws -> String {
    try userDirectory(_CS_DARWIN_USER_TEMP_DIR, named: "temporary")
  }

  /// Reads one of the per-user directories that `confstr` reports, naming it in the error if it cannot.
  private static func userDirectory(_ name: Int32, named description: String) throws -> String {
    let length = confstr(name, nil, 0)
    var buffer = [CChar](repeating: 0, count: length)
    guard length > 0, confstr(name, &buffer, length) > 0 else {
      throw ToolError("Could not find the user \(description) directory.")
    }
    return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
  }

  /// Adds the paths to both runtimes' configuration, reporting what changed.
  func configure() throws -> [SandboxConfigurationEntry] {
    [
      try update(.claude, file: claudeSettings) { text in
        try ClaudeSandboxSettings.adding(paths, to: text.map { Data($0.utf8) }).map { String(decoding: $0, as: UTF8.self) }
      },
      try update(.codex, file: codexConfig) { text in
        try CodexSandboxConfig.adding(paths, to: text ?? "")
      },
    ]
  }

  /// Applies `edit` to a configuration file, backing it up and writing the result when it returns new text.
  ///
  /// A symlinked file is edited in place at its destination, so the link survives.
  private func update(_ runtime: AgentRuntime, file: URL, edit: (String?) throws -> String?) throws -> SandboxConfigurationEntry {
    let fileManager = FileManager.default
    let target = file.resolvingSymlinksInPath()
    let exists = fileManager.fileExists(atPath: target.path)
    let text = exists ? try String(contentsOf: target, encoding: .utf8) : nil
    let updated: String?
    do {
      updated = try edit(text)
    } catch {
      throw ToolError("\(runtime.rawValue): \(file.path): \(error)")
    }
    guard let updated else {
      return SandboxConfigurationEntry(runtime: runtime, file: file, status: .unchanged)
    }

    if exists {
      let backup = URL(fileURLWithPath: target.path + ".bak")
      try? fileManager.removeItem(at: backup)
      try fileManager.copyItem(at: target, to: backup)
    }
    try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
    try updated.write(to: target, atomically: true, encoding: .utf8)
    return SandboxConfigurationEntry(runtime: runtime, file: file, status: .updated)
  }
}
