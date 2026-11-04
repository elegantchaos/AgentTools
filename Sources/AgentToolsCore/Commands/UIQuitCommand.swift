// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import AppKit
import ArgumentParser

/// Quits a running application and waits for it to exit.
struct UIQuitCommand: AsyncParsableCommand {
  /// Command metadata.
  static let configuration = CommandConfiguration(
    commandName: "quit",
    abstract: "Quit an application and wait for it to exit."
  )

  /// How long to wait for the application to exit.
  static let timeout = Duration.seconds(10)

  /// How often to check whether the application has exited.
  static let pollInterval = Duration.milliseconds(100)

  /// The application to quit.
  @Argument(help: "Bundle identifier or process identifier of the application.", transform: AppTarget.init(argument:))
  var application: AppTarget

  /// Whether to kill the application instead of asking it to quit.
  @Flag(help: "Force the application to quit, without letting it save or ask questions.")
  var force = false

  /// Asks the application to quit, then waits for it to exit.
  mutating func run() async throws {
    let running = try application.runningApplication()
    guard force ? running.forceTerminate() : running.terminate() else {
      throw ToolError("\(running.localizedName ?? "The application") did not accept the request to quit.")
    }
    // NSRunningApplication only updates isTerminated from a run loop, which agt does not run, so poll the process
    // itself until the timeout.
    let pid = running.processIdentifier
    let deadline = ContinuousClock.now + Self.timeout
    while kill(pid, 0) == 0 || errno != ESRCH {
      guard ContinuousClock.now < deadline else {
        throw ToolError("\(running.localizedName ?? "The application") was still running after \(Self.timeout); it may be showing a dialog. Use --force to kill it.")
      }
      try await Task.sleep(for: Self.pollInterval)
    }
    print("Quit \(running.localizedName ?? "process \(pid)").")
  }
}
