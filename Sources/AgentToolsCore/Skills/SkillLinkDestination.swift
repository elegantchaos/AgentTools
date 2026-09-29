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
    AgentRuntime.allCases.map { runtime in
      SkillLinkDestination(
        label: runtime.rawValue,
        directory: runtime.home(environment: environment, homeDirectory: homeDirectory).appendingPathComponent("skills")
      )
    }
  }
}
