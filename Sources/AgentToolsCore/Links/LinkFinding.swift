// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 16/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// A relative Markdown link whose target could not be confirmed.
struct LinkFinding: Equatable {
  /// Root-relative path of the document holding the link.
  let file: String

  /// The link as written.
  let link: MarkdownLink

  /// Why the target was not confirmed.
  let problem: Problem

  /// Where the finding points, as `file:line`.
  var location: String { "\(file):\(link.line)" }
}

extension LinkFinding {
  /// Why a link's target was not confirmed.
  enum Problem: Equatable {
    /// The target does not exist, or lies outside the repository.
    case broken

    /// The target is inside a submodule that is not checked out.
    case unverified(submodule: String)
  }
}
