# Running Apps in Throwaway tart Clones

`agt ui` drives a GUI session over ssh, but each check still needed a VM to be cloned, booted, reached and cleaned up by hand. This entry adds `agt vm`: `start`, `launch`, `ui`, `stop` and `list`, which run a macOS app in a disposable clone of a tart base image and drive it from the host. tart stays an external tool run as a subprocess, found on `PATH` or in its usual install locations, with a clear error when it is missing, so Mint installs are unaffected.

## Shape

- `start` clones the base image as `agt-<base>-<6 hex>`, runs `tart run --no-graphics --dir=products:<share>:ro` in the background with its output in a temporary log, then polls until `tart ip` answers, ssh works, the guest user owns `/dev/console` and Finder is running. A clone that does not become ready is stopped and deleted. `--window` drops `--no-graphics`; `--build` runs `agt validate --target <scheme>` in-process first.
- The share defaults to validation's `.build/agt/DerivedData/Build/Products/Debug`, and appears in the guest at `/Volumes/My Shared Files/products`.
- `launch` runs `open` over ssh, with launch arguments after `--args`. `ui` passes its arguments to the guest's `agt ui`; for `screenshot` the path argument is swapped for a guest temporary file, which is copied back with scp and deleted.
- `stop`, `launch` and `ui` refuse the base image and any VM whose name lacks `agt-`, and default to the only (running) clone.
- Settings live under `vm` in the layered config files, with the user's `~/.agt/config.json` as the last layer. Loading those files moved into `ConfigurationFiles`, shared by project, calendar and VM settings.
- ssh and scp always pass the tart key, `IdentitiesOnly`, tart's own `UserKnownHostsFile`, `BatchMode`, `StrictHostKeyChecking=accept-new`, a five-second connect timeout and `LogLevel=ERROR`. On a clone's first address, `start` runs `ssh-keygen -R <ip> -f <tart known_hosts>`, so a reused address never trips a mismatch, and `~/.ssh` is never touched. Commands are sent as one line built with POSIX single-quoting.

## Results

Unit tests cover settings defaults and layering, clone naming and the refusals, tart's run arguments and lookup, the ssh, scp and `ssh-keygen` command lines, quoting, the readiness and launch commands, the screenshot rewrite and the commands' parsing. The quoting and screenshot tests failed against stubs first; the rest were written with their implementations.

On Sam's Mac, outside the sandbox, with a scratch share holding a small ad-hoc signed AppKit app (TextEdit could not be copied out of `/System`): `start` was ready in 22 seconds; `launch Hello.app -- "two words" -x` opened it from the share with both arguments; `ui tree` read its label; `ui screenshot` brought back both a window and a display PNG to host paths, and no `/tmp/agt-vm-*` file stayed in the guest. A bad `ui key` combination exited with the guest's status 64. `stop --name golden-gate`, `stop --name my-vm`, `start --name golden-gate` and `launch Missing.app` all refused with clear errors. `stop` without a name deleted the only clone. A second cycle covered `--name`, `stop --keep` and deleting a stopped clone. `golden-gate` stayed stopped throughout, its disk unmodified since 15:04, before the runs; only tart's access time moved, since cloning reads it.

Full validation, run outside the sandbox because the worktree tests write git hook templates, failed once on the intermittent `RepositoryOperationLockTests.ownershipIsExclusiveAndReleased` noted in the [UI driving entry](2026-11-04-ui-driving.md), then passed all 271 tests on the next run.

Not exercised for real: `--window`, which would open a window on Sam's screen, and `--build`, for want of a configured app project here.

## Open

- A decision record is proposed but not written, pending Sam's confirmation: `agt vm` only stops, deletes or drives VMs it named (`agt-` prefix), never the configured base image, and runs tart as an external tool.
- Remote lldb into a clone remains a later stretch goal.

## Follow-up: Decision 0011

With Sam's approval, [0011](../Decisions/0011-agt-vm-only-touches-its-own-clones.md) records that `agt vm` only stops, deletes or drives `agt-` clones, never the base image, and that tart stays an external subprocess. This settles the decision record left open above.

## Follow-up: `press` Focuses Text Fields

Testing this branch against Bookish, another session found that `agt ui press link-entry.authors` failed on a SwiftUI text field with AXError -25206, since the field has no press action. Focus stayed in the title field, so the next `type` appended the author to the title. Sam asked for a fix before release.

`press` now chooses how to activate what it finds. An element with an `AXPress` action is pressed as before. One without it whose `AXFocused` attribute is settable is focused, and `press` reads the attribute back to check. If focus is refused, it clicks the centre of the element's frame clipped to its window and enclosing scroll areas, and fails with the frame when none of it is visible, instead of clicking somewhere else. Anything else is still offered the press action, so its refusal is reported as before. This extends `press` instead of adding a `focus` command: pressing is what an agent naturally tries on a field, as that session did, and the element's own actions decide what happens, so nothing has to be learnt. The output says "Focused" or "Pressed", so the caller can tell which happened. `agt vm ui` passes `press` through unchanged.

The choice between pressing and focusing, and the click point with its visibility check, are unit tested. Both failed against stubs first.

In a clone of `golden-gate` running Leaves.app from Bookish, built with `agt validate --target Bookish`, the guest's own granted `agt` reproduced the failure: after `press "New Book"` and `type`, `press link-entry.authors` failed with -25206. The new build, shared to the clone, needs its own Device Control and Data Access grant, because grants follow the code hash ([0007](../Decisions/0007-agt-holds-its-own-privacy-permissions.md)). Without one, it refused with the path to allow.
