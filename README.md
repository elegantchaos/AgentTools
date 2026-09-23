# AgentTools

[![Tests](https://github.com/elegantchaos/AgentTools/actions/workflows/Tests.yml/badge.svg)](https://github.com/elegantchaos/AgentTools/actions/workflows/Tests.yml)
[![Latest release](https://img.shields.io/github/v/release/elegantchaos/AgentTools)](https://github.com/elegantchaos/AgentTools/releases)
[![Swift 6.2](https://img.shields.io/badge/swift-6.2-F05138.svg)](https://swift.org)
![Platform: macOS](https://img.shields.io/badge/platform-macOS-lightgrey.svg)

Command-line maintenance tools for the shared [Agents](https://github.com/elegantchaos/Agents) repository.

## Installation

Install the latest release with [Mint](https://github.com/yonaskolb/Mint):

```shell
mint install elegantchaos/AgentTools
```

## Usage

Run `agt` from the root of the Agents repository. Set `AGENTS_REPO_ROOT` to use a different checkout.

```shell
agt <command>
```

### Rules

Inspect differences between canonical shared rules and Codex runtime copies:

```shell
agt rules status
```

Synchronize canonical rules into the runtime rules directory:

```shell
agt rules sync
```

### Skills

Initialize or update all public skill submodules to their recorded revisions:

```shell
agt skills sync --all
```

Rebuild runtime skill links in `~/.codex/skills` and `~/.claude/skills` (or under `CODEX_HOME` and `CLAUDE_CONFIG_DIR` when set). Existing links are replaced; any other file or directory with a skill's name is left in place and reported as an error:

```shell
agt skills link
```

Inspect submodule and runtime-link status:

```shell
agt skills status
```

Audit skills for publication blockers:

```shell
agt skills audit --all
```

## Development

```shell
swift build
swift test
```
