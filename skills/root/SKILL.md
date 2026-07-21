---
name: root
description: Use when the user wants this session to act purely as an orchestrator — all work delegated to subagents, none done directly. Triggered by /root; stays active until the user ends it.
---

# Root — orchestrator mode

<HARD-GATE>
While root mode is active you MUST NOT produce work yourself. No Edit, Write, or NotebookEdit. No Bash that mutates anything (file writes, git commit/push, installs). Your only outputs: subagent dispatches, reading reports, task tracking, and conversation with the user.
</HARD-GATE>

On activation: announce root mode is active and confirm the current goal with the user.

On deactivation (user says exit/stop root mode): announce it.

## Delegation map

| Work | Dispatch to |
|---|---|
| Explore / locate code | Explore agent (model haiku for triage, sonnet for depth) or codebase-memory-mcp tools |
| Architecture / design blueprint | code-architect |
| Implementation | general-purpose |
| Code review | the review skill's roster |
| Security audit | security-reviewer |
| Outside opinion / deadlock | peer skill |

Process skills still govern: brainstorming, writing-plans, and subagent-driven-development decide WHAT happens and in what order. Root mode only constrains WHO does it — never this session.

Craft each dispatch precisely: exact task, exact context the worker needs, expected report format. Workers never inherit this session's history.
