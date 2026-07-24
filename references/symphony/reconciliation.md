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
7. Evaluate Symphony closeout.
8. Append material journal events and exit.

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

Semantic drift produces one deduplicated `semantic-drift-detected` report.
Bounded decision/capability drift uses `maestro:needs-human`; drift requiring a
strategic contract or DAG revision uses `maestro:scope-change`. Record the
prior/resume phase and never repeatedly fight a human edit. Repair only generated
or mechanically derivable metadata.

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

The state merged remains distinct from merge-reconciled and does not mean Done.
Select every merged PR whose source issue/merge SHA lacks a confirmed
`merge-reconciled` result. If `merge-observed` is absent, append it so the
confirmed GitHub merge is never forgotten; if it already exists, consume it and
continue reconciliation. The observation event never suppresses the later
reconciliation attempt.

Derive the staged binding manifest before dispatch from fresh
provider-confirmed governing context. Canonicalize
`["maestro-reconciliation-input-v1","<Symphony UUID>","<implementation issue UUID>","<repository native identity>","<PR native ID>","<merge SHA>","<contract revision>","<approved DAG revision>",<complete canonical reconciliation binding manifest>,"<final diff revision>","<resolved finding/context revision>"]`
as `reconciliation-input-v1:<lowercase SHA-256 hex>`. Canonicalize
`["maestro-reconcile-action-v1","<Symphony UUID>","<implementation issue UUID>","<repository native identity>","<PR native ID>","<merge SHA>","<contract revision>","<approved DAG revision>","<reconciliation binding manifest revision>","<reconciliation-input-v1 revision>"]`
as `reconcile-action-v1:<lowercase SHA-256 hex>`. This full identity, rather
than issue UUID plus merge SHA, is the only current reconciliation action
authority. Then:

1. Inspect the final PR, diff, and merge SHA.
2. Resolve exactly the evidence requirements whose `evidence_stage` is
   `reconciliation` or `both`. A reconciliation-stage repository commit binds
   `${current_merge}`; a review-stage repository commit bound `${current_head}`
   before merge and is not reinterpreted. Require canonical
   `resolution_outcome=exact` for every selected binding. Derive the exact
   canonical reconciliation binding manifest before dispatch. Every entry contains the
   criterion and requirement key, evidence stage, source kind and static
   provider role, oracle-derived binding-context revision and resolved locator,
   resolution outcome, observable state, and provider identity, revision, and
   evidence.
3. Run `implementation-reconciler` with that complete canonical manifest,
   `reconciliation-input-v1`, and `reconcile-action-v1` in the request identity.
4. Recompute the authoritative runtime context and canonical reconciliation
   binding manifest before accepting the response. Require byte-for-byte
   equality with the dispatched manifest, then validate the byte-for-byte manifest echo,
   exact conclusion-to-binding mapping, and the full canonical reconciler identity
   against the Symphony UUID, implementation issue UUID, repository
   native identity, PR native ID, merge SHA, contract revision, approved DAG
   revision, exact current manifest revision, `reconciliation-input-v1`
   revision, and `reconcile-action-v1` identity. Require its echoed table to
   repeat every entry/key and map every acceptance, deviation, and follow-up
   conclusion to those exact bindings; this is the complete acceptance-evidence table.
5. Follow the verdict transition below.

Only verdict `complete`, with every acceptance criterion satisfied and every
post-merge `reconciliation`/`both` requirement exactly bound and evidenced,
may persist the merge-reconciliation record and append exactly one
`merge-reconciled`. An unresolved, ambiguous, missing, unavailable, omitted,
stale, or mismatched post-merge binding makes `complete` impossible and keeps `merge-reconciled`,
implementation completion, dependant unlock, and Symphony closeout blocked and
follows bounded recovery.

Implementation completion is a separate later transition that consumes a
confirmed `merge-reconciled`; only then may the controller append `Actual
implementation`, confirmed deviations and acceptance evidence, apply bounded
downstream updates, confirm required follow-up issues, move the implementation
issue to an unambiguous existing completed status, apply its completion phase,
or unlock dependants. Symphony closeout remains a third, later transition and
no merge transition may close the Symphony.

For `human-decision`, append the observed merge and `human-decision-required`
with the decision evidence, affected subgraph, and prior/resume phase. Use
`maestro:scope-change` for a strategic contract/DAG revision and
`maestro:needs-human` for a bounded decision. Leave the issue unreconciled and
keep all downstream blockers locked.

For `inconclusive`, append the observed merge and `action-failed` with the missing
evidence and applicable finite failure category. Follow bounded retry policy,
leave the issue unreconciled, and keep all downstream blockers locked. A confirmed
GitHub merge is never forgotten: later passes consume `merge-observed` and retry
the same reconcile identity without treating it as merge-reconciled.

Local deviations are recorded after a `complete` verdict. Contract deviations
update affected undispatched work. Scope discoveries create required follow-up
issues from the canonical `follow-up-v1:` key and complete identity in the Linear
contract. Recompute and search the full identity before create or retry; one match
is reused and multiple matches fail closed. Strategic deviations pause the
affected subgraph before any completion transition.

## Entity-scoped managed issue completion

Interpret every mutually exclusive phase label with the native entity type:

- A discovery issue remains `maestro:discovery` while evidence is incomplete.
  After its result and confidence/remaining-unknowns contract is durably recorded
  in `discovery-recorded`, append `discovery-completed` and apply
  `maestro:complete` to only that discovery issue.
- An implementation issue enters `maestro:complete` only after evidenced
  `merge-reconciled`, or after `issue-cancelled` records explicit approval,
  rationale, and the approved DAG's downstream dependency disposition. An
  implementation issue completion never implies Symphony completion.
- The control issue enters `maestro:complete` only through the evidenced Symphony
  closeout and confirmed `symphony-completed` transition below.

For `maestro:needs-human` or `maestro:scope-change`, record the entity type and its
prior/resume phase. Resuming one managed issue does not resume another. An
approved cancellation unlocks no dependant unless the approved revised DAG removes
the cancelled consumed contract or names its replacement.

## Symphony closeout

Evaluate closeout only after merge reconciliation. A Symphony may close only when:

```text
final integration/outcome-verification issue succeeded with evidence
AND all approved required work is completed or explicitly cancelled with rationale
AND all merged PRs are merge-reconciled
AND no required managed PR or delegation remains active
AND no unresolved semantic drift, human decision, ambiguous mutation,
    retry exhaustion, or owned-worktree cleanup debt remains
AND every required follow-up issue exists
```

If any condition is false or unknown, retain the current non-complete phase and
report the exact gate. Merely counting terminal implementation issues must not
close the Symphony.

When every condition is freshly confirmed, update the control issue's
`Final as-built outcome`. Link final integration evidence and record the final
approved/reconciled scope plus material deviations and follow-ups. Confirm that
write, append exactly one `symphony-completed` event using its stable closeout
identity and canonical `evidence-v1:` revision, then apply `maestro:complete` to
the control issue and confirm the label transition. Recompute and search the full
closeout identity before mutation or retry; multiple matches fail closed.

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
three consecutive attempts, append one `retry-exhausted` event, apply
`maestro:needs-human` to the affected issue or control issue, and stop retrying
until relevant state changes.

Read-only refreshes may continue. Pending CI, exhausted capacity, and normal Cursor
execution are not failures and do not consume a retry budget.
