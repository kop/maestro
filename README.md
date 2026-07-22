# maestro

Personal Claude Code plugin: model-tiered agents and orchestration, adapted from the official code-review, feature-dev, pr-review-toolkit plugins and integrated with superpowers; outside opinions via the Cursor CLI (peer agent).

## Install

    git clone git@github.com:kop/maestro.git ~/code/kop/maestro
    claude plugin marketplace add ~/code/kop/maestro
    claude plugin install maestro@kop
    mkdir -p ~/.claude/agents && ln -sf ~/code/kop/maestro/agents/general-purpose.md ~/.claude/agents/general-purpose.md

To pick up changes after editing the plugin source: `claude plugin update maestro@kop`.

## Agents

| Agent | Model | Role |
|---|---|---|
| general-purpose | sonnet | Implementer; overrides the built-in so subagents stay on sonnet |
| code-architect | opus | Architecture blueprints |
| code-reviewer | opus | Review verdicts (≥80 confidence), silent-failure + type lenses |
| security-reviewer | fable | Deep security audit |
| test-analyzer | sonnet | Behavioral test-coverage review |
| comment-analyzer | sonnet | Comment truthfulness + house comment discipline |
| peer | haiku | Proxy to non-Claude vendors (Cursor CLI); dispatched by the /review orchestrator in parallel with the reviewers as an independent outside reviewer |
| scribe | haiku | Mechanical hand for one dictated file edit; lets a write-free orchestrator delegate a write |
| maestro | opus | Orchestrator session — launch with `claude --agent maestro`; delegates all work, holds no edit/write/bash |

Haiku triage runs via the Agent tool's per-dispatch model override — no agent file.

`maestro` is launched as the session (not dispatched): its tool allowlist hard-blocks direct edits, so every artifact is produced by a worker it dispatches.

## Skills

- `/review [quick|full] [aspects] [target]` — code review in two modes: **quick** (code-reviewer + 1 peer) for a tight loop, **full** (all reviewers + 3 peers, 3 different vendors) as the end-to-end gate. Peers are dispatched by the orchestrator in parallel with the reviewers as independent outside reviewers. Human/maestro invocation defaults to full.
- `/autopilot [full|batch] <goal>` — run a session unattended to completion on best judgment. **full** (default): never ask, decide-and-log under uncertainty. **batch**: one upfront round of clarifying questions after initial research, then silent to completion. Guardrails are local-only (edit/test/commit on a branch; never push, PR, or touch `main`); every uncertain decision is appended to a ledger at `docs/autopilot/<date>-<goal-slug>-ledger.md`. Assumes an auto-approving permission layer; never manages permissions itself.

## Dependencies

| Dependency | Kind |
|---|---|
| superpowers (plugin) | Required — process skills; review output contract |
| security-guidance (plugin) | Recommended — passive security hooks this kit complements |
| Cursor CLI (`agent`, authenticated) | Required for the peer agent |
| codebase-memory-mcp | Recommended — exploration; falls back to Explore agent |
| `gh` CLI | Required for PR-scoped /review |

## Superpowers wiring

Add to `~/.claude/CLAUDE.md`:

    Code review dispatch: where a superpowers skill says to dispatch a `general-purpose` subagent for code review, dispatch the `code-reviewer` agent instead, filling the same template placeholders.

Two review entry points map to the two modes. A superpowers per-task cycle runs a quick review: whoever invokes it dispatches the code-reviewer agent plus 1 peer in parallel. The full mode is the `/review` skill run by a human or maestro at branch end as the end-to-end gate. A subagent cannot invoke the `/review` skill, so full review is always a main-loop invocation.
