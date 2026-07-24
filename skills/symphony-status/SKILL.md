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

rule symphony-status-consume-event-symphony-started | when control-creation-is-confirmed | consume event `symphony-started` | next entity-discovery | choice none

rule symphony-status-consume-event-discovery-requested | when canonical-discovery-request-is-durably-confirmed | consume event `discovery-requested` | next discovery-active | choice none

rule symphony-status-consume-event-discovery-recorded | when discovery-evidence-is-durably-confirmed | consume event `discovery-recorded` | next discovery-active | choice none

rule symphony-status-consume-event-discovery-completed | when discovery-result-contract-is-confirmed | consume event `discovery-completed` | next entity-complete | choice none

rule symphony-status-consume-event-dag-proposed | when exact-dag-proposal-is-durably-confirmed | consume event `dag-proposed` | next entity-planning | choice none

rule symphony-status-consume-event-dag-approved | when exact-dag-revision-approval-is-durably-confirmed | consume event `dag-approved` | next dag-recovery | choice none

rule symphony-status-consume-event-dag-rejected | when exact-dag-rejection-is-durably-confirmed | consume event `dag-rejected` | next dag-replanning | choice none

rule symphony-status-consume-event-dag-node-bound | when one-native-node-binding-is-confirmed | consume event `dag-node-bound` | next dag-recovery | choice none

rule symphony-status-consume-event-dag-edge-bound | when one-native-edge-binding-is-confirmed | consume event `dag-edge-bound` | next dag-recovery | choice none

rule symphony-status-consume-event-dag-materialized | when all-native-bindings-and-events-are-confirmed | consume event `dag-materialized` | next entity-executing | choice none

rule symphony-status-consume-event-semantic-drift-detected | when normalized-contract-or-edge-drift-is-confirmed | consume event `semantic-drift-detected` | next affected-subgraph-paused | choice none

rule symphony-status-consume-event-issue-dispatched | when cursor-delegation-is-freshly-confirmed | consume event `issue-dispatched` | next entity-executing | choice none

rule symphony-status-consume-event-review-requested | when canonical-review-input-revision-is-durably-confirmed | consume event `review-requested` | next review-revision-eligible | choice none

rule symphony-status-consume-event-review-worktree-reserved | when canonical-preclosure-review-reservation-is-confirmed | consume event `review-worktree-reserved` | next reservation-authorized | choice none

rule symphony-status-consume-event-review-worktree-action-bound | when reservation-to-final-review-action-binding-is-confirmed | consume event `review-worktree-action-bound` | next action-binding-confirmed | choice none

rule symphony-status-consume-event-review-recorded | when canonical-exact-head-and-input-revision-review-record-is-confirmed | consume event `review-recorded` | next review-gate-recorded | choice none

rule symphony-status-consume-event-review-stale-head | when remote-pr-head-or-context-preparation-changed-and-review-requested-is-absent | consume event `review-stale-head` | next review-new-head | choice none

rule symphony-status-consume-event-review-input-stale-before-github | when derivable-full-input-changed-and-review-requested-is-confirmed-and-github-record-is-absent | consume event `review-input-stale` | next new-review-input-eligible | choice none

rule symphony-status-consume-event-review-input-stale-after-github | when full-input-changed-or-underivable-and-confirmed-github-record-exists-and-linear-record-is-absent | consume event `review-input-stale` | next github-record-historical-input-recovery | choice none

An already-published GitHub record referenced by `review-input-stale` is
historical and cannot satisfy the current review/pass gate; report the new
eligible input or underivable-input recovery and the suppressed Linear follow-up.

rule symphony-status-consume-event-merge-observed | when github-merge-sha-is-freshly-confirmed | consume event `merge-observed` | next merge-reconciliation-pending | choice none

rule symphony-status-consume-event-merge-reconciled | when merge-reconciliation-is-complete-and-evidenced | consume event `merge-reconciled` | next merge-reconciled-confirmed | choice none

rule symphony-status-consume-event-implementation-completed | when confirmed-merge-reconciled-is-consumed-by-separate-implementation-transition | consume event `implementation-completed` | next implementation-complete | choice none

rule symphony-status-consume-event-human-decision-required | when bounded-or-strategic-human-authority-is-required | consume event `human-decision-required` | next affected-subgraph-paused | choice none

rule symphony-status-consume-event-decision-resolved | when resolution-disposition-and-resume-evidence-are-confirmed | consume event `decision-resolved` | next recorded-resume-phase | choice none

rule symphony-status-consume-event-follow-up-created | when required-follow-up-identity-is-confirmed | consume event `follow-up-created` | next follow-up-inventory-confirmed | choice none

rule symphony-status-consume-event-issue-cancelled | when approved-cancellation-and-dependency-disposition-are-confirmed | consume event `issue-cancelled` | next implementation-complete | choice none

rule symphony-status-consume-event-action-failed | when material-action-attempt-is-not-confirmed | consume event `action-failed` | next bounded-recovery | choice none

rule symphony-status-consume-event-retry-exhausted | when unchanged-state-retry-budget-is-exhausted | consume event `retry-exhausted` | next entity-needs-human | choice none

rule symphony-status-consume-event-cleanup-failed | when owned-cleanup-safety-or-completion-is-unconfirmed | consume event `cleanup-failed` | next cleanup-debt | choice none

rule symphony-status-consume-event-symphony-completed | when all-closeout-gates-and-final-outcome-are-confirmed | consume event `symphony-completed` | next entity-complete | choice none

Read the exact role, entity phase, and risk labels before interpreting them:

rule symphony-status-read-label-maestro-symphony | when native-role-scope-is-confirmed | read label `maestro-symphony` | next role-label-confirmed | choice none

rule symphony-status-read-label-maestro-managed | when native-role-scope-is-confirmed | read label `maestro-managed` | next role-label-confirmed | choice none

rule symphony-status-read-label-maestro-discovery | when entity-scoped-discovery-authority-is-confirmed | read label `maestro:discovery` | next entity-discovery | choice entity-phase

rule symphony-status-read-label-maestro-planning | when entity-scoped-planning-authority-is-confirmed | read label `maestro:planning` | next entity-planning | choice entity-phase

rule symphony-status-read-label-maestro-executing | when entity-scoped-execution-authority-is-confirmed | read label `maestro:executing` | next entity-executing | choice entity-phase

rule symphony-status-read-label-maestro-needs-human | when entity-scoped-pause-is-confirmed-and-strategic-authority-is-not-required | read label `maestro:needs-human` | next entity-needs-human | choice entity-phase

rule symphony-status-read-label-maestro-scope-change | when entity-scoped-pause-is-confirmed-and-strategic-authority-is-required | read label `maestro:scope-change` | next entity-scope-change | choice entity-phase

rule symphony-status-read-label-maestro-complete | when entity-scoped-completion-authority-is-confirmed | read label `maestro:complete` | next entity-complete | choice entity-phase

rule symphony-status-read-label-maestro-risk-security | when issue-label-or-changed-surface-has-security-risk | read label `maestro-risk-security` | next security-lens-selected | choice none

rule symphony-status-read-label-maestro-risk-infra | when issue-label-or-changed-surface-has-infrastructure-risk | read label `maestro-risk-infra` | next infrastructure-lens-selected | choice none

rule symphony-status-read-label-maestro-risk-migration | when issue-label-or-changed-surface-has-migration-risk | read label `maestro-risk-migration` | next migration-lenses-selected | choice none

If a current object or field is partial, omitted, inaccessible, or cannot be resolved by native ID, preserve dependent values as `unknown`, name missing evidence, and emit the complete required report structure. Never infer a pass, completion, approval, or failure.

Pair every `retry-exhausted` pause identity with an exact `decision-resolved`.
Report an exact pair as Resolved historical retry exhaustion and exclude it from
current debt. Report an absent, stale, or mismatched pair as Unresolved retry
exhaustion debt, retain the recorded needs-human phase, and block closeout. A
changed provider state without the matching event remains unresolved.

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
- Rejected DAG revisions:
- Missing evidence:

## Cursor implementation and PRs
| Issue | Repository | Delegation | PR | Head | Review input revision | CI | Approvals | Threads | Maestro review |
|---|---|---|---|---|---|---|---|---|---|

## Ready and blocked work
- Ready in deterministic order:
- Blocked by unreconciled merge:
- Blocked by capacity:

## Drift
- Mechanical drift:
- Semantic drift:

## Controller failures and cleanup
- Resolved historical retry exhaustion:
- Unresolved retry exhaustion debt:
- Ambiguous actions:
- Owned-worktree cleanup:

## Closeout gates
- Approved work completed or cancelled with rationale:
- Merged PRs merge-reconciled:
- Active managed PRs or delegations:
- Unresolved drift, decision, ambiguity, exhaustion, or cleanup debt:
- Required follow-up issues:

## Human decisions
- Resolved historical pauses:
- Decision:
  Affected subgraph:
  Evidence:

## Next transitions
1. Highest-priority expected transition.
```

Use actual values and omit empty list items only when their evidence is complete;
otherwise retain the corresponding section and report `unknown` with the missing
evidence. Do not call pending CI or normal Cursor execution an operational failure.
