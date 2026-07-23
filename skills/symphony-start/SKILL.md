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

When `$ARGUMENTS` identifies an existing control issue, read its full description,
native status, native relations, labels, project/parent scope, comments, and
journal. Preserve the current native status unless a transition is unambiguous.
If the current native status is terminal or cannot be interpreted unambiguously,
stop before discovery, planning, or materialization and request a user decision.
Continue only after an explicit decision or a clearly permitted existing-workflow transition. Do not invent a Maestro status. Verify it is the intended Symphony before resuming.

For a new goal:

1. Search the target Linear scope for an existing `[Symphony]` issue with the same
   approved goal or creation action identity.
2. If none exists, create one control issue titled `[Symphony] ` followed by the
   goal and use the Control issue contract.
3. Apply `maestro-symphony` and the correct child of the `maestro` group.
4. Append one `symphony-started` journal event.

If creation returns ambiguously, search by native scope, exact title, and creation
identity before retrying.

## Discovery gate

Classify the goal:

- sufficiently understood to propose a DAG; or
- blocked by material repository, architecture, interface, validation, or rollout
  uncertainty.

For one bounded unknown, dispatch one `maestro:symphony-researcher` or
`maestro:code-architect` with a complete assignment envelope and journal the
returned evidence.

For heterogeneous or multi-repository discovery:

1. Create idempotent discovery issues from the Discovery issue contract.
2. Never delegate them to Cursor.
3. Dispatch bounded `maestro:symphony-researcher` agents in parallel, subject to
   a maximum of three active research agents and one per repository.
4. Put each result on its discovery issue.
5. Dispatch `maestro:code-architect` with the normalized repository matrix for
   cross-repository synthesis.
6. Represent unresolved uncertainty as a discovery or proof-of-concept gate; do
   not fabricate the rest of the DAG.

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

Present before materialization:

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
only to the exact revision and contracts shown.

## Materialize the approved revision

After approval:

1. Re-read the control issue and confirm the proposed revision did not drift.
2. Create each candidate issue idempotently using Symphony UUID + DAG revision +
   fixed node key.
3. Bind every node key to the returned native Linear issue.
4. Apply `maestro-managed`, the correct `maestro` phase child, risk labels, and
   matching `repo:owner/repository`.
5. Create native `blockedBy` relations only after all endpoint issues have native
   IDs.
6. Do not add redundant `relatedTo` relations.
7. Record the node-to-native-ID map and materialized native DAG.
8. Append one `dag-approved-and-materialized` journal event.

Do not delegate implementation from this skill. End with the control issue,
approved revision, created native issues, blocker graph, unresolved discovery, and
the exact `/loop 10m /maestro:symphony-reconcile ISSUE-KEY` command to start the
controller.
