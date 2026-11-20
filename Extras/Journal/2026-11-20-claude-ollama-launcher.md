# Local Claude Code Launcher

Added `agt claude` to launch the restricted account's loopback Ollama server in Claude Code, starting on `gpt-oss:20b` by default. It uses Ollama's model IDs in the picker, a disposable Claude configuration and the tool-free parameters from the interactive probe. It requires a terminal and an already-running server. The [usage guide](../../README.md#local-claude-code) documents the command.

The red test reproduced the missing command. Formatting, the executable target build and all 326 AgentTools tests passed after implementation. A terminal smoke test opened Claude Code 2.1.281, showed the installed Ollama models in `/model`, and removed the disposable configuration on exit. Both normal Claude settings checksums matched across the smoke test. Ollama logged the inventory request and no inference request from the smoke test.

## CI Simplification

PR 22 also reduces the generated test workflow to one release test job on Swift 6.2 and macOS 26, covering the package's minimum toolchain. SwiftWorkflowBuilder 3.0.1 regenerated the workflow from `.swift-ci.json`. The separate Xcode 27 build and macOS 26 runtime check remain in place. `actionlint` passed for the regenerated workflow.

The final compiler selection uses `swiftLatest`. SwiftWorkflowBuilder 3.0.1 resolved it to Swift 6.4 on the `xcode-27` runner. Release tests and the separate runtime check remain enabled. Regenerating twice produced identical output, and `actionlint` passed.
