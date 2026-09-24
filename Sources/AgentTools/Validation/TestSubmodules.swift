// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser

/// When to test local packages that live in git submodules.
enum TestSubmodules: String, Codable, ExpressibleByArgument, CaseIterable {
  /// Test a submodule's packages when it differs from the commit the repository records.
  case changed
  /// Always test submodule packages.
  case always
  /// Never test submodule packages.
  case never
}
