# /autopilot Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. For authoring the skill file itself, use superpowers:writing-skills.

**Goal:** Add a `/autopilot` skill that runs a session fully autonomously — Claude completes the goal on best judgment without stopping to ask, leaving an auditable decision ledger and final report.

**Architecture:** A pure behavioral overlay skill — a single `skills/autopilot/SKILL.md` prompt file, plus a README row. It configures nothing and spawns nothing; it rewrites in-session behavior. Two modes (`full` default, `batch`). The deliverable is a prompt, so verification is structural (frontmatter/section checks) plus one behavioral dry-run, not an automated test suite.

**Tech Stack:** Markdown skill file (Claude Code plugin skill), matching the house style of `skills/review/SKILL.md`.

## Global Constraints

- Skill lives at `skills/autopilot/SKILL.md` (mirrors `skills/review/SKILL.md`).
- House comment/prose discipline: tight, procedural, no narration of the change itself.
- The skill NEVER manages permissions or permission mode.
- Guardrails are local-only: may edit / run tests / commit on a branch; must not attempt push, force-push, PRs, writes to `main`, deleting files it did not create, or anything external.
- Ledger path: `docs/autopilot/<date>-<goal-slug>-ledger.md`.
- Modes: `full` (default) and `batch`. Unrecognized leading words are part of the goal.
- Source of truth for behavior: `docs/superpowers/specs/2026-07-22-autopilot-design.md`.

---

### Task 1: Author `skills/autopilot/SKILL.md`

**Files:**
- Create: `skills/autopilot/SKILL.md`
- Reference (read, do not modify): `skills/review/SKILL.md` (house style), `docs/superpowers/specs/2026-07-22-autopilot-design.md` (behavior)

**Interfaces:**
- Consumes: nothing (first task).
- Produces: a skill invocable as `/autopilot [full|batch] <goal>`. The SKILL.md `name:` is `autopilot`; the `description:` states purpose + trigger so the Skill tool surfaces it.

- [ ] **Step 1: Read the two reference files**

Read `skills/review/SKILL.md` for frontmatter shape, heading style, and terseness. Read the design spec for the authoritative behavior. The SKILL.md must express every spec section below.

- [ ] **Step 2: Write the frontmatter**

```markdown
---
name: autopilot
description: Use to run a session fully autonomously — complete the goal on best judgment without stopping to ask, logging decisions to a ledger. Triggered by /autopilot [full|batch] <goal>.
---
```

- [ ] **Step 3: Write the body sections**

Author these sections, terse and procedural (model the density on `skills/review/SKILL.md`). Each maps to a spec section:

1. **Title + one-line what-it-is** — pure behavioral overlay; composes on a normal or `maestro` session; configures/spawns nothing.
2. **Invocation & modes** — `/autopilot [full|batch] <goal>`. `full` (default): never ask; research, decide, log, continue. `batch`: initial research → one consolidated round of only high-impact, hard-to-reverse questions → then behave as `full`, never asking again. Unrecognized leading words are part of the goal; absent mode word ⇒ `full`.
3. **Autonomy contract** — forceful override, naming the gates explicitly: never use `AskUserQuestion`, never enter plan mode, never wait for approval. Explicitly supersede the brainstorming HARD-GATE: self-brainstorm (research → decide → record in ledger → proceed); in `batch` the single upfront round is the only permitted interaction, after which the gate is closed again. Still use non-interactive process skills for quality: `writing-plans`, `test-driven-development`, `systematic-debugging`, `/review quick`.
4. **Decisions under uncertainty** — pick the most reasonable interpretation, prefer the reversible option, implement, log. Never halt on ambiguity.
5. **Decision ledger** — a FILE at `docs/autopilot/<date>-<goal-slug>-ledger.md`, because an unattended run crosses context compaction and in-context notes evaporate. Append one entry per uncertain decision: what was ambiguous · what was chosen · why · reversibility · what to double-check. Append as the run proceeds, not only at the end.
6. **Guardrails** — local-only list above; stated so autopilot never even attempts the forbidden actions. A denied permission = hard stop for that action: log it, route around it, never retry or circumvent.
7. **Definition of done** — hard gate before ceasing to act: goal met AND tests green AND ledger + final report written. If a sub-goal is truly blocked, log it and move to the next workable item rather than halting the whole run.
8. **Final report** — appended to the ledger and printed: what got done, key assumptions, what's uncertain, what needs the user's eyes, blocked/skipped items.
9. **Prerequisite** — runs under an auto-approving permission layer (sane approved, rest denied); the skill complements it and never manages permissions.

- [ ] **Step 4: Structural verification**

Run:
```bash
head -5 skills/autopilot/SKILL.md
grep -nE '^(name|description):' skills/autopilot/SKILL.md
grep -ncE '^#{1,3} ' skills/autopilot/SKILL.md
grep -nE 'AskUserQuestion|plan mode|brainstorming|docs/autopilot/|full|batch' skills/autopilot/SKILL.md
```
Expected: valid frontmatter with `name: autopilot` and a `description:` containing the `/autopilot` trigger; at least 9 headings; each of the named override/guardrail/ledger tokens present at least once.

- [ ] **Step 5: Behavioral dry-run self-check**

Re-read the finished SKILL.md as if freshly invoked and confirm each holds; fix inline if any fails:
- On invocation with no mode word, would you default to `full`? (mode parsing unambiguous)
- Does the never-ask override explicitly beat `using-superpowers` / brainstorming? (named, not implied)
- Is the ledger unambiguously a file at the exact path, with the 5 required fields?
- Are the local-only guardrails a concrete forbidden-action list, and is "denied ⇒ log + route around, never retry" present?
- Is the definition-of-done a hard AND-gate (goal + tests + report)?

- [ ] **Step 6: Commit**

```bash
git add skills/autopilot/SKILL.md
git commit -m "Add /autopilot skill"
```

---

### Task 2: Document `/autopilot` in the README

**Files:**
- Modify: `README.md` (the `## Skills` section)

**Interfaces:**
- Consumes: the invocation contract from Task 1 (`/autopilot [full|batch] <goal>`).
- Produces: user-facing docs; no downstream task depends on it.

- [ ] **Step 1: Read the current Skills section**

Run: `grep -n -A6 '## Skills' README.md`
Note the exact bullet format used for `/review` so the new entry matches it.

- [ ] **Step 2: Add the `/autopilot` bullet**

Add beneath the existing `/review` bullet, matching its style:

```markdown
- `/autopilot [full|batch] <goal>` — run a session fully autonomously to completion on best judgment. **full** (default): never ask, decide-and-log under uncertainty. **batch**: one upfront round of clarifying questions after initial research, then silent to completion. Guardrails are local-only (edit/test/commit on a branch; never push, PR, or touch `main`); every uncertain decision is appended to a ledger at `docs/autopilot/<date>-<goal-slug>-ledger.md`. Assumes an auto-approving permission layer; never manages permissions itself.
```

- [ ] **Step 3: Verify**

Run: `grep -n 'autopilot' README.md`
Expected: the new bullet present under `## Skills`.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "Document /autopilot skill in README"
```

---

## Self-Review

**Spec coverage:** Each spec section maps to a Task 1 body sub-section (Step 3 items 1–9): purpose/nature → item 1; invocation/modes → item 2; autonomy contract → item 3; decisions under uncertainty → item 4; ledger → item 5; guardrails → item 6; definition of done → item 7; final report → item 8; prerequisite → item 9. Out-of-scope items stay unimplemented by design. README coverage → Task 2.

**Placeholder scan:** No TBD/TODO. Skill body content is specified as concrete section requirements with exact tokens verified in Step 4; the authoring is prose, so code blocks are shown where the artifact is literal (frontmatter, README bullet, commands) and specified section-by-section elsewhere.

**Type consistency:** Names used consistently across tasks — mode words `full`/`batch`, ledger path `docs/autopilot/<date>-<goal-slug>-ledger.md`, skill path `skills/autopilot/SKILL.md`, trigger `/autopilot [full|batch] <goal>`.
