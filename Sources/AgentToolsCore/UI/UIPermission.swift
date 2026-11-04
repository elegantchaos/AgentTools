// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ApplicationServices
import CoreGraphics

/// A macOS privacy permission an `agt ui` command needs, checked before the command does anything.
///
/// macOS grants these permissions to the calling process's responsible process: the terminal or agent app that
/// started `agt`, or `/usr/libexec/sshd-keygen-wrapper` for a command run over ssh. Without them the underlying APIs fail
/// quietly, returning nothing or dropping events, so each command checks first and names the process to grant.
enum UIPermission {
  /// Reading and acting on other applications' accessibility elements.
  case accessibility

  /// Posting synthetic mouse and keyboard events. System Settings lists it under Accessibility.
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
    let holder = Self.grantee(responsiblePath: ResponsibleProcess.responsibleExecutablePath()).map { "\($0), which macOS holds responsible for agt" } ?? "the app or service that started agt"
    throw ToolError(
      "agt ui needs \(name) permission. In System Settings > Privacy & Security > \(settingsPane), allow \(holder), then run the command again. "
        + "Changes can take effect only for processes started afterwards."
    )
  }

  /// Returns the executable to allow in System Settings for a process whose responsible process runs
  /// `responsiblePath`.
  ///
  /// TCC records the executable the responsible process was started as, while its current path can differ after an
  /// `exec`. Over ssh, `sshd-keygen-wrapper` execs `sshd-session`: the process reports the session's path, but TCC
  /// checks grants for the wrapper.
  static func grantee(responsiblePath: String?) -> String? {
    responsiblePath == "/usr/libexec/sshd-session" ? "/usr/libexec/sshd-keygen-wrapper" : responsiblePath
  }

  /// The permission's name in messages.
  private var name: String {
    switch self {
      case .accessibility: "Accessibility"
      case .eventPosting: "Accessibility (to post events)"
      case .screenRecording: "Screen Recording"
    }
  }

  /// The System Settings list that grants the permission.
  private var settingsPane: String {
    switch self {
      case .accessibility, .eventPosting: "Accessibility"
      case .screenRecording: "Screen & System Audio Recording"
    }
  }
}
