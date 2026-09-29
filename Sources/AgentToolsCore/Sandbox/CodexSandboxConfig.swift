// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Adds writable roots to Codex's `config.toml`, as `sandbox_workspace_write.writable_roots`.
///
/// The file is the user's own, so it is edited as text rather than parsed and rewritten: new entries are inserted
/// into the existing array, or the key or table is added, and every other character is left alone, including
/// comments and layout. It understands a `[sandbox_workspace_write]` table or `sandbox_workspace_write.` dotted keys
/// in the root table, with a single-line or multi-line array of strings, and throws for any other layout, such as an
/// inline table, rather than guessing.
enum CodexSandboxConfig {
  /// Table that holds the sandbox settings.
  static let table = "sandbox_workspace_write"

  /// Key, within the table, that lists extra writable directories.
  static let key = "writable_roots"

  /// Returns `text` with any of `paths` that are missing added to the writable roots, or `nil` when none are missing.
  static func adding(_ paths: [String], to text: String) throws -> String? {
    var editor = Editor(characters: Array(text))
    return try editor.adding(paths).map { String($0) }
  }

  /// Returns a TOML basic string for `value`.
  static func quoted(_ value: String) -> String {
    let escaped = value.replacing("\\", with: "\\\\").replacing("\"", with: "\\\"")
    return "\"\(escaped)\""
  }
}

extension CodexSandboxConfig {
  /// Finds the table, key, and array in the configuration text, and makes the insertions.
  fileprivate struct Editor {
    /// The configuration, as characters so that positions can be used as integer offsets.
    var characters: [Character]

    /// Returns the edited characters, or `nil` when every path is already present.
    mutating func adding(_ paths: [String]) throws -> [Character]? {
      switch try locateKey() {
        case .missing:
          return appendingTable(with: unique(paths))
        case .unset(let lineEnd, let prefix):
          return insertingKey(with: unique(paths), afterLineEnd: lineEnd, prefix: prefix)
        case .set(let valueStart):
          let array = try parseArray(from: valueStart)
          let missing = unique(paths).filter { !array.values.contains($0) }
          guard !missing.isEmpty else { return nil }
          return extending(array, with: missing)
      }
    }

    /// Finds where the configuration sets the key, or where to add it.
    ///
    /// Dotted keys in the root table come first; otherwise the `[sandbox_workspace_write]` table is used. Throws when
    /// the root table sets the table inline, which this editor cannot extend.
    private func locateKey() throws -> KeyLocation {
      var lastDottedLineEnd: Int?
      for (start, end) in lines() {
        let line = String(characters[start..<end]).trimmingPrefix(while: \.isWhitespace)
        if tableName(in: line) != nil { break }
        guard line.hasPrefix(CodexSandboxConfig.table) else { continue }
        let rest = line.dropFirst(CodexSandboxConfig.table.count).trimmingPrefix(while: \.isWhitespace)
        if rest.hasPrefix("=") {
          throw ToolError("\(CodexSandboxConfig.table) is an inline table; add the writable roots by hand")
        }
        guard rest.hasPrefix(".") else { continue }
        if let valueStart = valueStart(ofKeyIn: rest.dropFirst().trimmingPrefix(while: \.isWhitespace), lineEnd: end) {
          return .set(valueStart: valueStart)
        }
        lastDottedLineEnd = end
      }
      if let lastDottedLineEnd {
        return .unset(lineEnd: lastDottedLineEnd, prefix: CodexSandboxConfig.table + ".")
      }
      for (start, end) in lines() where tableName(in: String(characters[start..<end]).trimmingPrefix(while: \.isWhitespace)) == CodexSandboxConfig.table {
        return tableKeyLocation(afterHeaderLineEnd: end)
      }
      return .missing
    }

    /// Finds the key within the table whose header line ends at `header`.
    private func tableKeyLocation(afterHeaderLineEnd header: Int) -> KeyLocation {
      for (start, end) in lines() where start > header {
        let line = String(characters[start..<end]).trimmingPrefix(while: \.isWhitespace)
        if tableName(in: line) != nil { break }
        if let valueStart = valueStart(ofKeyIn: line, lineEnd: end) {
          return .set(valueStart: valueStart)
        }
      }
      return .unset(lineEnd: header, prefix: "")
    }

    /// Returns the position just after `writable_roots =` when `text`, which runs to `lineEnd`, starts with that assignment.
    private func valueStart(ofKeyIn text: Substring, lineEnd: Int) -> Int? {
      guard text.hasPrefix(CodexSandboxConfig.key) else { return nil }
      let rest = text.dropFirst(CodexSandboxConfig.key.count).trimmingPrefix(while: \.isWhitespace)
      guard rest.hasPrefix("=") else { return nil }
      return lineEnd - rest.count + 1
    }

    /// Returns the name of the standard table that `line` declares, or `nil` when it is not a table header.
    private func tableName(in line: Substring) -> String? {
      guard line.hasPrefix("["), !line.hasPrefix("[["), let close = line.firstIndex(of: "]") else { return nil }
      return line[line.index(after: line.startIndex)..<close].trimmingCharacters(in: .whitespaces)
    }

    /// Returns the start and end, excluding the line break, of every line.
    private func lines() -> [(start: Int, end: Int)] {
      var result: [(Int, Int)] = []
      var start = 0
      for (index, character) in characters.enumerated() where character.isNewline {
        result.append((start, index))
        start = index + 1
      }
      if start < characters.count { result.append((start, characters.count)) }
      return result
    }

    /// Appends a new table that sets the key, separated from any existing settings by a blank line.
    private func appendingTable(with paths: [String]) -> [Character] {
      var text = String(characters)
      while text.last?.isNewline == true { text.removeLast() }
      let separator = text.isEmpty ? "" : "\n\n"
      return Array(text + separator + "[\(CodexSandboxConfig.table)]\n" + keyLine(for: paths) + "\n")
    }

    /// Inserts a line that sets the key, written with `prefix`, after the line that ends at `lineEnd`.
    private func insertingKey(with paths: [String], afterLineEnd lineEnd: Int, prefix: String) -> [Character] {
      var result = characters
      if lineEnd == result.count {
        result.append("\n")
      }
      result.insert(contentsOf: prefix + keyLine(for: paths) + "\n", at: lineEnd + 1)
      return result
    }

    /// Returns a single-line assignment of `paths` to the key.
    private func keyLine(for paths: [String]) -> String {
      "\(CodexSandboxConfig.key) = [" + paths.map(CodexSandboxConfig.quoted).joined(separator: ", ") + "]"
    }

    /// Inserts `missing` at the end of the array, matching its single-line or multi-line layout.
    private func extending(_ array: ParsedArray, with missing: [String]) -> [Character] {
      var result = characters
      let entries = missing.map(CodexSandboxConfig.quoted)
      guard array.isMultiLine else {
        let separator = array.values.isEmpty ? "" : array.hasTrailingComma ? " " : ", "
        result.insert(contentsOf: separator + entries.joined(separator: ", "), at: array.close)
        return result
      }

      let indent = array.lastValueEnd.map(indentation(ofLineContaining:)) ?? "  "
      let closeLineStart = lineStart(of: array.close)
      if characters[closeLineStart..<array.close].allSatisfy(\.isWhitespace) {
        result.insert(contentsOf: entries.map { indent + $0 + ",\n" }.joined(), at: closeLineStart)
      } else {
        result.insert(contentsOf: entries.map { "\n" + indent + $0 + "," }.joined() + "\n", at: array.close)
      }
      if let lastValueEnd = array.lastValueEnd, !array.hasTrailingComma {
        result.insert(",", at: lastValueEnd)
      }
      return result
    }

    /// Returns the position of the first character on the line containing `position`.
    private func lineStart(of position: Int) -> Int {
      var start = position
      while start > 0, !characters[start - 1].isNewline { start -= 1 }
      return start
    }

    /// Returns the leading spaces and tabs of the line containing `position`.
    private func indentation(ofLineContaining position: Int) -> String {
      String(characters[lineStart(of: position)...].prefix { $0 == " " || $0 == "\t" })
    }

    /// Returns `paths` without repeats, in their original order.
    private func unique(_ paths: [String]) -> [String] {
      var seen = Set<String>()
      return paths.filter { seen.insert($0).inserted }
    }
  }
}

extension CodexSandboxConfig.Editor {
  /// Where the configuration sets the writable roots, or where to add them.
  enum KeyLocation {
    /// The key is set, and its value starts at `valueStart`.
    case set(valueStart: Int)

    /// The table exists without the key, which belongs on a new line after `lineEnd`, written with `prefix`.
    case unset(lineEnd: Int, prefix: String)

    /// Neither the table nor the key exists.
    case missing
  }

  /// An array of strings found in the configuration, with the positions needed to extend it.
  struct ParsedArray {
    /// The decoded string values.
    var values: [String] = []

    /// Position just after the last value, if there is one.
    var lastValueEnd: Int?

    /// Whether a comma follows the last value.
    var hasTrailingComma = false

    /// Position of the closing bracket.
    var close = 0

    /// Whether the array spans more than one line.
    var isMultiLine = false
  }

  /// Parses the array of strings that starts, after optional spaces, at `start`.
  func parseArray(from start: Int) throws -> ParsedArray {
    var index = start
    while index < characters.count, characters[index] == " " || characters[index] == "\t" { index += 1 }
    guard index < characters.count, characters[index] == "[" else {
      throw ToolError("\(CodexSandboxConfig.key) is not an array; add the writable roots by hand")
    }

    var array = ParsedArray()
    index += 1
    while index < characters.count {
      let character = characters[index]
      switch character {
        case "]":
          array.close = index
          return array
        case _ where character.isNewline:
          array.isMultiLine = true
          index += 1
        case _ where character.isWhitespace:
          index += 1
        case "#":
          while index < characters.count, !characters[index].isNewline { index += 1 }
        case ",":
          guard array.lastValueEnd != nil, !array.hasTrailingComma else { throw unsupported() }
          array.hasTrailingComma = true
          index += 1
        case "\"", "'":
          guard array.lastValueEnd == nil || array.hasTrailingComma else { throw unsupported() }
          let (value, end) = try parseString(from: index)
          array.values.append(value)
          array.lastValueEnd = end
          array.hasTrailingComma = false
          index = end
        default:
          throw unsupported()
      }
    }
    throw unsupported()
  }

  /// Parses the single-line basic or literal string that starts at `start`, returning its value and end position.
  private func parseString(from start: Int) throws -> (String, Int) {
    let quote = characters[start]
    guard !characters[start...].starts(with: [quote, quote, quote]) else { throw unsupported() }
    var value = ""
    var index = start + 1
    while index < characters.count, !characters[index].isNewline {
      let character = characters[index]
      if character == quote {
        return (value, index + 1)
      }
      if quote == "\"", character == "\\" {
        let (escaped, end) = try parseEscape(from: index + 1)
        value.append(escaped)
        index = end
      } else {
        value.append(character)
        index += 1
      }
    }
    throw unsupported()
  }

  /// Decodes the escape sequence that follows a backslash at `start`, returning the character and end position.
  private func parseEscape(from start: Int) throws -> (Character, Int) {
    guard start < characters.count else { throw unsupported() }
    switch characters[start] {
      case "b": return ("\u{08}", start + 1)
      case "t": return ("\t", start + 1)
      case "n": return ("\n", start + 1)
      case "f": return ("\u{0C}", start + 1)
      case "r": return ("\r", start + 1)
      case "e": return ("\u{1B}", start + 1)
      case "\"": return ("\"", start + 1)
      case "\\": return ("\\", start + 1)
      case "u", "U":
        let length = characters[start] == "u" ? 4 : 8
        let end = start + 1 + length
        guard end <= characters.count,
          let code = UInt32(String(characters[(start + 1)..<end]), radix: 16),
          let scalar = Unicode.Scalar(code)
        else { throw unsupported() }
        return (Character(scalar), end)
      default:
        throw unsupported()
    }
  }

  /// Returns the error for an array this editor cannot read.
  private func unsupported() -> ToolError {
    ToolError("\(CodexSandboxConfig.key) is not a simple array of strings; add the writable roots by hand")
  }
}
