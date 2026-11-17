// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 16/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Checks the relative links in a checkout's tracked Markdown files against the files that exist there.
struct LinkChecker {
  /// Root of the checkout.
  let repoPath: String

  /// Returns every link whose target is missing or cannot be verified, ordered by file and position.
  func findings() throws -> [LinkFinding] {
    let index = try RepositoryIndex(repoPath: repoPath)
    var findings: [LinkFinding] = []
    for file in index.markdownFiles {
      let text = try String(contentsOf: URL(fileURLWithPath: repoPath).appending(path: file), encoding: .utf8)
      for link in MarkdownLinkScanner.links(in: text) where link.path != nil {
        switch link.repositoryPath(from: file).map(index.presence(of:)) ?? .missing {
          case .present: break
          case .missing: findings.append(LinkFinding(file: file, link: link, problem: .broken))
          case .unverified(let submodule): findings.append(LinkFinding(file: file, link: link, problem: .unverified(submodule: submodule)))
        }
      }
    }
    return findings
  }
}
