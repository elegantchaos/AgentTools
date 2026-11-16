// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 16/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// Normalises slash-separated paths inside a repository.
enum RepositoryPath {
  /// Returns `path` resolved against `directory` as a root-relative path without `.` or `..` components.
  ///
  /// A leading slash makes `path` relative to the repository root, as GitHub renders it. The root itself is the
  /// empty string. Returns `nil` when the path leaves the repository.
  static func resolve(_ path: String, in directory: String) -> String? {
    var components: [Substring] = path.hasPrefix("/") ? [] : directory.split(separator: "/")
    for component in path.split(separator: "/") where component != "." {
      if component == ".." {
        guard components.popLast() != nil else { return nil }
      } else {
        components.append(component)
      }
    }
    return components.joined(separator: "/")
  }

  /// Returns the directory holding `file`, or the empty string for a file at the root.
  static func directory(of file: String) -> String {
    file.lastIndex(of: "/").map { String(file[..<$0]) } ?? ""
  }

  /// Whether `path` is `ancestor` or lies beneath it; the empty string is an ancestor of everything.
  static func contains(_ path: String, in ancestor: String) -> Bool {
    ancestor.isEmpty || path == ancestor || path.hasPrefix(ancestor + "/")
  }
}
