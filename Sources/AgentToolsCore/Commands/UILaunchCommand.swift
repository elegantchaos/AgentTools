// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import AppKit
import ArgumentParser

/// Launches an application into the login session and brings it to the front.
struct UILaunchCommand: AsyncParsableCommand {
  /// Command metadata.
  static let configuration = CommandConfiguration(
    commandName: "launch",
    abstract: "Launch an application and bring it to the front.",
    discussion: "Prints the process identifier. Pass launch arguments after --, as in `agt ui launch ./Bookish.app -- -reset`."
  )

  /// The application's path or bundle identifier.
  @Argument(help: "Path to an .app bundle, or a bundle identifier.")
  var application: String

  /// Arguments to pass to the application.
  @Argument(parsing: .postTerminator, help: "Arguments for the application.")
  var arguments: [String] = []

  /// Launches the application.
  mutating func run() async throws {
    let url = try applicationURL()
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.arguments = arguments
    configuration.activates = true
    let launched = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    print("Launched \(launched.localizedName ?? url.lastPathComponent) (process \(launched.processIdentifier)).")
  }

  /// Resolves the argument as a path when it contains a slash or ends in `.app`, and as a bundle identifier otherwise.
  private func applicationURL() throws -> URL {
    if application.contains("/") || application.hasSuffix(".app") {
      return URL(filePath: application)
    }
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: application) else {
      throw ToolError("No application with the bundle identifier \(application) is installed.")
    }
    return url
  }
}
