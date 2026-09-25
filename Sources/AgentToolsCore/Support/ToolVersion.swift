// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// The version of `agt`, generated from git at build time by the Versionator plugin.
enum ToolVersion {
  /// The version of this build.
  static var current: String {
    description(tag: VersionatorVersion.tag, git: VersionatorVersion.git)
  }

  /// Describes a build: its tag when built exactly from a tag, otherwise the full `git describe` output.
  static func description(tag: String, git: String) -> String {
    "AgentTools \(git.contains("-0-") ? tag : git)."
  }
}
