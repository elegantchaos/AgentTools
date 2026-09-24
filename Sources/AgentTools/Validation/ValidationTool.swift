// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Runs build and test steps for a Swift repository and reports a PASS/FAIL/SKIP summary.
final class ValidationTool {
  /// Validation settings.
  private let config: ValidationConfig
  /// Repository root that validation runs in.
  private let repoPath: String
  /// Runs and records validation steps.
  private let runner: StepRunner

  /// Creates a tool that validates the repository at `repoPath`.
  init(config: ValidationConfig, repoPath: String) {
    self.config = config
    self.repoPath = repoPath
    self.runner = StepRunner(repoPath: repoPath, outputMode: config.outputMode)
  }

  /// Adds the build system and compiler flags used for every SwiftPM validation build.
  static func swiftPMArguments(_ arguments: [String]) -> [String] {
    arguments + ["--build-system", "swiftbuild", "-Xswiftc", "-DVALIDATING"]
  }

  /// Subprocess runner rooted at the repository.
  private var process: ValidationProcess { runner.process }

  /// Runs targeted or comprehensive validation, printing the summary whether or not it succeeds.
  func run() throws {
    guard FileManager.default.fileExists(atPath: "\(repoPath)/.git") else {
      throw ToolError("Current working directory is not a git repo root: \(repoPath)")
    }

    defer { runner.printSummary() }

    let paths = try ValidationPaths.prepare(repoPath: repoPath, clean: config.clean)
    let packages = ValidationDiscovery.packageDirectories(
      repoPath: repoPath,
      overrides: config.packageDirsOverride,
      recursive: config.recursivePackageDiscovery
    )

    var workspace = ValidationDiscovery.workspace(override: config.workspaceOverride, repoPath: repoPath)
    if let candidate = workspace, !isUsable(["-workspace", candidate]) {
      print("Workspace exists but is not usable by xcodebuild: \(candidate). Falling back to project/SwiftPM.")
      workspace = nil
    }

    var project = ValidationDiscovery.project(override: config.projectOverride, repoPath: repoPath)
    if let candidate = project, !isUsable(["-project", candidate]) {
      print("Project exists but is not usable by xcodebuild: \(candidate). Falling back to SwiftPM when possible.")
      project = nil
    }

    if let target = config.target {
      try runTargeted(target: target, paths: paths, packages: packages, workspace: workspace, project: project)
      return
    }

    if let workspace {
      try runXcodeBroad(container: ["-workspace", workspace], kind: "workspace", logPrefix: "comprehensive", paths: paths)
    } else if !packages.isEmpty {
      print("No workspace detected. Running SwiftPM broad validation across discovered packages.")
      try runSwiftPMBroad(packages: packages, paths: paths)
    } else if let project {
      try runXcodeBroad(container: ["-project", project], kind: "project", logPrefix: "project", paths: paths)
    } else {
      throw ToolError("No workspace/project or Swift packages detected for broad validation in \(repoPath).")
    }
  }

  /// Builds every scheme for its destinations, then optionally tests workspace schemes.
  private func runXcodeBroad(container: [String], kind: String, logPrefix: String, paths: ValidationPaths) throws {
    let isWorkspace = kind == "workspace"
    let actions = isWorkspace && config.clean ? ["clean", "build"] : ["build"]

    for scheme in config.schemes {
      for destination in try buildDestinations(container: container, scheme: scheme, paths: paths) {
        try runner.run(
          title: "Build \(kind) scheme \(scheme) for \(destination)",
          summary: "build \(scheme) (\(destination))",
          arguments: xcodebuildArguments(container: container, scheme: scheme, destination: destination, paths: paths, actions: actions),
          logPath: paths.logPath("\(logPrefix)_\(scheme)_\(destination)_build")
        )
      }
    }

    guard isWorkspace, config.runXcodeTests else { return }

    for scheme in config.schemes {
      for destination in config.testDestinations {
        try runner.run(
          title: "Test workspace scheme \(scheme) for \(destination)",
          summary: "test \(scheme) (\(destination))",
          arguments: xcodebuildArguments(container: container, scheme: scheme, destination: destination, paths: paths, actions: ["test"]),
          logPath: paths.logPath("\(logPrefix)_\(scheme)_\(destination)_test")
        )
      }
    }
  }

  /// Builds and tests each discovered Swift package.
  private func runSwiftPMBroad(packages: [String], paths: ValidationPaths) throws {
    for packageDir in packages {
      let package: SwiftPackageDescription
      do {
        package = try describePackage(packageDir)
      } catch {
        throw ToolError("Could not inspect Swift package at \(packageDir) before validation.\n\(error)")
      }

      try runner.run(
        title: "Build Swift package \(packageDir)",
        summary: "swift build \(packageDir)",
        arguments: swiftPMCommand(["build", "--package-path", packageDir]),
        logPath: paths.logPath("swift_build_\(packageDir)")
      )

      guard package.hasTestTargets else {
        runner.record("swift test \(packageDir) (no test targets)", status: .skip)
        continue
      }

      try runner.run(
        title: "Test Swift package \(packageDir)",
        summary: "swift test \(packageDir)",
        arguments: swiftPMCommand(["test", "--package-path", packageDir]),
        logPath: paths.logPath("swift_test_\(packageDir)")
      )
    }
  }

  /// Builds a modified non-test SwiftPM target before running its conventionally named test target, if present.
  ///
  /// When no discovered package defines the target, builds an Xcode scheme of the same name instead.
  private func runTargeted(target: String, paths: ValidationPaths, packages: [String], workspace: String?, project: String?) throws {
    var inspectionErrors: [String] = []

    for packageDir in packages {
      let package: SwiftPackageDescription
      do {
        package = try describePackage(packageDir)
      } catch {
        inspectionErrors.append("\(error)")
        continue
      }
      guard package.hasTarget(named: target) else { continue }

      try runner.run(
        title: "Build Swift target \(target)",
        summary: "swift build \(target)",
        arguments: swiftPMCommand(["build", "--package-path", packageDir, "--target", target]),
        logPath: paths.logPath("swift_build_target_\(target)_\(packageDir)")
      )

      let candidates = target.hasSuffix("Tests") ? [target] : [target, "\(target)Tests"]
      if let testTarget = candidates.first(where: { package.hasTarget(named: $0, type: "test") }) {
        try runner.run(
          title: "Test Swift target \(testTarget)",
          summary: "swift test \(testTarget)",
          arguments: swiftPMCommand(["test", "--package-path", packageDir, "--filter", testTarget]),
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

    let destination = "generic/platform=macOS"
    try runner.run(
      title: "Build \(fallback.kind) scheme \(target) for \(destination)",
      summary: "build \(target) (\(destination))",
      arguments: xcodebuildArguments(container: fallback.container, scheme: target, destination: destination, paths: paths, actions: ["build"]),
      logPath: paths.logPath("\(fallback.kind)_target_build_\(target)")
    )
  }

  /// Returns the `xcodebuild` arguments for one scheme, destination, and set of actions.
  private func xcodebuildArguments(container: [String], scheme: String, destination: String, paths: ValidationPaths, actions: [String]) -> [String] {
    var args = ["xcodebuild"] + container + ["-scheme", scheme, "-destination", destination, "-derivedDataPath", paths.derivedDataPath]
    if config.outputMode != .raw {
      args.append("-quiet")
    }
    return args + ["CODE_SIGNING_ALLOWED=NO"] + actions
  }

  /// Returns a `swift` command with validation flags and the optional sandbox override.
  private func swiftPMCommand(_ arguments: [String]) -> [String] {
    let args = Self.swiftPMArguments(["swift"] + arguments)
    return config.swiftPMDisableSandbox ? args + ["--disable-sandbox"] : args
  }

  /// Returns explicit destinations, or the generic destinations for the platforms a scheme supports.
  private func buildDestinations(container: [String], scheme: String, paths: ValidationPaths) throws -> [String] {
    guard config.destinations.isEmpty else { return config.destinations }

    let isWorkspace = container.first == "-workspace"
    let result = try process.capture(
      XcodeDestinations.showBuildSettingsArguments(
        workspace: isWorkspace ? container.last : nil,
        project: isWorkspace ? nil : container.last,
        scheme: scheme,
        derivedDataPath: paths.derivedDataPath
      )
    )
    guard result.status == 0 else {
      throw ToolError("Failed to read supported platforms for scheme '\(scheme)':\n\(result.stderr)")
    }

    let destinations = try XcodeDestinations.destinations(fromBuildSettingsJSON: result.stdout)
    guard !destinations.isEmpty else {
      throw ToolError("No supported build destinations found for scheme '\(scheme)'. Provide --destinations to override platform detection.")
    }
    return destinations
  }

  /// Reads a package's targets with `swift package describe`.
  private func describePackage(_ packageDir: String) throws -> SwiftPackageDescription {
    let result = try process.capture(["swift", "package", "--package-path", packageDir, "describe", "--type", "json"])
    guard result.status == 0 else {
      let suggestion =
        result.stderr.contains("sandbox_apply: Operation not permitted")
        ? "\nRetry with --swiftpm-disable-sandbox if this environment blocks SwiftPM's internal sandbox."
        : ""
      throw ToolError("Failed to describe Swift package at \(packageDir):\n\(result.stderr)\(suggestion)")
    }
    return try JSONDecoder().decode(SwiftPackageDescription.self, from: Data(result.stdout.utf8))
  }

  /// Returns `true` when `xcodebuild -list` accepts the workspace or project.
  private func isUsable(_ container: [String]) -> Bool {
    (try? process.capture(["xcodebuild", "-list"] + container))?.status == 0
  }
}
