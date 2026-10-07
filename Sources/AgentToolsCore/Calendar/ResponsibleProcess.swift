// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Darwin

/// Wrappers around macOS's private process-responsibility functions.
///
/// macOS charges a privacy permission to a process's responsible process, normally the app that started it, such as
/// Terminal. A process started with the disclaim attribute is responsible for itself, so a permission it is granted
/// belongs to its own executable. Processes it starts inherit that responsibility. The functions are looked up at run
/// time, so `agt` still runs if they disappear.
enum ResponsibleProcess {
  /// Returns whether the current process is its own responsible process, or `nil` when the private function is
  /// unavailable.
  static func isSelfResponsible() -> Bool? {
    guard let responsiblePID = symbol("responsibility_get_pid_responsible_for_pid", as: ResponsiblePIDFunction.self) else { return nil }
    let pid = getpid()
    return responsiblePID(pid) == pid
  }

  /// Runs `executable` with `arguments` and `environment` as its own responsible process, sharing this process's
  /// standard streams, and returns its exit status once it finishes.
  ///
  /// A process killed by a signal returns 128 plus the signal number, as a shell reports it.
  static func runDisclaimed(executable: String, arguments: [String], environment: [String: String]) throws -> Int32 {
    guard let setDisclaim = symbol("responsibility_spawnattrs_setdisclaim", as: SetDisclaimFunction.self) else {
      throw ToolError("This version of macOS does not provide the private function agt needs to run as its own responsible process.")
    }
    var attributes: posix_spawnattr_t?
    posix_spawnattr_init(&attributes)
    defer { posix_spawnattr_destroy(&attributes) }
    guard setDisclaim(&attributes, 1) == 0 else {
      throw ToolError("Could not set up \(executable) to run as its own responsible process.")
    }

    let argv = ([executable] + arguments).map { strdup($0) } + [nil]
    let envp = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
    defer {
      for string in argv + envp {
        free(string)
      }
    }

    var pid = pid_t()
    let spawnResult = posix_spawn(&pid, executable, nil, &attributes, argv, envp)
    guard spawnResult == 0 else {
      throw ToolError("Could not start \(executable): \(String(cString: strerror(spawnResult))).")
    }

    var status: Int32 = 0
    while waitpid(pid, &status, 0) == -1 {
      guard errno == EINTR else { throw ToolError("Lost track of \(executable): \(String(cString: strerror(errno))).") }
    }
    let signal = status & 0x7f
    return signal == 0 ? (status >> 8) & 0xff : 128 + signal
  }
}

extension ResponsibleProcess {
  /// The signature of `responsibility_get_pid_responsible_for_pid`, which returns the responsible process for a pid.
  private typealias ResponsiblePIDFunction = @convention(c) (pid_t) -> pid_t

  /// The signature of `responsibility_spawnattrs_setdisclaim`, which sets or clears the disclaim spawn attribute.
  private typealias SetDisclaimFunction = @convention(c) (UnsafeMutablePointer<posix_spawnattr_t?>, Int32) -> Int32

  /// Looks up the C function `name` in the loaded images, or returns `nil` when it is missing.
  private static func symbol<Function>(_ name: String, as type: Function.Type) -> Function? {
    let defaultHandle = UnsafeMutableRawPointer(bitPattern: -2)
    return dlsym(defaultHandle, name).map { unsafeBitCast($0, to: type) }
  }
}
