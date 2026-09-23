// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 23/04/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Implements skill discovery, syncing, linking, status, and audit operations.
final class SkillsPublicTool {
  /// Shared file manager used for filesystem operations.
  private let fileManager = FileManager.default

  /// Repository root used as the command working context.
  private let repoRoot: URL

  /// Root directory containing skills in the repository.
  private let skillsRoot: URL

  /// Runtime skill directories that receive links to discovered skills.
  private let linkDestinations: [SkillLinkDestination]

  /// Skill sources that are local to this repository rather than submodules.
  private let repoLocalSkillPaths = ["skills/refresh-skill"]

  /// Creates the tool using environment-driven path overrides when provided.
  convenience init() throws {
    try self.init(
      repoRoot: Self.locateRepoRoot(),
      linkDestinations: SkillLinkDestination.defaults(
        environment: ProcessInfo.processInfo.environment,
        homeDirectory: FileManager.default.homeDirectoryForCurrentUser
      )
    )
  }

  /// Creates a tool with explicit paths for testing or embedding.
  init(repoRoot: URL, linkDestinations: [SkillLinkDestination]) {
    self.repoRoot = repoRoot
    self.skillsRoot = repoRoot.appendingPathComponent("skills")
    self.linkDestinations = linkDestinations
  }

  /// Resolves the repository root from explicit environment or marker scanning.
  static func locateRepoRoot() throws -> URL {
    try RepoRootLocator.locateRepoRoot(
      environment: ProcessInfo.processInfo.environment,
      currentDirectoryPath: FileManager.default.currentDirectoryPath,
      fileExistsAtPath: FileManager.default.fileExists(atPath:)
    )
  }

  /// Runs a subprocess and captures stdout, stderr, and status.
  private func runProcess(
    _ executable: String,
    arguments: [String],
    currentDirectory: URL? = nil
  ) throws -> CommandResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    if let currentDirectory {
      process.currentDirectoryURL = currentDirectory
    }

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    try process.run()
    process.waitUntilExit()

    let stdout =
      String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
      ?? ""
    let stderr =
      String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
      ?? ""
    return CommandResult(status: process.terminationStatus, stdout: stdout, stderr: stderr)
  }

  /// Executes git in a specific repository directory.
  private func git(_ arguments: [String], in directory: URL) throws -> CommandResult {
    try runProcess("/usr/bin/env", arguments: ["git"] + arguments, currentDirectory: directory)
  }

  /// Creates a directory and all missing parent directories.
  private func makeDirectory(_ url: URL) throws {
    try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
  }

  /// Returns true when a path exists, including broken symlinks.
  private func pathExistsIncludingBrokenSymlink(_ url: URL) -> Bool {
    var info = stat()
    return lstat(url.path, &info) == 0
  }

  /// Returns true when a path is a symbolic link.
  private func isSymlink(_ url: URL) -> Bool {
    var info = stat()
    guard lstat(url.path, &info) == 0 else { return false }
    return (info.st_mode & S_IFMT) == S_IFLNK
  }

  /// Replaces an existing symbolic link, refusing to remove any other kind of path.
  private func replaceSymlink(at destination: URL, with target: URL) throws {
    if pathExistsIncludingBrokenSymlink(destination) {
      guard isSymlink(destination) else {
        throw ToolError(
          "Refusing to replace runtime skill path because it is not a symlink: \(destination.path)"
        )
      }
      try fileManager.removeItem(at: destination)
    }
    try fileManager.createSymbolicLink(at: destination, withDestinationURL: target)
  }

  /// Returns true when the path appears to be a git checkout.
  private func isGitCheckout(_ url: URL) -> Bool {
    fileManager.fileExists(atPath: url.appendingPathComponent(".git").path)
  }

  /// Trims surrounding whitespace and newlines.
  private func trimmed(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Resolves a submodule-relative path to a full URL.
  private func submoduleDirectory(for submodulePath: String) -> URL {
    repoRoot.appendingPathComponent(submodulePath)
  }

  /// Converts an absolute URL to repository-relative output when possible.
  private func relativePath(for url: URL) -> String {
    let repoPath = repoRoot.path + "/"
    let path = url.path
    if path.hasPrefix(repoPath) {
      return String(path.dropFirst(repoPath.count))
    }
    return path
  }

  /// Reads skill submodule paths from .gitmodules.
  private func registeredSubmodulePaths() throws -> [String] {
    let gitmodulesURL = repoRoot.appendingPathComponent(".gitmodules")
    guard fileManager.fileExists(atPath: gitmodulesURL.path) else {
      return []
    }

    let result = try git(
      ["config", "-f", ".gitmodules", "--get-regexp", #"^submodule\..*\.path$"#],
      in: repoRoot
    )
    if result.status != 0 && trimmed(result.stdout).isEmpty {
      return []
    }
    if result.status != 0 {
      throw ToolError(result.stderr.isEmpty ? result.stdout : result.stderr)
    }

    return result.stdout
      .split(separator: "\n")
      .compactMap { line in
        let columns = line.split(
          separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let rawPath = columns.last else { return nil }
        let path = String(rawPath)
        return path.hasPrefix("skills/") ? path : nil
      }
      .sorted()
  }

  /// Finds the first nested directory that contains SKILL.md.
  private func firstSkillDirectory(in directory: URL) throws -> URL? {
    let skillFile = directory.appendingPathComponent("SKILL.md")
    if fileManager.fileExists(atPath: skillFile.path) {
      return directory
    }

    let children = try fileManager.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    )
    let childDirectories =
      children
      .filter { child in
        (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
      }
      .sorted {
        $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent)
          == .orderedAscending
      }

    for child in childDirectories {
      if let match = try firstSkillDirectory(in: child) {
        return match
      }
    }

    return nil
  }

  /// Removes matching quote characters from both ends of a string.
  private func strippedQuotes(_ value: String) -> String {
    guard value.count >= 2 else { return value }
    let first = value.first
    let last = value.last
    if (first == "\"" && last == "\"") || (first == "'" && last == "'") {
      return String(value.dropFirst().dropLast())
    }
    return value
  }

  /// Reads skill front matter and returns the configured runtime name.
  private func readSkillName(at skillFile: URL) throws -> String? {
    let data = try Data(contentsOf: skillFile)
    guard let text = String(data: data, encoding: .utf8) else {
      throw ToolError("Unreadable UTF-8 text in \(relativePath(for: skillFile))")
    }

    let lines = text.components(separatedBy: .newlines)
    guard lines.first == "---" else {
      return nil
    }

    for line in lines.dropFirst() {
      if line == "---" {
        break
      }
      guard line.hasPrefix("name:") else {
        continue
      }
      return strippedQuotes(trimmed(String(line.dropFirst("name:".count))))
    }

    return nil
  }

  /// Discovers one skill from a source path.
  private func discoverSkill(in sourcePath: String, sourceKind: String, requiresGitCheckout: Bool)
    throws -> DiscoveredSkill?
  {
    let sourceDir = submoduleDirectory(for: sourcePath)
    guard fileManager.fileExists(atPath: sourceDir.path) else {
      return nil
    }
    guard !requiresGitCheckout || isGitCheckout(sourceDir) else {
      return nil
    }

    guard let skillDirectory = try firstSkillDirectory(in: sourceDir) else {
      throw ToolError("No SKILL.md found in \(sourcePath)")
    }

    let skillFile = skillDirectory.appendingPathComponent("SKILL.md")
    guard let skillName = try readSkillName(at: skillFile), !skillName.isEmpty else {
      throw ToolError("Missing front matter name in \(relativePath(for: skillFile))")
    }

    return DiscoveredSkill(
      name: skillName,
      sourcePath: sourcePath,
      sourceKind: sourceKind,
      skillDirectory: skillDirectory
    )
  }

  /// Throws if multiple skills resolve to the same runtime name.
  private func ensureUniqueNames(_ pairs: [(name: String, source: String)]) throws {
    var grouped: [String: [String]] = [:]
    for pair in pairs {
      grouped[pair.name, default: []].append(pair.source)
    }

    let duplicates =
      grouped
      .filter { $0.value.count > 1 }
      .sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }

    guard duplicates.isEmpty else {
      let details =
        duplicates
        .map { key, sources in
          "\(key): \(sources.joined(separator: ", "))"
        }
        .joined(separator: "; ")
      throw ToolError("Duplicate skill names detected: \(details)")
    }
  }

  /// Returns all discovered skills from submodules and repo-local sources.
  private func discoveredSkills() throws -> [DiscoveredSkill] {
    var skills: [DiscoveredSkill] = []
    for submodulePath in try registeredSubmodulePaths() {
      if let skill = try discoverSkill(
        in: submodulePath, sourceKind: "submodule", requiresGitCheckout: true)
      {
        skills.append(skill)
      }
    }
    for sourcePath in repoLocalSkillPaths {
      if let skill = try discoverSkill(
        in: sourcePath, sourceKind: "repo-local", requiresGitCheckout: false)
      {
        skills.append(skill)
      }
    }

    try ensureUniqueNames(
      skills.map { skill in
        (name: skill.name, source: relativePath(for: skill.skillDirectory))
      }
    )

    return skills.sorted {
      $0.name.localizedStandardCompare($1.name) == .orderedAscending
    }
  }

  /// Builds runtime link targets from discovered skills.
  private func linkTargets() throws -> [LinkTarget] {
    let targets = try discoveredSkills().map { skill in
      LinkTarget(name: skill.name, directory: skill.skillDirectory)
    }

    try ensureUniqueNames(
      targets.map { target in
        (name: target.name, source: relativePath(for: target.directory))
      }
    )

    return targets.sorted {
      $0.name.localizedStandardCompare($1.name) == .orderedAscending
    }
  }

  /// Returns ahead/behind summary compared to upstream.
  private func readAheadBehind(in directory: URL) throws -> String {
    let upstreamResult = try git(["rev-parse", "--abbrev-ref", "@{upstream}"], in: directory)
    guard upstreamResult.status == 0 else {
      return "n/a"
    }

    let countsResult = try git(
      ["rev-list", "--left-right", "--count", "HEAD...@{upstream}"], in: directory)
    let summary = trimmed(countsResult.stdout)
    guard !summary.isEmpty else {
      return "n/a"
    }

    return
      summary
      .replacingOccurrences(of: "\t", with: "/")
      .replacingOccurrences(of: " ", with: "/")
  }

  /// Returns status for one symlink compared to the expected target.
  private func symlinkStatus(link: URL, target: URL) -> String {
    guard let destination = try? fileManager.destinationOfSymbolicLink(atPath: link.path) else {
      return "mismatch"
    }
    return destination == target.path ? "ok" : "mismatch"
  }

  /// Resolves selected submodule paths for a sync request.
  private func selectedSyncSubmodulePaths(from selection: SkillSelection) throws -> [String] {
    let submodulePaths = try registeredSubmodulePaths()
    switch selection {
      case .all:
        return submodulePaths
      case .some(let arguments):
        guard !arguments.isEmpty else {
          throw ToolError("Pass --all or at least one skill/submodule.")
        }

        let discoveredByName = Dictionary(
          uniqueKeysWithValues: try discoveredSkills()
            .filter { $0.sourceKind == "submodule" }
            .map { ($0.name, $0.sourcePath) }
        )
        var selected: [String] = []
        var seen: Set<String> = []

        for argument in arguments {
          let match: String?
          if let runtimePath = discoveredByName[argument] {
            match = runtimePath
          } else if submodulePaths.contains(argument) {
            match = argument
          } else {
            match = submodulePaths.first {
              URL(fileURLWithPath: $0).lastPathComponent == argument
            }
          }

          guard let resolved = match else {
            throw ToolError("Unknown public skill or submodule: \(argument)")
          }
          if seen.insert(resolved).inserted {
            selected.append(resolved)
          }
        }

        return selected
    }
  }

  /// Resolves selected discovered skills for audit requests.
  private func selectedDiscoveredSkills(from selection: SkillSelection) throws -> [DiscoveredSkill] {
    let allSkills = try discoveredSkills()
    switch selection {
      case .all:
        return allSkills
      case .some(let arguments):
        guard !arguments.isEmpty else {
          throw ToolError("Pass --all or at least one skill.")
        }

        var selected: [DiscoveredSkill] = []
        var seen: Set<String> = []

        for argument in arguments {
          guard
            let skill = allSkills.first(where: {
              $0.name == argument
                || $0.sourcePath == argument
                || URL(fileURLWithPath: $0.sourcePath).lastPathComponent == argument
            })
          else {
            throw ToolError("Unknown skill: \(argument)")
          }

          if seen.insert(skill.name).inserted {
            selected.append(skill)
          }
        }

        return selected
    }
  }

  /// Syncs one or more public skill submodules.
  func runSync(selection: SkillSelection) throws {
    let submodulePaths = try selectedSyncSubmodulePaths(from: selection)
    guard !submodulePaths.isEmpty else { return }

    let result = try git(
      ["submodule", "update", "--init", "--recursive", "--"] + submodulePaths,
      in: repoRoot
    )
    guard result.status == 0 else {
      throw ToolError(result.stderr.isEmpty ? result.stdout : result.stderr)
    }

    for submodulePath in submodulePaths {
      if let skill = try discoverSkill(
        in: submodulePath, sourceKind: "submodule", requiresGitCheckout: true)
      {
        print("\(skill.name): \(relativePath(for: skill.skillDirectory))")
      } else {
        print("\(submodulePath): initialized")
      }
    }
  }

  /// Rebuilds runtime symlinks for all discovered skills in every destination.
  func runLink() throws {
    let targets = try linkTargets()
    for target in targets {
      guard fileManager.fileExists(atPath: target.directory.path) else {
        throw ToolError("Missing skill source for \(target.name): \(target.directory.path)")
      }
    }

    for destination in linkDestinations {
      try makeDirectory(destination.directory)
      for target in targets {
        try replaceSymlink(
          at: destination.directory.appendingPathComponent(target.name),
          with: target.directory
        )
        print("\(destination.label) \(target.name): \(target.directory.path)")
      }
    }
  }

  /// Returns one link status cell per destination for a skill.
  private func linkStatusCells(for skill: DiscoveredSkill) -> String {
    linkDestinations
      .map { destination in
        symlinkStatus(
          link: destination.directory.appendingPathComponent(skill.name),
          target: skill.skillDirectory
        )
      }
      .joined(separator: " | ")
  }

  /// Prints status for all known skill sources and runtime links.
  func runStatus() throws {
    let submodulePaths = try registeredSubmodulePaths()
    let destinationHeaders = linkDestinations.map(\.label).joined(separator: " | ")
    let destinationDividers = linkDestinations.map { _ in "---" }.joined(separator: " | ")
    let destinationPlaceholders = linkDestinations.map { _ in "-" }.joined(separator: " | ")

    print("# Skill Repo Status\n")
    print("Skills root: \(skillsRoot.path)\n")
    print("| Skill | Source | Working Tree | Ahead/Behind | \(destinationHeaders) |")
    print("| --- | --- | --- | --- | \(destinationDividers) |")

    for submodulePath in submodulePaths {
      let submoduleDir = submoduleDirectory(for: submodulePath)
      let discovered = try discoverSkill(
        in: submodulePath, sourceKind: "submodule", requiresGitCheckout: true)
      let skillName =
        discovered?.name ?? URL(fileURLWithPath: submodulePath).lastPathComponent
      let source = discovered.map { relativePath(for: $0.skillDirectory) } ?? submodulePath

      guard isGitCheckout(submoduleDir) else {
        print("| \(skillName) | \(source) | uninitialized | - | \(destinationPlaceholders) |")
        continue
      }

      let dirtyResult = try git(["status", "--short"], in: submoduleDir)
      let workingTree = trimmed(dirtyResult.stdout).isEmpty ? "clean" : "dirty"
      let aheadBehind = try readAheadBehind(in: submoduleDir)
      let linkStatus =
        discovered.map(linkStatusCells(for:))
        ?? linkDestinations.map { _ in "invalid" }.joined(separator: " | ")

      print("| \(skillName) | \(source) | \(workingTree) | \(aheadBehind) | \(linkStatus) |")
    }

    for sourcePath in repoLocalSkillPaths {
      guard
        let skill = try discoverSkill(
          in: sourcePath, sourceKind: "repo-local", requiresGitCheckout: false)
      else {
        continue
      }
      print(
        "| \(skill.name) | \(relativePath(for: skill.skillDirectory)) | repo-local | - | \(linkStatusCells(for: skill)) |"
      )
    }
  }

  /// Classifies a skill directory for publication suitability.
  private func classify(source: URL) throws -> (outcome: String, notes: [String]) {
    let secretRegex = try NSRegularExpression(
      pattern:
        "BEGIN [A-Z ]+PRIVATE KEY|gh[pousr]_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{20,}|AKIA[0-9A-Z]{12,}|ASIA[0-9A-Z]{12,}|client_secret"
    )
    let escapedHome = NSRegularExpression.escapedPattern(
      for: fileManager.homeDirectoryForCurrentUser.path)
    let portabilityRegex = try NSRegularExpression(pattern: escapedHome)
    let localLinkRegex = try NSRegularExpression(
      pattern: "file://|\(escapedHome)|git@github.com:")

    var foundSecrets = false
    var foundPortability = false
    var foundLocalLinks = false

    if let enumerator = fileManager.enumerator(
      at: source,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    ) {
      for case let fileURL as URL in enumerator {
        // Hidden git data should not influence publication checks.
        if fileURL.path.contains("/.git/") {
          enumerator.skipDescendants()
          continue
        }

        let values = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
        if values.isDirectory == true {
          continue
        }

        guard let data = fileManager.contents(atPath: fileURL.path),
          let text = String(data: data, encoding: .utf8)
        else {
          continue
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        if secretRegex.firstMatch(in: text, options: [], range: range) != nil {
          foundSecrets = true
        }
        if portabilityRegex.firstMatch(in: text, options: [], range: range) != nil {
          foundPortability = true
        }
        if localLinkRegex.firstMatch(in: text, options: [], range: range) != nil {
          foundLocalLinks = true
        }
      }
    }

    var notes: [String] = []
    let outcome: String
    if foundSecrets {
      outcome = "not suitable for publication"
      notes.append("secret-like material detected")
    } else if foundPortability || foundLocalLinks {
      outcome = "safe after sanitization"
      if foundPortability {
        notes.append("machine-specific path assumptions detected")
      }
      if foundLocalLinks {
        notes.append("local-only links or SSH transport references detected")
      }
    } else {
      outcome = "safe as-is"
      notes.append("no obvious secret or machine-local patterns detected")
    }

    return (outcome, notes)
  }

  /// Audits selected skills and prints publication readiness results.
  func runAudit(selection: SkillSelection) throws {
    let skills = try selectedDiscoveredSkills(from: selection)

    print("# Public Skill Audit\n")
    print("Source root: \(skillsRoot.path)\n")
    print("| Skill | Source | Outcome | Notes |")
    print("| --- | --- | --- | --- |")

    for skill in skills {
      let result = try classify(source: skill.skillDirectory)
      print(
        "| \(skill.name) | \(relativePath(for: skill.skillDirectory)) | \(result.outcome) | \(result.notes.joined(separator: "; ")) |"
      )
    }
  }
}
