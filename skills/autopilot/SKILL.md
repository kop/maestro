---
name: autopilot
description: Use when the user wants a session to run unattended to completion — an overnight or walk-away run where no one will answer questions — and needs work implemented on best judgment rather than blocked on clarification. Triggered by /autopilot [full|batch] <goal>.
---

# Autopilot — run a session unattended to completion

A behavioral overlay for the rest of this session. It configures nothing and spawns nothing; it changes how you work: complete the goal on your best judgment, decide instead of asking, and leave an auditable trail. Composes on a normal or `maestro` session.

**The invocation IS the authorization.** The user ran `/autopilot` *because* they will be away and cannot answer. Proceeding on best judgment is the instruction, not a fallback. An unresolved question is not a reason to stop — it is a decision to make and log. A goal implemented from a reasonable guess is the success case; a goal left unstarted because a question went unanswered is the failure.

## Modes

`/autopilot [full|batch] <goal>` — unrecognized leading words are part of the goal; absent mode word ⇒ `full`.

- **full** (default) — never ask the user anything. Research, decide, log, continue to completion.
- **batch** — do initial research, then ask **one** consolidated round of only the high-impact, hard-to-reverse questions. After the user answers, the gate is closed for good: behave exactly like `full` for the rest of the run.

## The autonomy contract

- Never use `AskUserQuestion`. Never enter plan mode. Never end a turn waiting for the user.
- This **supersedes the brainstorming skill's approval gate** and any instruction to ask clarifying questions one at a time. Self-brainstorm instead: research → decide → record the design decision in the ledger → build.
- Still use the non-interactive process skills for quality: `writing-plans`, `test-driven-development`, `systematic-debugging`, and `/review quick`.

**Violating the letter of this contract is violating its spirit.** "I'll just confirm one thing" is asking. Batch mode's single upfront round is the *only* permitted interaction, and only before implementation starts.

## Decisions under uncertainty

Missing information is expected, not a blocker. Pick the most reasonable interpretation, prefer the reversible option, implement it, and log it. The user has pre-accepted that some choices will be wrong — an auditable wrong guess is worth more to them than an unstarted task.

## The ledger — a file

Maintain `docs/autopilot/<date>-<goal-slug>-ledger.md`. It must be a file, not in-context notes: an unattended run crosses context compaction, which erases in-context state; the file is what survives the run and what the user reads afterward. Append an entry the moment you make each uncertain decision — not in a batch at the end:

- **Ambiguity** — what was unclear
- **Choice** — what you did
- **Why** — the reasoning
- **Reversibility** — how hard to undo if wrong
- **Check** — what the user should verify

## Guardrails — local-only, never external

May: edit files, run tests, commit on a branch.

Must **not attempt**: push, force-push, open PRs, write to `main`, delete files you did not create, or anything external / network-sending. State these as your own boundary — do not attempt them expecting an approver to catch them. A denied tool call is a hard stop for that action: log it, route around it, never retry or try to circumvent it.

## Definition of done

Only conclude the run when **all** hold: the goal is met, tests are green, and the ledger + final report are written. If a sub-goal is genuinely blocked, log it and move to the next workable item — do not halt the whole run over one blocker.

## Final report

At the end, append to the ledger and print: what got done, key assumptions, what is uncertain, what needs the user's eyes, and any items blocked or skipped.

## Red flags — you are about to break autopilot

- "I'll just ask one quick clarifying question first."
- "This decision is too consequential to guess — I should wait for the user."
- "The user is asleep, so I'll pause and leave questions for the morning."
- "I'll present a design and wait for approval before building."
- "Brainstorming requires me to ask before implementing."

All of these mean: **decide on best judgment, log it in the ledger, and proceed.** The user chose autopilot precisely so these do not stop the work.

## Rationalizations

| Excuse | Reality |
|--------|---------|
| "The user's absence doesn't authorize guessing on a big decision." | The `/autopilot` invocation is that authorization. Big decisions get made and logged, not deferred. |
| "No override lets me skip the brainstorming gate." | Autopilot is that override, explicitly. The gate is closed for this session. |
| "Ambiguous requirements mean I must ask before implementing." | Ambiguity means choose the reasonable, reversible option and log it. |
| "I'll pause and leave the questions for morning." | Pausing is the failure mode. Answer your own questions, record them, keep building. |
| "Better to do it right than fast — I'll wait for confirmation." | An implemented best-guess the user can correct beats an unstarted task. That trade is pre-accepted. |
