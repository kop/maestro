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

consume event `symphony-started`

consume event `discovery-recorded`

consume event `discovery-completed`

consume event `dag-proposed`

consume event `dag-approved`

consume event `dag-node-bound`

consume event `dag-edge-bound`

consume event `dag-materialized`

consume event `semantic-drift-detected`

consume event `issue-dispatched`

consume event `review-recorded`

consume event `review-stale-head`

consume event `merge-observed`

consume event `merge-reconciled`

consume event `human-decision-required`

consume event `follow-up-created`

consume event `issue-cancelled`

consume event `action-failed`

consume event `retry-exhausted`

consume event `cleanup-failed`

consume event `symphony-completed`

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

append event `semantic-drift-detected`

GitHub merge evidence is authoritative over lagging Linear automation. Done without
a merge-reconciliation identity never unlocks dependants.

## 3. Reconcile merges first

For every merged PR lacking a confirmed merge action identity:

1. Re-read the final PR and merge SHA. Append or recover `merge-observed` so the
   confirmed GitHub merge is never forgotten while merged remains distinct from
   merge-reconciled.
2. Obtain the final diff and relevant repository evidence.
3. Dispatch `maestro:implementation-reconciler` with the complete reconciliation
   envelope.
4. Validate the reconciler identity against the requested PR, issue UUID, merge
   SHA, contract revision, and DAG revision. Validate its declared verdict and
   acceptance-evidence table.
5. Only verdict `complete`, with every acceptance criterion satisfied and
   evidenced, may append `Actual implementation`, `Deviations and decisions`, and
   `Follow-up work`; apply bounded downstream edits; create and confirm required
   follow-ups with `follow-up-created`; record `merge-reconciled`; move the issue
   to an unambiguous native completed status; apply `maestro:complete` to that
   implementation issue; or unlock dependants. This implementation transition
   never implies completion of the control issue or Symphony.
6. For `human-decision`, journal `merge-observed` and
   `human-decision-required` with decision evidence and prior/resume phase. Apply
   `maestro:scope-change` for strategic contract/DAG revision or
   `maestro:needs-human` for a bounded decision; leave the issue unreconciled and
   keep all downstream blockers locked.
7. For `inconclusive`, journal `merge-observed` and `action-failed` with the
   missing evidence and finite failure category, then follow bounded retry policy;
   leave the issue unreconciled and keep all downstream blockers locked.
8. Recalculate downstream readiness only after confirmed `merge-reconciled`.

append event `merge-observed`

append event `merge-reconciled`

append event `human-decision-required`

append event `follow-up-created`

append event `action-failed`

Consume the reconciler result according to its exact returned value:

consume reconciliation verdict `complete`

consume reconciliation verdict `human-decision`

consume reconciliation verdict `inconclusive`

An ambiguous write is searched by native target/action identity before retry.

## 4. Review new PR heads

For each relevant current PR head without a confirmed review identity:

1. Assemble the complete Required review identity.
2. Invoke internal `maestro:symphony-review` through the Skill tool.
3. Record its exact-SHA result and cleanup status.
4. If the head became stale, publish nothing and leave the new head eligible.
5. If changes are required, let the internal skill create the canonical GitHub
   record and Linear `@Cursor` follow-up.
6. If human judgment is required, pause only the affected subgraph.

Consume the review result according to its exact returned value:

consume review verdict `pass`

consume review verdict `changes-required`

consume review verdict `human-decision`

consume review verdict `inconclusive`

Maestro does not triage other reviewers' comments and does not diagnose ordinary
CI failures. Cursor owns all PR convergence.

Do not mark a PR merge-ready unless current repository gates show zero failing
checks, at least one human/bot approval, addressed review comments/threads, all
other policy gates satisfied, and the passing Maestro review identity matches the
current head.

## 5. Continue discovery and planning

For approved outstanding discovery:

- dispatch `maestro:symphony-researcher` with bounded parallelism;
- create any approved discovery issue with `maestro-managed` and
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

append event `discovery-recorded`

append event `discovery-completed`

append event `dag-proposed`

append event `dag-approved`

append event `dag-node-bound`

append event `dag-edge-bound`

append event `dag-materialized`

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

append event `issue-dispatched`

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

append event `issue-cancelled`

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

append event `symphony-completed`

## 8. Journal and exit

Append only material events from the pass. Re-read each target before mutation and
confirm external outcomes afterward.

Mutations and expensive reviews use the failure taxonomy and a default maximum of
three consecutive attempts with the same action identity and unchanged state.
After three consecutive attempts, append one `retry-exhausted` event, apply
`maestro:needs-human`, and wait for relevant state change.

append event `retry-exhausted`

If ownership-checked cleanup cannot complete, preserve its debt and execute:

append event `cleanup-failed`

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

apply label `maestro-managed`

apply label `maestro:discovery`

apply label `maestro:planning`

apply label `maestro:executing`

apply label `maestro:needs-human`

apply label `maestro:scope-change`

apply label `maestro:complete`

apply label `maestro-risk-security`

apply label `maestro-risk-infra`

apply label `maestro-risk-migration`

## Classify reconciliation attempts

Every provider read, review, or mutation attempt emits exactly one outcome and
consumes it to select the transition:

emit outcome `confirmed`

consume outcome `confirmed`

emit outcome `ambiguous`

consume outcome `ambiguous`

emit outcome `retryable-failure`

consume outcome `retryable-failure`

emit outcome `permanent-failure`

consume outcome `permanent-failure`

When the outcome requires a category, emit an applicable locally produced
category. Consume every category returned by this pass or by `symphony-review`,
using the adjacent retryability rule:

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

consume failure category `review-stale-head`
Retryability: Do not retry the stale identity; create a new identity for the new head

consume failure category `validation-timeout`
Retryability: Terminate, clean up, and retry only within the unchanged-state budget

emit failure category `capability-lost`

consume failure category `capability-lost`
Retryability: Pause dependent operations until capability changes

emit failure category `cleanup-failed`

consume failure category `cleanup-failed`
Retryability: Retry only ownership-checked cleanup; blocks Symphony closeout

emit failure category `permanent-invalid`

consume failure category `permanent-invalid`
Retryability: Do not retry unchanged state; require human correction
