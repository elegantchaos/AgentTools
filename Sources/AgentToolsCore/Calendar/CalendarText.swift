// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Reduces calendar text to one short line before it leaves `agt`.
///
/// Calendar text can come from anyone who sends an invitation, so it is treated as untrusted. Line breaks would let it
/// pose as extra output lines, and control characters could drive a terminal, so both are removed. Links can carry
/// passwords, as meeting links in a location often do, so they are replaced. The length is capped last, so that a
/// link is never left partly visible.
enum CalendarText {
  /// The longest text, in characters, that `agt calendar` prints for one field.
  static let maximumLength = 80

  /// What is printed in place of a link.
  static let linkPlaceholder = "[link]"

  /// Finds links, with or without a scheme.
  private static let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

  /// Returns `text` on one line: whitespace runs become single spaces, control characters are dropped, links are
  /// replaced, and text longer than `maximumLength` is cut, ending with an ellipsis.
  static func singleLine(_ text: String) -> String {
    var result = ""
    var pendingSpace = false
    for character in text {
      if character.isWhitespace {
        pendingSpace = !result.isEmpty
      } else if !character.unicodeScalars.contains(where: { $0.properties.generalCategory == .control }) {
        if pendingSpace {
          result.append(" ")
          pendingSpace = false
        }
        result.append(character)
      }
    }
    result = withoutLinks(result)
    guard result.count > maximumLength else { return result }
    return String(result.prefix(maximumLength - 1)) + "…"
  }

  /// Returns `text` with each link replaced, or nothing at all if links cannot be looked for.
  private static func withoutLinks(_ text: String) -> String {
    guard let linkDetector else { return "" }
    var result = text
    let matches = linkDetector.matches(in: text, range: NSRange(text.startIndex..., in: text))
    for match in matches.reversed() {
      if let range = Range(match.range, in: result) {
        result.replaceSubrange(range, with: linkPlaceholder)
      }
    }
    return result
  }
}
