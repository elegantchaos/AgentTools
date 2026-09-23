# Release Notes

## 2.0.1

- `agt skills link` links skills into `~/.codex/skills` and `~/.claude/skills`, honouring `CODEX_HOME` and `CLAUDE_CONFIG_DIR`.
- `agt skills status` reports link status for each runtime directory.
- Linking refuses to replace any runtime path that is not a symlink.
- No longer uses `~/.agents/skills` or the `AGENTS_SKILLS_DIR` override.

## 2.0

- Reads shared rules from `runtimes/codex/rules` in the Agents repository.
- Detects the Agents repository root by `skills/`, `runtimes/`, and `COMMON.md`.
- Breaking: Agents checkouts that still use the top-level `codex/` layout are no longer recognised.

## 1.0

Initial standalone release.

- Adds the `agt` command-line tool.
- Synchronizes shared Codex rules into runtime copies.
- Synchronizes, links, reports, and audits shared skills.
- Supports explicit Agents checkout selection through `AGENTS_REPO_ROOT`.
