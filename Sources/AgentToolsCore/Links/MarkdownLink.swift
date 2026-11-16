// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 16/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// One link destination found in a Markdown document.
struct MarkdownLink: Equatable {
  /// The destination as written, without enclosing angle brackets.
  let destination: String

  /// One-based line the link starts on.
  let line: Int

  /// Where the destination, including any angle brackets, sits in the scanned text.
  let range: Range<String.Index>

  /// The decoded file path the destination names, or `nil` for an absolute URL, a `mailto:` or other scheme, or a
  /// link within the same document.
  var path: String? {
    guard destination.prefixMatch(of: #/[A-Za-z][A-Za-z0-9+.\-]*:/#) == nil, !destination.hasPrefix("//") else { return nil }
    let path = destination.prefix { $0 != "#" && $0 != "?" }
    guard !path.isEmpty else { return nil }
    return path.removingPercentEncoding ?? String(path)
  }

  /// The destination's `#anchor`, including the hash, or the empty string.
  var fragment: String {
    destination.firstIndex(of: "#").map { String(destination[$0...]) } ?? ""
  }

  /// Returns the root-relative path the link names when it appears in `file`, or `nil` when it does not name a file
  /// inside the repository.
  func repositoryPath(from file: String) -> String? {
    path.flatMap { RepositoryPath.resolve($0, in: RepositoryPath.directory(of: file)) }
  }
}
