// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation

/// Runs a command's work in an `agt` that is its own responsible process, so that macOS privacy permissions belong
/// to `agt` itself, not to the terminal, agent app or ssh service that started it.
///
/// Started normally, `agt` relaunches itself as its own responsible process with the same arguments, passes its
/// output through, and exits with its status. The relaunched `agt` does the work, and exits if the `agt` that started
/// it does. Calendar and `ui` commands use it; decision 0007 in `Extras/Decisions` records why.
enum SelfResponsibleRunner {
  /// Environment variable that marks a relaunched `agt`, so a failed disclaim cannot relaunch forever.
  static let relaunchVariable = "AGT_SELF_RESPONSIBLE_RELAUNCHED"

  /// Runs `work` in a self-responsible `agt`, relaunching first when this process is not one.
  ///
  /// `task` completes the phrase "agt … will not …" in failure messages, such as "read calendars".
  static func run(task: String, _ work: () async throws -> Void) async throws {
    let environment = ProcessInfo.processInfo.environment
    switch SelfResponsibleExecution.plan(selfResponsible: ResponsibleProcess.isSelfResponsible(), relaunched: environment[relaunchVariable] != nil) {
      case .run:
        let parentWatch = environment[relaunchVariable] == nil ? nil : exitWhenParentExits()
        defer { parentWatch?.cancel() }
        try await work()
      case .relaunch:
        guard let executable = Bundle.main.executablePath else {
          throw ToolError("Cannot find the agt executable to \(task).")
        }
        let status = try ResponsibleProcess.runDisclaimed(
          executable: executable,
          arguments: Array(CommandLine.arguments.dropFirst()),
          environment: environment.merging([relaunchVariable: "1"]) { _, new in new }
        )
        guard status == 0 else { throw ExitCode(status) }
      case .unavailable:
        throw ToolError("This version of macOS does not provide the private functions agt needs to \(task) as its own responsible process.")
      case .disclaimFailed:
        throw ToolError("agt could not run as its own responsible process, so it will not \(task).")
    }
  }

  /// Ends this process when the `agt` that relaunched it ends, so that cancelled work cannot carry on unseen.
  private static func exitWhenParentExits() -> any DispatchSourceProcess {
    let parent = getppid()
    let source = DispatchSource.makeProcessSource(identifier: parent, eventMask: .exit, queue: .global())
    source.setEventHandler { exit(EXIT_FAILURE) }
    source.resume()
    if getppid() != parent { exit(EXIT_FAILURE) }
    return source
  }
}
