# Markdown Link Check And History Repair

Bookish's decision log was renumbered and pruned on 11 November, which broke about 220 links from journal entries and archived reviews. A prototype script converted them to GitHub permalinks in Bookish PR #140. `agt links` makes that a command, so a change that moves or removes a file can repair the records that cited it.

## What Was Built

`agt links` scans tracked Markdown files and reports relative links whose target is missing, exiting non-zero when there are any. `agt links --fix-history [paths…]` rewrites broken links in historical records, by default `Extras/Journal` and `Extras/Reviews`, as permalinks built from the `origin` remote. `--dry-run` reports without writing. The README describes the behaviour.

The code is in `Sources/AgentToolsCore/Links`. `MarkdownLinkScanner` finds destinations, `RepositoryIndex` and `LinkChecker` judge them against Git's file listing, `LinkingFileHistory` finds the revision for a broken link, and `LinksTool` runs a check or a repair. `GitQuery` in `Support` runs read-only Git commands; `WorktreeCreator` now uses it too.

## Findings

- `git log --follow --reverse` does not follow renames: it listed only the commits after a document's move. The history is read newest first and reversed in code.
- Git lists paths case-exactly, and macOS file systems usually do not. Checking targets against `git ls-files` output catches links that differ from their target by case, which a file-system check would pass and GitHub would not.
- "The document's content at that commit contains the link" cannot mean the same text. Bookish's reviews were moved into `Extras/Reviews/Archive` with their links respelled from `../Decisions/…` to `../../Decisions/…`, after the targets had gone. Matching on text alone sent 105 of those links to the fallback. A link is now recognised in an older revision by either its text or the repository path it named.
- A file too small for Git's similarity threshold is not followed through a move that also edits it. That only affected a test fixture, which now has body text.

## Checks

The tests build real repositories under `.build/tmp`: a renamed target, a deleted one, a moved linking file, a moved and respelled link, a link that never resolved, a target that never existed, an anchor, percent-encoded and non-ASCII paths, a submodule that is not checked out, a dry run and a shallow clone. The implementation was written before the tests were first run, so the tests were then checked by breaking four behaviours in turn: rename following, fence skipping, the fallback and the shallow-clone refusal. Each break failed its test.

The command was replayed on a scratch clone of Bookish at the commit before PR #140's repair. It found 234 broken links and repaired all of them at the commit that introduced the link, leaving none broken. The result matched the prototype's committed output in every file but one: for two links in the `command-façade-environment` entry the prototype had fallen back to a later commit, and `agt links` found the commit that added them.

## Open

- The rule for links in historical records is in [Agents #47](https://github.com/elegantchaos/Agents/pull/47), which now names the command. It merges after this is released, since the Agents repository can only depend on a released `agt`.
- Historical folders are the two defaults or the paths given on the command line. A project with other locations has no configuration key for them.
- Permalinks are GitHub only. A repository whose `origin` is elsewhere can check links but not repair them.
