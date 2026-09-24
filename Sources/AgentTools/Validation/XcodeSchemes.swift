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

  /// Returns the relative paths of the local Swift packages a project file references.
  static func localPackagePaths(fromProjectFile contents: String) -> [String] {
    let pattern = #"isa = XCLocalSwiftPackageReference;\s*relativePath = ("([^"]*)"|[^;]*);"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    let range = NSRange(contents.startIndex..., in: contents)
    return regex.matches(in: contents, range: range).compactMap { match in
      let quoted = Range(match.range(at: 2), in: contents)
      let plain = Range(match.range(at: 1), in: contents)
      return (quoted ?? plain).map { String(contents[$0]) }
    }
  }

  /// Returns the paths of a workspace's members, such as projects and packages, relative to the workspace's directory.
  static func memberPaths(fromWorkspaceData contents: String) -> [String] {
    guard let regex = try? NSRegularExpression(pattern: #"location = "(?:group|container):([^"]*)""#) else { return [] }
    let range = NSRange(contents.startIndex..., in: contents)
    return regex.matches(in: contents, range: range).compactMap { match in
      Range(match.range(at: 1), in: contents).map { String(contents[$0]) }
    }
  }
}
