// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 25/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Starts and stops background full validation.
///
/// A background validation runs `agt` itself as a detached worker process, with its output going to a log file. Each
/// worker holds a token recorded in the status file. A newer validation replaces the token, and the worker, which checks
/// it about twice a second, interrupts its current tool and exits. The worker leads its own process group, so if it has
/// not exited after a grace period it can be killed together with the tools it runs.
enum BackgroundLauncher {
  /// Options that select something other than full validation, and are dropped from the worker's arguments.
  private static let droppedFlags: Set<String> = ["--fast", "--background", "--status", "--wait", "--plan", "--background-worker"]

  /// Returns the arguments for the worker: the command's own arguments, without options that select something other
  /// than full validation, followed by `--background-worker`.
  static func workerArguments(from arguments: [String]) -> [String] {
    var result: [String] = []
    var skipNext = false
    for argument in arguments {
      if skipNext {
        skipNext = false
      } else if argument == "--target" {
        skipNext = true
      } else if !droppedFlags.contains(argument), !argument.hasPrefix("--target=") {
        result.append(argument)
      }
    }
    return result + ["--background-worker"]
  }

  /// Environment variable that passes a worker its token.
  static let tokenVariable = "AGT_BACKGROUND_TOKEN"

  /// Seconds a replaced worker has to exit before it is killed.
  private static let gracePeriod: TimeInterval = 30

  /// Starts a worker in `repoPath`, recording it as running.
  static func start(repoPath: String, fingerprint: String, store: BackgroundStatusStore) throws -> BackgroundStatus {
    guard let executable = Bundle.main.executableURL else {
      throw ToolError("Cannot find the agt executable to start background validation.")
    }
    let token = UUID().uuidString
    var status = BackgroundStatus(state: .running, pid: 0, fingerprint: fingerprint, started: .now, token: token)
    try store.save(status)

    FileManager.default.createFile(atPath: store.logPath, contents: nil)
    let log = try FileHandle(forWritingTo: URL(fileURLWithPath: store.logPath))
    let worker = Process()
    worker.executableURL = executable
    worker.arguments = workerArguments(from: Array(CommandLine.arguments.dropFirst()))
    worker.currentDirectoryURL = URL(fileURLWithPath: repoPath)
    worker.environment = ProcessInfo.processInfo.environment.merging([tokenVariable: token]) { _, new in new }
    worker.standardInput = FileHandle.nullDevice
    worker.standardOutput = log
    worker.standardError = log
    try worker.run()
    try? log.close()

    status.pid = worker.processIdentifier
    if store.load()?.isOwned(byToken: token) ?? false {
      try store.save(status)
    }
    return status
  }

  /// Tells a running background validation to stop by replacing its token, then waits for it to exit, killing it only
  /// if it has not exited after a grace period. Returns `true` when one was running.
  @discardableResult
  static func supersede(store: BackgroundStatusStore) -> Bool {
    guard var status = store.load(), status.state == .running else { return false }
    let pid = status.pid
    status.state = .cancelled
    status.finished = .now
    status.token = ""
    try? store.save(status)

    guard pid > 0 else { return true }
    let deadline = Date.now.addingTimeInterval(gracePeriod)
    while isAlive(pid), Date.now < deadline {
      usleep(200_000)
    }
    if isAlive(pid) {
      killpg(pid, SIGTERM)
      for _ in 0..<25 where isAlive(pid) {
        usleep(200_000)
      }
      if isAlive(pid) {
        killpg(pid, SIGKILL)
      }
    }
    return true
  }

  /// Returns `true` when a process exists.
  static func isAlive(_ pid: Int32) -> Bool {
    kill(pid, 0) == 0
  }
}
