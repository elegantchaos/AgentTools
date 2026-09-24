// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser

/// Output verbosity modes supported by `agt validate`.
enum ValidateOutputMode: String, ExpressibleByArgument, CaseIterable {
  /// Print selected diagnostics from validation output.
  case filtered
  /// Suppress streamed validation output.
  case quiet
  /// Print raw validation output.
  case raw
}
