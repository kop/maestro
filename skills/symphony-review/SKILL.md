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

Consume only a durably confirmed request whose Symphony UUID, implementation
issue UUID, PR native ID, base/head SHAs, governance revisions, source-closure
revision, authoritative review-source requirements and revision,
acceptance-evidence manifest/revision, complete required evidence
manifest, applicable matching decision-resolutions, review input revision, and
Review PR action identity match this invocation.

rule symphony-review-consume-event-review-requested | when canonical-review-input-revision-is-durably-confirmed | consume event `review-requested` | next review-revision-eligible | choice none

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

rule symphony-review-read-label-maestro-risk-security | when issue-label-or-changed-surface-has-security-risk | read label `maestro-risk-security` | next security-lens-selected | choice none

rule symphony-review-read-label-maestro-risk-infra | when issue-label-or-changed-surface-has-infrastructure-risk | read label `maestro-risk-infra` | next infrastructure-lens-selected | choice none

rule symphony-review-read-label-maestro-risk-migration | when issue-label-or-changed-surface-has-migration-risk | read label `maestro-risk-migration` | next migration-lenses-selected | choice none

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
confirmed review-requested record and exact review input revision
confirmed authoritative review-source requirements record/revision
confirmed review-source-closure-v1 descriptor/revision
complete typed acceptance-evidence manifest/revision
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

Reject a result when Symphony UUID, implementation issue UUID, PR native ID, base SHA, head SHA, contract revision, DAG revision, review-policy revision, review input revision, or Review PR action identity differs from the request.

Deduplicate identical underlying findings while preserving sources. Retain
distinct concerns on the same line. Validate every requested outcome against
evidence; remove unsupported findings rather than forwarding speculation.

Normalize the aggregate into three booleans: strategic decision present, actionable defect present, and required evidence missing. A strategic decision
means the implementation requires an objective, scope, acceptance, strategic DAG,
product, or architecture decision. An actionable defect means a confirmed
blocker/major finding or product defect. Required evidence includes every required
lens, all required validation commands, and all required acceptance evidence.

Select exactly one verdict in this precedence order:

1. `human-decision` when strategic decision is present, regardless of defect or
   missing evidence;
2. otherwise `changes-required` when actionable defect is present, regardless of
   missing evidence;
3. otherwise `inconclusive` when required evidence is missing;
4. otherwise `pass`.

Missing required validation evidence or an unavailable required validator yields
`inconclusive`; a confirmed product defect yields `changes-required`.

Return exactly the verdict selected by those conditions:

rule symphony-review-return-review-verdict-pass | when aggregate-strategic-decision-actionable-defect-and-required-evidence-are-absent | return review verdict `pass` | next review-passed | choice review-verdict

rule symphony-review-return-review-verdict-changes-required | when aggregate-strategic-decision-is-absent-and-actionable-defect-is-present | return review verdict `changes-required` | next review-changes-required | choice review-verdict

rule symphony-review-return-review-verdict-human-decision | when aggregate-strategic-decision-is-present | return review verdict `human-decision` | next review-human-decision | choice review-verdict

rule symphony-review-return-review-verdict-inconclusive | when aggregate-strategic-decision-and-actionable-defect-are-absent-and-required-evidence-is-missing | return review verdict `inconclusive` | next review-inconclusive | choice review-verdict

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

Every formal review or fallback comment embeds
`Maestro-GitHub-Review-Publication-Identity: <complete publication identity>`,
`Maestro-Review-Input-Revision: <review input revision>` and
`Maestro-Review-Action-Identity: <review action identity>`. Search the full
GitHub publication identity on the exact PR/head/input revision before
publication and after an ambiguous response; suppress retry and Linear follow-up
until exactly one canonical GitHub record is confirmed.

For `changes-required`, submit one consolidated request-changes review when
permitted; otherwise post the same content as one top-level PR comment. Each
finding includes violated criterion/contract, location, evidence, and required
outcome.

Never tag `@Cursor` in the fallback GitHub comment. The subsequent Linear comment
is the only implementation follow-up channel.

After the canonical GitHub record is confirmed, add one Linear comment mentioning
`@Cursor`, with the exact reviewed SHA, review/comment link, and concise numbered
required outcomes. Embed
`Maestro-Cursor-Follow-Up-Identity: <complete linear publication identity>`,
search before create and after an ambiguous response, and link exactly one
confirmed canonical GitHub record. This Linear comment is the implementation
follow-up channel.

For `human-decision`, publish a non-approving review/comment and record the
prior/resume phase. Apply `maestro:scope-change` for a strategic contract/DAG
revision or `maestro:needs-human` for a bounded decision. Do not mention `@Cursor`
unless Cursor has a concrete implementation action.

rule symphony-review-apply-label-maestro-scope-change | when entity-scoped-pause-is-confirmed-and-strategic-authority-is-required | apply label `maestro:scope-change` | next entity-scope-change | choice entity-phase

rule symphony-review-apply-label-maestro-needs-human | when entity-scoped-pause-is-confirmed-and-strategic-authority-is-not-required | apply label `maestro:needs-human` | next entity-needs-human | choice entity-phase

For `inconclusive`, publish only when every verdict-relevant missing item is a
typed, stable acceptance-manifest entry with a deterministic locator and
changeable state. Unkeyed, untyped, free-form, or source-closure-unknown missing
evidence never publishes; append `action-failed` and allow bounded retry.

Append one `review-recorded` event for a confirmed published `pass`,
`changes-required`, `human-decision`, or actionable `inconclusive` result, with
the action identity, review input revision, attempt, exact SHA, outcome, evidence
link, and next transition. Also append `human-decision-required` for a
`human-decision` result. For an unpublished `inconclusive`
attempt, append `action-failed` with its finite failure category. Use
`review-stale-head` and `cleanup-failed` only as declared by the core vocabulary.

rule symphony-review-append-event-review-recorded | when canonical-exact-head-and-input-revision-review-record-is-confirmed | append event `review-recorded` | next review-gate-recorded | choice none

rule symphony-review-append-event-review-stale-head | when remote-pr-head-no-longer-matches-reviewed-head | append event `review-stale-head` | next review-new-head | choice none

rule symphony-review-append-event-human-decision-required | when bounded-or-strategic-human-authority-is-required | append event `human-decision-required` | next affected-subgraph-paused | choice none

rule symphony-review-append-event-action-failed | when material-action-attempt-is-not-confirmed | append event `action-failed` | next bounded-recovery | choice none

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

rule symphony-review-append-event-cleanup-failed | when owned-cleanup-safety-or-completion-is-unconfirmed | append event `cleanup-failed` | next cleanup-debt | choice none

Return to `symphony-reconcile`:

```markdown
## Symphony review result
Outcome:
Symphony UUID:
Implementation issue UUID:
PR native ID:
Base SHA:
Head SHA:
Contract revision:
DAG revision:
Review-policy revision:
Review action identity:
Review input revision:
GitHub record:
Linear @Cursor follow-up:
Cleanup:
Failure category:
Next transition:
```

## Classify review attempts

Every review read, validation, publication, and cleanup attempt emits exactly one
outcome and consumes it to choose the next transition:

rule symphony-review-emit-outcome-confirmed | when external-result-is-freshly-confirmed | emit outcome `confirmed` | next advance-confirmed-transition | choice action-outcome

rule symphony-review-consume-outcome-confirmed | when external-result-is-freshly-confirmed | consume outcome `confirmed` | next advance-confirmed-transition | choice action-outcome

rule symphony-review-emit-outcome-ambiguous | when external-result-may-exist-without-confirmation | emit outcome `ambiguous` | next resolve-action-identity | choice action-outcome

rule symphony-review-consume-outcome-ambiguous | when external-result-may-exist-without-confirmation | consume outcome `ambiguous` | next resolve-action-identity | choice action-outcome

rule symphony-review-emit-outcome-retryable-failure | when unchanged-state-permits-bounded-retry | emit outcome `retryable-failure` | next bounded-retry-with-phase-retained | choice action-outcome

rule symphony-review-consume-outcome-retryable-failure | when unchanged-state-permits-bounded-retry | consume outcome `retryable-failure` | next bounded-retry-with-phase-retained | choice action-outcome

rule symphony-review-emit-outcome-permanent-failure | when confirmed-invalid-state-or-capability-blocks-retry | emit outcome `permanent-failure` | next pause-affected-work | choice action-outcome

rule symphony-review-consume-outcome-permanent-failure | when confirmed-invalid-state-or-capability-blocks-retry | consume outcome `permanent-failure` | next pause-affected-work | choice action-outcome

When the outcome requires a category, emit one applicable category and consume
it with the adjacent retryability rule:

rule symphony-review-emit-failure-category-observation-failed | when observation-failed-category-is-evidenced | emit failure category `observation-failed` | next observation-failed-recovery | choice none

rule symphony-review-consume-failure-category-observation-failed | when observation-failed-category-is-evidenced | consume failure category `observation-failed` | next observation-failed-recovery | choice none
Retryability: Retry the read later; authorize no dependent mutation

rule symphony-review-emit-failure-category-observation-incomplete | when observation-incomplete-category-is-evidenced | emit failure category `observation-incomplete` | next observation-incomplete-recovery | choice none

rule symphony-review-consume-failure-category-observation-incomplete | when observation-incomplete-category-is-evidenced | consume failure category `observation-incomplete` | next observation-incomplete-recovery | choice none
Retryability: Resolve directly by native ID before retrying the dependent action

rule symphony-review-emit-failure-category-external-transient | when external-transient-category-is-evidenced | emit failure category `external-transient` | next external-transient-recovery | choice none

rule symphony-review-consume-failure-category-external-transient | when external-transient-category-is-evidenced | consume failure category `external-transient` | next external-transient-recovery | choice none
Retryability: Retry the affected operation while unrelated work continues

rule symphony-review-emit-failure-category-mutation-ambiguous | when mutation-ambiguous-category-is-evidenced | emit failure category `mutation-ambiguous` | next mutation-ambiguous-recovery | choice none

rule symphony-review-consume-failure-category-mutation-ambiguous | when mutation-ambiguous-category-is-evidenced | consume failure category `mutation-ambiguous` | next mutation-ambiguous-recovery | choice none
Retryability: Search by native target and action identity before any retry

rule symphony-review-emit-failure-category-semantic-drift | when semantic-drift-category-is-evidenced | emit failure category `semantic-drift` | next semantic-drift-recovery | choice none

rule symphony-review-consume-failure-category-semantic-drift | when semantic-drift-category-is-evidenced | consume failure category `semantic-drift` | next semantic-drift-recovery | choice none
Retryability: Do not retry mutation; require bounded decision or strategic revision

rule symphony-review-emit-failure-category-review-stale-head | when review-stale-head-category-is-evidenced | emit failure category `review-stale-head` | next review-stale-head-recovery | choice none

rule symphony-review-consume-failure-category-review-stale-head | when review-stale-head-category-is-evidenced | consume failure category `review-stale-head` | next review-stale-head-recovery | choice none
Retryability: Do not retry the stale identity; create a new identity for the new head

rule symphony-review-emit-failure-category-validation-timeout | when validation-timeout-category-is-evidenced | emit failure category `validation-timeout` | next validation-timeout-recovery | choice none

rule symphony-review-consume-failure-category-validation-timeout | when validation-timeout-category-is-evidenced | consume failure category `validation-timeout` | next validation-timeout-recovery | choice none
Retryability: Terminate, clean up, and retry only within the unchanged-state budget

rule symphony-review-emit-failure-category-capability-lost | when capability-lost-category-is-evidenced | emit failure category `capability-lost` | next capability-lost-recovery | choice none

rule symphony-review-consume-failure-category-capability-lost | when capability-lost-category-is-evidenced | consume failure category `capability-lost` | next capability-lost-recovery | choice none
Retryability: Pause dependent operations until capability changes

rule symphony-review-emit-failure-category-cleanup-failed | when cleanup-failed-category-is-evidenced | emit failure category `cleanup-failed` | next cleanup-failed-recovery | choice none

rule symphony-review-consume-failure-category-cleanup-failed | when cleanup-failed-category-is-evidenced | consume failure category `cleanup-failed` | next cleanup-failed-recovery | choice none
Retryability: Retry only ownership-checked cleanup; blocks Symphony closeout

rule symphony-review-emit-failure-category-permanent-invalid | when permanent-invalid-category-is-evidenced | emit failure category `permanent-invalid` | next permanent-invalid-recovery | choice none

rule symphony-review-consume-failure-category-permanent-invalid | when permanent-invalid-category-is-evidenced | consume failure category `permanent-invalid` | next permanent-invalid-recovery | choice none
Retryability: Do not retry unchanged state; require human correction
