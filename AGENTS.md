## Project Specific Rules

- This repository is a Swift package that provides the `agt` CLI for maintaining the shared Agents repository.
- Keep a development journal in `Extras/Journal/`.

## Standard Rules

- Understand request boundaries, inspect relevant code, tests, manifests, and documentation, then make a focused change that addresses the root cause.
- Keep code modern, idiomatic, simple, and explicit; maintain DRY and a single source of truth, avoid hidden coupling, and do not add speculative abstractions or unrelated refactors.
- Update documentation when behavior, commands, workflows, or configuration change, and describe the current state rather than historical migration details.
- Add or update tests for behavior changes, using red/green TDD for non-UI code.
- Create previews for UI code when the platform supports them.
- Run the narrowest validation that proves the change first, broaden to relevant project checks, and report skipped validation, validation gaps, and residual risk.
- Prefer trusted primary sources for technical decisions, especially official language, platform, package, API, and dependency documentation.
- Use portable path references in documentation and guidance; prefer repository-relative paths for files in this repository and `~/...` home-relative paths for shared resources outside it.
- Never expose or commit credentials or secrets, and never perform irreversible destructive actions without explicit approval.
- If unexpected workspace changes appear, pause and confirm direction before proceeding.

## Skills

- Follow the `coding-standards` skill for all coding.
- Use the `swift` skill for baseline Swift language, package, and API design guidance.
- Use the `swift-testing-pro` skill for Swift Testing work in `Tests/`.
- Use the `validation-flow` skill for post-change validation in this Swift repository.
- Use the `codex-git` skill for git operations.
- Use the `codex-github` skill for GitHub and release operations.

To refresh this file, use the `refresh` skill.
