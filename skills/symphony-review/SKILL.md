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
plan-time `review`/`both` evidence requirements, acceptance-evidence binding manifest/revision, complete required evidence
manifest, applicable matching decision-resolutions, review input revision, and
Review PR action identity match this invocation.

rule symphony-review-consume-event-review-requested | when canonical-review-input-revision-is-durably-confirmed | consume event `review-requested` | next review-revision-eligible | choice none

rule symphony-review-consume-event-review-worktree-action-bound | when reservation-to-final-review-action-binding-is-confirmed | consume event `review-worktree-action-bound` | next action-binding-confirmed | choice none

Return `inconclusive` when:

- a required native identity is absent;
- repository routing conflicts;
- the PR repository does not match the issue;
- the requested exact PR head SHA is not the current head;
- the governing contract is ambiguous or drifted.

Before confirmed dispatch/transfer, reconciliation retains cleanup ownership.
After confirmed transfer, review retains cleanup ownership and cleans on every exit, including invalid-input exits; there is no reverse transfer.

Reconciliation records `review-stale-head` only when the requested head is
already stale before `review-requested`; this review skill never appends it.
After review begins, every
prepublication difference, including head movement, produces exactly one
`review-input-stale` and never `review-stale-head`.

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

## Accept the prepared exact-head worktree

Reconciliation confirms a pre-closure review worktree reservation, creates or
acquires the owned isolated detached worktree under its reservation-only marker,
derives closure/action, confirms the durable reservation-to-action binding, and
atomically updates the marker before `review-requested`. Cleanup by reservation
identity remains valid before final action binding. Review consumes that exact
cleanup-ledger entry only after dispatch is confirmed; before use, revalidate
the reservation, journal action binding, bound marker, component containment,
repository identity, detached attachment state, and
`git rev-parse HEAD == <expected head SHA>`.
Any mismatch publishes nothing, returns `inconclusive`, and follows guarded
cleanup. A diff-only reviewer may receive no worktree; every command-running
reviewer uses the transferred exact-head worktree or a separately ledgered
worktree derived from that same confirmed repository/head.

Maintain the transferred cleanup ledger containing repository, canonical
worktree path, canonical review directory, marker contents, reservation
identity, bound action identity, attachment state, and current cleanup owner.
If the marker claims a binding absent from the journal, fail closed and retain
cleanup debt without dispatch or deletion.
Confirmed dispatch atomically and durably changes that ledger owner from
reconciliation to review before review work begins.

## Run contained validation commands

At pre-review require the exact-head worktree to be fully clean. At
pre-publication, fail on any tracked, staged, symlink, or submodule mutation.
Allow an untracked validation artifact only when the descriptor explicitly
declares every implicit source—even with no validators—and its path cannot
equal, alias, contain, be contained by, or shadow any declared source path,
including repository evidence, policy, configuration, or instructions. Do not run `git clean`;
disposable outputs are removed only by guarded cleanup.

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
plugin-owned review-source requirements exact-byte revision
confirmed review-source-closure-v1 descriptor/revision
complete plan-time `review`/`both` evidence requirements and typed runtime binding manifest/revision
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

Immediately before any GitHub review/comment publication, freshly re-read the complete current review context.
Resolve every plan-time `review` and `both` evidence requirement against freshly confirmed native state; a reconciliation-only unresolved requirement cannot block this pre-merge review. Require `resolution_outcome=exact` for every binding that enters the publishable manifest; then freshly rederive review context, evidence templates/bindings, acceptance-evidence manifest, exact-head source closure, capability state, decision-resolution revision, and the complete review-input-v1 revision.
Revalidate worktree ownership, repository identity, and head before use.
Compare the canonical input bytes and revision byte-for-byte with the revision
actually reviewed.

If any component differs, publish neither the GitHub record nor Linear
`@Cursor` follow-up. Append exactly one `review-input-stale` containing the old reviewed revision, new revision, changed component, and cleanup result; clean
every owned worktree; and return the new input to `symphony-reconcile`. The new
input is eligible and the stale result satisfies no gate. If the fresh input
cannot be derived, publish nothing, append `action-failed` with the old revision,
clean up, and follow bounded recovery. `review-stale-head` remains the legacy
pre-review observation only; head movement in this complete post-review
comparison produces only the unified stale-input record and never publishes.

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

After that GitHub record is confirmed and immediately before any Linear
`@Cursor` follow-up, re-read, rebind, and rederive the complete current review
input again with `pre-publication` closure. Require byte equality with the
reviewed and GitHub-published revision. If changed or underivable, do not publish
Linear; append exactly one `review-input-stale` referencing the already-published
GitHub record and the old, new, or `underivable` revision. The already-published
GitHub record remains historical and cannot satisfy the current Maestro pass
gate. Clean the owned worktree; make a derivable new revision eligible or enter
bounded derivation recovery. If unchanged, search and publish or recover exactly
one canonical Linear follow-up.

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
`review-stale-head`, `review-input-stale`, and `cleanup-failed` only as declared by the core vocabulary.

rule symphony-review-append-event-review-recorded | when canonical-exact-head-and-input-revision-review-record-is-confirmed | append event `review-recorded` | next review-gate-recorded | choice none

rule symphony-review-append-event-review-input-stale | when full-input-changed-or-underivable-and-review-requested-is-confirmed | append event `review-input-stale` | next new-review-input-eligible | choice none

rule symphony-review-append-event-human-decision-required | when bounded-or-strategic-human-authority-is-required | append event `human-decision-required` | next affected-subgraph-paused | choice none

rule symphony-review-append-event-action-failed | when material-action-attempt-is-not-confirmed | append event `action-failed` | next bounded-recovery | choice none

## Cleanup guarantee

Cleanup runs after pass, changes required, human decision, inconclusive result,
stale head, tool failure, reviewer failure, and publication failure.

For each cleanup-ledger entry:

1. Canonicalize paths again.
2. Verify component-level containment beneath the dedicated root.
3. Read and match the ownership marker and reservation identity. Before action
   binding, that reservation match is sufficient for guarded cleanup. After a
   confirmed journal binding, also require the bound action identity; a marker
   claim without its journal binding fails closed.
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

rule symphony-review-emit-failure-category-review-input-stale | when review-input-stale-after-request-category-is-evidenced | emit failure category `review-input-stale` | next new-review-input-eligible | choice none

rule symphony-review-consume-failure-category-review-input-stale | when review-input-stale-after-request-category-is-evidenced | consume failure category `review-input-stale` | next new-review-input-eligible | choice none
Retryability: Do not retry or publish the stale result; reconcile the newly derived input

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
