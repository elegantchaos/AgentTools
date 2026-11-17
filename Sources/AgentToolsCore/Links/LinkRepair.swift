// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 16/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// What `agt links --fix-history` decided for one broken link in a historical record.
struct LinkRepair: Equatable {
  /// The broken link.
  let finding: LinkFinding

  /// Whether a revision was found for it.
  let outcome: Outcome
}

extension LinkRepair {
  /// The result of looking for a link's target in history.
  enum Outcome: Equatable {
    /// The link's destination becomes `url`, which names the target at `resolution`.
    case permalink(url: String, resolution: LinkResolution)

    /// The target never existed on the current branch, so the link is left alone.
    case unresolved
  }
}
