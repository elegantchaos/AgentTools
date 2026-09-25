// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// Whether validation runs inside another sandbox, such as an agent's, and the arguments that account for it.
///
/// SwiftPM and Xcode run manifests, plugins, macros, and build scripts in sandboxes of their own, which
/// cannot start inside another sandbox. When validation is already sandboxed, it turns those sandboxes off.
struct EnclosingSandbox {
  /// Whether validation runs inside another sandbox.
  let isNested: Bool

  /// Detects an enclosing sandbox by trying to start an empty one.
  static func detect(using process: ValidationProcess) throws -> EnclosingSandbox {
    let result = try process.capture(["sandbox-exec", "-p", "(version 1)(allow default)", "/usr/bin/true"])
    return EnclosingSandbox(isNested: isNestedFailure(status: result.status, stderr: result.stderr))
  }

  /// Returns `true` when starting a sandbox failed because the process is already sandboxed.
  static func isNestedFailure(status: Int32, stderr: String) -> Bool {
    status != 0 && stderr.contains("sandbox_apply: Operation not permitted")
  }

  /// Xcode defaults, passed to every `xcodebuild` invocation, that turn off package manifest and plugin sandboxes.
  var xcodebuildDefaults: [String] {
    isNested ? ["-IDEPackageSupportDisableManifestSandbox=YES", "-IDEPackageSupportDisablePluginExecutionSandbox=YES"] : []
  }

  /// Build settings, passed to `xcodebuild` builds and tests, that turn off macro plugin and build script sandboxes.
  var xcodebuildBuildSettings: [String] {
    isNested ? ["SWIFTC_DISABLE_SANDBOX=YES", "ENABLE_USER_SCRIPT_SANDBOXING=NO"] : []
  }
}
