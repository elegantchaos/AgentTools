// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 16/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// Finds link destinations in Markdown text: inline links and images, and reference definitions.
///
/// Fenced code blocks and inline code spans are skipped, since links there are examples, not navigation.
enum MarkdownLinkScanner {
  /// Returns every link destination in `text`, in document order.
  static func links(in text: String) -> [MarkdownLink] {
    let inline = #/\]\(\s*(<[^<>]*>|(?:[^\s()<>]|\([^\s()]*\))+)(?:\s+(?:"[^"]*"|'[^']*'))?\s*\)/#
    let definition = #/^ {0,3}\[(?!\^)[^\]]+\]:\s*(<[^<>]*>|\S+)/#
    let fence = #/^ {0,3}(`{3,}|~{3,})(.*)$/#
    var links: [MarkdownLink] = []
    var openFence: Substring?
    for (index, line) in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).enumerated() {
      if let marker = line.wholeMatch(of: fence) {
        if let open = openFence {
          let closes = marker.1.first == open.first && marker.1.count >= open.count && marker.2.allSatisfy(\.isWhitespace)
          if closes { openFence = nil }
        } else {
          openFence = marker.1
        }
        continue
      }
      guard openFence == nil else { continue }
      let code = codeSpans(in: line)
      let destinations = line.matches(of: inline).map(\.1) + (line.firstMatch(of: definition).map { [$0.1] } ?? [])
      for destination in destinations where !code.contains(where: { $0.contains(destination.startIndex) }) {
        let bracketed = destination.hasPrefix("<")
        links.append(MarkdownLink(destination: String(bracketed ? destination.dropFirst().dropLast() : destination), line: index + 1, range: destination.startIndex..<destination.endIndex))
      }
    }
    return links.sorted { $0.range.lowerBound < $1.range.lowerBound }
  }

  /// Returns the ranges of inline code spans in a line: a run of backticks up to the next run of the same length.
  private static func codeSpans(in line: Substring) -> [Range<String.Index>] {
    let runs = line.matches(of: #/`+/#).map(\.range)
    var spans: [Range<String.Index>] = []
    var index = 0
    while index < runs.count {
      let length = line.distance(from: runs[index].lowerBound, to: runs[index].upperBound)
      if let close = runs[(index + 1)...].firstIndex(where: { line.distance(from: $0.lowerBound, to: $0.upperBound) == length }) {
        spans.append(runs[index].lowerBound..<runs[close].upperBound)
        index = close + 1
      } else {
        index += 1
      }
    }
    return spans
  }
}
