// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 16/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation

/// Checks relative Markdown links, and repairs broken ones in historical records with `--fix-history`.
struct LinksCommand: AsyncParsableCommand {
  /// Command metadata.
  static let configuration = CommandConfiguration(
    commandName: "links",
    abstract: "Check relative Markdown links, and point broken ones in historical records at the revision they cited.",
    discussion: """
      Run inside a Git checkout. Scans tracked Markdown files and reports relative links whose target does not exist, \
      exiting non-zero when there are any. Links in fenced code blocks and code spans, absolute URLs, mailto: links and \
      same-document anchors are ignored. Links into a submodule that is not checked out are reported as unverified, \
      not broken.

      --fix-history rewrites broken links in historical records only: the documents under the given paths, or under \
      \(LinksTool.defaultHistoryPaths.joined(separator: " and ")) when none are given. Each becomes a GitHub permalink, built from the \
      origin remote, to the target at the first commit on the current branch where the document carried the link and the \
      target existed. A link that never resolved uses the parent of the commit that removed the target; one whose \
      target never existed is left alone and reported. Broken links in other documents are reported for a person to \
      update. Needs full history, so it refuses a shallow clone.
      """
  )

  /// Whether to repair broken links in historical records.
  @Flag(help: "Rewrite broken links in historical records as permalinks to the revision they cited.")
  var fixHistory = false

  /// Whether to describe repairs without writing them.
  @Flag(help: "With --fix-history, print what would change without changing it.")
  var dryRun = false

  /// Files or folders to treat as historical records.
  @Argument(help: "With --fix-history, the files or folders holding historical records.")
  var paths: [String] = []

  /// Rejects options that only make sense when repairing history.
  func validate() throws {
    guard fixHistory || (!dryRun && paths.isEmpty) else {
      throw ValidationError("--dry-run and paths apply only with --fix-history.")
    }
  }

  /// Prints one line per link and a summary, then fails when broken links remain.
  func run() async throws {
    let tool = LinksTool(directory: FileManager.default.currentDirectoryPath)
    let report = try fixHistory ? tool.fixHistory(paths: paths, dryRun: dryRun) : tool.check()
    for line in report.lines {
      print(line)
    }
    if report.hasBrokenLinks { throw ExitCode.failure }
  }
}
