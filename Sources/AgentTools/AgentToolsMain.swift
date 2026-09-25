// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 25/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import AgentToolsCore

/// Entry point for the `agt` executable.
///
/// It only runs `AgentToolsCommand`. Everything else lives in `AgentToolsCore`, which the tests import,
/// so no test build has to link, or rename, this `main`.
@main
enum AgentToolsMain {
  /// Parses the command line and runs the selected command.
  static func main() async {
    await AgentToolsCommand.main()
  }
}
