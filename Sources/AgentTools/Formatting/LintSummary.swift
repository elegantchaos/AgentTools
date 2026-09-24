// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Counts the findings in `swift format lint` output, by file and by rule.
struct LintSummary: CustomStringConvertible {
  /// Number of rules named in the description before the rest are counted.
  private static let listedRules = 5

  /// Number of findings.
  let findings: Int
  /// Number of files with findings.
  let files: Int
  /// Findings per rule, most common first, then by name.
  let rules: [(name: String, count: Int)]

  /// Reads findings from lines of the form `path:line:column: error|warning: [Rule] message`.
  init(output: String) {
    var files = Set<String>()
    var rules: [String: Int] = [:]
    var findings = 0
    let pattern = #"^(.+?):\d+:\d+: (?:error|warning): \[([A-Za-z0-9]+)\]"#
    let regex = try? NSRegularExpression(pattern: pattern)
    for line in output.split(separator: "\n").map(String.init) {
      let range = NSRange(line.startIndex..., in: line)
      guard let match = regex?.firstMatch(in: line, range: range),
        let file = Range(match.range(at: 1), in: line),
        let rule = Range(match.range(at: 2), in: line)
      else { continue }
      findings += 1
      files.insert(String(line[file]))
      rules[String(line[rule]), default: 0] += 1
    }
    self.findings = findings
    self.files = files.count
    self.rules = rules.map { (name: $0.key, count: $0.value) }.sorted { ($0.count, $1.name) > ($1.count, $0.name) }
  }

  /// A one-line summary, such as `513 findings in 31 files: Indentation 399, TrailingWhitespace 55`.
  var description: String {
    let listed = rules.prefix(Self.listedRules).map { "\($0.name) \($0.count)" }
    let remaining = rules.count - listed.count
    let more = remaining > 0 ? ", and \(remaining) more rule\(remaining == 1 ? "" : "s")" : ""
    return "\(findings) finding\(findings == 1 ? "" : "s") in \(files) file\(files == 1 ? "" : "s"): \(listed.joined(separator: ", "))\(more)"
  }
}
