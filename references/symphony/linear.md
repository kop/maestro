# Symphony Linear Contract

Use existing team statuses and native Linear relationships. Maestro provisions
only the labels defined by the core protocol.

## Control issue contract

The control issue title is `[Symphony] ` followed by the goal. Preserve the
original intent and append the as-built result.

```markdown
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

## Implementation issue contract

Every Cursor issue targets exactly one repository.

```markdown
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
