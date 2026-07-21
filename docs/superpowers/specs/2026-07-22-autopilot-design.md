# /autopilot — design

## Purpose

A skill for running a session fully autonomously — Claude completes the goal on
its best judgment without stopping to ask the user, so a session can be launched
and left to run (the primary case: overnight). Some things may be implemented
incorrectly for lack of information; that is an accepted trade — implemented and
auditable beats blocked and unaddressed.

## Nature

A **pure behavioral overlay skill**. It configures nothing, spawns nothing,
scaffolds nothing. It rewrites how Claude behaves for the rest of the session:
work autonomously to completion, decide under uncertainty instead of asking, and
leave an auditable trail. It composes on top of a normal session or a `maestro`
orchestrator session.

## Invocation

`/autopilot [full|batch] <goal>`

- `full` (default) — never ask the user anything. Research, decide on best
  judgment, log every uncertain decision, keep going to completion.
- `batch` — do initial research, then ask **one** consolidated round of
  clarifying questions (only the high-impact, hard-to-reverse ones), wait for
  answers, then behave exactly like `full` to completion. Never asks again.

Unrecognized leading words are part of the goal. If no mode word is present, the
mode is `full`.

## The autonomy contract

Forceful, explicit override — `using-superpowers` fires every turn and pushes
toward interactive gates, so the contract must name them:

- Never use `AskUserQuestion`; never enter plan mode; never wait for approval.
- Explicitly supersedes the brainstorming skill's interactive HARD-GATE. Instead
  of interactive design approval, autopilot self-brainstorms: research → decide →
  record the design decision in the ledger → proceed. In `batch` mode the single
  upfront question round is the one permitted interaction; after it, the gate is
  closed again.
- Still uses the non-interactive process skills for quality: `writing-plans`,
  `test-driven-development`, `systematic-debugging`, and `/review quick`.

## Decision-making under uncertainty

When information is missing: pick the most reasonable interpretation, prefer the
reversible option, implement it, and log it. Never halt on ambiguity. Only in
`batch` mode, and only during the single upfront round, are unresolved
high-impact ambiguities surfaced to the user; everything else is decided and
logged.

## The decision ledger

A **file**: `docs/autopilot/<date>-<goal-slug>-ledger.md`.

It must be a file, not in-context notes: an unattended run crosses context
compaction, which evaporates in-context state. The file is what survives the run
and what the user reads afterward.

One entry per uncertain decision, recording:

- what was ambiguous
- what was chosen
- why
- reversibility (how hard to undo if wrong)
- what the user should double-check

The ledger is appended to as the run proceeds, not written only at the end.

## Guardrails — local-only, never external

Autopilot **may**: edit files, run tests, commit on a branch.

Autopilot **must not attempt**: push, force-push, open PRs, write to `main`,
delete files it did not create, or anything external / network-sending.

These mirror what the auto-approver would reject; they are stated in the skill so
autopilot never even attempts them. A denied permission is a hard stop for that
action: log it in the ledger, route around it, and never retry or attempt to
circumvent it.

## Definition of done

A hard gate checked before autopilot stops emitting actions. It may conclude only
when all hold:

- the goal is met
- tests are green
- the ledger and final report are written

This prevents premature "done." If a sub-goal is genuinely blocked, autopilot
logs it and moves to the next workable item rather than halting the whole run.

## Final report

At the end of the run, appended to the ledger file and printed:

- what got done
- key assumptions made
- what is uncertain
- what needs the user's eyes
- any items blocked or skipped

## Prerequisite (documented, not enforced)

Autopilot runs under an auto-approving permission layer that approves sane actions
and denies the rest. The skill's guardrails complement that layer; the skill
itself never manages or configures permissions.

## Out of scope

- Configuring permissions or permission mode.
- Spawning or defining agents.
- Scheduling / looping infrastructure (the existing `/loop` and scheduling tools
  cover recurrence; autopilot governs behavior within a single run).
