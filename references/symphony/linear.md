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
Maestro-Discovery-Revision: discovery-v1:<digest>
Maestro-Discovery-Question-Key: question-v1:<digest>
Maestro-Discovery-Creation-Identity: <canonical creation tuple>

## Question
## Repository
## Evidence required
## Relevant integration points
## Constraints to identify
## Validation commands to discover
## Result
## Confidence and remaining unknowns
```

Before any discovery issue mutation, normalize the repository/question
descriptors with the core identity text rules, encode each descriptor as
`["<normalized-repository>","<normalized-question>"]`, deduplicate exact
descriptors, and sort them by their canonical UTF-8 bytes. Each descriptor
produces one fixed approved/planned discovery question key. The discovery
revision is `discovery-v1:<digest>` of:

```json
["maestro-discovery-revision-v1","<Symphony UUID>","symphony-control-v1",[<ordered descriptors>]]
```

Append and confirm `discovery-requested` with that revision and complete ordered
descriptor set before creating an issue. Each fixed question key is
`question-v1:<digest>` of:

```json
["maestro-discovery-question-v1","<discovery revision>","<normalized repository>","<normalized question>"]
```

The embedded creation identity is the whitespace-free canonical array
`["maestro-discovery-create-v1","<Symphony UUID>","<discovery revision>","<question key>"]`.
These values are fixed by durable inputs, never model-random. Recompute the
complete identity from the confirmed `discovery-requested` record and search the
native Symphony scope before create, after an ambiguous create, and in every
fresh session. Reuse exactly one match; zero permits one create attempt; fail
closed on multiple matches and apply the bounded ambiguity pause. Apply
`maestro-managed` plus `maestro:discovery` only to the confirmed unique record.
The mandatory identity search runs before create and after an ambiguous result.

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

Recovery is staged. A pass performs only the first applicable step:

1. Proposed but not approved: perform no materialization.
2. Approved with a missing node: create only that node and await confirmation.
3. Ambiguous node creation: search its action identity; create no edge.
4. Confirmed node without its binding event: append only `dag-node-bound`.
5. All nodes bound with a missing edge: create only that edge and await confirmation.
6. Ambiguous edge creation: resolve the native edge; perform no materialization.
7. Confirmed edge without its binding event: append only `dag-edge-bound`.
8. All node and edge bindings confirmed: append only `dag-materialized`.
9. Already materialized: perform no duplicate mutation or event.

A node and its dependant edge are never created in the same unconfirmed step.
`dag-materialized` is impossible until every required binding is confirmed.

If the user rejects a proposal, append `dag-rejected` before replanning with the
Symphony UUID, exact rejected DAG/contract revision, proposal action identity,
evidence, rationale, and whether it is superseded or may be revised. A rejected
revision can never authorize materialization.

## Required follow-up issue contract

```markdown
Maestro-Follow-Up-Key: follow-up-v1:<digest>
Maestro-Follow-Up-Creation-Identity: <canonical follow-up creation tuple>

## Required outcome
## Source merge evidence
## Repository and routing
## Dependency impact
## Acceptance criteria
```

For each reconciler-declared follow-up, normalize these fields with the core
single-line text rules: classification, repository, required outcome, normalized
gap/evidence, and acceptance criteria. The reconciler and controller derive the
same `follow-up-v1:<digest>` from:

```json
["maestro-follow-up-gap-v1","<source implementation issue UUID>","<source merge SHA>",["<classification>","<repository>","<required outcome>","<normalized gap/evidence>","<acceptance criteria>"]]
```

The controller must recompute the key and reject a reconciler result whose
declared key differs. The complete embedded identity is
`["maestro-follow-up-create-v1","<Symphony UUID>","<source issue UUID>","<source merge SHA>","<follow-up key>"]`.
Search the exact native Symphony scope for the complete identity before create,
after an ambiguous create, and in a fresh session. Reuse exactly one match; zero
permits one create attempt; fail closed on multiple matches. Never duplicate the
follow-up on a later pass. Apply `maestro-managed`, repository routing,
entity-appropriate phase, and native dependency metadata required by its issue
contract.

## Symphony closeout

Before mutating closeout, build the canonical evidence list from every durable
merge-reconciled, issue-cancelled, follow-up-created, discovery-completed,
decision-resolved, and final integration evidence record that governs the final
approved DAG revision. Encode every item as exactly three JSON
strings: `["<family>","<native identity>","<durable revision>"]`. The finite
family tags and third fields are: `merge`/merge SHA,
`cancellation`/issue-cancelled action identity, `follow-up`/creation identity,
`discovery`/discovery revision, `decision`/decision-resolved action identity,
and `integration`/verification evidence revision. Deduplicate exact arrays, then sort the canonical evidence
arrays lexicographically by UTF-8 bytes. Derive `evidence-v1:<digest>` from:

```json
["maestro-closeout-evidence-v1","<Symphony UUID>","<final approved DAG revision>","<final integration issue UUID>",[<ordered canonical evidence>]]
```

The complete Symphony mutation identity is
`["maestro-symphony-complete-v1","<Symphony UUID>","<final DAG revision>","<final integration issue UUID>","<evidence revision>"]`.
Embed `Maestro-Symphony-Completion-Identity: <canonical completion identity>` and
`Maestro-Closeout-Evidence-Revision: evidence-v1:<digest>` in the
`Final as-built outcome` update. Recompute both from durable records and search
the control issue journal/native record before the final update, before a retry,
and after an ambiguous result. Reuse one exact match, permit the mutation only
for zero matches, and fail closed on multiple matches. A fresh session must
derive the identical evidence revision without process memory or model-selected
ordering.

Cleanup debt is a separate fresh closeout gate. Because a cleared temporary
resource has no durable success event in this protocol, its absence contributes
no invented evidence item; any still-present `cleanup-failed` debt blocks the
mutation before identity derivation.

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
