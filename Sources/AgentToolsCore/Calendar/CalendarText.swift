// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// Reduces calendar text to one short line before it leaves `agt`.
///
/// Calendar text can come from anyone who sends an invitation, so it is treated as untrusted. Line breaks would let it
/// pose as extra output lines, and control characters could drive a terminal, so both are removed, and the length is
/// capped.
enum CalendarText {
  /// The longest text, in characters, that `agt calendar` prints for one field.
  static let maximumLength = 80

  /// Returns `text` on one line: whitespace runs become single spaces, control characters are dropped, and text longer
  /// than `maximumLength` is cut, ending with an ellipsis.
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
    guard result.count > maximumLength else { return result }
    return String(result.prefix(maximumLength - 1)) + "…"
  }
}
