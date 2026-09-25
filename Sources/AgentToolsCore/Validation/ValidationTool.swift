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

  /// State and output of background validation.
  private var backgroundStore: BackgroundStatusStore {
    BackgroundStatusStore(directory: ValidationPaths(repoPath: repoPath).backgroundDirectory)
  }

  /// Runs the requested validation: reports or waits for background validation, runs as a background worker, starts
  /// background validation, or validates in the foreground, stopping any background validation first.
  func run() throws {
    // Line-buffer output, so progress and errors appear in order and promptly when output goes to a pipe or file.
    setvbuf(stdout, nil, _IOLBF, 0)
    guard FileManager.default.fileExists(atPath: "\(repoPath)/.git") else {
      throw ToolError("Current working directory is not a git repo root: \(repoPath)")
    }

    if config.status {
      try reportBackground(waiting: false)
    } else if config.wait {
      try reportBackground(waiting: true)
    } else if config.backgroundWorker {
      try runWorker()
    } else if config.background, !config.fast, config.target == nil, !config.planOnly {
      try startBackground()
    } else {
      if !config.planOnly, BackgroundLauncher.supersede(store: backgroundStore) {
        print("Stopped the background validation that was running, so they do not compete for build directories.")
      }
      try validate()
      if config.background, !config.planOnly {
        try startBackground()
      }
    }
  }

  /// Starts full validation in the background, unless the last one passed for the current working tree.
  private func startBackground() throws {
    let fingerprint = try WorkingTreeFingerprint.current(using: process)
    if let last = backgroundStore.load(), last.isCurrentPass(currentFingerprint: fingerprint) {
      print("Full validation already passed for this working tree; not running it again.")
      return
    }
    if BackgroundLauncher.supersede(store: backgroundStore) {
      print("Stopped the previous background validation.")
    }
    let status = try BackgroundLauncher.start(repoPath: repoPath, fingerprint: fingerprint, store: backgroundStore)
    print("Full validation started in the background (process \(status.pid)).")
    print("Check it with `agt validate --status`, or wait for it with `agt validate --wait`. Output: \(backgroundStore.logPath)")
  }

  /// Runs full validation as a background worker, recording the result unless a newer validation has replaced it.
  ///
  /// The worker leads its own process group, so stopping it stops the tools it runs, and ignores the hang-up signal
  /// sent when the terminal that started it closes.
  private func runWorker() throws {
    setpgid(0, 0)
    signal(SIGHUP, SIG_IGN)
    let store = backgroundStore
    guard ownsBackgroundStatus() else {
      print("A newer validation replaced this one before it started.")
      return
    }
    let startFingerprint = try WorkingTreeFingerprint.current(using: process)
    var status = BackgroundStatus(state: .running, pid: getpid(), fingerprint: startFingerprint, started: .now, token: workerToken)
    try store.save(status)
    runner.shouldStop = { [unowned self] in !self.ownsBackgroundStatus() }

    var passed = false
    do {
      try validate()
      passed = true
    } catch is Superseded {
      print("A newer validation replaced this one.")
      return
    } catch {
      print("Error: \(error)")
    }

    guard ownsBackgroundStatus() else {
      print("A newer validation replaced this one; not recording its result.")
      return
    }
    let endFingerprint = try WorkingTreeFingerprint.current(using: process)
    status.state = endFingerprint != startFingerprint ? .stale : passed ? .passed : .failed
    status.finished = .now
    status.steps = runner.summaryLines
    try store.save(status)
  }

  /// Runs one planned step. A step that fails because a newer validation interrupted it throws `Superseded`.
  private func runStep(_ step: PlannedStep, paths: ValidationPaths) throws {
    do {
      try runner.run(
        title: step.title,
        summary: step.summary,
        arguments: step.arguments,
        workingDirectory: step.workingDirectory,
        logPath: paths.logPath(step.logName)
      )
    } catch {
      try checkNotSuperseded()
      throw error
    }
  }

  /// Thrown when a newer background validation has replaced this one.
  private struct Superseded: Error {}

  /// The token that identifies this process when it is a background worker.
  private var workerToken: String {
    ProcessInfo.processInfo.environment[BackgroundLauncher.tokenVariable] ?? ""
  }

  /// Returns `true` unless this process is a background worker that a newer validation has replaced or cancelled.
  private func ownsBackgroundStatus() -> Bool {
    guard config.backgroundWorker else { return true }
    return backgroundStore.load()?.isOwned(byToken: workerToken) ?? false
  }

  /// Throws `Superseded` when a newer background validation has replaced this worker.
  private func checkNotSuperseded() throws {
    if !ownsBackgroundStatus() {
      throw Superseded()
    }
  }

  /// Reports the background validation, first waiting for it to finish when `waiting`. When waiting, fails unless it
  /// passed for the current working tree.
  private func reportBackground(waiting: Bool) throws {
    let store = backgroundStore
    guard var status = store.load() else {
      if waiting {
        throw ToolError("No background validation has run. Start one with `agt validate --background`, or run `agt validate`.")
      }
      print("No background validation has run.")
      return
    }
    while waiting, status.state == .running, BackgroundLauncher.isAlive(status.pid) {
      sleep(2)
      status = store.load() ?? status
    }
    if status.state == .running, !BackgroundLauncher.isAlive(status.pid) {
      status.state = .cancelled
    }

    let fingerprint = try WorkingTreeFingerprint.current(using: process)
    print(status.headline(currentFingerprint: fingerprint))
    for line in status.steps {
      print(line)
    }
    print("Output: \(store.logPath)")
    if waiting, !status.isCurrentPass(currentFingerprint: fingerprint) {
      throw ToolError("Full validation did not pass for the current working tree.")
    }
  }

  /// Runs the fast phase or full validation in this process, printing the summary whether or not it succeeds.
  private func validate() throws {
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

    let container = workspace.map { ["-workspace", $0] } ?? project.map { ["-project", $0] } ?? []
    if config.fast || config.target != nil {
      try runFast(container: container, packageDirs: packageDirs, paths: paths)
      return
    }

    let discovered = try discoverProject(container: container, packageDirs: packageDirs, paths: paths)
    for note in discovered.simulatorNotes {
      print(note)
    }
    if config.planOnly {
      print("== Packages")
      let summaries = ValidationPlan.packageSummaries(
        for: discovered,
        testSubmodules: config.testSubmodules,
        excludedPackages: config.excludedPackages,
        repoPath: repoPath
      )
      for summary in summaries {
        print(summary)
      }
      print("== Steps")
    }
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
      try checkNotSuperseded()
      if step.skipped {
        runner.record(step.summary, status: .skip)
      } else {
        try runStep(step, paths: paths)
      }
    }
  }

  /// Discovers the product schemes, their platforms and tests, and the local packages of the root container.
  private func discoverProject(container: [String], packageDirs: [String], paths: ValidationPaths) throws -> ValidationProject {
    guard !container.isEmpty || FileManager.default.fileExists(atPath: "\(repoPath)/Package.swift") else {
      throw ToolError("No Xcode workspace or project, and no Package.swift, in \(repoPath).")
    }

    let schemes = try listSchemes(container)
    let schemeFiles = ValidationDiscovery.fingerprintFiles(repoPath: repoPath).filter { $0.hasSuffix(".xcscheme") }
    func schemeFileHasTests(_ scheme: String) -> Bool {
      guard let file = schemeFiles.first(where: { URL(fileURLWithPath: $0).lastPathComponent == "\(scheme).xcscheme" }),
        let contents = try? String(contentsOfFile: "\(repoPath)/\(file)", encoding: .utf8)
      else { return false }
      return XcodeSchemes.hasTests(schemeFile: contents)
    }
    let rootPackages = Set(ValidationDiscovery.rootPackages(container: container, repoPath: repoPath).map(ValidationPaths.canonical))
    let changedSubmodules = try changedSubmodulePaths()
    var packages: [LocalPackage] = []
    var descriptions: [String: SwiftPackageDescription] = [:]
    var unexamined: [String] = []
    var rootPackage: SwiftPackageDescription?
    for packageDir in packageDirs {
      let submodule = SubmoduleStatus.enclosingSubmodule(of: packageDir, repoPath: repoPath)
      let submoduleChanged = submodule.map(changedSubmodules.contains) ?? false
      if submodule != nil, config.testSubmodules == .never || (config.testSubmodules == .changed && !submoduleChanged) {
        unexamined.append(packageDir)
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
          scheme: LocalPackage.scheme(for: description, in: schemes).flatMap { scheme in
            rootPackages.contains(ValidationPaths.canonical(packageDir)) || schemeFileHasTests(scheme) ? scheme : nil
          },
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
    let schemesWithTests = Set(productSchemes.filter(schemeFileHasTests))

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
    let simulators = try needsSimulators ? self.simulators(container: container, scheme: productSchemes[0], platforms: testPlatforms, paths: paths) : [:]
    let testDestinations = simulators.mapValues(\.destination).merging([.macOS: "platform=macOS"]) { current, _ in current }

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
      simulatorNotes: testPlatforms.compactMap { simulators[$0]?.note },
      packages: packages,
      unexaminedSubmodulePackages: unexamined
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

  /// Returns the repository-relative paths of uncommitted changes, including untracked files and changed submodules.
  private func changedPaths() throws -> [String] {
    let result = try process.capture(["git", "status", "--porcelain", "-z", "--untracked-files=all"])
    guard result.status == 0 else {
      throw ToolError("Failed to read git status:\n\(result.stderr)")
    }
    return SubmoduleStatus.changedPaths(fromPorcelainZ: result.stdout)
  }

  /// Returns the repository-relative paths of submodules that differ from the commits the repository records, when
  /// the submodule policy needs them.
  private func changedSubmodulePaths() throws -> Set<String> {
    guard config.testSubmodules == .changed else { return [] }
    return Set(try changedPaths())
  }

  /// Runs the fast phase: builds what the uncommitted changes, or the named target, touched, and runs the tests that
  /// depend on it.
  private func runFast(container: [String], packageDirs: [String], paths: ValidationPaths) throws {
    let scope: FastScope
    var packages: [(directory: String, description: SwiftPackageDescription)] = []
    if let target = config.target {
      for packageDir in packageDirs {
        if let description = try? describePackage(packageDir, paths: paths) {
          packages.append((packageDir, description))
        }
      }
      scope = FastScope(targets: [target], packages: packages)
    } else {
      let changed = try changedPaths()
      let repo = ValidationPaths.canonical(repoPath)
      for packageDir in packageDirs {
        let path = ValidationPaths.canonical(packageDir)
        let relative = path == repo ? "" : path.hasPrefix("\(repo)/") ? String(path.dropFirst(repo.count + 1)) : path
        let touched = changed.contains { relative.isEmpty || $0 == relative || $0.hasPrefix("\(relative)/") || relative.hasPrefix("\($0)/") }
        if touched {
          packages.append((packageDir, try describePackage(packageDir, paths: paths)))
        }
      }
      scope = FastScope(changedFiles: changed, packages: packages, repoPath: repoPath)
    }

    if config.planOnly, !scope.assignments.isEmpty {
      print("== Changes")
      for assignment in scope.assignments {
        print(assignment)
      }
      print("== Steps")
    }
    guard !scope.isEmpty else {
      print(scope.assignments.isEmpty ? "No changes to validate." : "Nothing to build or test for these changes.")
      return
    }

    let schemes = scope.productSources.isEmpty && scope.unmatchedTargets.isEmpty || container.isEmpty ? [] : try listSchemes(container)
    let productSchemes = scope.productSources.isEmpty || container.isEmpty ? [] : try self.productSchemes(container: container, schemes: schemes, rootPackage: nil)
    var steps = ValidationPlan.fastSteps(
      for: scope,
      packages: packages,
      container: container,
      productSchemes: productSchemes,
      paths: paths,
      sandbox: sandbox,
      disableSwiftPMSandbox: config.swiftPMDisableSandbox || sandbox.isNested,
      quiet: config.outputMode != .raw
    )
    for name in scope.unmatchedTargets {
      guard !container.isEmpty, schemes.contains(name) else {
        throw ToolError(
          "Target '\(name)' was not found in the repository's Swift packages, and there is no Xcode scheme of that name. Provide --package-dirs, --workspace, or --project."
        )
      }
      let arguments = ValidationPlan.xcodebuildArguments(
        container: container,
        scheme: name,
        destination: ApplePlatform.macOS.buildDestination,
        action: "build",
        paths: paths,
        sandbox: sandbox,
        quiet: config.outputMode != .raw
      )
      steps.append(PlannedStep(title: "Build \(name) for macOS", summary: "build \(name) (macOS)", arguments: arguments, logName: "fast_build_\(name)_macOS"))
    }
    for step in steps {
      try checkNotSuperseded()
      try runStep(step, paths: paths)
    }
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

  /// Returns the simulator that runs tests on each simulator platform, choosing from those available to a scheme.
  ///
  /// When a platform has no test device for its newest installed runtime, one is created, and the destinations are
  /// listed again. Xcode can list destinations before it has loaded its simulators, so a list missing any of
  /// `platforms` is retried once and never cached.
  private func simulators(container: [String], scheme: String, platforms: [ApplePlatform], paths: ValidationPaths) throws -> [ApplePlatform: SimulatorChoice] {
    let simulatorPlatforms = platforms.filter { $0 != .macOS }
    let isComplete = { (simulators: [ApplePlatform: SimulatorChoice]) in simulatorPlatforms.allSatisfy { simulators[$0] != nil } }
    return try discovered("simulators \(container.joined(separator: " ")) \(scheme)", isComplete: isComplete) {
      let runtimes = try process.capture(["xcrun", "simctl", "list", "-j", "runtimes"])
      let newestOS = runtimes.status == 0 ? (try? TestSimulators.newestOS(runtimesJSON: runtimes.stdout)) ?? [:] : [:]
      func list() throws -> [ApplePlatform: SimulatorChoice] {
        var simulators: [ApplePlatform: SimulatorChoice] = [:]
        for _ in 1...2 where !isComplete(simulators) {
          let result = try process.capture(XcodeDestinations.showDestinationsArguments(container: container, scheme: scheme, paths: paths, sandbox: sandbox))
          guard result.status == 0 else {
            throw ToolError("Failed to list destinations for scheme '\(scheme)':\n\(result.stderr)")
          }
          simulators = XcodeDestinations.simulators(fromShowDestinations: result.stdout, newestOS: newestOS)
        }
        return simulators
      }

      let simulators = try list()
      let missing = TestSimulators.missingTestDevices(for: simulatorPlatforms, in: simulators)
      guard !missing.isEmpty, runtimes.status == 0 else { return simulators }
      var created = false
      for platform in missing {
        created = try createTestDevice(for: platform, runtimesJSON: runtimes.stdout) || created
      }
      return created ? try list() : simulators
    }
  }

  /// Creates the test device for `platform`'s newest runtime, returning `true` when it was created. Failures are
  /// reported, and validation continues with the simulators that exist.
  private func createTestDevice(for platform: ApplePlatform, runtimesJSON: String) throws -> Bool {
    let devices = try process.capture(["xcrun", "simctl", "list", "-j", "devices"])
    guard devices.status == 0, let device = try? TestSimulators.newDevice(for: platform, runtimesJSON: runtimesJSON, devicesJSON: devices.stdout) else {
      return false
    }
    let result = try process.capture(device.arguments)
    guard result.status == 0 else {
      print("Could not create simulator \(device.name) (\(device.deviceTypeName), \(device.runtimeName)): \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
      return false
    }
    print("Created simulator \(device.name) (\(device.deviceTypeName), \(device.runtimeName)) for \(platform.rawValue) tests.")
    return true
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
