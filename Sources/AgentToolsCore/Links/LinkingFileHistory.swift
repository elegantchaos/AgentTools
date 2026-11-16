// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 16/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// The commits that changed one document, with the path it had at each, used to find the revision a broken link in
/// it once pointed at.
///
/// Built from `git log --follow` on the current branch, so renames of the document are followed and only commits
/// reachable from HEAD are offered. Needs full history: the caller refuses shallow clones before building one.
/// Link destinations found at each revision are cached, so resolving many links in one document reads each
/// revision once.
struct LinkingFileHistory {
  /// Queries the checkout's Git history.
  private let git: GitQuery

  /// The document's revisions, oldest first.
  private let revisions: [Revision]

  /// Link destinations in the document at each revision, by index into `revisions`.
  private var destinations: [Int: Set<String>] = [:]

  /// Reads the history of `file`, a root-relative path, in the checkout `git` queries.
  init(file: String, git: GitQuery) throws {
    // `--reverse` stops `--follow` tracking renames, so the log is read newest first and reversed here.
    let log = try git.output(["log", "--follow", "--format=%x01%H", "--name-status", "-z", "--", file])
    var revisions: [Revision] = []
    var current = file
    for record in log.split(separator: "\u{01}") {
      let fields = record.split(separator: "\0").map { $0.drop(while: \.isNewline) }
      guard let commit = fields.first else { continue }
      // A rename lists the old path then the new one; every other status lists the path alone.
      let renamedFrom = fields.count == 4 ? String(fields[2]) : nil
      revisions.append(Revision(commit: String(commit), path: fields.count > 2 ? String(fields[fields.count - 1]) : current))
      current = renamedFrom ?? revisions[revisions.count - 1].path
    }
    self.git = git
    self.revisions = revisions.reversed()
  }

  /// Returns the revision `link` should point at, or `nil` when its target never existed.
  ///
  /// Prefers the first commit where the document carried the link and the target existed at the path the link then
  /// resolved to. Otherwise falls back to the parent of the commit that removed the target.
  mutating func resolution(for link: MarkdownLink) throws -> LinkResolution? {
    for (index, revision) in revisions.enumerated() {
      guard try destinations(at: index).contains(link.destination), let path = link.repositoryPath(from: revision.path) else { continue }
      if let isDirectory = try kind(of: path, at: revision.commit) {
        return LinkResolution(commit: revision.commit, path: path, isDirectory: isDirectory, basis: .introduced)
      }
    }
    var tried: Set<String> = []
    for revision in revisions.reversed() {
      guard let path = link.repositoryPath(from: revision.path), !path.isEmpty, tried.insert(path).inserted else { continue }
      let removal = try git.output(["log", "-1", "--diff-filter=D", "--format=%H", "--", path]).trimmingCharacters(in: .whitespacesAndNewlines)
      guard !removal.isEmpty, let parent = try git.outputIfSuccessful(["rev-parse", "--verify", "--quiet", "\(removal)^"]) else { continue }
      let commit = parent.trimmingCharacters(in: .whitespacesAndNewlines)
      if let isDirectory = try kind(of: path, at: commit) {
        return LinkResolution(commit: commit, path: path, isDirectory: isDirectory, basis: .beforeRemoval)
      }
    }
    return nil
  }

  /// Returns the link destinations in the document at a revision, reading it on first use.
  private mutating func destinations(at index: Int) throws -> Set<String> {
    if let known = destinations[index] { return known }
    let revision = revisions[index]
    let text = try git.outputIfSuccessful(["show", "\(revision.commit):\(revision.path)"]) ?? ""
    let found = Set(MarkdownLinkScanner.links(in: text).map(\.destination))
    destinations[index] = found
    return found
  }

  /// Returns whether `path` is a directory in `commit`, or `nil` when nothing exists there.
  private func kind(of path: String, at commit: String) throws -> Bool? {
    guard !path.isEmpty else { return true }
    return try git.outputIfSuccessful(["cat-file", "-t", "\(commit):\(path)"]).map { $0.hasPrefix("tree") }
  }
}

extension LinkingFileHistory {
  /// One commit that changed the document.
  private struct Revision {
    /// Full hash of the commit.
    let commit: String

    /// Root-relative path of the document in that commit.
    let path: String
  }
}
