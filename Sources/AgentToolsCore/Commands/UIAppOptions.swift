// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser

/// The `--app` option shared by `agt ui` commands that read or act on one application.
struct UIAppOptions: ParsableArguments {
  /// The application named on the command line, if any.
  @Option(name: .customLong("app"), help: "Bundle identifier or process identifier of the application (default: the frontmost one).", transform: AppTarget.init(argument:))
  var application: AppTarget?

  /// The application to act on.
  var target: AppTarget {
    application ?? .frontmost
  }
}
