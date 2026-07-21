# kop-kit

Personal Claude Code plugin: model-tiered agents and orchestration skills, adapted from the official code-review, feature-dev, pr-review-toolkit plugins and integrated with superpowers and the peer skill.

## Install

    claude plugin marketplace add ~/code/kop/claude-code
    claude plugin install kop-kit@kop
    ln -s ~/code/kop/claude-code/agents/general-purpose.md ~/.claude/agents/general-purpose.md

Remove any pre-existing `~/.claude/skills/peer` — the plugin ships `/peer`.

To pick up changes after editing the plugin source: `claude plugin update kop-kit@kop`.

## Agents

| Agent | Model | Role |
|---|---|---|
| general-purpose | sonnet | Implementer; overrides the built-in so subagents stay on sonnet |
| code-architect | opus | Architecture blueprints |
| code-reviewer | opus | Review verdicts (≥80 confidence), silent-failure + type lenses, peer cross-check |
| security-reviewer | fable | Deep security audit, peer cross-check via gpt-5.6-sol |
| test-analyzer | sonnet | Behavioral test-coverage review |
| comment-analyzer | sonnet | Comment truthfulness + house comment discipline |

Haiku triage runs via the Agent tool's per-dispatch model override — no agent file.

## Skills

- `/review [aspects] [target]` — parallel multi-aspect review (code, security, tests, comments, simplify, all)
- `/root` — orchestrator mode: all work delegated, main session prohibited from direct edits
- `/peer` — second/third opinion via Cursor CLI (GPT, Gemini, Grok)

## Dependencies

| Dependency | Kind |
|---|---|
| superpowers (plugin) | Required — process skills; review output contract |
| security-guidance (plugin) | Recommended — passive security hooks this kit complements |
| Cursor CLI (`agent`, authenticated) | Required for peer escalation |
| codebase-memory-mcp | Recommended — exploration; falls back to Explore agent |
| `gh` CLI | Required for PR-scoped /review |

## Superpowers wiring

Add to `~/.claude/CLAUDE.md`:

    Code review dispatch: where a superpowers skill says to dispatch a `general-purpose` subagent for code review, dispatch the `code-reviewer` agent instead, filling the same template placeholders.
