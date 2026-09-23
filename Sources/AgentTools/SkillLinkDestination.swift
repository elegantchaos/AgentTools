// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 23/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// A runtime skill directory that receives links to discovered skills.
struct SkillLinkDestination: Equatable {
  /// Short runtime name used in status output.
  let label: String

  /// Directory that holds one symlink per skill.
  let directory: URL

  /// Returns the Codex and Claude Code skill directories, honouring their home overrides.
  static func defaults(environment: [String: String], homeDirectory: URL) -> [SkillLinkDestination] {
    /// Builds the skills directory inside one runtime's home.
    func runtime(_ label: String, homeVariable: String, defaultHome: String) -> SkillLinkDestination {
      let home =
        environment[homeVariable].map { URL(fileURLWithPath: $0) }
        ?? homeDirectory.appendingPathComponent(defaultHome)
      return SkillLinkDestination(label: label, directory: home.appendingPathComponent("skills"))
    }

    return [
      runtime("codex", homeVariable: "CODEX_HOME", defaultHome: ".codex"),
      runtime("claude", homeVariable: "CLAUDE_CONFIG_DIR", defaultHome: ".claude"),
    ]
  }
}
