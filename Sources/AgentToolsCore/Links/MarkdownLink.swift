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
    let destination = decodedDestination
    guard destination.prefixMatch(of: #/[A-Za-z][A-Za-z0-9+.\-]*:/#) == nil, !destination.hasPrefix("//") else { return nil }
    let path = destination.prefix { $0 != "#" && $0 != "?" }
    guard !path.isEmpty else { return nil }
    return path.removingPercentEncoding ?? String(path)
  }

  /// The destination's `#anchor`, including the hash, or the empty string.
  var fragment: String {
    let destination = decodedDestination
    return destination.firstIndex(of: "#").map { String(destination[$0...]) } ?? ""
  }

  /// Decodes Markdown punctuation escapes and character references before interpreting URL delimiters.
  private var decodedDestination: String {
    var decoded = destination
    for match in destination.matches(of: #/\\([!-/:-@\[-`{-~])|&(?:\#[xX][0-9a-fA-F]+|\#[0-9]+|[A-Za-z][A-Za-z0-9]+);/#).reversed() {
      if let escaped = match.1 {
        decoded.replaceSubrange(match.range, with: escaped)
      } else {
        // Foundation's Markdown parser supplies the complete named and numeric entity rules.
        let entity = String(match.output.0)
        let parsed = try? AttributedString(markdown: entity, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))
        decoded.replaceSubrange(match.range, with: parsed.map { String($0.characters) } ?? entity)
      }
    }
    return decoded
  }

  /// Returns the root-relative path the link names when it appears in `file`, or `nil` when it does not name a file
  /// inside the repository.
  func repositoryPath(from file: String) -> String? {
    path.flatMap { RepositoryPath.resolve($0, in: RepositoryPath.directory(of: file)) }
  }
}
