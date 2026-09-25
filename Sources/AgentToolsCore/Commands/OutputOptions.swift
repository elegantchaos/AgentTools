// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser

/// Terminal output options shared by commands that run logged steps.
struct OutputOptions: ParsableArguments {
  /// Output mode.
  @Option(help: "Output mode for step output.")
  var output: ValidateOutputMode = .filtered

  /// Quiet output alias.
  @Flag(help: "Alias for --output quiet.")
  var quiet = false

  /// Raw output alias.
  @Flag(help: "Alias for --output raw.")
  var raw = false

  /// The selected output mode; `--raw` and `--quiet` take precedence over `--output`.
  var mode: ValidateOutputMode {
    raw ? .raw : quiet ? .quiet : output
  }
}
