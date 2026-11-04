# 0011: `agt vm` Only Touches Its Own Clones

- Status: Accepted
- Date: 2026-11-04

## Decision

`agt vm` stops, deletes and drives only the clones it made, whose names start with `agt-`. It never stops, deletes, runs or drives the configured base image, even if that image's name has the prefix. Any other VM is refused with advice to use tart directly.

tart stays an external tool: `agt` runs its executable as a subprocess, found on `PATH` or in its usual install locations, and never links it. A missing tart is a clear error that affects only `agt vm`.

## Context

The base image is prepared by hand: an auto-login test account, ssh keys, and an `agt` holding Accessibility and Screen Recording grants tied to its code hash ([0007](0007-agt-holds-its-own-privacy-permissions.md)). Clones inherit all of that by copying its disk, so losing or altering it costs a manual rebuild. `agt` is installed through Mint, which builds a plain Swift package, and most of its users never need tart. The [2026-11-04 journal entry](../Journal/2026-11-04-vm-commands.md) records the first runs.

## Consequences

- A VM created or renamed outside `agt vm` must be managed with tart, even if it was cloned from the base image.
- tart's command-line interface is a dependency without a version pin; a change to its arguments or JSON output breaks `agt vm` until `agt` is updated.
