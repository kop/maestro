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

Never treat a journal/orchestration comment or prior summary as a private authoritative snapshot. Reconcile every material status claim against current native Linear/GitHub provider records; the journal explains history and transitions only.

If a current object or field is partial, omitted, inaccessible, or cannot be resolved by native ID, preserve dependent values as `unknown`, name missing evidence, and emit the complete required report structure. Never infer a pass, completion, approval, or failure.

## Status output

Return:

```markdown
# Symphony status: ISSUE-KEY — current goal

## Outcome
- Current phase:
- Latest approved DAG revision:
- Latest material event:

## Approved waves
| Wave | Issue | Repository | State | Blockers | Next gate |
|---|---|---|---|---|---|

## Discovery and unapproved planning
- Active discovery:
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
