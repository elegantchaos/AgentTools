// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 16/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// Finds source ranges for inline links, images and reference definitions without changing their spelling.
/// Fences and code spans are excluded before scanning brackets; destinations can continue onto the next line.
enum MarkdownLinkScanner {
  /// Returns every link destination in `text`, in document order.
  static func links(in text: String) -> [MarkdownLink] {
    let fences = fencedRanges(in: text)
    let excluded = fences + codeSpans(in: text, excluding: fences)
    var links: [MarkdownLink] = []
    var brackets: [String.Index] = []
    var cursor = text.startIndex
    while cursor < text.endIndex {
      if let range = excluded.first(where: { $0.contains(cursor) }) {
        if fences.contains(range) { brackets.removeAll() }
        cursor = range.upperBound
        continue
      }
      if text[cursor] == "\\" {
        cursor = text.index(after: cursor)
        if cursor < text.endIndex, isPunctuation(text[cursor]) { cursor = text.index(after: cursor) }
        continue
      }
      if text[cursor] == "[" { brackets.append(cursor) }
      if text[cursor] == "]", let start = brackets.popLast(),
        let destination = inlineDestination(in: text, after: cursor)
      {
        links.append(link(in: text, range: destination.range, start: start))
        brackets.removeAll()
        cursor = destination.end
        continue
      }
      // A blank line ends an inline construct, including any unmatched opening brackets.
      if text[cursor...].prefixMatch(of: #/\r?\n[ \t]*\r?\n/#) != nil { brackets.removeAll() }
      cursor = text.index(after: cursor)
    }
    for line in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
      guard let opener = line.prefixMatch(of: #/ {0,3}\[(?!\^)(?:\\.|[^\]\\])+\]:/#),
        !excluded.contains(where: { $0.contains(line.startIndex) }),
        let range = destinationRange(in: text, at: skipSpace(in: text, at: opener.range.upperBound))
      else { continue }
      links.append(link(in: text, range: range, start: line.startIndex))
    }
    return links.sorted { $0.range.lowerBound < $1.range.lowerBound }
  }

  /// Reads a complete inline destination and its optional title after a closing label bracket.
  private static func inlineDestination(in text: String, after bracket: String.Index) -> (range: Range<String.Index>, end: String.Index)? {
    let parenthesis = text.index(after: bracket)
    guard parenthesis < text.endIndex, text[parenthesis] == "(",
      let range = destinationRange(in: text, at: skipSpace(in: text, at: text.index(after: parenthesis)))
    else { return nil }
    var end = skipSpace(in: text, at: range.upperBound)
    if end < text.endIndex, text[end] != ")" {
      // A title needs whitespace after the destination, and its own matching delimiter.
      guard end != range.upperBound,
        let title = text[end...].prefixMatch(of: #/"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|\((?:\\.|[^)\\])*\)/#),
        title.output.split(separator: "\n", omittingEmptySubsequences: false).dropFirst().dropLast().allSatisfy({ !$0.allSatisfy(\.isWhitespace) })
      else { return nil }
      end = skipSpace(in: text, at: title.range.upperBound)
    }
    guard end < text.endIndex, text[end] == ")" else { return nil }
    return (range, text.index(after: end))
  }

  /// Reads an angle-bracketed or balanced bare destination, retaining Markdown escapes in its source range.
  private static func destinationRange(in text: String, at start: String.Index) -> Range<String.Index>? {
    guard start < text.endIndex else { return nil }
    let bracketed = text[start] == "<"
    var cursor = bracketed ? text.index(after: start) : start
    var depth = 0
    while cursor < text.endIndex {
      let character = text[cursor]
      if character == "\\" {
        let next = text.index(after: cursor)
        if next < text.endIndex, isPunctuation(text[next]) {
          cursor = text.index(after: next)
          continue
        }
      }
      if bracketed {
        if character == ">" { return start..<text.index(after: cursor) }
        if character == "<" || character.isNewline { return nil }
      } else {
        if character.isWhitespace || (character == ")" && depth == 0) { break }
        if character == "<" || character == ">" { return nil }
        if character == "(" { depth += 1 }
        if character == ")" { depth -= 1 }
      }
      cursor = text.index(after: cursor)
    }
    return !bracketed && depth == 0 && cursor > start ? start..<cursor : nil
  }

  /// Skips horizontal whitespace and at most one line ending between components of a link.
  private static func skipSpace(in text: String, at start: String.Index) -> String.Index {
    text[start...].prefixMatch(of: #/[ \t]*(?:\r?\n[ \t]*)?/#)?.range.upperBound ?? start
  }

  /// Builds a link with its original destination spelling and one-based opening line.
  private static func link(in text: String, range: Range<String.Index>, start: String.Index) -> MarkdownLink {
    let source = text[range]
    let destination = source.hasPrefix("<") ? source.dropFirst().dropLast() : source[...]
    let line = text[..<start].split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).count
    return MarkdownLink(destination: String(destination), line: line, range: range)
  }

  /// Marks fenced blocks, including their delimiter lines, so examples never become repair candidates.
  private static func fencedRanges(in text: String) -> [Range<String.Index>] {
    var ranges: [Range<String.Index>] = []
    var open: (marker: Substring, start: String.Index)?
    for line in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
      guard let marker = line.wholeMatch(of: #/ {0,3}(`{3,}|~{3,})(.*)/#) else { continue }
      if let current = open {
        if marker.1.first == current.marker.first, marker.1.count >= current.marker.count, marker.2.allSatisfy(\.isWhitespace) {
          ranges.append(current.start..<line.endIndex)
          open = nil
        }
      } else {
        open = (marker.1, line.startIndex)
      }
    }
    if let open { ranges.append(open.start..<text.endIndex) }
    return ranges
  }

  /// Pairs backtick runs across a paragraph, excluding fenced blocks and escaped opening delimiters.
  private static func codeSpans(in text: String, excluding fences: [Range<String.Index>]) -> [Range<String.Index>] {
    let runs = text.matches(of: #/`+/#).map(\.range).filter { run in !fences.contains(where: { $0.contains(run.lowerBound) }) }
    var spans: [Range<String.Index>] = []
    var index = 0
    while index < runs.count {
      let run = runs[index]
      let length = text.distance(from: run.lowerBound, to: run.upperBound)
      if !isEscaped(in: text, at: run.lowerBound),
        let close = runs[(index + 1)...].firstIndex(where: { text.distance(from: $0.lowerBound, to: $0.upperBound) == length })
      {
        let between = run.upperBound..<runs[close].lowerBound
        if text[between].firstMatch(of: #/\r?\n[ \t]*\r?\n/#) == nil,
          !fences.contains(where: { $0.overlaps(between) })
        {
          spans.append(run.lowerBound..<runs[close].upperBound)
          index = close + 1
          continue
        }
      }
      index += 1
    }
    return spans
  }

  /// Whether an odd number of preceding backslashes escapes a punctuation character.
  private static func isEscaped(in text: String, at index: String.Index) -> Bool {
    var cursor = index
    var count = 0
    while cursor > text.startIndex {
      cursor = text.index(before: cursor)
      guard text[cursor] == "\\" else { break }
      count += 1
    }
    return count % 2 == 1
  }

  /// Markdown escapes apply to ASCII punctuation, not arbitrary characters after a backslash.
  private static func isPunctuation(_ character: Character) -> Bool {
    character.isASCII && character.unicodeScalars.allSatisfy { (33...47).contains($0.value) || (58...64).contains($0.value) || (91...96).contains($0.value) || (123...126).contains($0.value) }
  }
}
