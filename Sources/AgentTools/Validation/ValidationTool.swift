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
  /// The sandbox validation runs in, detected when validation starts.
  private var sandbox = EnclosingSandbox(isNested: false)

  /// Creates a tool that validates the repository at `repoPath`.
  init(config: ValidationConfig, repoPath: String) {
    self.config = config
    self.repoPath = repoPath
    self.runner = StepRunner(repoPath: repoPath, outputMode: config.outputMode)
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

  /// Runs targeted or comprehensive validation, printing the summary whether or not it succeeds.
  func run() throws {
    guard FileManager.default.fileExists(atPath: "\(repoPath)/.git") else {
      throw ToolError("Current working directory is not a git repo root: \(repoPath)")
    }

    defer { runner.printSummary() }

    let paths = try ValidationPaths.prepare(repoPath: repoPath, clean: config.clean)
    sandbox = try EnclosingSandbox.detect(using: process)
    if sandbox.isNested {
      print("Running inside another sandbox; turning off SwiftPM's and Xcode's own sandboxes.")
    }
    let packages = ValidationDiscovery.packageDirectories(
      repoPath: repoPath,
      overrides: config.packageDirsOverride,
      recursive: config.recursivePackageDiscovery
    )

    let workspace = ValidationDiscovery.workspace(override: config.workspaceOverride, repoPath: repoPath)
    if let workspace {
      try checkReadable(["-workspace", workspace])
    }

    let project = ValidationDiscovery.project(override: config.projectOverride, repoPath: repoPath)
    if let project {
      try checkReadable(["-project", project])
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
        package = try describePackage(packageDir, paths: paths)
      } catch {
        throw ToolError("Could not inspect Swift package at \(packageDir) before validation.\n\(error)")
      }

      try runner.run(
        title: "Build Swift package \(packageDir)",
        summary: "swift build \(packageDir)",
        arguments: swiftPMCommand(["build"], packageDir: packageDir, paths: paths),
        logPath: paths.logPath("swift_build_\(packageDir)")
      )

      guard package.hasTestTargets else {
        runner.record("swift test \(packageDir) (no test targets)", status: .skip)
        continue
      }

      try runner.run(
        title: "Test Swift package \(packageDir)",
        summary: "swift test \(packageDir)",
        arguments: swiftPMCommand(["test"], packageDir: packageDir, paths: paths),
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
    var args = ["xcodebuild"] + container + ["-scheme", scheme, "-destination", destination, "-derivedDataPath", paths.derivedDataPath] + sandbox.xcodebuildDefaults
    if config.outputMode != .raw {
      args.append("-quiet")
    }
    return args + ["CODE_SIGNING_ALLOWED=NO"] + sandbox.xcodebuildBuildSettings + actions
  }

  /// Returns a `swift` command for a package, turning off SwiftPM's sandbox when requested or already sandboxed.
  private func swiftPMCommand(_ command: [String], packageDir: String, paths: ValidationPaths) -> [String] {
    Self.swiftPMArguments(command, packageDir: packageDir, paths: paths, disableSandbox: config.swiftPMDisableSandbox || sandbox.isNested)
  }

  /// Returns explicit destinations, or the generic destinations for the platforms a scheme supports.
  private func buildDestinations(container: [String], scheme: String, paths: ValidationPaths) throws -> [String] {
    guard config.destinations.isEmpty else { return config.destinations }

    let result = try process.capture(XcodeDestinations.showBuildSettingsArguments(container: container, scheme: scheme, paths: paths, sandbox: sandbox))
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
  private func describePackage(_ packageDir: String, paths: ValidationPaths) throws -> SwiftPackageDescription {
    let result = try process.capture(swiftPMCommand(["package"], packageDir: packageDir, paths: paths) + ["describe", "--type", "json"])
    guard result.status == 0 else {
      throw ToolError("Failed to describe Swift package at \(packageDir):\n\(result.stderr)")
    }
    return try JSONDecoder().decode(SwiftPackageDescription.self, from: Data(result.stdout.utf8))
  }

  /// Throws when `xcodebuild -list` cannot read the workspace or project, so validation never silently skips it.
  private func checkReadable(_ container: [String]) throws {
    let result = try process.capture(["xcodebuild", "-list"] + container + sandbox.xcodebuildDefaults)
    guard result.status == 0 else {
      let details = ValidationOutput.failureDiagnostics(result.stdout + "\n" + result.stderr).joined(separator: "\n")
      throw ToolError("xcodebuild cannot read \(container[1]):\n\(details)")
    }
  }
}
