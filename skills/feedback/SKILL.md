---
name: feedback
description: Use when the user wants a retrospective on how the maestro plugin performed this session — which agents and skills were used, what worked, what was weak or missing, and what agents/skills would help future sessions. Triggered by /feedback.
---

# Feedback — retrospective on the maestro plugin

You have just spent a whole session using (or trying to use) the maestro plugin's agents and skills. This skill turns that lived experience into a critique of the plugin. Run it at the end of a long session, while the session's detail is still in context.

Produce a report in the chat. Write no files and make no edits — the user acts on the report themselves.

## The core principle

**Every judgment cites a specific moment from THIS session.** A retrospective is only worth reading if it is grounded in what actually happened — which agent you dispatched, what it returned, where a skill's guidance was wrong, where you worked around a missing capability. Generic plugin commentary the user could have written without you is worthless.

If a component was not exercised this session, say so and do not evaluate it. An honest "not used" beats an invented verdict. The most valuable parts of the report are the failures and the gaps, not the praise.

## Scope

- **Maestro plugin** — the agents and skills that were actually invoked this session (reconstruct these from the conversation, not from memory of what the plugin offers).
- **Workflow gaps** — friction this session that points to a NEW agent or skill worth adding, even outside the plugin's current scope.

## The report

Five sections, in this order. Skip a section only if the session produced nothing real for it, and say why.

1. **Session recap** — two or three sentences: what the session was doing, and which maestro agents/skills were actually invoked. This grounds everything below.

2. **What worked** — components that earned their place. Per item: the component, the moment it helped, and what specifically was good about the result.

3. **Friction & weaknesses** — where the plugin underperformed. Per item: the component, the moment, what went wrong (weak output, wrong or missing guidance, wrong model tier, a workaround you had to invent), and the concrete cost.

4. **Proposed changes** — concrete edits to EXISTING maestro agents or skills, each tied to a friction item above. Name the file, the change, and the friction it resolves.

5. **New agents or skills** — gaps that warrant something new. Per idea: a one-line `description`-style trigger, what it would do, and the session moment that motivates it. Distinguish "I hit this repeatedly" from "this might help once."

## Before you write

Reconstruct what actually happened this session — scan the conversation for maestro agent dispatches and skill invocations rather than reasoning from memory of what the plugin offers. If the session barely touched the plugin, the honest report is short: say what little was exercised and stop. Do not pad it to look thorough.
