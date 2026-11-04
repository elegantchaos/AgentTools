// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser

/// Types text into whatever has keyboard focus.
struct UITypeCommand: AsyncParsableCommand {
  /// Command metadata.
  static let configuration = CommandConfiguration(
    commandName: "type",
    abstract: "Type text into the focused element.",
    discussion: "Sends each character as itself, whatever the keyboard layout. Newlines press Return. Use `agt ui key` for shortcuts."
  )

  /// The text to type.
  @Argument(help: "Text to type.")
  var text: String

  /// Posts the characters.
  mutating func run() async throws {
    try UIPermission.eventPosting.require()
    try await EventSynthesizer().type(text)
  }
}
