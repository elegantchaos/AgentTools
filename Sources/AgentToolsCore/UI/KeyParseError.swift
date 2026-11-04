// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// A failure to parse a key combination or set of modifiers, naming the text at fault.
enum KeyParseError: Error, Equatable, CustomStringConvertible {
  /// The text, or one of its `+`-separated components, is empty.
  case empty(String)

  /// A component before the key is not a modifier name.
  case unknownModifier(String)

  /// The final component is not a key name.
  case unknownKey(String)

  /// A message for the command line.
  var description: String {
    switch self {
      case .empty(let text): "'\(text)' has an empty key or modifier; join names with '+', as in cmd+shift+n."
      case .unknownModifier(let name): "'\(name)' is not a modifier; use cmd, shift, option, control or fn."
      case .unknownKey(let name): "'\(name)' is not a key name; use a letter, digit, punctuation mark, or a name such as return, escape, tab, space, delete, left or f1."
    }
  }
}
