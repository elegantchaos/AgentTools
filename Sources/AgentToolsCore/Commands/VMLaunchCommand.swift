// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation

/// Opens an application in a clone as the guest user.
struct VMLaunchCommand: AsyncParsableCommand {
  /// Command metadata.
  static let configuration = CommandConfiguration(
    commandName: "launch",
    abstract: "Open an application in a clone.",
    discussion: "Pass launch arguments after --, as in `agt vm launch Bookish.app -- -reset`."
  )

  /// The clone to use.
  @OptionGroup var clone: VMCloneOptions

  /// The application's path in the guest.
  @Argument(help: "Path of the .app bundle, relative to the share, or absolute in the guest.")
  var application: String

  /// Arguments to pass to the application.
  @Argument(parsing: .postTerminator, help: "Arguments for the application.")
  var arguments: [String] = []

  /// Opens the application with `open` over ssh.
  mutating func run() async throws {
    let settings = try await VMSettings.load(repoPath: FileManager.default.currentDirectoryPath, homeDirectory: FileManager.default.homeDirectoryForCurrentUser)
    let guest = try clone.guest(tart: try Tart.current(), settings: settings)
    let command = VMGuest.launchCommand(app: application, arguments: arguments)
    let result = try guest.capture(command)
    guard result.status == 0 else {
      throw ToolError("Could not open \(command[1]): \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
    print("Opened \(command[1]).")
  }
}
