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

## 2. Detect drift

Compare every approved issue contract and native dependency set with current
Linear. Apply the reconciliation protocol's drift table.

Repair only generated, mechanically derivable metadata. For semantic drift:

1. pause only the affected subgraph;
2. apply `maestro:needs-human`;
3. append one deduplicated event with the exact contract or edge diff;
4. do not repeatedly restore the old value.

GitHub merge evidence is authoritative over lagging Linear automation. Done without
a merge-reconciliation identity never unlocks dependants.

## 3. Reconcile merges first

For every merged PR lacking a confirmed merge action identity:

1. Re-read the final PR and merge SHA.
2. Obtain the final diff and relevant repository evidence.
3. Dispatch `maestro:implementation-reconciler` with the complete reconciliation
   envelope.
4. Validate the returned merge identity and evidence.
5. Append `Actual implementation`, `Deviations and decisions`, and `Follow-up
   work` without replacing the original issue contract.
6. Apply only allowed bounded edits to undispatched downstream context, proposed
   approach, validation, and dependency notes.
7. Create proposed follow-up issues idempotently when required.
8. Pause and request approval for objective, scope, acceptance, strategic DAG, or
   running-work changes.
9. Confirm the merge action identity externally, then move the issue to the
   appropriate existing completed status and apply `maestro:complete`.
10. Recalculate downstream readiness.

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

Maestro does not triage other reviewers' comments and does not diagnose ordinary
CI failures. Cursor owns all PR convergence.

Do not mark a PR merge-ready unless current repository gates show zero failing
checks, at least one human/bot approval, addressed review comments/threads, all
other policy gates satisfied, and the passing Maestro review identity matches the
current head.

## 5. Continue discovery and planning

For approved outstanding discovery:

- dispatch `maestro:symphony-researcher` with bounded parallelism;
- write returned evidence to the matching discovery issue;
- use `maestro:code-architect` for cross-repository synthesis;
- propose a new versioned DAG wave only when evidence is sufficient.

Every material DAG revision requires explicit user approval. A `/loop` pass may
prepare and journal the proposal, apply `maestro:needs-human`, and report it; it
must not self-approve or dispatch that revision.

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

If delegation is ambiguous, search for the existing Cursor delegation before
retrying. Capacity exhaustion is not a failure and creates no event.

## 7. Journal and exit

Append only material events from the pass. Re-read each target before mutation and
confirm external outcomes afterward.

Mutations and expensive reviews use the failure taxonomy and a default maximum of
three consecutive attempts with the same action identity and unchanged state.
After three consecutive attempts, record one exhaustion event, apply
`maestro:needs-human`, and wait for relevant state change.

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
