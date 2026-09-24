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

  /// Returns the repository directory name, used as the default scheme and container name.
  static func repoName(_ repoPath: String) -> String {
    URL(fileURLWithPath: repoPath).lastPathComponent
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
  /// Explicit overrides are used as given. Otherwise the repository root and `Dependencies/Core` are
  /// checked, followed by a recursive search that skips hidden directories, DerivedData, and test resources.
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

    addPackageDir(repoPath)
    addPackageDir("Dependencies/Core")

    guard recursive else { return ordered }
    walk(repoPath) { relativePath, file in
      if file.lastPathComponent == "Package.swift" {
        addPackageDir(file.deletingLastPathComponent().path)
      }
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
      let memberPath = directory.appendingPathComponent(member).standardizedFileURL.path
      return member.hasSuffix(".xcodeproj") ? referencedPackages(container: ["-project", memberPath]) : [memberPath]
    }
  }

  /// Returns the repository-relative paths of the files whose contents determine discovery's results: package
  /// manifests and resolved dependencies, Xcode workspaces and projects, and their shared and user schemes.
  static func fingerprintFiles(repoPath: String) -> [String] {
    var files: [String] = []
    walk(repoPath) { relativePath, file in
      let name = file.lastPathComponent
      let isManifest = name == "Package.swift" || name == "Package.resolved" || (name.hasPrefix("Package@swift-") && name.hasSuffix(".swift"))
      let isXcodeFile = name == "project.pbxproj" || name == "contents.xcworkspacedata" || name.hasSuffix(".xcscheme")
      if isManifest || isXcodeFile {
        files.append(relativePath)
      }
    }
    return files
  }

  /// Visits every file in the repository with its repository-relative path, skipping hidden directories,
  /// DerivedData, and test resources.
  private static func walk(_ repoPath: String, visit: (String, URL) -> Void) {
    func walk(_ directory: URL, relativePath: String) {
      guard let contents = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
      for child in contents {
        let childPath = relativePath.isEmpty ? child.lastPathComponent : "\(relativePath)/\(child.lastPathComponent)"
        if isExcluded(childPath) || isInTestResources(childPath) {
          continue
        }
        if isDirectory(child.path) {
          walk(child, relativePath: childPath)
        } else {
          visit(childPath, child)
        }
      }
    }
    walk(URL(fileURLWithPath: repoPath), relativePath: "")
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
