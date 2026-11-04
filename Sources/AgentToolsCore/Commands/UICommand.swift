// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser

/// Parent command for driving a macOS login session: screenshots, input events and the accessibility tree.
struct UICommand: AsyncParsableCommand {
  /// Command metadata and available subcommands.
  static let configuration = CommandConfiguration(
    commandName: "ui",
    abstract: "Drive the macOS GUI: screenshots, clicks, keys and the accessibility tree.",
    discussion: """
      Intended for a disposable test machine or VM, driven over ssh, never the machine you are using: these commands \
      move the real pointer and type into whatever is frontmost. A user must be logged in to the console. \
      Coordinates are screen points from the top left of the main display, as `tree` reports frames and as a \
      display screenshot's pixels lie. macOS grants the permissions these commands need to the process responsible \
      for agt: the terminal or app that started it, or /usr/libexec/sshd-session over ssh. Grant Accessibility for \
      tree, press and input events, and Screen Recording for screenshots; a command that lacks one says which \
      process to allow.
      """,
    subcommands: [
      UIScreenshotCommand.self,
      UITreeCommand.self,
      UIPressCommand.self,
      UIClickCommand.self,
      UIDragCommand.self,
      UIScrollCommand.self,
      UITypeCommand.self,
      UIKeyCommand.self,
      UILaunchCommand.self,
      UIQuitCommand.self,
    ]
  )
}
