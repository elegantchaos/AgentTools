// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser

/// Presses a key combination such as `cmd+n`.
struct UIKeyCommand: AsyncParsableCommand {
  /// Command metadata.
  static let configuration = CommandConfiguration(
    commandName: "key",
    abstract: "Press a key combination, such as cmd+n, return or escape.",
    discussion: "Join modifiers (cmd, shift, option, control, fn) and one key with '+'. Letters and punctuation name keys on a US keyboard."
  )

  /// The combination to press.
  @Argument(help: "Key combination, such as cmd+shift+n.", transform: KeyCombo.init(parsing:))
  var combo: KeyCombo

  /// Posts the key press.
  mutating func run() async throws {
    try await SelfResponsibleRunner.run(task: "post input events") {
      try UIPermission.eventPosting.require()
      try await EventSynthesizer().press(combo)
    }
  }
}
