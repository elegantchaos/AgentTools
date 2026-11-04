// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Rewrites the arguments of an `agt ui screenshot` passed through to a clone, so that its path names a host file.
///
/// The guest writes the PNG to `guestPath` instead; `agt vm ui` then copies it to `hostPath` and deletes the guest
/// copy.
struct ScreenshotRedirect: Equatable {
  /// The arguments to run in the guest, with the path replaced by the guest file.
  let guestArguments: [String]

  /// The absolute host path the caller asked for.
  let hostPath: String

  /// Rewrites `arguments` when they are a screenshot with a path, resolving a relative path against `hostDirectory`;
  /// returns `nil` for anything else, which passes through unchanged.
  init?(arguments: [String], guestPath: String, hostDirectory: String) {
    guard arguments.first == "screenshot" else { return nil }
    var index = 1
    while index < arguments.count {
      let argument = arguments[index]
      if argument == "--app" {
        index += 2
      } else if argument.hasPrefix("-") {
        index += 1
      } else {
        var rewritten = arguments
        rewritten[index] = guestPath
        guestArguments = rewritten
        hostPath = URL(fileURLWithPath: argument, relativeTo: URL(fileURLWithPath: hostDirectory, isDirectory: true)).standardizedFileURL.path
        return
      }
    }
    return nil
  }
}
