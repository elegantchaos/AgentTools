// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 29/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// Preserves a dependency metadata denial through discovery paths that otherwise skip unreadable packages.
struct DependencyPermissionError: Error, CustomStringConvertible {
  /// Original diagnostic and actionable preparation advice.
  let description: String
}
