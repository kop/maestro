---
name: symphony-start
description: Use when starting or resuming a Maestro Symphony for an epic, milestone, Linear project, broader goal, or existing `[Symphony]` issue.
disable-model-invocation: true
---

# Start or resume a Symphony

Input: `$ARGUMENTS`, interpreted as either a goal or an existing `[Symphony]`
Linear issue reference. If empty, ask for the goal before any external mutation.

Read these completely before acting:

- `${CLAUDE_PLUGIN_ROOT}/references/symphony/core.md`
- `${CLAUDE_PLUGIN_ROOT}/references/symphony/linear.md`
- `${CLAUDE_PLUGIN_ROOT}/references/symphony/reconciliation.md`

This skill is the Maestro-specific adapter for Superpowers brainstorming and
writing-plans discipline. Apply their research, alternatives, explicit approval,
small verifiable work units, and evidence requirements at the Symphony/DAG level.
Do not run a product-code implementation workflow. Do not use
subagent-driven-development; Cursor delegation later replaces the implementer
loop.

## Capability preflight

Before creating or modifying a Symphony, verify:

1. Linear read/write access and visibility of the target team/project/epic.
2. GitHub read and PR-comment access.
3. Whether the current GitHub identity can submit approvals/request-changes.
4. Cursor is available as a Linear delegation target.
5. The `maestro` label group and required independent labels exist or can be
   created.
6. The Cursor-defined `repo` label group and required
   `repo:owner/repository` children exist or can be created.
7. Required repositories are present in available workspaces or can be cloned.
8. Temporary review worktrees can be created and removed.
9. Linear `@Cursor` comments are supported for delegated follow-up.

Classify missing capability as:

- hard blocker;
- reduced-functionality warning; or
- repository-specific discovery.

Do not create a control issue when a hard blocker makes the Symphony unrecoverable.
Record warnings in the first journal event.

## Establish the control issue

Control contract revision: `symphony-control-v1`

The control-contract revision is fixed by the protocol, not selected at runtime.
Every creation lookup uses native target scope plus the embedded identity.

When `$ARGUMENTS` identifies an existing control issue, read its full description,
native status, native relations, labels, project/parent scope, comments, and
journal. Require the persisted `symphony-control-v1` revision and matching
four-item creation identity; a missing or different revision does not authorize
recomputation or rebinding.
Preserve the current native status unless a transition is unambiguous.
If the current native status is terminal or cannot be interpreted unambiguously,
append `human-decision-required` with the prior/resume phase; stop before discovery, planning, or materialization and request a user decision.

rule symphony-start-append-event-human-decision-required | when bounded-or-strategic-human-authority-is-required | append event `human-decision-required` | next affected-subgraph-paused | choice none

Continue only after an explicit decision or a clearly permitted existing-workflow transition. Do not invent a Maestro status. Verify it is the intended Symphony before resuming.

Resume is journal-driven but provider-confirmed. Execute each applicable consume
instruction while reconstructing the control, discovery, proposal, approval,
binding, materialization, pause, and retry state:

rule symphony-start-consume-event-symphony-started | when control-creation-is-confirmed | consume event `symphony-started` | next entity-discovery | choice none

rule symphony-start-consume-event-discovery-requested | when canonical-discovery-request-is-durably-confirmed | consume event `discovery-requested` | next discovery-active | choice none

rule symphony-start-consume-event-discovery-recorded | when discovery-evidence-is-durably-confirmed | consume event `discovery-recorded` | next discovery-active | choice none

rule symphony-start-consume-event-discovery-completed | when discovery-result-contract-is-confirmed | consume event `discovery-completed` | next entity-complete | choice none

rule symphony-start-consume-event-dag-proposed | when exact-dag-proposal-is-durably-confirmed | consume event `dag-proposed` | next entity-planning | choice none

rule symphony-start-consume-event-dag-approved | when exact-dag-revision-approval-is-durably-confirmed | consume event `dag-approved` | next dag-recovery | choice none

rule symphony-start-consume-event-dag-rejected | when exact-dag-rejection-is-durably-confirmed | consume event `dag-rejected` | next dag-replanning | choice none

rule symphony-start-consume-event-dag-node-bound | when one-native-node-binding-is-confirmed | consume event `dag-node-bound` | next dag-recovery | choice none

rule symphony-start-consume-event-dag-edge-bound | when one-native-edge-binding-is-confirmed | consume event `dag-edge-bound` | next dag-recovery | choice none

rule symphony-start-consume-event-dag-materialized | when all-native-bindings-and-events-are-confirmed | consume event `dag-materialized` | next entity-executing | choice none

rule symphony-start-consume-event-semantic-drift-detected | when normalized-contract-or-edge-drift-is-confirmed | consume event `semantic-drift-detected` | next affected-subgraph-paused | choice none

rule symphony-start-consume-event-human-decision-required | when bounded-or-strategic-human-authority-is-required | consume event `human-decision-required` | next affected-subgraph-paused | choice none

rule symphony-start-consume-event-decision-resolved | when resolution-disposition-and-resume-evidence-are-confirmed | consume event `decision-resolved` | next recorded-resume-phase | choice none

rule symphony-start-consume-event-action-failed | when material-action-attempt-is-not-confirmed | consume event `action-failed` | next bounded-recovery | choice none

rule symphony-start-consume-event-retry-exhausted | when unchanged-state-retry-budget-is-exhausted | consume event `retry-exhausted` | next entity-needs-human | choice none

For a new goal:

1. Normalize the requested goal exactly as the core protocol specifies. Derive the
   control creation identity from the native target Linear scope UUID and
   normalized goal as the exact four-item JSON array defined by the Linear
   contract. The fourth JSON array item is `symphony-control-v1`; this skill and
   its agent must not select another revision.
2. Pre-create lookup uses `symphony-control-v1` and searches the native target
   scope for the full embedded identity. Exact title matching is never sufficient.
3. If none exists, create one control issue titled `[Symphony] ` followed by the
   goal, use the Control issue contract, and persist `symphony-control-v1` plus
   the creation identity in the initial description/native record.
4. Apply `maestro-symphony` and `maestro:discovery`.
5. Append one `symphony-started` journal event.

rule symphony-start-apply-label-maestro-symphony | when native-role-scope-is-confirmed | apply label `maestro-symphony` | next role-label-confirmed | choice none

rule symphony-start-apply-label-maestro-discovery | when entity-scoped-discovery-authority-is-confirmed | apply label `maestro:discovery` | next entity-discovery | choice entity-phase

rule symphony-start-append-event-symphony-started | when control-creation-is-confirmed | append event `symphony-started` | next entity-discovery | choice none

Ambiguous-create lookup uses `symphony-control-v1` and searches the same native
target scope for the full embedded identity before retrying. The title may
disambiguate display results but never authorizes reuse by itself.

## Discovery gate

Classify the goal:

- sufficiently understood to propose a DAG; or
- blocked by material repository, architecture, interface, validation, or rollout
  uncertainty.

For one bounded unknown, dispatch one `maestro:symphony-researcher` or
`maestro:code-architect` with a complete assignment envelope and append
`discovery-recorded` for the returned evidence.

rule symphony-start-append-event-discovery-recorded | when discovery-evidence-is-durably-confirmed | append event `discovery-recorded` | next discovery-active | choice none

For heterogeneous or multi-repository discovery:

1. Canonicalize the complete repository/question descriptor set as the Linear
   contract specifies. Append and confirm `discovery-requested` with its
   reproducible discovery revision and fixed question keys before any issue
   mutation.
2. Create idempotent discovery issues from the Discovery issue contract. Derive
   `Maestro-Discovery-Creation-Identity` from the discovery revision + fixed discovery question key in that confirmed record, embed
   it in the initial issue, and search the exact native scope before create,
   after an ambiguous create, and in a fresh session. Reuse one match and fail
   closed on multiple matches. Apply `maestro-managed` plus
   `maestro:discovery`. The fixed approved/planned key is never model-random.
3. Never delegate them to Cursor.
4. Dispatch bounded `maestro:symphony-researcher` agents in parallel, subject to
   a maximum of three active research agents and one per repository.
5. Put each result on its discovery issue and append `discovery-recorded`. When
   every required evidence item is answered or retained as an explicit unknown
   with consequence, append `discovery-completed`, then apply
   `maestro:complete` to that discovery issue only.
6. Dispatch `maestro:code-architect` with the normalized repository matrix for
   cross-repository synthesis.
7. Represent unresolved uncertainty as a discovery or proof-of-concept gate; do
   not fabricate the rest of the DAG.

rule symphony-start-append-event-discovery-requested | when canonical-discovery-request-is-durably-confirmed | append event `discovery-requested` | next discovery-active | choice none

rule symphony-start-append-event-discovery-completed | when discovery-result-contract-is-confirmed | append event `discovery-completed` | next entity-complete | choice none

rule symphony-start-apply-label-maestro-complete | when entity-scoped-completion-authority-is-confirmed | apply label `maestro:complete` | next entity-complete | choice entity-phase

## Plan the DAG revision

Produce two or three viable high-level approaches when the architecture admits
real alternatives. Recommend one and explain its outcome, risks, sequencing, and
reversibility.

Draft the smallest acyclic approved subgraph that delivers a verifiable increment.
Each candidate implementation issue must:

- use the Implementation issue contract;
- target one `owner/repository`;
- carry matching `repo:owner/repository` routing;
- have observable acceptance criteria and exact validation guidance;
- name produced and consumed contracts;
- use a fixed proposal node key;
- remain small enough for focused implementation/review;
- identify applicable Maestro risk labels.

Every dependency edge names the prerequisite artifact. Include a final integration
and outcome-verification issue from the first revision even when later details
remain behind discovery.

## Approval gate

Before requesting approval, append one complete `dag-proposed` event to the
control issue. It must include the control issue native UUID, contract revision,
fixed proposal node keys, complete candidate issue contracts, repository routing,
dependency edges, execution waves, open assumptions, and proposal action identity.
Confirm the comment from a fresh native read; if it is ambiguous, search that
proposal action identity before retrying. Apply `maestro:planning` after the
`dag-proposed` event is confirmed. Only then request explicit user approval and
present:

rule symphony-start-append-event-dag-proposed | when exact-dag-proposal-is-durably-confirmed | append event `dag-proposed` | next entity-planning | choice none

rule symphony-start-apply-label-maestro-planning | when entity-scoped-planning-authority-is-confirmed | apply label `maestro:planning` | next entity-planning | choice entity-phase

```markdown
## Proposed DAG revision
- Symphony:
- Revision:
- Goal and contract revision:

## Candidate issues
| Node key | Repository | Objective | Blocked by | Produces | Consumes | Validation |
|---|---|---|---|---|---|---|

## Execution waves
| Wave | Node keys | Verifiable increment |
|---|---|---|

## Open assumptions
- Assumption:
  Planned gate:
```

Require explicit user approval for this DAG revision. A previous approval applies
only to the exact revision and contracts shown. Before any candidate issue or
relation is created, append and confirm one `dag-approved` event containing the
approval evidence, proposal action identity, and exact approved DAG
revision/contract identity. Approval of another revision must not authorize this
one.

rule symphony-start-append-event-dag-approved | when exact-dag-revision-approval-is-durably-confirmed | append event `dag-approved` | next dag-recovery | choice none

If the user rejects the proposal, append `dag-rejected` with the Symphony UUID,
exact rejected DAG/contract revision, proposal action identity, rejection evidence
and rationale, and whether it is superseded or may be revised. Confirm the event
before replanning; the rejected revision never authorizes materialization.

rule symphony-start-append-event-dag-rejected | when exact-dag-rejection-is-durably-confirmed | append event `dag-rejected` | next dag-replanning | choice none

## Materialize the approved revision

After `dag-approved` is confirmed:

1. Re-read the control issue and confirm the proposed and approved revision did
   not drift.
2. Reconstruct every prior `dag-node-bound` and `dag-edge-bound` event and verify
   the referenced native objects. A fresh pass must resume a partially
   materialized approved revision without duplicating issues, relations, or
   approval evidence.
3. Create or resume each candidate idempotently using the Symphony UUID, approved
   DAG revision, and fixed node key. Embed that fixed creation action identity in
   the initial issue description.
4. Before create, and after an ambiguous create, search the embedded action
   identity before retry. Treat an exact title as display evidence only.
5. After each confirmed candidate creation or identity match, immediately append
   `dag-node-bound`, mapping the fixed node key/action identity to the returned
   native Linear UUID and human key. Do not wait for other candidates.

rule symphony-start-append-event-dag-node-bound | when one-native-node-binding-is-confirmed | append event `dag-node-bound` | next dag-recovery | choice none

6. Apply `maestro-managed`, `maestro:planning`, risk labels, and
   matching `repo:owner/repository`.
7. Create a native `blockedBy` relation only after both endpoints are bound.
   After each fresh confirmation, immediately append `dag-edge-bound` with its
   fixed edge identity, native endpoint UUIDs, and native relation identity when
   available.

rule symphony-start-append-event-dag-edge-bound | when one-native-edge-binding-is-confirmed | append event `dag-edge-bound` | next dag-recovery | choice none

8. Do not add redundant `relatedTo` relations.
9. Append `dag-materialized` only after every candidate and native relation is
   confirmed and recoverable from the binding events.
10. Confirm `dag-materialized`, then transition the control issue from
    `maestro:planning` to `maestro:executing`.

rule symphony-start-append-event-dag-materialized | when all-native-bindings-and-events-are-confirmed | append event `dag-materialized` | next entity-executing | choice none

Perform only the first missing step in a pass: create one missing node and await
confirmation; resolve an ambiguous node before any edge; append only its missing
`dag-node-bound`; create one missing edge only after all nodes are bound; resolve
an ambiguous edge before materialization; append only its missing
`dag-edge-bound`; then append only `dag-materialized`. Never create a node and
dependant edge in the same unconfirmed step.

When a prior `human-decision-required`, `semantic-drift-detected`, or
`retry-exhausted` pause appears, preserve its exact pause identity and prior/resume
phase. A changed external observation alone never resumes work. Confirm a matching
`decision-resolved` for that exact pause identity, finite disposition, governing
revision, affected subgraph, required approval evidence, and recorded resume phase
before any resume. Only then, atomically remove the matching pause label and
restore the declared phase; a stale or mismatched resolution remains paused.
Require the matching `decision-resolved` before any resume transition.

rule symphony-start-append-event-decision-resolved | when resolution-disposition-and-resume-evidence-are-confirmed | append event `decision-resolved` | next recorded-resume-phase | choice none

For a non-confirmed material mutation, append `action-failed` with the finite
outcome/category and retain the current entity phase. After the unchanged-state
attempt limit, append `retry-exhausted` with a reproducible pause identity and
apply `maestro:needs-human` with the prior/resume phase. Relevant external state
change may use disposition `resume-after-confirmed-external-state-change`, but
only a matching durable `decision-resolved` authorizes the retry.
Derive and validate the complete `retry-pause-v1:` identity before either
mutation; missing inputs or a mismatched digest suppress both the event and label
and retain the prior phase.

rule symphony-start-apply-label-maestro-managed | when native-role-scope-is-confirmed | apply label `maestro-managed` | next role-label-confirmed | choice none

rule symphony-start-apply-label-maestro-risk-security | when issue-label-or-changed-surface-has-security-risk | apply label `maestro-risk-security` | next security-lens-selected | choice none

rule symphony-start-apply-label-maestro-risk-infra | when issue-label-or-changed-surface-has-infrastructure-risk | apply label `maestro-risk-infra` | next infrastructure-lens-selected | choice none

rule symphony-start-apply-label-maestro-risk-migration | when issue-label-or-changed-surface-has-migration-risk | apply label `maestro-risk-migration` | next migration-lenses-selected | choice none

rule symphony-start-apply-label-maestro-executing | when entity-scoped-execution-authority-is-confirmed | apply label `maestro:executing` | next entity-executing | choice entity-phase

rule symphony-start-apply-label-maestro-needs-human | when entity-scoped-bounded-pause-is-confirmed | apply label `maestro:needs-human` | next entity-needs-human | choice entity-phase

rule symphony-start-append-event-action-failed | when material-action-attempt-is-not-confirmed | append event `action-failed` | next bounded-recovery | choice none

rule symphony-start-append-event-retry-exhausted | when unchanged-state-retry-budget-is-exhausted | append event `retry-exhausted` | next entity-needs-human | choice none

## Classify start and materialization attempts

For every read or mutation attempted by this skill, execute exactly one outcome
emission and consume it immediately to select the transition:

rule symphony-start-emit-outcome-confirmed | when external-result-is-freshly-confirmed | emit outcome `confirmed` | next advance-confirmed-transition | choice action-outcome

rule symphony-start-consume-outcome-confirmed | when external-result-is-freshly-confirmed | consume outcome `confirmed` | next advance-confirmed-transition | choice action-outcome

rule symphony-start-emit-outcome-ambiguous | when external-result-may-exist-without-confirmation | emit outcome `ambiguous` | next resolve-action-identity | choice action-outcome

rule symphony-start-consume-outcome-ambiguous | when external-result-may-exist-without-confirmation | consume outcome `ambiguous` | next resolve-action-identity | choice action-outcome

rule symphony-start-emit-outcome-retryable-failure | when unchanged-state-permits-bounded-retry | emit outcome `retryable-failure` | next bounded-retry-with-phase-retained | choice action-outcome

rule symphony-start-consume-outcome-retryable-failure | when unchanged-state-permits-bounded-retry | consume outcome `retryable-failure` | next bounded-retry-with-phase-retained | choice action-outcome

rule symphony-start-emit-outcome-permanent-failure | when confirmed-invalid-state-or-capability-blocks-retry | emit outcome `permanent-failure` | next pause-affected-work | choice action-outcome

rule symphony-start-consume-outcome-permanent-failure | when confirmed-invalid-state-or-capability-blocks-retry | consume outcome `permanent-failure` | next pause-affected-work | choice action-outcome

When the outcome requires a category, emit one applicable category and consume
it with the adjacent retryability rule:

rule symphony-start-emit-failure-category-observation-failed | when observation-failed-category-is-evidenced | emit failure category `observation-failed` | next observation-failed-recovery | choice none

rule symphony-start-consume-failure-category-observation-failed | when observation-failed-category-is-evidenced | consume failure category `observation-failed` | next observation-failed-recovery | choice none
Retryability: Retry the read later; authorize no dependent mutation

rule symphony-start-emit-failure-category-observation-incomplete | when observation-incomplete-category-is-evidenced | emit failure category `observation-incomplete` | next observation-incomplete-recovery | choice none

rule symphony-start-consume-failure-category-observation-incomplete | when observation-incomplete-category-is-evidenced | consume failure category `observation-incomplete` | next observation-incomplete-recovery | choice none
Retryability: Resolve directly by native ID before retrying the dependent action

rule symphony-start-emit-failure-category-external-transient | when external-transient-category-is-evidenced | emit failure category `external-transient` | next external-transient-recovery | choice none

rule symphony-start-consume-failure-category-external-transient | when external-transient-category-is-evidenced | consume failure category `external-transient` | next external-transient-recovery | choice none
Retryability: Retry the affected operation while unrelated work continues

rule symphony-start-emit-failure-category-mutation-ambiguous | when mutation-ambiguous-category-is-evidenced | emit failure category `mutation-ambiguous` | next mutation-ambiguous-recovery | choice none

rule symphony-start-consume-failure-category-mutation-ambiguous | when mutation-ambiguous-category-is-evidenced | consume failure category `mutation-ambiguous` | next mutation-ambiguous-recovery | choice none
Retryability: Search by native target and action identity before any retry

rule symphony-start-emit-failure-category-semantic-drift | when semantic-drift-category-is-evidenced | emit failure category `semantic-drift` | next semantic-drift-recovery | choice none

rule symphony-start-consume-failure-category-semantic-drift | when semantic-drift-category-is-evidenced | consume failure category `semantic-drift` | next semantic-drift-recovery | choice none
Retryability: Do not retry mutation; require bounded decision or strategic revision

rule symphony-start-emit-failure-category-capability-lost | when capability-lost-category-is-evidenced | emit failure category `capability-lost` | next capability-lost-recovery | choice none

rule symphony-start-consume-failure-category-capability-lost | when capability-lost-category-is-evidenced | consume failure category `capability-lost` | next capability-lost-recovery | choice none
Retryability: Pause dependent operations until capability changes

rule symphony-start-emit-failure-category-permanent-invalid | when permanent-invalid-category-is-evidenced | emit failure category `permanent-invalid` | next permanent-invalid-recovery | choice none

rule symphony-start-consume-failure-category-permanent-invalid | when permanent-invalid-category-is-evidenced | consume failure category `permanent-invalid` | next permanent-invalid-recovery | choice none
Retryability: Do not retry unchanged state; require human correction

Do not delegate implementation from this skill. End with the control issue,
approved revision, created native issues, blocker graph, unresolved discovery, and
the exact `/loop 10m /maestro:symphony-reconcile ISSUE-KEY` command to start the
controller.
