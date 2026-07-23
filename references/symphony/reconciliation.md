# Symphony Reconciliation Protocol

Each `/maestro:symphony-reconcile` invocation performs one bounded pass and exits.
It never sleeps or polls; `/loop` owns repetition.

## Pass order

1. Reconstruct full observed state.
2. Detect and classify manual drift.
3. Reconcile newly merged PRs first.
4. Review every unreviewed relevant PR head.
5. Continue approved discovery and propose planning revisions.
6. Dispatch ready implementation issues.
7. Append material journal events and exit.

A failure in one repository or subgraph does not halt unrelated work.

## Drift policy

Linear is shared state; human and automation edits are expected.

| Drift | Response |
|---|---|
| Missing generated Maestro label | Repair mechanically |
| Clearly stale workflow status | Normalize only when unambiguous |
| Objective, constraints, or acceptance criteria changed | Pause affected subgraph |
| Dependency added, removed, or reversed | Pause and show exact edge diff |
| Cursor delegation changed | Treat as potentially intentional |
| Done without a merge-reconciliation record | Do not unlock dependants |
| Linked PR changed, closed, or replaced | Resolve the implementation source |
| GitHub merged state disagrees with Linear | Trust merge evidence and reconcile Linear |

Semantic drift produces one deduplicated report and `maestro:needs-human`. Never
repeatedly fight a human edit. Repair only generated or mechanically derivable
metadata.

## Dispatch readiness

An implementation issue is ready only when:

```text
approved DAG revision governs it
AND every blocker is complete and merge-reconciled
AND contract revision is approved
AND repository and validation are known
AND no unresolved drift or human decision exists
AND no Cursor dispatch or implementation PR exists
```

## Dispatch preflight

Immediately before delegation, re-read the issue and affected native objects.
Verify the approved revision, blockers, eligible existing status, repository
routing, complete acceptance/validation, Cursor availability, absence of an
existing implementation, and unused action identity.

Stable failure reason codes:

```text
not-approved
blocker-unreconciled
status-ineligible
repository-routing-conflict
contract-incomplete
cursor-unavailable
existing-implementation
semantic-drift
already-dispatched
```

A failed preflight skips only that issue. It never prevents merge reconciliation,
review, cleanup, discovery, or unrelated dispatch.

## Bounded deterministic dispatch

Defaults:

```text
maximum active Cursor issues: 3
maximum active issues per repository: 1
```

Approve same-repository concurrency only after overlap analysis proves
independence. When capacity is insufficient, order ready issues by:

1. approved wave and topological readiness;
2. Linear priority, unknown last;
3. first journaled ready time, falling back to creation time;
4. native issue identifier.

Capacity exhaustion is not a failure and creates no journal event.

## PR responsibility

Cursor owns failing CI and all human, bot, and Maestro review resolution. Maestro
does not diagnose ordinary CI failures or triage other reviewers' comments.

A PR is merge-ready only when repository policy reports zero failing checks, at
least one approval from a human or bot, addressed review comments/threads, and all
remaining configured gates satisfied. Maestro does not merge.

## Post-merge reconciliation

Merged does not mean Done. For each new merge:

1. Inspect the final PR, diff, and merge SHA.
2. Run `implementation-reconciler`.
3. Append `Actual implementation`, deviations, and acceptance evidence.
4. Apply bounded updates to undispatched downstream context, proposed approach,
   validation, and dependency notes.
5. Propose follow-up issues for discovered work.
6. Request approval for objective, scope, acceptance-criteria, strategic DAG, or
   running-work changes.
7. Record the merge action identity.
8. Mark complete and recalculate readiness.

Local deviations are recorded. Contract deviations update affected undispatched
work. Scope discoveries propose follow-up work. Strategic deviations pause the
affected subgraph.

## Failure taxonomy and bounded recovery

| Category | Response |
|---|---|
| `observation-failed` | No dependent mutation; retry read later |
| `observation-incomplete` | Resolve directly by native ID |
| `external-transient` | Retry affected operation; continue unrelated work |
| `mutation-ambiguous` | Search native target and action identity before retry |
| `semantic-drift` | Pause affected subgraph for a decision |
| `review-stale-head` | Discard unpublished result; review new head |
| `validation-timeout` | Terminate command, clean up, report inconclusive |
| `capability-lost` | Pause only dependent operations |
| `cleanup-failed` | Journal once; retry ownership-checked cleanup |
| `permanent-invalid` | Apply `maestro:needs-human`; wait for state change |

Mutations and expensive reviews default to three consecutive attempts with the
same action identity and unchanged external state. Journal each attempt. After
three consecutive attempts, record one exhaustion event, apply
`maestro:needs-human` to the affected issue or control issue, and stop retrying
until relevant state changes.

Read-only refreshes may continue. Pending CI, exhausted capacity, and normal Cursor
execution are not failures and do not consume a retry budget.
