// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Reads scheme information from `xcodebuild -list -json` output and scheme files.
enum XcodeSchemes {
  /// The container entry of `xcodebuild -list -json` output.
  private struct Container: Decodable {
    /// Scheme names.
    let schemes: [String]
  }

  /// Returns the schemes listed for a workspace, project, or package.
  static func schemes(fromListJSON output: String) throws -> [String] {
    let containers = try JSONDecoder().decode([String: Container].self, from: Data(output.utf8))
    return containers["workspace"]?.schemes ?? containers["project"]?.schemes ?? []
  }

  /// Returns `true` when a scheme file's test action includes at least one test target.
  static func hasTests(schemeFile contents: String) -> Bool {
    contents.contains("<TestableReference")
  }
}
