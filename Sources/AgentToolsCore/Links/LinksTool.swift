// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 16/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Checks a repository's relative Markdown links and, on request, repairs broken ones in historical records.
///
/// A check lists links whose target is missing and links into submodules that are not checked out. History repair
/// applies only to documents under the given paths, by default the journal and reviews folders: each broken link
/// there becomes a GitHub permalink to the target at the revision `LinkingFileHistory` finds for it. Broken links
/// elsewhere are only reported, since a living document should point at the target's current home. The tool reads
/// Git history and the `origin` remote, and writes nothing but the repaired documents.
struct LinksTool {
  /// Folders whose documents are historical records when no paths are given.
  static let defaultHistoryPaths = ["Extras/Journal", "Extras/Reviews"]

  /// Directory the command was run in, anywhere inside the checkout.
  let directory: String

  /// Reports every broken and unverified link, changing nothing.
  func check() throws -> LinksReport {
    try report(findings: LinkChecker(repoPath: root()).findings())
  }

  /// Repairs broken links in the documents under `paths`, which are relative to `directory`; an empty list means
  /// `defaultHistoryPaths` at the root. With `dryRun`, reports the repairs without writing them.
  func fixHistory(paths: [String], dryRun: Bool) throws -> LinksReport {
    let repoPath = try root()
    let git = GitQuery(workingDirectory: repoPath)
    guard try git.output(["rev-parse", "--is-shallow-repository"]).hasPrefix("false") else {
      throw ToolError("This is a shallow clone, so the revisions that links pointed at cannot be found reliably. Run `git fetch --unshallow` first.")
    }
    let prefix = try GitQuery(workingDirectory: directory).output(["rev-parse", "--show-prefix"]).trimmingCharacters(in: .whitespacesAndNewlines)
    let historyPaths =
      try paths.isEmpty
      ? Self.defaultHistoryPaths
      : paths.map { path in
        guard let resolved = RepositoryPath.resolve(path, in: prefix) else { throw ToolError("Path is outside the repository: \(path)") }
        return resolved
      }

    var report = try report(findings: LinkChecker(repoPath: repoPath).findings())
    report.dryRun = dryRun
    let historical = report.broken.filter { finding in historyPaths.contains { RepositoryPath.contains(finding.file, in: $0) } }
    guard !historical.isEmpty else { return report }
    report.broken.removeAll { historical.contains($0) }

    let remote = try GitHubRemote(url: git.output(["remote", "get-url", "origin"]))
    for (file, findings) in Dictionary(grouping: historical, by: \.file).sorted(by: { $0.key < $1.key }) {
      var history = try LinkingFileHistory(file: file, git: git)
      var permalinks: [String: String] = [:]
      for finding in findings {
        if let resolution = try history.resolution(for: finding.link) {
          let url = remote.permalink(to: resolution, fragment: finding.link.fragment)
          permalinks[finding.link.destination] = url
          report.repairs.append(LinkRepair(finding: finding, outcome: .permalink(url: url, resolution: resolution)))
        } else {
          report.repairs.append(LinkRepair(finding: finding, outcome: .unresolved))
        }
      }
      if !dryRun, !permalinks.isEmpty {
        try rewrite(URL(fileURLWithPath: repoPath).appending(path: file), replacing: permalinks)
      }
    }
    return report
  }

  /// Returns the root of the checkout holding `directory`.
  private func root() throws -> String {
    try GitQuery(workingDirectory: directory).output(["rev-parse", "--show-toplevel"]).trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Sorts findings into a report's broken and unverified lists.
  private func report(findings: [LinkFinding]) -> LinksReport {
    LinksReport(broken: findings.filter { $0.problem == .broken }, unverified: findings.filter { $0.problem != .broken })
  }

  /// Replaces each link destination in a document that has a permalink, leaving link text and titles as written.
  private func rewrite(_ document: URL, replacing permalinks: [String: String]) throws {
    var text = try String(contentsOf: document, encoding: .utf8)
    // Later links are replaced first, so the ranges of earlier ones stay valid.
    for link in MarkdownLinkScanner.links(in: text).reversed() {
      if let url = permalinks[link.destination] {
        text.replaceSubrange(link.range, with: url)
      }
    }
    try text.write(to: document, atomically: true, encoding: .utf8)
  }
}
