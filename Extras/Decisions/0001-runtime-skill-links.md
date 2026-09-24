# 0001: Runtime Skill Links

- Status: Accepted
- Date: 2026-09-24

## Context

`agt skills link` writes into runtime skill directories that `agt` does not own. Those directories can hold skills installed by the runtime itself or by the user, alongside links to shared skills.

## Decision

`agt skills link` links each discovered skill into every runtime's own skills directory. It only ever replaces an existing symlink; any other file or directory with a skill's name is left in place and reported as an error.

## Alternatives

- Rejected: replacing whatever occupies a skill's name.
- Rejected: a single shared link directory that every runtime reads.

## Consequences

- `agt` never deletes skill content it did not create.
- Name collisions with runtime-installed skills need manual resolution.
- The set of runtimes and their directories follows the Agents repository; supporting another runtime means adding a link destination.
