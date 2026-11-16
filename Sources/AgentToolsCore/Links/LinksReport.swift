// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 16/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// The result of one `agt links` run: what is still wrong, and what history repair did or would do.
struct LinksReport: Equatable {
  /// Broken links that were not offered for repair.
  var broken: [LinkFinding] = []

  /// Links into submodules that are not checked out.
  var unverified: [LinkFinding] = []

  /// Broken links in historical records, with the outcome of looking for each in history.
  var repairs: [LinkRepair] = []

  /// Whether repairs were only described, leaving the files unchanged.
  var dryRun = false

  /// Whether broken links remain in the checkout after the run.
  var hasBrokenLinks: Bool {
    !broken.isEmpty || repairs.contains { $0.outcome == .unresolved || dryRun }
  }

  /// One line per link, followed by a summary.
  var lines: [String] {
    var lines = broken.map { "broken      \($0.location)  \($0.link.destination)" }
    for finding in unverified {
      guard case .unverified(let submodule) = finding.problem else { continue }
      lines.append("unverified  \(finding.location)  \(finding.link.destination)  (submodule \(submodule) is not checked out)")
    }
    for repair in repairs {
      let link = "\(repair.finding.location)  \(repair.finding.link.destination)"
      switch repair.outcome {
        case .permalink(_, let resolution):
          let basis = resolution.basis == .introduced ? "the commit that introduced the link" : "fallback: the parent of the commit that removed the target"
          lines.append("\(dryRun ? "would fix" : "fixed")   \(link)  ->  \(resolution.commit) \(resolution.path)  (\(basis))")
        case .unresolved:
          lines.append("unresolved  \(link)  (the target never existed on this branch)")
      }
    }
    let fixed = repairs.count { $0.outcome != .unresolved }
    let unresolved = repairs.count - fixed
    var summary = ["\(broken.count + unresolved) broken", "\(unverified.count) unverified"]
    if !repairs.isEmpty { summary.append("\(fixed) \(dryRun ? "fixable" : "fixed")") }
    return lines + [summary.joined(separator: ", ")]
  }
}
