// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 16/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// The revision a broken link in a historical record should point at.
struct LinkResolution: Equatable {
  /// Full hash of the commit holding the target.
  let commit: String

  /// Root-relative path of the target in that commit.
  let path: String

  /// Whether the target is a directory there.
  let isDirectory: Bool

  /// How the commit was chosen.
  let basis: Basis
}

extension LinkResolution {
  /// How a resolution's commit was chosen.
  enum Basis: Equatable {
    /// The first commit where the document carried the link and the target existed.
    case introduced

    /// The parent of the commit that removed the target, used when the link never resolved.
    case beforeRemoval
  }
}
