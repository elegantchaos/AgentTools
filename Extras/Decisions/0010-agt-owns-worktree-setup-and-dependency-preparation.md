# 0010: AgentTools Owns Worktree Setup And Dependency Preparation

- Status: Accepted
- Date: 2026-10-29

## Decision

AgentTools owns development worktree creation and dependency preparation, including the conventions and setup needed to make a checkout ready for validation. Shared guidance invokes these capabilities rather than independently implementing their rules. Preparation is also available for an existing checkout.

Preparation is separate from building and testing. Successful preparation is not validation evidence.

AgentTools commands remain within the caller's permissions and do not escalate themselves. Authorization for broader execution and runtime-specific checkout attachment or working-context changes belong to the invoking runtime and its guidance.

## Context

Fresh checkouts can require Git metadata writes to materialise dependencies before sandboxed test runs. Owning setup in one tool keeps its paths aligned with validation and lets authorization happen before TDD starts.
