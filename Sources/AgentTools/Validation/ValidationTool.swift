// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Runs build and test steps for a Swift repository and reports a PASS/FAIL/SKIP summary.
///
/// Full validation discovers the repository's product and local packages, plans the builds and tests with
/// `ValidationPlan`, and runs the plan. Targeted validation builds and tests a single SwiftPM target.
final class ValidationTool {
  /// Validation settings.
  private let config: ValidationConfig
  /// Repository root that validation runs in.
  private let repoPath: String
  /// Runs and records validation steps.
  private let runner: StepRunner
  /// The sandbox validation runs in, detected when validation starts.
  private var sandbox = EnclosingSandbox(isNested: false)
  /// Discovery results saved between runs, loaded when validation starts.
  private var cache: DiscoveryCache?

  /// Creates a tool that validates the repository at `repoPath`.
  init(config: ValidationConfig, repoPath: String) {
    self.config = config
    self.repoPath = repoPath
    self.runner = StepRunner(repoPath: repoPath, outputMode: config.outputMode, planOnly: config.planOnly)
  }

  /// Returns a `swift` command for a package that builds into validation's private build directory.
  ///
  /// `command` is the subcommand, such as `["build"]` or `["package"]`; its own arguments follow the result.
  static func swiftPMArguments(_ command: [String], packageDir: String, paths: ValidationPaths, disableSandbox: Bool) -> [String] {
    ["swift"] + command + [
      "--package-path", packageDir,
      "--scratch-path", paths.swiftPMScratchPath(forPackage: packageDir),
    ] + (disableSandbox ? ["--disable-sandbox"] : [])
  }

  /// Subprocess runner rooted at the repository.
  private var process: ValidationProcess { runner.process }

  /// Runs targeted or full validation, printing the summary whether or not it succeeds.
  func run() throws {
    // Line-buffer output, so progress and errors appear in order and promptly when output goes to a pipe or file.
    setvbuf(stdout, nil, _IOLBF, 0)
    guard FileManager.default.fileExists(atPath: "\(repoPath)/.git") else {
      throw ToolError("Current working directory is not a git repo root: \(repoPath)")
    }

    defer { runner.printSummary() }

    let paths = try ValidationPaths.prepare(repoPath: repoPath, clean: config.clean)
    sandbox = try EnclosingSandbox.detect(using: process)
    if sandbox.isNested {
      print("Running inside another sandbox; turning off SwiftPM's and Xcode's own sandboxes.")
    }
    let cache = try loadCache(paths: paths)
    self.cache = cache
    defer {
      try? cache.save()
      print("Discovery: \(cache.reused) cached, \(cache.computed) looked up.")
    }

    let packageDirs = ValidationDiscovery.packageDirectories(
      repoPath: repoPath,
      overrides: config.packageDirsOverride,
      recursive: config.recursivePackageDiscovery
    )
    let workspace = ValidationDiscovery.workspace(override: config.workspaceOverride, repoPath: repoPath)
    let project = ValidationDiscovery.project(override: config.projectOverride, repoPath: repoPath)

    if let target = config.target {
      try runTargeted(target: target, paths: paths, packages: packageDirs, workspace: workspace, project: project)
      return
    }

    let container = workspace.map { ["-workspace", $0] } ?? project.map { ["-project", $0] } ?? []
    let discovered = try discoverProject(container: container, packageDirs: packageDirs, paths: paths)
    let steps = ValidationPlan.steps(
      for: discovered,
      testSubmodules: config.testSubmodules,
      excludedPackages: config.excludedPackages,
      paths: paths,
      sandbox: sandbox,
      disableSwiftPMSandbox: config.swiftPMDisableSandbox || sandbox.isNested,
      quiet: config.outputMode != .raw
    )
    for step in steps {
      if step.skipped {
        runner.record(step.summary, status: .skip)
      } else {
        try runner.run(
          title: step.title,
          summary: step.summary,
          arguments: step.arguments,
          workingDirectory: step.workingDirectory,
          logPath: paths.logPath(step.logName)
        )
      }
    }
  }

  /// Discovers the product schemes, their platforms and tests, and the local packages of the root container.
  private func discoverProject(container: [String], packageDirs: [String], paths: ValidationPaths) throws -> ValidationProject {
    guard !container.isEmpty || FileManager.default.fileExists(atPath: "\(repoPath)/Package.swift") else {
      throw ToolError("No Xcode workspace or project, and no Package.swift, in \(repoPath).")
    }

    let schemes = try listSchemes(container)
    let changedSubmodules = try changedSubmodulePaths()
    var packages: [LocalPackage] = []
    var descriptions: [String: SwiftPackageDescription] = [:]
    var rootPackage: SwiftPackageDescription?
    for packageDir in packageDirs {
      let submodule = SubmoduleStatus.enclosingSubmodule(of: packageDir, repoPath: repoPath)
      let submoduleChanged = submodule.map(changedSubmodules.contains) ?? false
      if submodule != nil, config.testSubmodules == .never || (config.testSubmodules == .changed && !submoduleChanged) {
        continue
      }

      let description: SwiftPackageDescription
      do {
        description = try describePackage(packageDir, paths: paths)
      } catch {
        let reason = "\(error)".split(separator: "\n").dropFirst().first.map(String.init) ?? "\(error)"
        runner.record("test \(relativePath(packageDir)) (cannot describe package: \(reason.trimmingCharacters(in: .whitespaces)))", status: .skip)
        continue
      }
      descriptions[packageDir] = description
      if submodule == nil, relativePath(packageDir).isEmpty {
        rootPackage = description
      }
      packages.append(
        LocalPackage(
          directory: packageDir,
          name: description.name,
          hasTests: description.hasTestTargets,
          scheme: LocalPackage.scheme(for: description, in: schemes),
          submodule: submodule,
          submoduleChanged: submoduleChanged
        )
      )
    }

    let roots = container.isEmpty ? [repoPath] : ValidationDiscovery.referencedPackages(container: container)
    let localDependencies = Dictionary(
      packages.map { package in
        (ValidationPaths.canonical(package.directory), descriptions[package.directory]?.localDependencyPaths.map(ValidationPaths.canonical) ?? [])
      },
      uniquingKeysWith: { first, _ in first }
    )
    let product = ValidationDiscovery.productPackages(roots: roots.map(ValidationPaths.canonical), localDependencies: localDependencies)
    for index in packages.indices {
      packages[index].inProduct = product.contains(ValidationPaths.canonical(packages[index].directory))
    }

    let productSchemes = try self.productSchemes(container: container, schemes: schemes, rootPackage: rootPackage)
    let schemeFiles = ValidationDiscovery.fingerprintFiles(repoPath: repoPath).filter { $0.hasSuffix(".xcscheme") }
    let schemesWithTests = Set(
      productSchemes.filter { scheme in
        guard let file = schemeFiles.first(where: { URL(fileURLWithPath: $0).lastPathComponent == "\(scheme).xcscheme" }),
          let contents = try? String(contentsOfFile: "\(repoPath)/\(file)", encoding: .utf8)
        else { return false }
        return XcodeSchemes.hasTests(schemeFile: contents)
      }
    )

    let buildPlatforms: [ApplePlatform]
    if !config.platforms.isEmpty {
      buildPlatforms = config.platforms
    } else if container.isEmpty {
      buildPlatforms = [.macOS]
    } else {
      var platforms: [ApplePlatform] = []
      for scheme in productSchemes {
        for platform in try supportedPlatforms(container: container, scheme: scheme, paths: paths) where !platforms.contains(platform) {
          platforms.append(platform)
        }
      }
      buildPlatforms = platforms
    }
    let testPlatforms = config.testPlatforms.isEmpty ? buildPlatforms : config.testPlatforms
    let needsSimulators = testPlatforms.contains { $0 != .macOS }
    let testDestinations = try needsSimulators ? self.testDestinations(container: container, scheme: productSchemes[0], platforms: testPlatforms, paths: paths) : [.macOS: "platform=macOS"]

    if needsSimulators {
      for index in packages.indices where packages[index].inProduct && packages[index].hasTests && packages[index].scheme == nil {
        guard let description = descriptions[packages[index].directory] else { continue }
        let packageSchemes = try listSchemes([], in: packages[index].directory)
        packages[index].packageScheme = LocalPackage.scheme(for: description, in: packageSchemes)
      }
    }

    return ValidationProject(
      container: container,
      productSchemes: productSchemes,
      schemesWithTests: schemesWithTests,
      buildPlatforms: buildPlatforms,
      testPlatforms: testPlatforms,
      testDestinations: testDestinations,
      packages: packages
    )
  }

  /// Returns a directory's path relative to the repository, or an empty string for the repository itself.
  private func relativePath(_ directory: String) -> String {
    let repo = URL(fileURLWithPath: repoPath).standardizedFileURL.path
    let path = URL(fileURLWithPath: directory).standardizedFileURL.path
    return path == repo ? "" : path.hasPrefix("\(repo)/") ? String(path.dropFirst(repo.count + 1)) : path
  }

  /// Returns the configured product schemes, or by default the scheme named after the repository for an Xcode
  /// container, or the root package's scheme.
  private func productSchemes(container: [String], schemes: [String], rootPackage: SwiftPackageDescription?) throws -> [String] {
    let wanted: [String]
    if !config.schemes.isEmpty {
      wanted = config.schemes
    } else if !container.isEmpty {
      wanted = [ValidationDiscovery.repoName(repoPath)]
    } else if let rootPackage, let scheme = LocalPackage.scheme(for: rootPackage, in: schemes) {
      wanted = [scheme]
    } else {
      wanted = []
    }

    let missing = wanted.filter { !schemes.contains($0) }
    guard !wanted.isEmpty, missing.isEmpty else {
      let names = missing.isEmpty ? "No product scheme was found" : "No scheme named \(missing.joined(separator: ", "))"
      throw ToolError(
        "\(names). Set validate.schemes in .agt/config.json, or pass --schemes. Available schemes: \(schemes.joined(separator: ", "))."
      )
    }
    return wanted
  }

  /// Returns the repository-relative paths of submodules that differ from the commits the repository records, when
  /// the submodule policy needs them.
  private func changedSubmodulePaths() throws -> Set<String> {
    guard config.testSubmodules == .changed else { return [] }
    let result = try process.capture(["git", "status", "--porcelain"])
    guard result.status == 0 else {
      throw ToolError("Failed to read git status:\n\(result.stderr)")
    }
    return Set(SubmoduleStatus.changedPaths(fromPorcelain: result.stdout))
  }

  /// Builds a modified non-test SwiftPM target before running its conventionally named test target, if present.
  ///
  /// When no discovered package defines the target, builds an Xcode scheme of that name instead.
  private func runTargeted(target: String, paths: ValidationPaths, packages: [String], workspace: String?, project: String?) throws {
    var inspectionErrors: [String] = []

    for packageDir in packages {
      let package: SwiftPackageDescription
      do {
        package = try describePackage(packageDir, paths: paths)
      } catch {
        inspectionErrors.append("\(error)")
        continue
      }
      guard package.hasTarget(named: target) else { continue }

      try runner.run(
        title: "Build Swift target \(target)",
        summary: "swift build \(target)",
        arguments: swiftPMCommand(["build"], packageDir: packageDir, paths: paths) + ["--target", target],
        logPath: paths.logPath("swift_build_target_\(target)_\(packageDir)")
      )

      let candidates = target.hasSuffix("Tests") ? [target] : [target, "\(target)Tests"]
      if let testTarget = candidates.first(where: { package.hasTarget(named: $0, type: "test") }) {
        try runner.run(
          title: "Test Swift target \(testTarget)",
          summary: "swift test \(testTarget)",
          arguments: swiftPMCommand(["test"], packageDir: packageDir, paths: paths) + ["--filter", testTarget],
          logPath: paths.logPath("swift_test_target_\(testTarget)_\(packageDir)")
        )
      } else {
        runner.record("swift test \(target) (no matching test target)", status: .skip)
      }
      return
    }

    let fallback: (container: [String], kind: String)?
    if let workspace {
      fallback = (["-workspace", workspace], "workspace")
    } else if let project {
      fallback = (["-project", project], "project")
    } else {
      fallback = nil
    }

    guard let fallback else {
      if !inspectionErrors.isEmpty {
        throw ToolError(
          """
          Could not inspect SwiftPM packages while resolving target '\(target)'.
          \(inspectionErrors.joined(separator: "\n\n"))
          Provide --package-dirs to narrow package discovery, or ensure SwiftPM commands can run in this environment.
          """
        )
      }
      throw ToolError(
        "Target '\(target)' was not found in discovered Swift packages, and no Xcode workspace/project is available for scheme fallback. Provide --package-dirs, --workspace, or --project."
      )
    }

    if !inspectionErrors.isEmpty {
      print("SwiftPM target inspection failed; continuing with Xcode \(fallback.kind) fallback.")
    }

    let destination = ApplePlatform.macOS.buildDestination
    var args =
      ["xcodebuild"] + fallback.container + ["-scheme", target, "-destination", destination, "-derivedDataPath", paths.derivedDataPath]
      + XcodeDestinations.trustArguments + sandbox.xcodebuildDefaults
    if config.outputMode != .raw {
      args.append("-quiet")
    }
    try runner.run(
      title: "Build \(fallback.kind) scheme \(target) for \(destination)",
      summary: "build \(target) (\(destination))",
      arguments: args + ["CODE_SIGNING_ALLOWED=NO"] + sandbox.xcodebuildBuildSettings + ["build"],
      logPath: paths.logPath("\(fallback.kind)_target_build_\(target)")
    )
  }

  /// Returns a `swift` command for a package, turning off SwiftPM's sandbox when requested or already sandboxed.
  private func swiftPMCommand(_ command: [String], packageDir: String, paths: ValidationPaths) -> [String] {
    Self.swiftPMArguments(command, packageDir: packageDir, paths: paths, disableSandbox: config.swiftPMDisableSandbox || sandbox.isNested)
  }

  /// Loads the discovery cache, keyed by the files discovery reads, the tool version, the selected Xcode, and the
  /// options that change what discovery finds.
  private func loadCache(paths: ValidationPaths) throws -> DiscoveryCache {
    let developerDir = try process.capture(["xcode-select", "--print-path"]).stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    let inputs = [
      ToolVersion.current,
      ProcessInfo.processInfo.environment["DEVELOPER_DIR"] ?? developerDir,
      config.workspaceOverride ?? "",
      config.projectOverride ?? "",
      (config.packageDirsOverride ?? []).joined(separator: ","),
      String(config.recursivePackageDiscovery),
    ]
    return DiscoveryCache(
      path: "\(paths.root)/discovery.json",
      fingerprint: DiscoveryCache.fingerprint(root: repoPath, files: ValidationDiscovery.fingerprintFiles(repoPath: repoPath), inputs: inputs)
    )
  }

  /// Returns the cached result for `key`, or computes it, caching it only when `isComplete` accepts it.
  private func discovered<T: Codable>(_ key: String, isComplete: (T) -> Bool = { _ in true }, compute: () throws -> T) throws -> T {
    guard let cache else { return try compute() }
    return try cache.value(key, isComplete: isComplete, compute: compute)
  }

  /// Returns the schemes of a workspace, project, or package, failing when `xcodebuild` cannot read it, so validation
  /// never skips it. An empty container means the package in `directory`, which defaults to the repository.
  private func listSchemes(_ container: [String], in directory: String? = nil) throws -> [String] {
    let location = directory ?? repoPath
    return try discovered("schemes \(location) \(container.joined(separator: " "))") {
      let process = directory.map { ValidationProcess(workingDirectory: $0) } ?? self.process
      let result = try process.capture(["xcodebuild", "-list", "-json"] + container + XcodeDestinations.trustArguments + sandbox.xcodebuildDefaults)
      guard result.status == 0 else {
        let details = ValidationOutput.failureDiagnostics(result.stdout + "\n" + result.stderr).joined(separator: "\n")
        throw ToolError("xcodebuild cannot read \(container.last ?? location):\n\(details)")
      }
      return try XcodeSchemes.schemes(fromListJSON: result.stdout)
    }
  }

  /// Returns the platforms a scheme supports, from its build settings.
  private func supportedPlatforms(container: [String], scheme: String, paths: ValidationPaths) throws -> [ApplePlatform] {
    try discovered("platforms \(container.joined(separator: " ")) \(scheme)") {
      let result = try process.capture(XcodeDestinations.showBuildSettingsArguments(container: container, scheme: scheme, paths: paths, sandbox: sandbox))
      guard result.status == 0 else {
        throw ToolError("Failed to read supported platforms for scheme '\(scheme)':\n\(result.stderr)")
      }
      let platforms = try XcodeDestinations.platforms(fromBuildSettingsJSON: result.stdout)
      guard !platforms.isEmpty else {
        throw ToolError("No supported platforms found for scheme '\(scheme)'. Set validate.platforms in .agt/config.json, or pass --platforms.")
      }
      return platforms
    }
  }

  /// Returns a test destination for each platform, choosing simulators from those available to a scheme.
  ///
  /// Xcode can list destinations before it has loaded its simulators, so a list missing any of `platforms` is retried
  /// once and never cached.
  private func testDestinations(container: [String], scheme: String, platforms: [ApplePlatform], paths: ValidationPaths) throws -> [ApplePlatform: String] {
    let isComplete = { (destinations: [ApplePlatform: String]) in platforms.allSatisfy { destinations[$0] != nil } }
    return try discovered("testDestinations \(container.joined(separator: " ")) \(scheme)", isComplete: isComplete) {
      var destinations: [ApplePlatform: String] = [:]
      for _ in 1...2 where !isComplete(destinations) {
        let result = try process.capture(XcodeDestinations.showDestinationsArguments(container: container, scheme: scheme, paths: paths, sandbox: sandbox))
        guard result.status == 0 else {
          throw ToolError("Failed to list destinations for scheme '\(scheme)':\n\(result.stderr)")
        }
        destinations = XcodeDestinations.testDestinations(fromShowDestinations: result.stdout)
      }
      return destinations
    }
  }

  /// Reads a package's targets and products with `swift package describe`.
  private func describePackage(_ packageDir: String, paths: ValidationPaths) throws -> SwiftPackageDescription {
    try discovered("describe \(packageDir)") {
      let result = try process.capture(swiftPMCommand(["package"], packageDir: packageDir, paths: paths) + ["describe", "--type", "json"])
      guard result.status == 0 else {
        throw ToolError("Failed to describe Swift package at \(packageDir):\n\(result.stderr)")
      }
      return try JSONDecoder().decode(SwiftPackageDescription.self, from: Data(result.stdout.utf8))
    }
  }
}
