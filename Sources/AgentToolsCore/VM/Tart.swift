// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Runs the external `tart` command to clone, boot, stop, delete and list virtual machines.
///
/// tart is never linked: each operation runs its executable as a subprocess, found by `locate`. Operations that
/// fail throw with tart's own error output. `start` leaves `tart run` running in the background, writing to a log,
/// after `agt` exits; `stop` ends it.
struct Tart {
  /// The tart executable.
  let executable: URL

  /// Finds tart on `PATH`, then in the usual install locations, or throws explaining that it is missing.
  static func locate(environment: [String: String], homeDirectory: URL, rootDirectory: URL = URL(fileURLWithPath: "/")) throws -> Tart {
    let onPath = (environment["PATH"] ?? "").split(separator: ":").map { URL(fileURLWithPath: String($0)).appending(path: "tart") }
    let fallbacks = [
      homeDirectory.appending(path: "Applications/tart.app/Contents/MacOS/tart"),
      rootDirectory.appending(path: "Applications/tart.app/Contents/MacOS/tart"),
      rootDirectory.appending(path: "opt/homebrew/bin/tart"),
    ]
    guard let executable = (onPath + fallbacks).first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) else {
      throw ToolError("agt vm needs tart, which is not installed. Install it from https://tart.run and try again.")
    }
    return Tart(executable: executable)
  }

  /// Returns tart for the current process.
  static func current() throws -> Tart {
    try locate(environment: ProcessInfo.processInfo.environment, homeDirectory: FileManager.default.homeDirectoryForCurrentUser)
  }

  /// Returns the command line that boots `name`, headless unless `window` is set, sharing `share` read-only as
  /// `products` when given, so it appears in the guest at `VMGuest.sharePath`.
  func runArguments(name: String, share: String?, window: Bool) -> [String] {
    [executable.path, "run", name] + (window ? [] : ["--no-graphics"]) + (share.map { ["--dir=\(VMGuest.shareName):\($0):ro"] } ?? [])
  }

  /// Clones `base` as `name`.
  func clone(_ base: String, as name: String) throws {
    try check(["clone", base, name])
  }

  /// Boots `name` in the background with `tart run`, writing its output to `logPath`, and returns the running process.
  func start(name: String, share: String?, window: Bool, logPath: String) throws -> Process {
    FileManager.default.createFile(atPath: logPath, contents: nil)
    let log = try FileHandle(forWritingTo: URL(fileURLWithPath: logPath))
    defer { try? log.close() }
    let arguments = runArguments(name: name, share: share, window: window)
    let process = Process()
    process.executableURL = executable
    process.arguments = Array(arguments.dropFirst())
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = log
    process.standardError = log
    try process.run()
    return process
  }

  /// Returns the address of `name`, or `nil` while it has none.
  func ip(_ name: String) throws -> String? {
    let result = try capture(["ip", name])
    let address = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    return result.status == 0 && !address.isEmpty ? address : nil
  }

  /// Stops `name` if it is running.
  func stop(_ name: String) throws {
    try check(["stop", name])
  }

  /// Deletes `name`.
  func delete(_ name: String) throws {
    try check(["delete", name])
  }

  /// Returns the local virtual machines.
  func list() throws -> [Machine] {
    let result = try check(["list", "--source", "local", "--format", "json"])
    return try JSONDecoder().decode([Machine].self, from: Data(result.stdout.utf8))
  }

  /// Runs tart with `arguments` and captures its output.
  private func capture(_ arguments: [String]) throws -> CommandResult {
    try ValidationProcess(workingDirectory: FileManager.default.currentDirectoryPath).capture([executable.path] + arguments)
  }

  /// Runs tart with `arguments`, throwing with its error output when it fails.
  @discardableResult
  private func check(_ arguments: [String]) throws -> CommandResult {
    let result = try capture(arguments)
    guard result.status == 0 else {
      let output = [result.stderr, result.stdout].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty } ?? "exit status \(result.status)"
      throw ToolError("tart \(arguments.joined(separator: " ")) failed: \(output)")
    }
    return result
  }
}

extension Tart {
  /// A virtual machine as `tart list --format json` describes it.
  struct Machine: Decodable, Equatable {
    /// The machine's name.
    let name: String

    /// tart's state for it, such as `running` or `stopped`.
    let state: String

    /// Whether it is running.
    var isRunning: Bool { state == "running" }

    /// tart's capitalised JSON keys.
    private enum CodingKeys: String, CodingKey {
      /// The machine's name.
      case name = "Name"
      /// The machine's state.
      case state = "State"
    }
  }
}
