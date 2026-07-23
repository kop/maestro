---
name: feedback
description: Retrospective on how Maestro's Symphony control plane performed in this session: discovery, Linear DAG planning, Cursor dispatch, contextual PR review, merge reconciliation, drift handling, and recovery. Report only; never edits files or external systems.
---

# Feedback on a Maestro Symphony session

Produce a chat report only. Write no files and mutate no external system.

Every judgment must cite a specific event from this session. Reconstruct which
Maestro skills and agents were actually used; do not evaluate an unused component.
An honest non-use signal is valid evidence.

## Report

1. **Session recap** — Symphony goal, repositories, approved waves, and components
   exercised.
2. **What worked** — concrete discovery, planning, dispatch, review,
   reconciliation, or recovery moments that earned their cost.
3. **Friction and weaknesses** — exact component, event, failure mode, workaround,
   and cost.
4. **Protocol or component changes** — exact existing file and behavioral change
   tied to a friction item.
5. **New agents or skills** — only recurring gaps that do not already belong in a
   current Symphony component.

Evaluate, when exercised:

- whether discovery removed the right uncertainty before planning;
- whether issue contracts, repository routing, and dependency edges were precise;
- whether approved waves and dispatch ordering were safe;
- whether Cursor, rather than Maestro, owned implementation and PR convergence;
- whether reviews used the exact SHA and whole-Symphony context;
- whether validators and CI runtime assumptions were checked;
- whether worktrees were ownership-safe and cleaned;
- whether merged reality correctly updated downstream issues;
- whether manual Linear drift and ambiguous writes were handled without duplicate
  actions;
- whether `/loop` stayed quiet while nothing material changed.

Do not manufacture praise. Distinguish a component defect from a component that
was simply never invoked.
