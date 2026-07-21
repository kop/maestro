---
name: peer
description: Use when you want a second or third opinion from another AI model — sanity-checking a design decision or approach, getting an outside code review on a diff, brainstorming alternatives, breaking a deadlock when stuck, or cross-checking a risky conclusion. Consults GPT, Gemini, and Grok through the Cursor CLI (`agent`) in headless mode. Also triggered by /peer.
---

# Peer (second/third opinion via Cursor CLI)

## Overview

The Cursor CLI (`agent`, headless via `-p`) gives you frontier models from several vendors — GPT, Gemini, Grok, and others — behind one command. Consult them as peers for a **fresh, non-Claude perspective**: design review, code review, brainstorming, or checking a conclusion you're unsure of.

For a real "third opinion", ask TWO different vendors (e.g. GPT + Gemini) and synthesize — agreement/disagreement is signal.

Don't consult a peer for trivial one-shots — the round-trip isn't worth it. Do it when the question is genuinely hard, high-stakes, or benefits from an outside view.

## Use the most capable models (do NOT guess model IDs)

Guessing model names is the #1 way this goes wrong. **Run `agent --list-models`** to see what this account actually serves, then pick a flagship. Current top picks by vendor:

| Vendor | Model ID | Use for |
|--------|----------|---------|
| OpenAI | `gpt-5.6-sol-xhigh` | general opinions, reasoning, code review |
| Google | `gemini-3.1-pro` | general opinions, second view |
| xAI | `cursor-grok-4.5-high` | genuine third vendor |

Do NOT route to the `claude-*` entries in the list — that's the same model family as you, which defeats the "outside opinion" purpose. Verified: these IDs serve the named model (no silent downgrade) on this account.

## Invocation (read-only by default)

Default headless mode has **write and shell access** — never use it just to get an opinion. Add `--mode ask` (Q&A) or `--plan` (read-only planning) so a "get an opinion" call can't wander off and edit.

```bash
agent -p --output-format json --mode ask --model gemini-3.1-pro "<prompt>"
```

Parse the model's answer from the `.result` field of the JSON. `--output-format text` prints raw text if you prefer.

## Asking for an opinion / brainstorming

State the question in one paragraph: context, constraints, and the specific deliverable you want. Run two vendors, then synthesize agreements, disagreements, and anything only one raised.

```bash
Q="<question + context + constraints + 'what would you do and why?'>"
agent -p --output-format json --mode ask --model gpt-5.6-sol-xhigh "$Q"
agent -p --output-format json --mode ask --model gemini-3.1-pro  "$Q"
```

## Full code review

1. Get the diff yourself — this is deterministic and doesn't depend on the peer reading files:

```bash
DIFF=$(git diff main...HEAD)
```

2. Pipe it into the prompt and run (use the codex-tuned or a flagship model):

```bash
agent -p --output-format json --mode ask --model gpt-5.6-sol-xhigh "Review this diff. Findings in priority order:
1. correctness (logic bugs, edge cases, races)
2. security (input validation, injection, secret handling)
3. performance
4. style (only if it hurts readability — skip nits)
Output: numbered findings, each tagged P0/P1/P2/P3, with file:line and a concrete fix.

$DIFF"
```

3. Run a second vendor (`gemini-3.1-pro`) on the same prompt, then merge findings, dedupe, and flag disagreements. Report the union with your own judgment on each.

Alternative to pasting the diff: point at the repo with `--workspace <path>` (add `--add-dir <path>` for extra roots, `--trust` for headless workspace trust) and name the branch/files to review. Pasting the diff is preferred.

## Follow-ups (same conversation)

Consulting is stateful. To push back or drill in, continue the SAME session instead of starting fresh. The JSON result carries a `session_id`; pass it to `--resume`:

```bash
agent -p --output-format json --mode ask --resume <session_id> "<follow-up>"
```

(`--continue` resumes the most recent session without an ID.)

## Common mistakes

| Mistake | Reality |
|---------|---------|
| Guessing model IDs | Run `agent --list-models` first. Wrong IDs error or fall back. |
| Using a low/default tier | Default is `auto`. Pass a flagship (`gpt-5.6-sol-xhigh`, `gemini-3.1-pro`). |
| Asking a `claude-*` model for the outside opinion | Same family as you — defeats the purpose. Pick GPT/Gemini/Grok. |
| Omitting `--mode ask`/`--plan` | Default headless mode can write files and run shell. Keep opinions read-only. |
| Only asking one model | A "third opinion" needs two vendors. Run both, synthesize. |
| Starting a new call for a follow-up | Loses context. Capture `session_id`, use `--resume`. |
| Forgetting to parse `.result` | With `--output-format json`, the answer is in `.result`. |
| Consulting a peer on a trivial question | Round-trip cost > value. Reserve for hard/high-stakes calls. |
