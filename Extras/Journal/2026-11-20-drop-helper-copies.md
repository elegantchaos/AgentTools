# Drop the ensure-agt.sh Drift Check

The Agents repository no longer has `ensure-agt.sh` ([Agents #60](https://github.com/elegantchaos/Agents/pull/60)). Its new `baseline:tools` skill installs and updates `agt` with Mint at the start of each session, and a new machine is set up by hand with `brew install mint` and `mint install elegantchaos/AgentTools`.

`agt refresh` checked plugin copies of the script against a hard-coded canonical path, and threw when that file was missing, which would have stopped every refresh once the script went. `HelperCopies` and its test are deleted, and the refresh help and README now name `mint install` for updating `agt`. `agt` Is the Agents Repository's Only Dependency (0006) is revised: it no longer names a bootstrap exception. Targeted validation of `AgentToolsTests` passed.
