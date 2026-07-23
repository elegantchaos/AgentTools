// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 23/04/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Describes a skill discovered from a source directory.
struct DiscoveredSkill {
  /// Runtime skill name from SKILL.md front matter.
  let name: String

  /// Repository-relative source path that was scanned.
  let sourcePath: String

  /// Origin type, for example submodule or repo-local.
  let sourceKind: String

  /// Directory containing the SKILL.md file.
  let skillDirectory: URL
}
