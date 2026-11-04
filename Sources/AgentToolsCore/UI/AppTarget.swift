// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import AppKit

/// The running application an `agt ui` command acts on.
enum AppTarget: Equatable {
  /// The application that is frontmost in the login session.
  case frontmost

  /// The first running application with this bundle identifier.
  case bundleIdentifier(String)

  /// The application with this process identifier.
  case processIdentifier(pid_t)

  /// Reads a process identifier when `argument` is numeric, and a bundle identifier otherwise.
  init(argument: String) {
    self = pid_t(argument).map { .processIdentifier($0) } ?? .bundleIdentifier(argument)
  }

  /// Finds the running application, or throws when it is not running.
  func runningApplication() throws -> NSRunningApplication {
    let application: NSRunningApplication? =
      switch self {
        case .frontmost: NSWorkspace.shared.frontmostApplication
        case .bundleIdentifier(let identifier): NSRunningApplication.runningApplications(withBundleIdentifier: identifier).first
        case .processIdentifier(let pid): NSRunningApplication(processIdentifier: pid)
      }
    guard let application else {
      throw ToolError(missingMessage)
    }
    return application
  }

  /// Explains which application could not be found.
  private var missingMessage: String {
    switch self {
      case .frontmost: "No application is frontmost. Is anyone logged in to the console?"
      case .bundleIdentifier(let identifier): "No running application has the bundle identifier \(identifier)."
      case .processIdentifier(let pid): "No running application has the process identifier \(pid)."
    }
  }
}
