---
name: symphony-reconcile
description: Perform one bounded idempotent Maestro reconciliation pass for a Symphony: detect drift, reconcile merges, review new PR heads, continue discovery/planning, and delegate ready Linear issues to Cursor. Intended for /loop; never sleeps or polls internally.
disable-model-invocation: true
---

# Reconcile one Symphony

Input: `$ARGUMENTS`, which must identify exactly one `[Symphony]` control issue.
If empty or ambiguous, report the input error and perform no mutation.

Read completely:

- `${CLAUDE_PLUGIN_ROOT}/references/symphony/core.md`
- `${CLAUDE_PLUGIN_ROOT}/references/symphony/linear.md`
- `${CLAUDE_PLUGIN_ROOT}/references/symphony/reconciliation.md`
- `${CLAUDE_PLUGIN_ROOT}/references/symphony/review.md`

This skill is the Maestro adapter for Superpowers executing-plans,
receiving/requesting-code-review, and verification-before-completion discipline.
The tracked plan is the approved Linear DAG, implementation belongs to Cursor,
review uses `symphony-review`, and completion means merge-reconciled delivered
reality.

Perform one pass only. Never sleep, poll, or dispatch a watcher subagent.

## Pass setup

Create an in-memory pass ledger:

```text
Symphony native UUID
observed control-issue revision
approved DAG/contract revisions
material actions attempted this pass
action identities already confirmed
retry attempts reconstructed from journal
owned-worktree cleanup debt
```

If the control issue cannot be read completely, classify `observation-failed` and
stop without mutation.

## 1. Reconstruct observed state

Read full native snapshots for:

- control issue, approved DAG revisions, and journal;
- every managed discovery and implementation issue;
- current statuses, labels, native blockers, assignees, Cursor delegation, and
  repository routing;
- linked/referenced PRs and any candidate PR resolved by native issue/repository
  metadata;
- each PR's repository, base, current head, draft/closed/merged state, checks,
  approvals, review comments/threads when exposed, and merge SHA;
- confirmed action identities and failed-attempt counts.

Resolve missing scoped-list objects directly by native ID. A partial or malformed
read blocks only dependent actions.

Inspect `${TMPDIR:-/tmp}/maestro-symphony-reviews` for cleanup debt. Attempt cleanup
only through the ownership checks in the review protocol.

Consume every journal event while reconstructing history, then require the fresh
provider evidence named by its transition:

rule symphony-reconcile-consume-event-symphony-started | when control-creation-is-confirmed | consume event `symphony-started` | next entity-discovery | choice none

rule symphony-reconcile-consume-event-discovery-requested | when canonical-discovery-request-is-durably-confirmed | consume event `discovery-requested` | next discovery-active | choice none

rule symphony-reconcile-consume-event-discovery-recorded | when discovery-evidence-is-durably-confirmed | consume event `discovery-recorded` | next discovery-active | choice none

rule symphony-reconcile-consume-event-discovery-completed | when discovery-result-contract-is-confirmed | consume event `discovery-completed` | next entity-complete | choice none

rule symphony-reconcile-consume-event-dag-proposed | when exact-dag-proposal-is-durably-confirmed | consume event `dag-proposed` | next entity-planning | choice none

rule symphony-reconcile-consume-event-dag-approved | when exact-dag-revision-approval-is-durably-confirmed | consume event `dag-approved` | next dag-recovery | choice none

rule symphony-reconcile-consume-event-dag-rejected | when exact-dag-rejection-is-durably-confirmed | consume event `dag-rejected` | next dag-replanning | choice none

rule symphony-reconcile-consume-event-dag-node-bound | when one-native-node-binding-is-confirmed | consume event `dag-node-bound` | next dag-recovery | choice none

rule symphony-reconcile-consume-event-dag-edge-bound | when one-native-edge-binding-is-confirmed | consume event `dag-edge-bound` | next dag-recovery | choice none

rule symphony-reconcile-consume-event-dag-materialized | when all-native-bindings-and-events-are-confirmed | consume event `dag-materialized` | next entity-executing | choice none

rule symphony-reconcile-consume-event-semantic-drift-detected | when normalized-contract-or-edge-drift-is-confirmed | consume event `semantic-drift-detected` | next affected-subgraph-paused | choice none

rule symphony-reconcile-consume-event-issue-dispatched | when cursor-delegation-is-freshly-confirmed | consume event `issue-dispatched` | next entity-executing | choice none

rule symphony-reconcile-consume-event-review-requested | when canonical-review-input-revision-is-durably-confirmed | consume event `review-requested` | next review-revision-eligible | choice none

rule symphony-reconcile-consume-event-review-worktree-reserved | when canonical-preclosure-review-reservation-is-confirmed | consume event `review-worktree-reserved` | next reservation-authorized | choice none

rule symphony-reconcile-consume-event-review-worktree-action-bound | when reservation-to-final-review-action-binding-is-confirmed | consume event `review-worktree-action-bound` | next action-binding-confirmed | choice none

rule symphony-reconcile-consume-event-review-recorded | when canonical-exact-head-and-input-revision-review-record-is-confirmed | consume event `review-recorded` | next review-gate-recorded | choice none

rule symphony-reconcile-consume-event-review-stale-head | when remote-pr-head-or-context-preparation-changed-and-review-requested-is-absent | consume event `review-stale-head` | next review-new-head | choice none

rule symphony-reconcile-consume-event-review-input-stale-before-github | when derivable-full-input-changed-and-review-requested-is-confirmed-and-github-record-is-absent | consume event `review-input-stale` | next new-review-input-eligible | choice none

rule symphony-reconcile-consume-event-review-input-stale-after-github | when full-input-changed-or-underivable-and-confirmed-github-record-exists-and-linear-record-is-absent | consume event `review-input-stale` | next github-record-historical-input-recovery | choice none

rule symphony-reconcile-consume-event-merge-observed | when github-merge-sha-is-freshly-confirmed | consume event `merge-observed` | next merge-reconciliation-pending | choice none

rule symphony-reconcile-consume-event-merge-reconciled | when merge-reconciliation-is-complete-and-evidenced | consume event `merge-reconciled` | next merge-reconciled-confirmed | choice none

rule symphony-reconcile-consume-event-implementation-completed | when confirmed-merge-reconciled-is-consumed-by-separate-implementation-transition | consume event `implementation-completed` | next implementation-complete | choice none

rule symphony-reconcile-consume-event-human-decision-required | when bounded-or-strategic-human-authority-is-required | consume event `human-decision-required` | next affected-subgraph-paused | choice none

rule symphony-reconcile-consume-event-decision-resolved | when resolution-disposition-and-resume-evidence-are-confirmed | consume event `decision-resolved` | next recorded-resume-phase | choice none

rule symphony-reconcile-consume-event-follow-up-created | when required-follow-up-identity-is-confirmed | consume event `follow-up-created` | next follow-up-inventory-confirmed | choice none

rule symphony-reconcile-consume-event-issue-cancelled | when approved-cancellation-and-dependency-disposition-are-confirmed | consume event `issue-cancelled` | next implementation-complete | choice none

rule symphony-reconcile-consume-event-action-failed | when material-action-attempt-is-not-confirmed | consume event `action-failed` | next bounded-recovery | choice none

rule symphony-reconcile-consume-event-retry-exhausted | when unchanged-state-retry-budget-is-exhausted | consume event `retry-exhausted` | next entity-needs-human | choice none

rule symphony-reconcile-consume-event-cleanup-failed | when owned-cleanup-safety-or-completion-is-unconfirmed | consume event `cleanup-failed` | next cleanup-debt | choice none

rule symphony-reconcile-consume-event-symphony-completed | when all-closeout-gates-and-final-outcome-are-confirmed | consume event `symphony-completed` | next entity-complete | choice none

## 2. Detect drift

Compare every approved issue contract and native dependency set with current
Linear. Apply the reconciliation protocol's drift table.

Repair only generated, mechanically derivable metadata. For semantic drift:

1. pause only the affected subgraph;
2. apply `maestro:needs-human` for a bounded decision/capability pause or
   `maestro:scope-change` when a strategic contract/DAG revision is required;
3. append one deduplicated `semantic-drift-detected` event with the exact contract
   or edge diff and prior/resume phase;
4. do not repeatedly restore the old value.

rule symphony-reconcile-append-event-semantic-drift-detected | when normalized-contract-or-edge-drift-is-confirmed | append event `semantic-drift-detected` | next affected-subgraph-paused | choice none

GitHub merge evidence is authoritative over lagging Linear automation. Done without
a merge-reconciliation identity never unlocks dependants. The state merged remains distinct
from a confirmed `merge-reconciled` result.

## 3. Reconcile merges first

For every merged PR lacking a confirmed `merge-reconciled` result for its source issue and merge SHA:

1. Re-read the final PR and merge SHA. Append `merge-observed` only if that event
   is absent, otherwise consume it. The existence of `merge-observed` never
   suppresses reconciliation and never counts as `merge-reconciled`.
2. Obtain the final diff and resolve every `reconciliation`/`both` requirement
   from authoritative runtime context. Build the canonical exact post-merge
   binding manifest containing criterion/requirement key, evidence stage,
   source kind/static role, binding-context revision, resolved locator,
   resolution outcome, observable state, and provider
   identity/revision/evidence. Any unresolved, ambiguous, missing, unavailable,
   omitted, stale, or mismatched required entry blocks dispatch acceptance and
   makes `complete` impossible.
3. Dispatch `maestro:implementation-reconciler` with the complete reconciliation
   envelope and canonical binding manifest/revision.
4. Always recompute the binding manifest before accepting the reconciler result.
   Immediately before acceptance, derive it from
   fresh native state. Require byte equality with the request, exact reconciler identity and request
   identity, every entry/key echoed, and every acceptance/deviation/follow-up
   conclusion mapped to those exact bindings in the complete acceptance-evidence table.
5. Only verdict `complete`, with every acceptance criterion satisfied and
   evidenced, may persist the merge reconciliation and append exactly one
   `merge-reconciled`. In a separate transition after that confirmation, append
   `Actual implementation`, `Deviations and decisions`, and `Follow-up work`;
   apply bounded downstream edits; create and confirm required follow-ups with
   `follow-up-created`; move the issue to an unambiguous native completed status;
   apply `maestro:complete` to that implementation issue; or unlock dependants.
   A third, later closeout transition evaluates the whole Symphony. No merge
   transition completes the control issue or Symphony.
6. For `human-decision`, journal `merge-observed` and
   `human-decision-required` with decision evidence and prior/resume phase. Apply
   `maestro:scope-change` for strategic contract/DAG revision or
   `maestro:needs-human` for a bounded decision; leave the issue unreconciled and
   keep all downstream blockers locked.
7. For `inconclusive`, journal `merge-observed` and `action-failed` with the
   missing evidence and finite failure category, then follow bounded retry policy;
   leave the issue unreconciled and keep all downstream blockers locked.
8. Recalculate downstream readiness only after confirmed `merge-reconciled`.

rule symphony-reconcile-append-event-merge-observed | when github-merge-sha-is-freshly-confirmed | append event `merge-observed` | next merge-reconciliation-pending | choice none

rule symphony-reconcile-append-event-merge-reconciled | when merge-reconciliation-is-complete-and-evidenced | append event `merge-reconciled` | next merge-reconciled-confirmed | choice none

rule symphony-reconcile-append-event-implementation-completed | when confirmed-merge-reconciled-is-consumed-by-separate-implementation-transition | append event `implementation-completed` | next implementation-complete | choice none

rule symphony-reconcile-append-event-human-decision-required | when bounded-or-strategic-human-authority-is-required | append event `human-decision-required` | next affected-subgraph-paused | choice none

Resolve a human-decision or semantic-drift pause only from a declared disposition,
governing revision, affected subgraph, required approval evidence, and confirmed
recorded resume phase. Append `decision-resolved` before removing
`maestro:needs-human` or `maestro:scope-change`; then restore only that phase.

rule symphony-reconcile-append-event-decision-resolved | when resolution-disposition-and-resume-evidence-are-confirmed | append event `decision-resolved` | next recorded-resume-phase | choice none

rule symphony-reconcile-append-event-follow-up-created | when required-follow-up-identity-is-confirmed | append event `follow-up-created` | next follow-up-inventory-confirmed | choice none

For every required follow-up, recompute and validate the reconciler's
`follow-up-v1:` key from source implementation issue UUID, source merge SHA, and
the normalized gap fields in the Linear contract. Derive the complete
`Maestro-Follow-Up-Creation-Identity` from Symphony UUID plus those durable
inputs; this is the source implementation issue UUID + source merge SHA + fixed follow-up key contract. Search the exact native scope before create, after an ambiguous create,
and in every fresh session. Reuse exactly one match; fail closed on multiple
matches; never duplicate it on a later pass. Apply managed/routing/dependency
metadata from its issue contract.

rule symphony-reconcile-append-event-action-failed | when material-action-attempt-is-not-confirmed | append event `action-failed` | next bounded-recovery | choice none

Consume the reconciler result according to its exact returned value:

rule symphony-reconcile-consume-reconciliation-verdict-complete | when aggregate-reconciliation-decision-is-not-required-and-identity-or-required-evidence-is-present-and-complete-is-evidenced | consume reconciliation verdict `complete` | next merge-reconciliation-eligible | choice reconciliation-verdict

rule symphony-reconcile-consume-reconciliation-verdict-human-decision | when aggregate-reconciliation-decision-is-required | consume reconciliation verdict `human-decision` | next reconciliation-human-decision | choice reconciliation-verdict

rule symphony-reconcile-consume-reconciliation-verdict-inconclusive | when aggregate-reconciliation-decision-is-not-required-and-identity-or-required-evidence-is-missing | consume reconciliation verdict `inconclusive` | next reconciliation-inconclusive | choice reconciliation-verdict

An ambiguous write is searched by native target/action identity before retry.

## 4. Review new PR heads

For each relevant current PR head, derive the current review input revision from
the complete review-source closure, typed acceptance-evidence manifest, required
lens/validator evidence manifest, full context identity, and applicable exact
decision-resolutions. Select records by exact full context plus review input revision.
An older revision is historical and neither satisfies nor blocks the current
revision.

A base SHA movement or Symphony/implementation/PR relink makes every old result non-authoritative and creates a new eligible identity even when head SHA is unchanged.

1. Confirm Symphony/implementation/PR/repository/base/head identities,
   governance revisions, required lenses/validators, and the plan-time evidence
   requirements. For pre-merge review resolve only `review` and `both`; a
   reconciliation-only unresolved binding cannot block review. After merge
   resolve only `reconciliation` and `both`, require every binding to be exact,
   and keep post-merge evidence gating `merge-reconciled`, implementation
   completion, and closeout. Zero or multiple matches fail closed.
2. Before needing repository worktree bytes, derive canonical
   `review-preparation-v1` from Symphony/implementation/repository/PR/base/head/
   contract/DAG/policy context, plan-time evidence requirements and preworktree
   provider bindings, capabilities, applicable decision resolutions,
   plugin-owned source/policy closure, and exact-head repository source
   requirements. Derive and confirm the stable review worktree reservation from
   that preparation revision and the full identity. Same-head evidence,
   capability, decision, plugin-policy, base, or relink changes create a new
   preparation/reservation; unchanged retries reuse the current one.
   Write only that reservation to the initial cleanup ledger and marker, then
   create the owned exact-head worktree before source closure or
   `review-requested`. Verify marker/containment, expected GitHub repository,
   detached state, fully clean pre-review state, and
   `git rev-parse HEAD == <expected head SHA>`.
3. From that exact root derive the explicit repository
   evidence/instruction/policy/config closure and require the descriptor-level
   declaration that every implicit repository source is listed, even with no
   validators. Combine it with the plugin-owned authoritative closure,
   capability state, binding manifest, decision resolutions, and canonical
   input/action arrays using
   `--phase pre-review`. Publication rederivation uses
   `--phase pre-publication`, which allows only path-disjoint untracked regular
   validation artifacts and rejects tracked/symlink/submodule mutation.
4. Append and confirm one durable reservation-to-action binding. Only then
   atomically update the marker to repeat the bound action identity and verify
   the journal/marker pair. If the matching `review-requested` event is absent,
   append and confirm it before dispatching an expensive review or publishing
   either channel. Keep the same worktree and ledger throughout.
   One reservation maps to exactly one review action. A differing exact-head
   repository closure, conflicting second action, or historical reservation is
   stale and fails closed.
5. If no result exists, dispatch internal `maestro:symphony-review` with the same
   ledger/worktree. Ownership transfer occurs only after confirmed dispatch as
   an atomic durable cleanup-ledger owner update; cleanup remains
   reconciliation-owned when dispatch fails, and the guarded attachment-state
   branch runs before return. There is no reverse transfer after review begins.

Crash recovery is state-derived: reservation confirmed with no worktree resumes
owned creation; worktree attached with no source closure resumes closure;
action binding confirmed with marker not updated performs only the atomic marker
update; a marker claiming a binding absent from the journal must fail closed
without dispatch, transfer, or deletion. Dispatch absent always leaves cleanup
ownership with reconciliation; dispatch confirmed permits the one-way transfer
to review.
6. Record its exact-head and exact-input-revision result and cleanup status.
7. If `review-input-stale` is returned, the old result satisfies and blocks
   nothing; the event's newly derived input is eligible for a fresh request.
8. An unchanged `changes-required` result waits for a new head, contract
   revision, review-policy revision, or review input revision; do not redispatch.
9. A `human-decision` result remains paused until an exact matching
   `decision-resolved` is applicable. That resolution changes the same-head
   review input revision and makes only the new revision eligible; a stale or
   mismatched resolution changes nothing.
10. A confirmed published actionable `inconclusive` result appends
   `review-recorded` only when every missing item is keyed, typed, locatable, and
   represented in the acceptance manifest. It waits for changed provider state.
   An unkeyed/free-form or unpublished transient `inconclusive` result appends
   `action-failed` and follows bounded retry without consuming publication
   identity.
11. If changes are required, let the internal skill create the canonical GitHub
   record and Linear `@Cursor` follow-up. If human judgment is required, pause
   only the affected subgraph.

rule symphony-reconcile-append-event-review-requested | when canonical-review-input-revision-is-durably-confirmed | append event `review-requested` | next review-revision-eligible | choice none

rule symphony-reconcile-append-event-review-worktree-reserved | when canonical-preclosure-review-reservation-is-confirmed | append event `review-worktree-reserved` | next reservation-authorized | choice none

rule symphony-reconcile-append-event-review-worktree-action-bound | when reservation-to-final-review-action-binding-is-confirmed | append event `review-worktree-action-bound` | next action-binding-confirmed | choice none

rule symphony-reconcile-append-event-review-stale-head | when remote-pr-head-or-context-preparation-changed-and-review-requested-is-absent | append event `review-stale-head` | next review-new-head | choice none

Consume the review result according to its exact returned value:

rule symphony-reconcile-consume-review-verdict-pass | when aggregate-strategic-decision-actionable-defect-and-required-evidence-are-absent | consume review verdict `pass` | next review-passed | choice review-verdict

rule symphony-reconcile-consume-review-verdict-changes-required | when aggregate-strategic-decision-is-absent-and-actionable-defect-is-present | consume review verdict `changes-required` | next review-changes-required | choice review-verdict

rule symphony-reconcile-consume-review-verdict-human-decision | when aggregate-strategic-decision-is-present | consume review verdict `human-decision` | next review-human-decision | choice review-verdict

rule symphony-reconcile-consume-review-verdict-inconclusive | when aggregate-strategic-decision-and-actionable-defect-are-absent-and-required-evidence-is-missing | consume review verdict `inconclusive` | next review-inconclusive | choice review-verdict

Maestro does not triage other reviewers' comments and does not diagnose ordinary
CI failures. Cursor owns all PR convergence.

Do not mark a PR merge-ready unless the current passing Maestro review identity matches the current head and current review input revision, current repository gates show zero failing checks, at least one human/bot approval exists, review comments/threads are addressed, and all other policy gates are satisfied.

## 5. Continue discovery and planning

For approved outstanding discovery:

- canonicalize the complete approved descriptor set and append/confirm
  `discovery-requested` before any discovery issue mutation;
- dispatch `maestro:symphony-researcher` with bounded parallelism;
- derive each complete discovery identity from that record; search the exact
  scope before create/retry, fail closed on multiple matches, and create any
  missing approved discovery issue with `maestro-managed` and
  `maestro:discovery`;
- write returned evidence to the matching discovery issue and append
  `discovery-recorded`;
- when its result and confidence/remaining-unknowns contract is complete, append
  `discovery-completed`, then apply `maestro:complete` to that discovery issue
  only;
- use `maestro:code-architect` for cross-repository synthesis;
- propose a new versioned DAG wave only when evidence is sufficient.

Every material DAG revision requires explicit user approval. A `/loop` pass must
append and confirm the complete `dag-proposed` event before requesting approval.
It applies the appropriate pause phase and reports the proposal; it must not
self-approve or dispatch that revision. A later explicit approval must be
recorded as `dag-approved` for the exact proposal/contract identity before
materialization resumes. Follow the durable node/edge binding protocol in the
Linear reference and append `dag-materialized` only after all native objects are
confirmed. Append each required `dag-node-bound` and `dag-edge-bound` during that
recovery/materialization sequence.

rule symphony-reconcile-append-event-discovery-requested | when canonical-discovery-request-is-durably-confirmed | append event `discovery-requested` | next discovery-active | choice none

rule symphony-reconcile-append-event-discovery-recorded | when discovery-evidence-is-durably-confirmed | append event `discovery-recorded` | next discovery-active | choice none

rule symphony-reconcile-append-event-discovery-completed | when discovery-result-contract-is-confirmed | append event `discovery-completed` | next entity-complete | choice none

rule symphony-reconcile-append-event-dag-proposed | when exact-dag-proposal-is-durably-confirmed | append event `dag-proposed` | next entity-planning | choice none

rule symphony-reconcile-append-event-dag-approved | when exact-dag-revision-approval-is-durably-confirmed | append event `dag-approved` | next dag-recovery | choice none

On explicit rejection, append `dag-rejected` with the exact rejected
DAG/contract revision, proposal action identity, evidence, rationale, and
superseded/revisable disposition before replanning.

rule symphony-reconcile-append-event-dag-rejected | when exact-dag-rejection-is-durably-confirmed | append event `dag-rejected` | next dag-replanning | choice none

rule symphony-reconcile-append-event-dag-node-bound | when one-native-node-binding-is-confirmed | append event `dag-node-bound` | next dag-recovery | choice none

rule symphony-reconcile-append-event-dag-edge-bound | when one-native-edge-binding-is-confirmed | append event `dag-edge-bound` | next dag-recovery | choice none

rule symphony-reconcile-append-event-dag-materialized | when all-native-bindings-and-events-are-confirmed | append event `dag-materialized` | next entity-executing | choice none

Partial materialization advances only one confirmed step per pass: one node
create, node identity resolution, one node-binding event, one edge create, edge
identity resolution, one edge-binding event, or the final materialization event.
Never create a node and dependant edge together. Every native binding must be
confirmed before `dag-materialized`.

## 6. Dispatch ready implementation issues

Apply the exact readiness expression and Dispatch preflight from the reconciliation
protocol using fresh observations.

Bounded parallelism:

```text
maximum active Cursor issues: 3
maximum active issues per repository: 1
```

Select ready issues by approved wave/topological order, Linear priority with
unknown last, first recorded ready time or creation time, then native identifier.

For each available slot:

1. Re-read the target issue, blockers, repository routing, current delegation, and
   existing PR evidence; verify the absence of an existing implementation before
   delegating.
2. Stop on a stable preflight reason code.
3. Keep the current human assignee where Linear supports separate agent
   delegation.
4. Delegate the issue to Cursor through Linear.
5. Confirm delegation from a fresh native read.
6. Apply `maestro:executing`.
7. Append one `issue-dispatched` journal event with the native action identity.

rule symphony-reconcile-append-event-issue-dispatched | when cursor-delegation-is-freshly-confirmed | append event `issue-dispatched` | next entity-executing | choice none

If delegation is ambiguous, search for the existing Cursor delegation before
retrying. Capacity exhaustion is not a failure and creates no event.

## Approved implementation cancellation

An implementation issue may be cancelled only after explicit approval identifies
its native UUID, governing contract/DAG revision, cancellation rationale, and
downstream dependency disposition. Confirm the native cancellation, append
`issue-cancelled`, and apply `maestro:complete` to that implementation issue only.
Do not unlock a dependant unless the approved revised DAG removes the cancelled
contract or names its replacement. Cancellation never implies completion of the
control issue or Symphony.

rule symphony-reconcile-append-event-issue-cancelled | when approved-cancellation-and-dependency-disposition-are-confirmed | append event `issue-cancelled` | next implementation-complete | choice none

## 7. Evaluate Symphony closeout

Do not infer closeout from terminal implementation issues. Evaluate the complete
Symphony closeout contract from the Linear and reconciliation references:

- the final integration/outcome-verification issue succeeded with evidence;
- all approved required work is completed or explicitly cancelled with rationale;
- all merged PRs are merge-reconciled;
- no required managed PR or delegation remains active;
- no unresolved semantic drift, human decision, ambiguous mutation, retry
  exhaustion, or owned-worktree cleanup debt remains; and
- every required follow-up issue exists.

If any gate is false or unknown, retain the current phase and report it. Merely
observing terminal implementation issues must not close the Symphony.

When all gates are freshly confirmed, append the control issue's
`Final as-built outcome`. Link final integration evidence and record final
approved/reconciled scope plus material deviations/follow-ups. Confirm the update,
append exactly one `symphony-completed` event, then apply and confirm
`maestro:complete` on the control issue only.

rule symphony-reconcile-append-event-symphony-completed | when all-closeout-gates-and-final-outcome-are-confirmed | append event `symphony-completed` | next entity-complete | choice none

## 8. Journal and exit

Append only material events from the pass. Re-read each target before mutation and
confirm external outcomes afterward.

Mutations and expensive reviews use the failure taxonomy and a default maximum of
three consecutive attempts with the same action identity and unchanged state.
After three consecutive attempts, append one `retry-exhausted` event, apply
`maestro:needs-human`, and preserve its exact pause identity and recorded resume
phase. A relevant external state change does not itself resume work. Resume only
after a `decision-resolved` matches that pause identity, declares
`resume-after-confirmed-external-state-change`, and confirms the recorded phase;
stale or mismatched resolutions remain paused. Remove the label and resume the
declared phase only after that event is durable.
Derive and validate the complete `retry-pause-v1:` identity before appending the
exhaustion event or applying the label. Missing inputs or a mismatched digest
suppress both mutations and retain the prior phase.

rule symphony-reconcile-append-event-retry-exhausted | when unchanged-state-retry-budget-is-exhausted | append event `retry-exhausted` | next entity-needs-human | choice none

If ownership-checked cleanup cannot complete, preserve its debt and execute:

rule symphony-reconcile-append-event-cleanup-failed | when owned-cleanup-safety-or-completion-is-unconfirmed | append event `cleanup-failed` | next cleanup-debt | choice none

End quietly unless:

- human input or DAG approval is required;
- material scope or strategy changed;
- a wave or Symphony completed;
- retry exhaustion occurred;
- cleanup needs operator action; or
- an unrecoverable integration error occurred.

Otherwise return only a terse pass summary for `/loop`:

```text
reconciled=<count> reviewed=<count> dispatched=<count> material_events=<count>
```

Apply only the label transition selected by the entity-scoped rules above:

rule symphony-reconcile-apply-label-maestro-managed | when native-role-scope-is-confirmed | apply label `maestro-managed` | next role-label-confirmed | choice none

rule symphony-reconcile-apply-label-maestro-discovery | when entity-scoped-discovery-authority-is-confirmed | apply label `maestro:discovery` | next entity-discovery | choice entity-phase

rule symphony-reconcile-apply-label-maestro-planning | when entity-scoped-planning-authority-is-confirmed | apply label `maestro:planning` | next entity-planning | choice entity-phase

rule symphony-reconcile-apply-label-maestro-executing | when entity-scoped-execution-authority-is-confirmed | apply label `maestro:executing` | next entity-executing | choice entity-phase

rule symphony-reconcile-apply-label-maestro-needs-human | when entity-scoped-pause-is-confirmed-and-strategic-authority-is-not-required | apply label `maestro:needs-human` | next entity-needs-human | choice entity-phase

rule symphony-reconcile-apply-label-maestro-scope-change | when entity-scoped-pause-is-confirmed-and-strategic-authority-is-required | apply label `maestro:scope-change` | next entity-scope-change | choice entity-phase

rule symphony-reconcile-apply-label-maestro-complete | when entity-scoped-completion-authority-is-confirmed | apply label `maestro:complete` | next entity-complete | choice entity-phase

rule symphony-reconcile-apply-label-maestro-risk-security | when issue-label-or-changed-surface-has-security-risk | apply label `maestro-risk-security` | next security-lens-selected | choice none

rule symphony-reconcile-apply-label-maestro-risk-infra | when issue-label-or-changed-surface-has-infrastructure-risk | apply label `maestro-risk-infra` | next infrastructure-lens-selected | choice none

rule symphony-reconcile-apply-label-maestro-risk-migration | when issue-label-or-changed-surface-has-migration-risk | apply label `maestro-risk-migration` | next migration-lenses-selected | choice none

## Classify reconciliation attempts

Every provider read, review, or mutation attempt emits exactly one outcome and
consumes it to select the transition:

rule symphony-reconcile-emit-outcome-confirmed | when external-result-is-freshly-confirmed | emit outcome `confirmed` | next advance-confirmed-transition | choice action-outcome

rule symphony-reconcile-consume-outcome-confirmed | when external-result-is-freshly-confirmed | consume outcome `confirmed` | next advance-confirmed-transition | choice action-outcome

rule symphony-reconcile-emit-outcome-ambiguous | when external-result-may-exist-without-confirmation | emit outcome `ambiguous` | next resolve-action-identity | choice action-outcome

rule symphony-reconcile-consume-outcome-ambiguous | when external-result-may-exist-without-confirmation | consume outcome `ambiguous` | next resolve-action-identity | choice action-outcome

rule symphony-reconcile-emit-outcome-retryable-failure | when unchanged-state-permits-bounded-retry | emit outcome `retryable-failure` | next bounded-retry-with-phase-retained | choice action-outcome

rule symphony-reconcile-consume-outcome-retryable-failure | when unchanged-state-permits-bounded-retry | consume outcome `retryable-failure` | next bounded-retry-with-phase-retained | choice action-outcome

rule symphony-reconcile-emit-outcome-permanent-failure | when confirmed-invalid-state-or-capability-blocks-retry | emit outcome `permanent-failure` | next pause-affected-work | choice action-outcome

rule symphony-reconcile-consume-outcome-permanent-failure | when confirmed-invalid-state-or-capability-blocks-retry | consume outcome `permanent-failure` | next pause-affected-work | choice action-outcome

When the outcome requires a category, emit an applicable locally produced
category. Consume every category returned by this pass or by `symphony-review`,
using the adjacent retryability rule:

rule symphony-reconcile-emit-failure-category-observation-failed | when observation-failed-category-is-evidenced | emit failure category `observation-failed` | next observation-failed-recovery | choice none

rule symphony-reconcile-consume-failure-category-observation-failed | when observation-failed-category-is-evidenced | consume failure category `observation-failed` | next observation-failed-recovery | choice none
Retryability: Retry the read later; authorize no dependent mutation

rule symphony-reconcile-emit-failure-category-observation-incomplete | when observation-incomplete-category-is-evidenced | emit failure category `observation-incomplete` | next observation-incomplete-recovery | choice none

rule symphony-reconcile-consume-failure-category-observation-incomplete | when observation-incomplete-category-is-evidenced | consume failure category `observation-incomplete` | next observation-incomplete-recovery | choice none
Retryability: Resolve directly by native ID before retrying the dependent action

rule symphony-reconcile-emit-failure-category-external-transient | when external-transient-category-is-evidenced | emit failure category `external-transient` | next external-transient-recovery | choice none

rule symphony-reconcile-consume-failure-category-external-transient | when external-transient-category-is-evidenced | consume failure category `external-transient` | next external-transient-recovery | choice none
Retryability: Retry the affected operation while unrelated work continues

rule symphony-reconcile-emit-failure-category-mutation-ambiguous | when mutation-ambiguous-category-is-evidenced | emit failure category `mutation-ambiguous` | next mutation-ambiguous-recovery | choice none

rule symphony-reconcile-consume-failure-category-mutation-ambiguous | when mutation-ambiguous-category-is-evidenced | consume failure category `mutation-ambiguous` | next mutation-ambiguous-recovery | choice none
Retryability: Search by native target and action identity before any retry

rule symphony-reconcile-emit-failure-category-semantic-drift | when semantic-drift-category-is-evidenced | emit failure category `semantic-drift` | next semantic-drift-recovery | choice none

rule symphony-reconcile-consume-failure-category-semantic-drift | when semantic-drift-category-is-evidenced | consume failure category `semantic-drift` | next semantic-drift-recovery | choice none
Retryability: Do not retry mutation; require bounded decision or strategic revision

rule symphony-reconcile-emit-failure-category-review-stale-head | when review-stale-head-before-request-category-is-evidenced | emit failure category `review-stale-head` | next review-stale-head-recovery | choice none

rule symphony-reconcile-consume-failure-category-review-stale-head | when review-stale-head-before-request-category-is-evidenced | consume failure category `review-stale-head` | next review-stale-head-recovery | choice none
Retryability: Do not retry the stale identity; create a new identity for the new head

rule symphony-reconcile-consume-failure-category-review-input-stale-derivable | when derivable-review-input-stale-after-request-category-is-evidenced | consume failure category `review-input-stale` | next new-review-input-eligible | choice none
Retryability: Do not retry or publish the stale result; a derivable input becomes eligible, while an underivable post-GitHub input keeps that record historical and enters recovery

rule symphony-reconcile-consume-failure-category-review-input-stale-underivable-after-github | when underivable-review-input-stale-after-github-category-is-evidenced | consume failure category `review-input-stale` | next github-record-historical-input-recovery | choice none
Retryability: Do not retry or publish the stale result; a derivable input becomes eligible, while an underivable post-GitHub input keeps that record historical and enters recovery

rule symphony-reconcile-consume-failure-category-review-input-underivable | when review-input-underivable-before-github-category-is-evidenced | consume failure category `review-input-underivable` | next review-input-derivation-recovery | choice none
Retryability: Before GitHub, claim no new eligible revision; clean up and use bounded input-derivation recovery

rule symphony-reconcile-consume-failure-category-validation-timeout | when validation-timeout-category-is-evidenced | consume failure category `validation-timeout` | next validation-timeout-recovery | choice none
Retryability: Terminate, clean up, and retry only within the unchanged-state budget

rule symphony-reconcile-emit-failure-category-capability-lost | when capability-lost-category-is-evidenced | emit failure category `capability-lost` | next capability-lost-recovery | choice none

rule symphony-reconcile-consume-failure-category-capability-lost | when capability-lost-category-is-evidenced | consume failure category `capability-lost` | next capability-lost-recovery | choice none
Retryability: Pause dependent operations until capability changes

rule symphony-reconcile-emit-failure-category-cleanup-failed | when cleanup-failed-category-is-evidenced | emit failure category `cleanup-failed` | next cleanup-failed-recovery | choice none

rule symphony-reconcile-consume-failure-category-cleanup-failed | when cleanup-failed-category-is-evidenced | consume failure category `cleanup-failed` | next cleanup-failed-recovery | choice none
Retryability: Retry only ownership-checked cleanup; blocks Symphony closeout

rule symphony-reconcile-emit-failure-category-permanent-invalid | when permanent-invalid-category-is-evidenced | emit failure category `permanent-invalid` | next permanent-invalid-recovery | choice none

rule symphony-reconcile-consume-failure-category-permanent-invalid | when permanent-invalid-category-is-evidenced | consume failure category `permanent-invalid` | next permanent-invalid-recovery | choice none
Retryability: Do not retry unchanged state; require human correction
