# 0006: `agt` Is the Agents Repository's Only Dependency

- Status: Accepted
- Date: 2026-09-29

## Context

The shared Agents repository kept maintenance scripts alongside `agt`: `scripts/refresh` in bash, and `scripts/configure-sandboxes` in Python. Each brought its own dependencies: `jq`, a Python version pinned by `.tool-versions`, and the `claude` and `codex` commands being on `PATH`. A refresh on a new machine failed because the pinned Python was not installed, and then skipped plugin installation because neither runtime's command was on `PATH`. The Python script also gave up on a multi-line array in Codex's configuration and asked for a hand edit.

## Decision

Every script the Agents repository needs is an `agt` command, so `agt` is the only tool the repository depends on. The one exception is `ensure-agt.sh`, the bootstrap that installs or updates `agt` itself, which stays a small shell script copied into each plugin that needs `agt`.

## Alternatives

- Rejected: keeping the scripts and documenting their dependencies. Each new script can add a runtime and its version, and failures show up on a machine that lacks one, as the Python pin did.
- Rejected: making `agt refresh` update `agt` itself. A running binary cannot reliably replace itself, and the bootstrap already does this with `--update`.
- Retained for later: third-party scripts that plugins bundle unchanged, such as the `swift:swiftui-trace` analyzer, which has no licence to port it under. They stay as they are until they can be rewritten or their licence allows porting.

## Consequences

- `agt refresh` replaces `scripts/refresh`, and `agt sandbox configure` replaces `scripts/configure-sandboxes`. The Agents repository's skills and documentation name the commands, and require the `agt` release that added them.
- New maintenance behaviour for the Agents repository is added to `agt`, in `AgentToolsCore` following [0004](0004-executable-is-only-an-entry-point.md), rather than as a script there.
- Changes to what the Agents repository needs from `agt` require an `agt` release before the Agents repository can depend on them.
- This complements [0005](0005-agt-manages-agent-scripts.md), whose final tier promotes agents' recurring helper scripts to native `agt` commands.
