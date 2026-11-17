// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 16/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// The commits that changed one document, with the path it had at each, used to find the revision a broken link in
/// it once pointed at.
///
/// Built from `git log --follow` on the current branch, so renames of the document are followed and only commits
/// reachable from HEAD are offered. Needs full history: the caller refuses shallow clones before building one.
/// The links found at each revision are cached, so resolving many links in one document reads each revision once.
struct LinkingFileHistory {
  /// Queries the checkout's Git history.
  private let git: GitQuery

  /// Root-relative path of the document now.
  private let file: String

  /// The document's revisions, oldest first.
  private let revisions: [Revision]

  /// The document's links at each revision, by index into `revisions`.
  private var links: [Int: RevisionLinks] = [:]

  /// Target additions, oldest first, cached by path for links whose target was absent at a document edit.
  private var additions: [String: [String]] = [:]

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
    self.file = file
    self.revisions = revisions.reversed()
  }

  /// Returns the revision `link` should point at, or `nil` when its target never existed.
  ///
  /// Prefers the first commit where the document carried the link and the target existed at the path the link then
  /// resolved to. The document carried the link when it held the same destination text, which may have named a
  /// different path if the document has moved, or a link to the same path under another spelling, as happens when
  /// links are adjusted for a move. Otherwise falls back to the parent of the commit that removed the target.
  mutating func resolution(for link: MarkdownLink) throws -> LinkResolution? {
    let currentPath = link.repositoryPath(from: file)
    for (index, revision) in revisions.enumerated() {
      let links = try links(at: index)
      var candidates: [String] = []
      if links.destinations.contains(link.destination), let path = link.repositoryPath(from: revision.path) { candidates.append(path) }
      if let currentPath, links.paths.contains(currentPath) { candidates.append(currentPath) }
      for path in candidates {
        if let isDirectory = try kind(of: path, at: revision.commit) {
          return LinkResolution(commit: revision.commit, path: path, isDirectory: isDirectory, basis: .introduced)
        }
        let next = index + 1 < revisions.count ? revisions[index + 1].commit : nil
        if let resolution = try firstAddition(of: path, after: revision, before: next, carrying: link) {
          return resolution
        }
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

  /// Finds when a missing target first appeared while this document revision still carried its link.
  private mutating func firstAddition(of path: String, after revision: Revision, before next: String?, carrying link: MarkdownLink) throws -> LinkResolution? {
    if additions[path] == nil {
      // Include merges against each parent: a merge can first bring the target together with the document.
      // Renames into this path are additions too; a directory appears when its first child is added.
      additions[path] = try git.output(["log", "--reverse", "--topo-order", "--full-history", "-m", "--no-renames", "--diff-filter=A", "--format=%H", "--", path])
        .split(whereSeparator: \.isNewline).map(String.init)
    }
    for commit in additions[path] ?? [] {
      guard try git.outputIfSuccessful(["merge-base", "--is-ancestor", revision.commit, commit]) != nil else { continue }
      if let next, try git.outputIfSuccessful(["merge-base", "--is-ancestor", next, commit]) != nil { continue }
      guard let text = try git.outputIfSuccessful(["show", "\(commit):\(revision.path)"]) else { continue }
      let carriesLink = MarkdownLinkScanner.links(in: text).contains {
        if $0.destination == link.destination { return true }
        guard let currentPath = link.repositoryPath(from: file) else { return false }
        return $0.repositoryPath(from: revision.path) == currentPath
      }
      if carriesLink, let isDirectory = try kind(of: path, at: commit) {
        return LinkResolution(commit: commit, path: path, isDirectory: isDirectory, basis: .introduced)
      }
    }
    return nil
  }

  /// Returns the document's links at a revision, reading it on first use.
  private mutating func links(at index: Int) throws -> RevisionLinks {
    if let known = links[index] { return known }
    let revision = revisions[index]
    let text = try git.outputIfSuccessful(["show", "\(revision.commit):\(revision.path)"]) ?? ""
    let found = MarkdownLinkScanner.links(in: text)
    let result = RevisionLinks(destinations: Set(found.map(\.destination)), paths: Set(found.compactMap { $0.repositoryPath(from: revision.path) }))
    links[index] = result
    return result
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

extension LinkingFileHistory {
  /// The links the document held at one revision.
  private struct RevisionLinks {
    /// Their destinations as written.
    let destinations: Set<String>

    /// The root-relative paths they named from the document's location at that revision.
    let paths: Set<String>
  }
}
