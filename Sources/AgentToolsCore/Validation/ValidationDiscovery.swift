// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Locates the Xcode workspaces, projects, and Swift packages that validation should build.
enum ValidationDiscovery {
  /// Resolves a CLI path that may be absolute, home-relative, or repo-relative.
  static func resolvePath(_ value: String, repoPath: String) -> String {
    let expanded = NSString(string: value).expandingTildeInPath
    if expanded.hasPrefix("/") {
      return URL(fileURLWithPath: expanded).standardizedFileURL.path
    }
    return URL(fileURLWithPath: repoPath).appendingPathComponent(expanded).standardizedFileURL.path
  }

  /// Returns the main repository's directory name, used as the default scheme and container name.
  /// Linked worktrees follow Git's gitdir and commondir files so a semantic worktree name cannot change the scheme.
  static func repoName(_ repoPath: String) -> String {
    let repo = URL(fileURLWithPath: repoPath, isDirectory: true)
    if let pointer = try? String(contentsOf: repo.appendingPathComponent(".git"), encoding: .utf8), pointer.hasPrefix("gitdir: ") {
      let gitDir = URL(fileURLWithPath: String(pointer.dropFirst("gitdir: ".count)).trimmingCharacters(in: .whitespacesAndNewlines), isDirectory: true, relativeTo: repo)
      if let common = try? String(contentsOf: gitDir.appendingPathComponent("commondir"), encoding: .utf8) {
        let directory = URL(fileURLWithPath: common.trimmingCharacters(in: .whitespacesAndNewlines), isDirectory: true, relativeTo: gitDir).standardizedFileURL
        if directory.lastPathComponent == ".git" {
          return directory.deletingLastPathComponent().lastPathComponent
        }
      }
    }
    return repo.lastPathComponent
  }

  /// Returns the explicit workspace when valid, or the repository's workspace, preferring one named after the repository.
  static func workspace(override: String?, repoPath: String) -> String? {
    container(override: override, suffix: ".xcworkspace", marker: "contents.xcworkspacedata", repoPath: repoPath)
  }

  /// Returns the explicit project when valid, or the repository's project, preferring one named after the repository.
  static func project(override: String?, repoPath: String) -> String? {
    container(override: override, suffix: ".xcodeproj", marker: "project.pbxproj", repoPath: repoPath)
  }

  /// Returns `true` when a repository-relative path lies inside a `Resources` directory under `Tests`, where fixtures live.
  static func isInTestResources(_ path: String) -> Bool {
    let parts = path.split(separator: "/").map { $0.lowercased() }
    guard let testsIndex = parts.firstIndex(of: "tests") else { return false }
    return parts[(testsIndex + 1)...].contains("resources")
  }

  /// Returns the package directories to validate.
  ///
  /// Explicit overrides are used as given, even when Git ignores them. Otherwise the repository root and
  /// `Dependencies/Core` are checked, followed by a recursive search that skips hidden directories, DerivedData, and
  /// test resources. Packages whose manifests Git ignore rules match are skipped in both.
  static func packageDirectories(repoPath: String, overrides: [String]?, recursive: Bool) -> [String] {
    var ordered: [String] = []
    var seen = Set<String>()

    func addPackageDir(_ candidate: String) {
      let resolved = resolvePath(candidate, repoPath: repoPath)
      guard fileExists("\(resolved)/Package.swift") else { return }
      if seen.insert(resolved).inserted {
        ordered.append(resolved)
      }
    }

    if let overrides, !overrides.isEmpty {
      overrides.forEach(addPackageDir)
      return ordered
    }

    let defaults = [(manifest: "Package.swift", directory: repoPath), (manifest: "Dependencies/Core/Package.swift", directory: "Dependencies/Core")]
    let ignoredDefaults = ignoredPaths(defaults.map(\.manifest), repoPath: repoPath)
    for (manifest, directory) in defaults where !ignoredDefaults.contains(manifest) {
      addPackageDir(directory)
    }

    guard recursive else { return ordered }
    func isManifest(_ file: URL) -> Bool { file.lastPathComponent == "Package.swift" }
    walk(repoPath, matching: isManifest) { _, file in
      addPackageDir(file.deletingLastPathComponent().path)
    }
    return ordered
  }

  /// Returns the packages reachable from `roots` through local path dependencies, including the roots.
  static func productPackages(roots: [String], localDependencies: [String: [String]]) -> Set<String> {
    var reached = Set<String>()
    var pending = roots
    while let next = pending.popLast() {
      guard reached.insert(next).inserted else { continue }
      pending.append(contentsOf: localDependencies[next] ?? [])
    }
    return reached
  }

  /// Returns the directories of the packages a workspace or project references, resolved against their files.
  static func referencedPackages(container: [String]) -> [String] {
    guard container.count == 2 else { return [] }
    let path = container[1]
    let directory = URL(fileURLWithPath: path).deletingLastPathComponent()
    if container[0] == "-project" {
      guard let contents = try? String(contentsOfFile: "\(path)/project.pbxproj", encoding: .utf8) else { return [] }
      return XcodeSchemes.localPackagePaths(fromProjectFile: contents).map { directory.appendingPathComponent($0).standardizedFileURL.path }
    }
    guard let contents = try? String(contentsOfFile: "\(path)/contents.xcworkspacedata", encoding: .utf8) else { return [] }
    return XcodeSchemes.memberPaths(fromWorkspaceData: contents).flatMap { member -> [String] in
      let memberURL = member.hasPrefix("/") ? URL(fileURLWithPath: member) : directory.appendingPathComponent(member)
      let memberPath = memberURL.standardizedFileURL.path
      return member.hasSuffix(".xcodeproj") ? referencedPackages(container: ["-project", memberPath]) : [memberPath]
    }
  }

  /// Returns whether `packageDir` is the package `xcodebuild` opens directly: the repository's package, when there is
  /// no workspace or project.
  ///
  /// Xcode gives a package's generated schemes a test action only when it opens that package directly. In a
  /// workspace, even as a member, they are build-only; the package's tests run there only when a shared scheme or test
  /// plan lists them.
  static func isOpenedDirectly(packageDir: String, container: [String], repoPath: String) -> Bool {
    container.isEmpty && ValidationPaths.canonical(packageDir) == ValidationPaths.canonical(repoPath)
  }

  /// Returns whether a shared scheme with `tests` can test the package in `packageDir` on its own: the package is a
  /// workspace member, and the scheme runs every test of each of its `testTargets`.
  static func schemeTestsPackage(_ tests: SchemeTests?, packageDir: String, testTargets: [String], workspaceMembers: Set<String>) -> Bool {
    guard let tests, Set(workspaceMembers.map(ValidationPaths.canonical)).contains(ValidationPaths.canonical(packageDir)) else { return false }
    return tests.runsAllTests(testTargets, in: packageDir)
  }

  /// Returns the directories of the packages a workspace lists as members, which are the only packages whose tests
  /// Xcode runs when a workspace scheme or test plan lists them. A project, or no container, has none.
  static func workspaceMemberPackages(container: [String]) -> [String] {
    guard container.count == 2, container[0] == "-workspace",
      let contents = try? String(contentsOfFile: "\(container[1])/contents.xcworkspacedata", encoding: .utf8)
    else { return [] }
    let directory = URL(fileURLWithPath: container[1]).deletingLastPathComponent()
    return XcodeSchemes.memberPaths(fromWorkspaceData: contents).filter { !$0.hasSuffix(".xcodeproj") }.map { member in
      (member.hasPrefix("/") ? URL(fileURLWithPath: member) : directory.appendingPathComponent(member)).standardizedFileURL.path
    }
  }

  /// Returns the paths of the files whose contents determine discovery's results: package manifests and resolved
  /// dependencies, Xcode workspaces and projects, and their shared and user schemes.
  ///
  /// Paths are repository-relative, except for the manifests of `overrides` outside the repository, which are
  /// absolute. Overridden packages' manifests are included even when Git ignores them, because discovery uses them.
  static func fingerprintFiles(repoPath: String, overrides: [String]? = nil) -> [String] {
    func isManifest(_ name: String) -> Bool {
      name == "Package.swift" || name == "Package.resolved" || (name.hasPrefix("Package@swift-") && name.hasSuffix(".swift"))
    }
    func isDiscoveryInput(_ file: URL) -> Bool {
      let name = file.lastPathComponent
      return isManifest(name) || name == "project.pbxproj" || name == "contents.xcworkspacedata" || name.hasSuffix(".xcscheme")
    }
    var files: [String] = []
    walk(repoPath, matching: isDiscoveryInput) { relativePath, _ in
      files.append(relativePath)
    }
    let repo = ValidationPaths.canonical(repoPath)
    for directory in overrides ?? [] {
      let resolved = resolvePath(directory, repoPath: repoPath)
      let names = (try? FileManager.default.contentsOfDirectory(atPath: resolved)) ?? []
      for name in names where isManifest(name) {
        let path = ValidationPaths.canonical("\(resolved)/\(name)")
        let file = path.hasPrefix("\(repo)/") ? String(path.dropFirst(repo.count + 1)) : path
        if !files.contains(file) {
          files.append(file)
        }
      }
    }
    return files
  }

  /// Visits every relevant file in the repository with its repository-relative path, skipping hidden directories,
  /// DerivedData, test resources, and paths that Git ignore rules match, even when Git tracks them.
  private static func walk(_ repoPath: String, matching isRelevant: (URL) -> Bool, visit: (String, URL) -> Void) {
    var found: [(String, URL)] = []
    func walk(_ directory: URL, relativePath: String) {
      guard let contents = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
      for child in contents {
        let childPath = relativePath.isEmpty ? child.lastPathComponent : "\(relativePath)/\(child.lastPathComponent)"
        if isExcluded(childPath) || isInTestResources(childPath) {
          continue
        }
        if isDirectory(child.path) {
          walk(child, relativePath: childPath)
        } else if isRelevant(child) {
          found.append((childPath, child))
        }
      }
    }
    walk(URL(fileURLWithPath: repoPath), relativePath: "")
    let ignored = ignoredPaths(found.map(\.0), repoPath: repoPath)
    for (relativePath, file) in found where !ignored.contains(relativePath) {
      visit(relativePath, file)
    }
  }

  /// Returns the repository-relative `paths` that the repository's Git ignore rules match, whether or not Git tracks
  /// them. Outside a Git repository, or if Git fails, none are ignored.
  ///
  /// Paths are exchanged NUL-separated, so Git does not quote unusual names. Without the index, Git also checks paths
  /// inside submodules against the repository's own rules instead of rejecting them.
  static func ignoredPaths(_ paths: [String], repoPath: String) -> Set<String> {
    guard !paths.isEmpty else { return [] }
    let input = Data(paths.map { "\($0)\0" }.joined().utf8)
    guard let result = try? ValidationProcess(workingDirectory: repoPath).capture(["git", "check-ignore", "--no-index", "--stdin", "-z"], input: input),
      result.status == 0
    else { return [] }
    return Set(result.stdout.split(separator: "\0").map(String.init))
  }

  /// Resolves an Xcode container from an override or by searching the repository root.
  private static func container(override: String?, suffix: String, marker: String, repoPath: String) -> String? {
    func isValid(_ path: String) -> Bool {
      isDirectory(path) && fileExists("\(path)/\(marker)")
    }

    if let override {
      let resolved = resolvePath(override, repoPath: repoPath)
      return isValid(resolved) ? resolved : nil
    }

    let preferred = "\(repoPath)/\(repoName(repoPath))\(suffix)"
    if isValid(preferred) { return preferred }

    let entries = (try? FileManager.default.contentsOfDirectory(atPath: repoPath)) ?? []
    return
      entries
      .filter { $0.hasSuffix(suffix) }
      .sorted()
      .map { "\(repoPath)/\($0)" }
      .first(where: isValid)
  }

  /// Returns `true` for paths under hidden directories or DerivedData.
  private static func isExcluded(_ path: String) -> Bool {
    let parts = path.split(separator: "/")
    return parts.contains { $0.hasPrefix(".") } || parts.contains("DerivedData")
  }

  /// Returns `true` when a path exists on disk.
  private static func fileExists(_ path: String) -> Bool {
    FileManager.default.fileExists(atPath: path)
  }

  /// Returns `true` when a path exists and is a directory.
  private static func isDirectory(_ path: String) -> Bool {
    var isDir: ObjCBool = false
    return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
  }
}
