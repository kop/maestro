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

append event `human-decision-required`

Continue only after an explicit decision or a clearly permitted existing-workflow transition. Do not invent a Maestro status. Verify it is the intended Symphony before resuming.

Resume is journal-driven but provider-confirmed. Execute each applicable consume
instruction while reconstructing the control, discovery, proposal, approval,
binding, materialization, pause, and retry state:

consume event `symphony-started`

consume event `discovery-recorded`

consume event `discovery-completed`

consume event `dag-proposed`

consume event `dag-approved`

consume event `dag-node-bound`

consume event `dag-edge-bound`

consume event `dag-materialized`

consume event `human-decision-required`

consume event `action-failed`

consume event `retry-exhausted`

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

apply label `maestro-symphony`

apply label `maestro:discovery`

append event `symphony-started`

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

append event `discovery-recorded`

For heterogeneous or multi-repository discovery:

1. Create idempotent discovery issues from the Discovery issue contract and apply
   `maestro:discovery`.
2. Never delegate them to Cursor.
3. Dispatch bounded `maestro:symphony-researcher` agents in parallel, subject to
   a maximum of three active research agents and one per repository.
4. Put each result on its discovery issue and append `discovery-recorded`. When
   every required evidence item is answered or retained as an explicit unknown
   with consequence, append `discovery-completed`, then apply
   `maestro:complete` to that discovery issue only.
5. Dispatch `maestro:code-architect` with the normalized repository matrix for
   cross-repository synthesis.
6. Represent unresolved uncertainty as a discovery or proof-of-concept gate; do
   not fabricate the rest of the DAG.

append event `discovery-completed`

apply label `maestro:complete`

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

append event `dag-proposed`

apply label `maestro:planning`

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

append event `dag-approved`

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

append event `dag-node-bound`

6. Apply `maestro-managed`, `maestro:planning`, risk labels, and
   matching `repo:owner/repository`.
7. Create a native `blockedBy` relation only after both endpoints are bound.
   After each fresh confirmation, immediately append `dag-edge-bound` with its
   fixed edge identity, native endpoint UUIDs, and native relation identity when
   available.

append event `dag-edge-bound`

8. Do not add redundant `relatedTo` relations.
9. Append `dag-materialized` only after every candidate and native relation is
   confirmed and recoverable from the binding events.
10. Confirm `dag-materialized`, then transition the control issue from
    `maestro:planning` to `maestro:executing`.

append event `dag-materialized`

For a non-confirmed material mutation, append `action-failed` with the finite
outcome/category and retain the current entity phase. After the unchanged-state
attempt limit, append `retry-exhausted` and apply `maestro:needs-human` with the
prior/resume phase.

apply label `maestro-managed`

apply label `maestro-risk-security`

apply label `maestro-risk-infra`

apply label `maestro-risk-migration`

apply label `maestro:executing`

append event `action-failed`

append event `retry-exhausted`

## Classify start and materialization attempts

For every read or mutation attempted by this skill, execute exactly one outcome
emission and consume it immediately to select the transition:

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

emit failure category `capability-lost`

consume failure category `capability-lost`
Retryability: Pause dependent operations until capability changes

emit failure category `permanent-invalid`

consume failure category `permanent-invalid`
Retryability: Do not retry unchanged state; require human correction

Do not delegate implementation from this skill. End with the control issue,
approved revision, created native issues, blocker graph, unresolved discovery, and
the exact `/loop 10m /maestro:symphony-reconcile ISSUE-KEY` command to start the
controller.
