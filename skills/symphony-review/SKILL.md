---
name: symphony-review
description: Internal Maestro workflow that reviews one exact managed PR head with Symphony context and risk-adaptive specialists, publishes one GitHub verdict or comment, follows up with Cursor through Linear when changes are required, and always removes owned worktrees.
user-invocable: false
---

# Review one managed PR revision

Input: `$ARGUMENTS`, supplied by `symphony-reconcile` as a complete review request.

Read completely:

- `${CLAUDE_PLUGIN_ROOT}/references/symphony/core.md`
- `${CLAUDE_PLUGIN_ROOT}/references/symphony/linear.md`
- `${CLAUDE_PLUGIN_ROOT}/references/symphony/reconciliation.md`
- `${CLAUDE_PLUGIN_ROOT}/references/symphony/review.md`

This is the only Maestro review entry point. Apply Superpowers code-review and
verification discipline through this higher-level adapter. Do not advertise or
invoke a standalone `/review` command.

## Validate review identity

Require every field in `Required review identity`. Re-read the Linear issue,
approved contract/DAG revision, GitHub PR, current head, checks/reviews, upstream
issues, downstream issues, and Symphony goal.

Return `inconclusive` without creating a worktree when:

- a required native identity is absent;
- repository routing conflicts;
- the PR repository does not match the issue;
- the requested exact PR head SHA is not the current head;
- the governing contract is ambiguous or drifted.

Record `review-stale-head` only when a previously current head changed during the
review.

## Select the risk-adaptive roster

Always dispatch `maestro:symphony-reviewer`.

Add:

- `maestro:code-reviewer` for product code, infrastructure, build, or workflow
  changes;
- `maestro:test-analyzer` when behavior or tests changed, or acceptance evidence
  depends on tests;
- `maestro:security-reviewer` for trust boundaries, auth, secrets, network inputs,
  privileged operations, dependencies, or `maestro-risk-security`;
- `maestro:comment-analyzer` when comments, public docs, schemas, or interface
  contracts materially changed.

Label selection is mandatory:

- `maestro-risk-security` selects `maestro:security-reviewer`.
- `maestro-risk-infra` selects `maestro:code-reviewer` plus available rendered
  infrastructure/workflow validators and runtime-toolchain checks.
- `maestro-risk-migration` selects the contextual, code, and test lenses and
  requires migration/rollback/compatibility evidence. Add the security lens only
when a trust boundary also applies.

read label `maestro-risk-security`

read label `maestro-risk-infra`

read label `maestro-risk-migration`

Infrastructure changes require the code reviewer to validate rendered artifacts
with available domain tools and inspect the CI runtime toolchain. Absence of a
required validator is uncertainty, not a silent pass.

## Create owned worktrees

Before any command-running reviewer starts:

1. Locate or clone/fetch the repository without checking out a user branch.
2. Use `${TMPDIR:-/tmp}/maestro-symphony-reviews` as the dedicated temporary
   review root and create one unique review directory beneath it.
3. Derive the directory name from sanitized native IDs.
4. Write an ownership marker beside the future worktree containing Symphony UUID,
   repository, PR native ID, exact PR head SHA, and review action identity. Add a
   cleanup-ledger entry with attachment state `reserved-unattached`.
5. Canonicalize root and child paths and verify component-level containment.
6. Add a detached Git worktree at the exact PR head SHA, then atomically change
   the ledger attachment state to `attached-worktree`.
7. Verify `HEAD` equals the requested SHA and tracked and staged state is clean.

Parallel command-running reviewers receive separate owned worktrees. A reviewer
that only needs the diff and supplied context receives no worktree.

Maintain an explicit cleanup ledger in memory containing repository, canonical
worktree path, canonical review directory, marker contents, expected action
identity, and attachment state for every created directory.

## Run contained validation commands

Every validation command runs with its assigned owned worktree as its exact CWD
and an explicit timeout. Immediately before and after each command, compare the
worktree's tracked and staged state. When a validation sequence cannot be safely
isolated command-by-command, make the same comparison immediately before and
after that sequence.

If a command unexpectedly changes tracked or staged state, invalidate all
dependent evidence, publish no patch, discard and clean that worktree, and return
`inconclusive`. On timeout, terminate the command, classify `validation-timeout`,
clean the worktree, and return `inconclusive`. A command-running reviewer may
never repair, stage, commit, or otherwise preserve a product-code change.

## Dispatch reviewers

Dispatch the selected reviewers in parallel with a self-contained envelope:

```text
full Required review identity
Symphony outcome and constraints
implementation issue contract and acceptance criteria
approved DAG revision
upstream outputs and downstream assumptions
base/head diff
relevant repository instruction paths
assigned owned worktree or explicit diff-only mode
time-bounded validation commands
required Common finding contract
```

No reviewer receives permission to edit or publish.

## Validate and aggregate

Reject a result whose reviewed PR, head SHA, contract revision, or review-policy
revision differs from the request.

Deduplicate identical underlying findings while preserving sources. Retain
distinct concerns on the same line. Validate every requested outcome against
evidence; remove unsupported findings rather than forwarding speculation.

Aggregate:

- `changes-required` when any confirmed blocker/major finding exists;
- `human-decision` when the implementation requires an objective, scope,
  acceptance, strategic DAG, or architecture decision;
- `inconclusive` when a required lens lacks evidence;
- `pass` only when all required lenses pass and evidence covers the implementation
  issue's required validation commands and required acceptance evidence.

Missing required validation evidence or an unavailable required validator yields
`inconclusive`; a confirmed product defect yields `changes-required`.

Return exactly the verdict selected by those conditions:

return review verdict `pass`

return review verdict `changes-required`

return review verdict `human-decision`

return review verdict `inconclusive`

Repository CI, review, and merge gates are not prerequisites for a Symphony
review `pass`. That verdict means Maestro's exact-SHA contextual review passed;
`symphony-reconcile` separately reconstructs repository merge readiness, while
Cursor owns CI/review convergence.

Never implement the fix, generate a patch, or ask a reviewer to do so.

## Revalidate before publication

Immediately before publishing, re-read and compare both the current GitHub head
and the Linear issue contract and approved DAG revision. If the current head
differs from the exact PR head SHA:

1. publish nothing;
2. classify `review-stale-head`;
3. append `review-stale-head` only if the unpublished attempt consumed an
   expensive retry;
4. clean every worktree;
5. return the new head to `symphony-reconcile`.

If the Linear contract or approved DAG drifted, suppress stale publication and
follow the semantic-drift/human-decision policy instead of publishing a verdict
against obsolete governance.

## Publish the outcome

For `pass`, submit an approving review when the authenticated identity may do so.
If it cannot approve, post one top-level PR comment recording the passed Symphony
review and exact SHA.

For `changes-required`, submit one consolidated request-changes review when
permitted; otherwise post the same content as one top-level PR comment. Each
finding includes violated criterion/contract, location, evidence, and required
outcome.

Never tag `@Cursor` in the fallback GitHub comment. The subsequent Linear comment
is the only implementation follow-up channel.

After the canonical GitHub record is confirmed, add one Linear comment mentioning
`@Cursor`, with the exact reviewed SHA, review/comment link, and concise numbered
required outcomes. This Linear comment is the implementation follow-up channel.

For `human-decision`, publish a non-approving review/comment and record the
prior/resume phase. Apply `maestro:scope-change` for a strategic contract/DAG
revision or `maestro:needs-human` for a bounded decision. Do not mention `@Cursor`
unless Cursor has a concrete implementation action.

apply label `maestro:scope-change`

apply label `maestro:needs-human`

For `inconclusive`, publish only when the missing evidence itself requires action.
Otherwise append `action-failed` and allow bounded retry.

Append one `review-recorded` event for a confirmed published `pass`,
`changes-required`, or `human-decision` result, with the action identity, attempt,
exact SHA, outcome, evidence link, and next transition. Also append
`human-decision-required` for the latter. For an unpublished `inconclusive`
attempt, append `action-failed` with its finite failure category. Use
`review-stale-head` and `cleanup-failed` only as declared by the core vocabulary.

append event `review-recorded`

append event `review-stale-head`

append event `human-decision-required`

append event `action-failed`

## Cleanup guarantee

Cleanup runs after pass, changes required, human decision, inconclusive result,
stale head, tool failure, reviewer failure, and publication failure.

For each cleanup-ledger entry:

1. Canonicalize paths again.
2. Verify component-level containment beneath the dedicated root.
3. Read and match the ownership marker and expected action identity.
4. Branch on the explicit attachment state:
   - For `attached-worktree`, confirm Git worktree metadata matches the expected repository and canonical path. Remove the expected worktree through Git,
     then remove only expected owned transient artifacts.
   - For `reserved-unattached`, freshly prove attachment state is false and prove
     no repository/worktree metadata, checkout, unexpected file, or unexpected
     contents exists. Remove only the known empty reservation and marker artifacts
     without requiring Git worktree metadata.

Marker mismatch, unexpected contents, ambiguous attachment, containment failure,
or Git metadata mismatch never permits deletion. Journal a `cleanup-failed`
event once, retain the exact owned path, and retry only after a new safe observation.

Apply this attachment-state branch on success, failure, timeout, stale head, reviewer error, and publication failure.

append event `cleanup-failed`

Return to `symphony-reconcile`:

```markdown
## Symphony review result
Outcome:
Review action identity:
Reviewed head:
GitHub record:
Linear @Cursor follow-up:
Cleanup:
Failure category:
Next transition:
```

## Classify review attempts

Every review read, validation, publication, and cleanup attempt emits exactly one
outcome and consumes it to choose the next transition:

emit outcome `confirmed`

consume outcome `confirmed`

emit outcome `ambiguous`

consume outcome `ambiguous`

emit outcome `retryable-failure`

consume outcome `retryable-failure`

emit outcome `permanent-failure`

consume outcome `permanent-failure`

When the outcome requires a category, emit one applicable category and consume
it with the adjacent retryability rule:

emit failure category `observation-failed`

consume failure category `observation-failed`
Retryability: Retry the read later; authorize no dependent mutation

emit failure category `observation-incomplete`

consume failure category `observation-incomplete`
Retryability: Resolve directly by native ID before retrying the dependent action

emit failure category `external-transient`

consume failure category `external-transient`
Retryability: Retry the affected operation while unrelated work continues

emit failure category `mutation-ambiguous`

consume failure category `mutation-ambiguous`
Retryability: Search by native target and action identity before any retry

emit failure category `semantic-drift`

consume failure category `semantic-drift`
Retryability: Do not retry mutation; require bounded decision or strategic revision

emit failure category `review-stale-head`

consume failure category `review-stale-head`
Retryability: Do not retry the stale identity; create a new identity for the new head

emit failure category `validation-timeout`

consume failure category `validation-timeout`
Retryability: Terminate, clean up, and retry only within the unchanged-state budget

emit failure category `capability-lost`

consume failure category `capability-lost`
Retryability: Pause dependent operations until capability changes

emit failure category `cleanup-failed`

consume failure category `cleanup-failed`
Retryability: Retry only ownership-checked cleanup; blocks Symphony closeout

emit failure category `permanent-invalid`

consume failure category `permanent-invalid`
Retryability: Do not retry unchanged state; require human correction
