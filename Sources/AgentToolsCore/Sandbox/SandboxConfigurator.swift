// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Lets Claude Code's and Codex's sandboxes write where Swift validation needs to, outside the project.
///
/// `agt validate` runs inside the agents' sandboxes. Xcode writes package manifests to SwiftPM's cache, and compiles
/// manifests that import macro support with the per-user clang module cache, so both runtimes must allow writes
/// there. The paths are machine-specific, so they are computed here and merged into each runtime's user
/// configuration by ``ClaudeSandboxSettings`` and ``CodexSandboxConfig``. Configuring is idempotent, and backs a file
/// up, with a `.bak` suffix, before changing it.
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
      paths: cachePaths(homeDirectory: homeDirectory, userCacheDirectory: try userCacheDirectory())
    )
  }

  /// Returns SwiftPM's cache and the per-user clang module cache.
  static func cachePaths(homeDirectory: URL, userCacheDirectory: String) -> [String] {
    [
      homeDirectory.appendingPathComponent("Library/Caches/org.swift.swiftpm").path,
      URL(fileURLWithPath: userCacheDirectory, isDirectory: true).appendingPathComponent("clang/ModuleCache").path,
    ]
  }

  /// Returns the per-user cache directory, under `/var/folders`, that `getconf DARWIN_USER_CACHE_DIR` prints.
  static func userCacheDirectory() throws -> String {
    let length = confstr(_CS_DARWIN_USER_CACHE_DIR, nil, 0)
    var buffer = [CChar](repeating: 0, count: length)
    guard length > 0, confstr(_CS_DARWIN_USER_CACHE_DIR, &buffer, length) > 0 else {
      throw ToolError("Could not find the user cache directory.")
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
