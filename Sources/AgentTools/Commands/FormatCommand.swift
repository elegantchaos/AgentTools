// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation

/// Formats and lints every Swift file in the repository in the current directory.
struct FormatCommand: ParsableCommand {
  /// Command metadata.
  static let configuration = CommandConfiguration(
    commandName: "format",
    abstract: "Format and lint every Swift file in a repository.",
    discussion: """
      Run from the repository root. Formats every tracked and untracked, non-ignored Swift file in place with \
      swift format, then lints them and reports any findings without failing. Swift files inside a Resources \
      directory under Tests are treated as fixtures and skipped; other files can opt out with a \
      `// swift-format-ignore-file` comment. With --check, modifies nothing and fails on any finding.
      """
  )

  /// Whether to lint strictly without modifying files.
  @Flag(help: "Lint without modifying files, failing on any finding.")
  var check = false

  /// Terminal output options.
  @OptionGroup var output: OutputOptions

  /// Executes formatting in the current directory.
  mutating func run() throws {
    try FormatTool(repoPath: FileManager.default.currentDirectoryPath, check: check, outputMode: output.mode).run()
  }
}
