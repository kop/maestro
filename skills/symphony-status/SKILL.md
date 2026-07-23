---
name: symphony-status
description: Use when a user asks for Symphony status or progress, fresh-session recovery, or inspection of drift, blockers, or next-transition state.
---

# Report Symphony status

Input: `$ARGUMENTS`, which must identify exactly one `[Symphony]` control issue.

Read completely:

- `${CLAUDE_PLUGIN_ROOT}/references/symphony/core.md`
- `${CLAUDE_PLUGIN_ROOT}/references/symphony/linear.md`
- `${CLAUDE_PLUGIN_ROOT}/references/symphony/reconciliation.md`

This skill is read-only. Never write Linear or GitHub, append a journal comment,
delegate Cursor, create a worktree, or change a repository.

Read the full current control issue; native status, labels, and relations; approved revisions; managed issues; dependencies; delegations; and linked PR head, checks, reviews, threads, and merge state. Resolve material omissions by native ID.

Classify every managed Linear issue as control, discovery, or implementation
before interpreting its mutually exclusive phase label. Report `maestro:complete`
with its entity-scoped authority: `symphony-completed` for the control issue,
`discovery-completed` after durable discovery evidence for a discovery issue, or
`merge-reconciled`/approved `issue-cancelled` for an implementation issue. Never
infer control/Symphony completion from a completed managed child.

Never treat a journal/orchestration comment or prior summary as a private authoritative snapshot. Reconcile every material status claim against current native Linear/GitHub provider records; the journal explains history and transitions only.

Consume each event kind present in the journal while building the report, without
treating it as proof until provider state confirms its claim:

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

Read the exact role, entity phase, and risk labels before interpreting them:

read label `maestro-symphony`

read label `maestro-managed`

read label `maestro:discovery`

read label `maestro:planning`

read label `maestro:executing`

read label `maestro:needs-human`

read label `maestro:scope-change`

read label `maestro:complete`

read label `maestro-risk-security`

read label `maestro-risk-infra`

read label `maestro-risk-migration`

If a current object or field is partial, omitted, inaccessible, or cannot be resolved by native ID, preserve dependent values as `unknown`, name missing evidence, and emit the complete required report structure. Never infer a pass, completion, approval, or failure.

## Status output

Return:

```markdown
# Symphony status: ISSUE-KEY — current goal

## Outcome
- Current phase:
- Latest approved DAG revision:
- Latest material event:
- Final integration/outcome-verification evidence:
- Closeout readiness:

## Approved waves
| Wave | Issue | Entity type | Repository | Phase | Completion authority | Blockers | Next gate |
|---|---|---|---|---|---|---|---|

## Discovery and unapproved planning
- Active discovery:
- Completed discovery and `discovery-completed` evidence:
- Proposed DAG revision:
- Missing evidence:

## Cursor implementation and PRs
| Issue | Repository | Delegation | PR | Head | CI | Approvals | Threads | Maestro review |
|---|---|---|---|---|---|---|---|---|

## Ready and blocked work
- Ready in deterministic order:
- Blocked by unreconciled merge:
- Blocked by capacity:

## Drift
- Mechanical drift:
- Semantic drift:

## Controller failures and cleanup
- Retry exhaustion:
- Ambiguous actions:
- Owned-worktree cleanup:

## Closeout gates
- Approved work completed or cancelled with rationale:
- Merged PRs merge-reconciled:
- Active managed PRs or delegations:
- Unresolved drift, decision, ambiguity, exhaustion, or cleanup debt:
- Required follow-up issues:

## Human decisions
- Decision:
  Affected subgraph:
  Evidence:

## Next transitions
1. Highest-priority expected transition.
```

Use actual values and omit empty list items only when their evidence is complete;
otherwise retain the corresponding section and report `unknown` with the missing
evidence. Do not call pending CI or normal Cursor execution an operational failure.
