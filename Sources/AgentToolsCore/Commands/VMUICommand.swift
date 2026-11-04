// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation

/// Runs an `agt ui` command in a clone, bringing screenshots back to the host.
struct VMUICommand: AsyncParsableCommand {
  /// Command metadata.
  static let configuration = CommandConfiguration(
    commandName: "ui",
    abstract: "Run an agt ui command in a clone.",
    discussion: """
      Everything after the options is passed to the guest's agt ui, as in `agt vm ui tree --app com.example.Bookish`. \
      A screenshot's path is a host path: the guest writes a temporary file, which is copied here and deleted. \
      Coordinates are the guest's screen points.
      """
  )

  /// The clone to use.
  @OptionGroup var clone: VMCloneOptions

  /// The `agt ui` subcommand and its arguments.
  @Argument(parsing: .captureForPassthrough, help: "The agt ui subcommand and its arguments.")
  var arguments: [String] = []

  /// Runs the command in the guest, exiting with its status.
  mutating func run() async throws {
    let directory = FileManager.default.currentDirectoryPath
    let settings = try await VMSettings.load(repoPath: directory, homeDirectory: FileManager.default.homeDirectoryForCurrentUser)
    let guest = try clone.guest(tart: try Tart.current(), settings: settings)
    let guestPath = "/tmp/agt-vm-\(UUID().uuidString).png"
    guard let redirect = ScreenshotRedirect(arguments: arguments, guestPath: guestPath, hostDirectory: directory) else {
      let status = try guest.run([guest.agt, "ui"] + arguments)
      if status != 0 { throw ExitCode(status) }
      return
    }

    defer { _ = try? guest.capture(["rm", "-f", guestPath]) }
    let result = try guest.capture([guest.agt, "ui"] + redirect.guestArguments)
    FileHandle.standardError.write(Data(result.stderr.utf8))
    guard result.status == 0 else { throw ExitCode(result.status) }
    let copy = try VMGuest.capture(guest.copyArguments(from: guestPath, to: redirect.hostPath))
    guard copy.status == 0 else {
      throw ToolError("Could not copy the screenshot to \(redirect.hostPath): \(copy.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
    print(result.stdout.replacingOccurrences(of: guestPath, with: redirect.hostPath), terminator: "")
  }
}
