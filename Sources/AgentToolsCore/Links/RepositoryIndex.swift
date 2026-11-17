// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 16/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// The paths present in a checkout, taken from Git so that matching is case-exact on any file system.
///
/// Holds tracked and untracked-but-not-ignored files that are still on disk, the directories containing them, and
/// the submodule paths. `LinkChecker` asks it which Markdown files to scan and whether a link's target exists.
struct RepositoryIndex {
  /// Tracked Markdown files, sorted.
  let markdownFiles: [String]

  /// Every file present in the checkout.
  private let files: Set<String>

  /// Every directory that holds a present file.
  private let directories: Set<String>

  /// Paths of the checkout's submodules.
  private let submodules: [String]

  /// Each initialised submodule's own case-exact index, including its nested submodules.
  private let checkedOutSubmodules: [String: RepositoryIndex]

  /// Reads the index and working tree state of the checkout at `repoPath`.
  init(repoPath: String) throws {
    let git = GitQuery(workingDirectory: repoPath)
    let deleted = Set(Self.paths(try git.output(["ls-files", "-z", "--deleted"])))
    var tracked: [String] = []
    var submodules: [String] = []
    for entry in Self.paths(try git.output(["ls-files", "-z", "--stage"])) {
      guard let tab = entry.firstIndex(of: "\t") else { continue }
      let path = String(entry[entry.index(after: tab)...])
      if entry.hasPrefix("160000 ") {
        submodules.append(path)
      } else if !deleted.contains(path) {
        tracked.append(path)
      }
    }
    let files = Set(tracked).union(Self.paths(try git.output(["ls-files", "-z", "--others", "--exclude-standard"])))
    var directories: Set<String> = []
    for file in files.union(submodules) {
      var directory = RepositoryPath.directory(of: file)
      while !directory.isEmpty, directories.insert(directory).inserted {
        directory = RepositoryPath.directory(of: directory)
      }
    }
    var checkedOutSubmodules: [String: RepositoryIndex] = [:]
    for submodule in submodules {
      let checkout = URL(fileURLWithPath: repoPath).appending(path: submodule)
      if FileManager.default.fileExists(atPath: checkout.appending(path: ".git").path) {
        checkedOutSubmodules[submodule] = try RepositoryIndex(repoPath: checkout.path)
      }
    }
    self.markdownFiles = Set(tracked).filter { $0.lowercased().hasSuffix(".md") || $0.lowercased().hasSuffix(".markdown") }.sorted()
    self.files = files
    self.directories = directories
    self.submodules = submodules
    self.checkedOutSubmodules = checkedOutSubmodules
  }

  /// Reports whether a root-relative path exists; the empty string is the root.
  func presence(of path: String) -> Presence {
    if path.isEmpty || files.contains(path) || directories.contains(path) { return .present }
    guard let submodule = submodules.first(where: { RepositoryPath.contains(path, in: $0) }) else { return .missing }
    if path == submodule { return .present }
    guard let index = checkedOutSubmodules[submodule] else { return .unverified(submodule: submodule) }
    switch index.presence(of: String(path.dropFirst(submodule.count + 1))) {
      case .present: return .present
      case .missing: return .missing
      case .unverified(let nested): return .unverified(submodule: submodule + "/" + nested)
    }
  }

  /// Splits NUL-separated Git output into its entries.
  private static func paths(_ output: String) -> [String] {
    output.split(separator: "\0").map(String.init)
  }
}

extension RepositoryIndex {
  /// Whether a path exists in the checkout.
  enum Presence: Equatable {
    /// The path is a file or directory in the checkout.
    case present

    /// Nothing exists at the path.
    case missing

    /// The path is inside a submodule that is not checked out, so its existence is unknown.
    case unverified(submodule: String)
  }
}
