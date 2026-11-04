// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ApplicationServices
import CoreGraphics

/// A macOS privacy permission an `agt ui` command needs, checked before the command does anything.
///
/// macOS grants these permissions to a process's responsible process. The commands that check them run in an `agt`
/// that is its own responsible process, so the grant belongs to the `agt` executable. Without them the underlying
/// APIs fail quietly, returning nothing or dropping events, so each command checks first and names the executable to
/// grant.
enum UIPermission {
  /// Reading and acting on other applications' accessibility elements.
  case accessibility

  /// Posting synthetic mouse and keyboard events. System Settings grants it under Device Control and Data Access, called Accessibility before macOS 27.
  case eventPosting

  /// Capturing the screen.
  case screenRecording

  /// Whether the permission is currently granted.
  var isGranted: Bool {
    switch self {
      case .accessibility: AXIsProcessTrusted()
      case .eventPosting: CGPreflightPostEventAccess()
      case .screenRecording: CGPreflightScreenCaptureAccess()
    }
  }

  /// Throws an error explaining how to grant the permission when it is missing.
  func require() throws {
    guard !isGranted else { return }
    let holder = ResponsibleProcess.responsibleExecutablePath() ?? "agt"
    throw ToolError(
      "agt ui needs \(name) permission. In System Settings > Privacy & Security > \(settingsPane), allow \(holder), then run the command again. "
        + "A grant belongs to this exact build of agt, so each rebuild needs granting again."
    )
  }

  /// The permission's name in messages.
  private var name: String {
    switch self {
      case .accessibility: "Device Control and Data Access (formerly Accessibility)"
      case .eventPosting: "Device Control and Data Access (formerly Accessibility) to post events"
      case .screenRecording: "Screen Recording"
    }
  }

  /// The System Settings list that grants the permission.
  private var settingsPane: String {
    switch self {
      case .accessibility, .eventPosting: "Device Control and Data Access"
      case .screenRecording: "Screen & System Audio Recording"
    }
  }
}
