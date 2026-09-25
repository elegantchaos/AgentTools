# 0005: `agt` Manages Agents' Helper Scripts

- Status: Draft
- Date: 2026-09-25

## Context

Claude and Codex often write small helper scripts, usually Python, to perform an action. Each one is written, used once and deleted, even when an earlier session wrote the same thing. Nothing records which helpers recur, so none of them get reused, improved or turned into proper tools.

Guidance alone will not change this. Writing a fifteen-line script costs an agent almost nothing, so an instruction to check for an existing one first gets skipped. Any reuse scheme needs discovery that is cheaper than rewriting, usage accounting that does not depend on agent discipline, and enforcement.

Both runtimes support `PreToolUse` hooks with near-identical contracts: JSON on stdin with `tool_name` and `tool_input`, and blocking by exit code `2` with a reason on stderr, or by `hookSpecificOutput.permissionDecision: "deny"`. Both can load hooks from a plugin's `hooks/hooks.json`, and the shared `baseline` plugin already has both Claude and Codex manifests. Codex hooks are experimental and need a one-off trust approval of the hook definition's hash.

## Decision

`agt` owns the whole lifecycle of agents' helper scripts through an `agt script` command: finding, creating, running, usage accounting, review, promotion and retirement. Agents use it instead of writing inline or scratch scripts.

- Scripts are data in a store in the shared Agents repository, outside `agt`. Adding a script never needs a rebuild of `agt`.
- There are two tiers: an incubator, which takes anything with no ceremony and expires unused scripts, and a curated set with a short index agents read. Promotion to a native `agt` subcommand, rewritten in Swift, is the final tier.
- Each script's metadata lives in a header in the script. Indexes are generated from the headers and never maintained by hand.
- `agt script new` searches the store with the proposed summary first, and refuses to create a script when close matches exist unless forced.
- Creation and every run are logged by `agt`, as JSON lines in a machine-local file outside git. Agents never record usage themselves.
- A `PreToolUse` hook, `agt script guard`, blocks inline interpreter use and running scripts from scratch locations, and points the agent at `agt script`. It is shipped once in the `baseline` plugin for both runtimes. The hook definition stays a fixed one-liner, and all its logic lives in `agt`, so changes to the guard never invalidate Codex's hook trust.
- The review of the store is part of `baseline:refresh`, and it works from the usage log and from inline scripts found in Claude and Codex transcripts.

## Alternatives

- Rejected: a store and index maintained by the agents, with an instruction in `COMMON.md`. Agents skip the lookup and forget to record usage, so the index drifts and the counts are worthless.
- Rejected: a separate dispatcher command alongside `agt`. It splits search, accounting and promotion across two tools for no gain.
- Rejected: asking agents to judge whether a script is reusable before saving it. They judge this badly; saving everything to an expiring incubator and letting usage decide gives better evidence.
- Retained for later: mining transcripts for inline scripts as the only source of candidates. It needs no agent cooperation, but finds candidates only after the fact. It becomes part of the review instead.

## Consequences

- `agt` gains a `script` command family and a hook entry point. Its code goes in `AgentToolsCore`, following [0004](0004-executable-is-only-an-entry-point.md).
- The Agents repository gains the store, a two-line instruction in `COMMON.md`, the hook in the `baseline` plugin and a review section in `baseline:refresh`.
- Codex sessions need a writable root for the store and the usage log, and a one-off `/hooks` trust approval for the plugin hook.
- Agents lose the ability to run inline Python unobserved. The guard needs an escape hatch for legitimate one-liners, and uses of it are logged.
- Guidance that tells agents to write temporary scripts, including the temporary file rule in `COMMON.md`, must be checked for conflicts with the guard.
