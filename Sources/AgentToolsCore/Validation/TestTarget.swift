// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// A test target that a scheme or test plan runs: its name, and the directory of the package or project holding it.
struct TestTarget: Hashable {
  /// The absolute path of the package directory or `.xcodeproj` that holds the target.
  let container: String

  /// The target's name.
  let name: String

  /// Whether only some of the target's tests run, because the scheme or plan selects or skips individual tests.
  var isFiltered = false
}
