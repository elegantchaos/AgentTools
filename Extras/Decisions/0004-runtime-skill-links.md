# 0004: Runtime Skill Links

- Status: Accepted
- Date: 2026-09-23 (recorded 2026-09-24)

## Context

Claude Code does not read `~/.agents/skills`, so a single shared link directory no longer reaches every runtime. `~/.codex/skills` also holds real skill directories installed by Codex.

## Decision

`agt skills link` links each discovered skill into every runtime's own skills directory: `~/.codex/skills` and `~/.claude/skills`, honouring `CODEX_HOME` and `CLAUDE_CONFIG_DIR`. Linking replaces existing symlinks only; any other file or directory with a skill's name is left in place and reported as an error.

## Alternatives

- Rejected: the shared `~/.agents/skills` directory and its `AGENTS_SKILLS_DIR` override.
- Rejected: replacing whatever occupies a skill's name.

## Consequences

- Adding a runtime means adding a link destination.
- Name collisions with runtime-installed skills need manual resolution.
