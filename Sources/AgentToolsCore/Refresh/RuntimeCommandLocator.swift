// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Finds a runtime's command-line tool.
///
/// A standalone install on `PATH` comes first. Otherwise it falls back to the usual install locations, including
/// the copies bundled with the desktop apps: the Claude app keeps one per version, of which the newest is used, and
/// the ChatGPT app bundles Codex's.
struct RuntimeCommandLocator {
  /// Environment whose `PATH` is searched first.
  let environment: [String: String]

  /// The user's home directory.
  let homeDirectory: URL

  /// The filesystem root that system install locations are relative to.
  let rootDirectory: URL

  /// Creates a locator for the current process.
  static var current: RuntimeCommandLocator {
    RuntimeCommandLocator(
      environment: ProcessInfo.processInfo.environment,
      homeDirectory: FileManager.default.homeDirectoryForCurrentUser,
      rootDirectory: URL(fileURLWithPath: "/")
    )
  }

  /// Returns the runtime's command, or `nil` when it is not installed.
  func locate(_ runtime: AgentRuntime) -> URL? {
    (onPath(runtime.rawValue) + fallbacks(for: runtime)).first(where: isExecutable)
  }

  /// Returns the candidates for `name` in each `PATH` directory.
  private func onPath(_ name: String) -> [URL] {
    (environment["PATH"] ?? "")
      .split(separator: ":")
      .map { URL(fileURLWithPath: String($0)).appendingPathComponent(name) }
  }

  /// Returns the usual install locations for the runtime, in order of preference.
  private func fallbacks(for runtime: AgentRuntime) -> [URL] {
    switch runtime {
      case .claude:
        [homeDirectory.appendingPathComponent(".local/bin/claude")] + bundledClaude()
      case .codex:
        [
          "opt/homebrew/bin/codex",
          "usr/local/bin/codex",
          "Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex",
        ].map { rootDirectory.appendingPathComponent($0) }
    }
  }

  /// Returns the Claude app's bundled commands, newest version first.
  private func bundledClaude() -> [URL] {
    let versions = homeDirectory.appendingPathComponent("Library/Application Support/Claude/claude-code")
    let names = (try? FileManager.default.contentsOfDirectory(atPath: versions.path)) ?? []
    return
      names
      .sorted { versionComponents($0).lexicographicallyPrecedes(versionComponents($1)) }
      .reversed()
      .map { versions.appendingPathComponent("\($0)/claude.app/Contents/MacOS/claude") }
  }

  /// Returns the numeric components of a dotted version, so that `2.1.30` sorts after `2.1.9`.
  private func versionComponents(_ version: String) -> [Int] {
    version.split(separator: ".").map { Int($0) ?? 0 }
  }

  /// Returns whether `url` is an executable file.
  private func isExecutable(_ url: URL) -> Bool {
    var isDirectory: ObjCBool = false
    return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && !isDirectory.boolValue
      && FileManager.default.isExecutableFile(atPath: url.path)
  }
}
