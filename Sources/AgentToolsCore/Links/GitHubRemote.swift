// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 16/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// The GitHub repository a checkout's remote names, used to build permalinks to its files.
struct GitHubRemote: Equatable {
  /// Account that owns the repository.
  let owner: String

  /// Repository name, without `.git`.
  let name: String

  /// Parses an SSH or HTTPS GitHub remote URL.
  init(url: String) throws {
    let pattern = #/^(?:https?://(?:[^@/]+@)?|ssh://git@|git@)github\.com[:/]([^/]+)/(.+?)(?:\.git)?/?$/#
    guard let match = url.trimmingCharacters(in: .whitespacesAndNewlines).wholeMatch(of: pattern) else {
      throw ToolError("Permalinks need a GitHub remote; cannot read owner and repository from \(url).")
    }
    owner = String(match.1)
    name = String(match.2)
  }

  /// Returns the permanent URL of a file or directory at a commit, keeping `fragment` as its anchor.
  func permalink(to resolution: LinkResolution, fragment: String) -> String {
    // Brackets and parentheses are valid in URL paths but would end a Markdown link early.
    let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "()[]"))
    let path = resolution.path.addingPercentEncoding(withAllowedCharacters: allowed) ?? resolution.path
    return "https://github.com/\(owner)/\(name)/\(resolution.isDirectory ? "tree" : "blob")/\(resolution.commit)/\(path)\(fragment)"
  }
}
