# Local Claude Code Launcher

Added `agt claude` to launch the restricted account's loopback Ollama server in Claude Code, starting on `gpt-oss:20b` by default. It uses Ollama's model IDs in the picker, a disposable Claude configuration and the tool-free parameters from the interactive probe. It requires a terminal and an already-running server. The [usage guide](../../README.md#local-claude-code) documents the command.

The red test reproduced the missing command. Formatting, the executable target build and all 326 AgentTools tests passed after implementation. A terminal smoke test opened Claude Code 2.1.281, showed the installed Ollama models in `/model`, and removed the disposable configuration on exit. Both normal Claude settings checksums matched across the smoke test. Ollama logged the inventory request and no inference request from the smoke test.
