# Symphony Linear Contract

Use existing team statuses and native Linear relationships. Maestro provisions
only the labels defined by the core protocol.

## Control issue contract

Control contract revision: `symphony-control-v1`

The control issue title is `[Symphony] ` followed by the goal. Preserve the
original intent and append the as-built result.

```markdown
Maestro-Control-Creation-Identity: <canonical native-scope/goal/contract identity>
Maestro-Control-Contract-Revision: symphony-control-v1

## Outcome
## Scope
## Success criteria
## Constraints
## Out of scope
## Target Linear entities
## Execution policy
## Final as-built outcome
```

The issue or its journal links every approved DAG revision, discovery result,
managed issue, and final verification result.

The control creation identity contains the native target Linear scope UUID and
normalized requested goal. Its control-contract revision literal is
`symphony-control-v1`. The identity is exactly
`["maestro-control-create-v1","<native-scope-uuid>","<normalized-goal>","symphony-control-v1"]`
using RFC 8259 JSON string escaping and no optional whitespace. Embed the creation
identity and literal revision in the initial description/native record. Before
create and after an ambiguous response, search the native target scope for the
embedded identity and `symphony-control-v1`. Exact title matching is never
sufficient, and a random/model/agent-selected revision is forbidden.

## Discovery issue contract

Discovery issues are Maestro-managed research work and are never delegated to
Cursor.

```markdown
## Question
## Repository
## Evidence required
## Relevant integration points
## Constraints to identify
## Validation commands to discover
## Result
## Confidence and remaining unknowns
```

A new discovery issue enters `maestro:discovery`. After its result and confidence
sections are durably written, append `discovery-recorded`. When every required
evidence item is answered or explicitly retained as an unknown with consequence,
append `discovery-completed`, then apply `maestro:complete` to that discovery
issue. This completion makes the evidence consumable by planning and never means
the control issue or Symphony is complete.

## Implementation issue contract

Every Cursor issue targets exactly one repository.

```markdown
Maestro-DAG-Node-Creation-Identity: <Symphony UUID + approved DAG revision + fixed node key>

## Objective
## Symphony contribution
## Repository
## Scope
## Dependencies and consumed contracts
## Produced contracts
## Implementation constraints
## Proposed approach
## Acceptance criteria
## Validation
## Out of scope
## Expected outputs

## Actual implementation
## Deviations and decisions
## Follow-up work
```

A materialized implementation issue enters `maestro:planning`; confirmed Cursor
delegation enters `maestro:executing`. Apply `maestro:complete` only after
evidenced `merge-reconciled`, or after `issue-cancelled` records explicit approval,
the cancellation rationale, and dependency disposition from an approved DAG
revision. Completion is scoped to that implementation issue and never means the
control issue or Symphony is complete.

`Proposed approach` is guidance. Cursor may choose a materially better internal
implementation, but cannot violate the objective, constraints, scope, acceptance
criteria, or produced/consumed contracts without escalation.

## Cursor repository routing

Set the issue-level label `repo:owner/repository`, where `owner/repository` is the
exact GitHub repository. Put the same value in `## Repository`.

Before delegation:

1. Verify the field and label agree.
2. Search the description and comments for Cursor's higher-priority
   `[repo=owner/repository]` syntax.
3. Treat any conflicting repository value as semantic drift.
4. Split multi-repository work into one implementation issue per repository.

## Native DAG identity

Before issue creation, an approved DAG proposal may use a fixed human-readable
node key such as `SYM-42/DAG-3/N07`. Read it from the approved proposal; never
regenerate or hash it.

After Linear creates the issue, bind the node key to the returned native issue:

```text
N07 -> FB-2184
```

The materialized DAG uses native Linear issue identifiers and native `blockedBy`
relations. Do not add a redundant `relatedTo` relation for the same dependency.

## Approval records

Every material DAG revision records:

- revision number;
- approved goal and contract revision;
- fixed node keys and their proposed issue contracts;
- dependency edges with named produced/consumed artifacts;
- execution waves;
- explicit user approval;
- native issue bindings after materialization.

Only approved revisions may become dispatchable.

## Durable DAG approval and materialization

Before requesting approval, append `dag-proposed` with the control issue native
UUID, contract revision, fixed proposal node keys, complete candidate issue
contracts, repository routing, dependency edges, waves, open assumptions, and
proposal action identity. After explicit approval of that exact revision, append
`dag-approved` with approval evidence and the exact approved DAG
revision/contract identity before creating any issue or relation. Approval for a
different revision conveys no authority.

Each candidate embeds its Symphony UUID + approved DAG revision + fixed node key
creation identity in its initial description. Search that embedded action identity
before retrying an ambiguous create. Immediately after each confirmed creation or
identity match, append `dag-node-bound` with the fixed node key, action identity,
native Linear UUID, and human key.

Create a native `blockedBy` relation only after both endpoints are bound. Append
`dag-edge-bound` after each relation is confirmed, recording both native endpoint
UUIDs and the native relation identity when available. Append `dag-materialized`
only after every candidate and relation is confirmed. A fresh pass reconstructs
`dag-approved`, existing `dag-node-bound` and `dag-edge-bound` events, verifies
them against native records, and resumes only the missing work.

## Symphony closeout

The control issue remains open until the final integration/outcome-verification
issue has succeeded with linked evidence and all of these conditions are true:

- every approved required item is completed or explicitly cancelled with rationale;
- all merged PRs are merge-reconciled;
- no required managed PR or delegation remains active;
- no unresolved semantic drift, human decision, ambiguous mutation, retry
  exhaustion, or owned-worktree cleanup debt remains; and
- every required follow-up issue exists.

At closeout, append the control issue's `Final as-built outcome`, link final
integration evidence, record the final approved/reconciled scope and material
deviations/follow-ups, append exactly one `symphony-completed` event, and only then
apply `maestro:complete` to the control issue. `maestro:complete` on a discovery or
implementation issue never satisfies this closeout transition. Merely observing
terminal implementation issues must not close the Symphony.
