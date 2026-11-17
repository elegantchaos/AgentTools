# PR #17 Review Fixes

Addressed all six findings in the [PR #17 review](../Reviews/PR17%20Review%202026-11-16.md).

- The history search considers target additions between edits to the linking document, including merges that first bring the document and target together. It verifies that the document still carries the link at the candidate commit and keeps the fallback for links that never resolved. Target additions are cached by path; ordinary introducing-commit resolutions retain their existing fast path.
- The shared Markdown scanner tracks opening brackets, escaped punctuation, fences and multiline code spans. It reads multiline inline destinations and reference definitions while retaining replacement ranges in the original text. Checking, historical matching and rewriting use that same scanner.
- Markdown destination escapes and named or numeric character references are decoded before URL delimiters and percent escapes are interpreted. Foundation's existing Markdown parser supplies character-reference decoding; no dependency was added. Permalink anchors protect decoded brackets and parentheses while preserving existing URL escapes.
- Submodule targets use recursively built, case-exact Git indexes. Ancestor directories include gitlinks even when a module is not initialised, and unavailable nested modules retain their full path in unverified reports.
- Dry-run output now identifies the first commit where the link resolved, which need not be the commit that added the link. README behaviour and examples remain aligned.

## Validation

Added regression tests before changing the implementation. The first targeted run built successfully and failed with 17 expected assertions covering all six findings; existing tests passed. The fixes passed all 317 tests. Additional history and end-to-end cases exposed the separate-branch merge case, which failed before its fix; the suite then passed all 320 tests. Anchor punctuation and the revised dry-run wording were also checked failing before their changes.

Final targeted validation with `agt validate --target AgentToolsCore` passed all 321 tests in 46 suites. `agt format` completed without lint findings. Full validation of the committed change is the remaining gate; its result will be recorded below when complete.

The first build spent several minutes in SwiftPM planning, then completed without intervention. A read-only process sample confirmed it was waiting in llbuild process handling; no service was stopped or environment setting changed. The sample was removed. Test fixtures clean themselves up.

## Full Validation Result

`agt validate --full` passed the macOS product build and all 321 tests in 46 suites for commit `068d54312e928917adeb790b7129ea762510fcae`. The final code change after targeted validation removed the index's unused stored repository path; full validation covers that cleanup too. No lint findings remained, and `git diff --check` passed.

The rebuilt product's `agt links --fix-history --dry-run` found only the four pre-existing broken decision links in `2026-09-24.md` and resolved all four at `959ea98c73a620d6e4c9a87d56ae06bd92b73bc3`. Its exit status was 1, as documented for a dry run that leaves fixable links unchanged. No historical documents were repaired by this check. Temporary review files and test fixtures were removed.

The original Bookish replay and other Swift toolchain versions were not repeated. The new real-repository regression cases cover the six findings, separate-branch merges, periods when the link is absent, nested unavailable modules, and end-to-end multiline repair with escaped Unicode destinations. Subsequent changes only record this validation result.
