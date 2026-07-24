# maestro

Claude Code plugin for planning and supervising externally implemented work
through Linear and GitHub.

Maestro discovers across repositories, creates approved Linear issue DAGs,
delegates implementation to Cursor, reviews exact PR revisions in the context of
the whole goal, and reconciles merged reality into downstream issues. Maestro does
not implement product code or merge PRs.

Current plugin version: **0.2.0**.

## Install

```bash
git clone git@github.com:kop/maestro.git ~/code/kop/maestro
claude plugin marketplace add ~/code/kop/maestro
claude plugin install maestro@kop
```

After an update:

```bash
claude plugin update maestro@kop
```

Older Maestro installations may have a user-level
`~/.claude/agents/general-purpose.md` symlink. Inspect it yourself and remove it
only when it points to this plugin's deleted `agents/general-purpose.md`.

## Workflow

Start or resume a goal:

```text
/maestro:symphony-start <goal or [Symphony] issue>
```

`/maestro:symphony-start` accepts an epic, milestone, Linear project, broader goal, or existing Symphony issue. Planning is discovery-first: when the DAG cannot yet be known, Maestro research and architecture subagents gather evidence before proposing approved waves.

Review the proposed issue contracts, dependencies, and execution waves. Maestro
durably records the complete proposal before asking, records approval of that
exact revision before materialization, and resumes partial creation from fixed
issue identities without duplication. It does not delegate implementation until
you explicitly approve that DAG revision.

Run one reconciliation pass:

```text
/maestro:symphony-reconcile ISSUE-KEY
```

Each `/maestro:symphony-reconcile` invocation is one bounded, idempotent pass.
/loop owns repetition, and no subagent sleeps or polls.

Keep a controller session active:

```text
/loop 10m /maestro:symphony-reconcile ISSUE-KEY
```

Read current state without mutation:

```text
/maestro:symphony-status ISSUE-KEY
```

`/maestro:symphony-review` is internal and does not appear in the manual command
menu.

## Responsibility boundary

Maestro owns:

- discovery and cross-repository architecture;
- outcome-oriented Linear issue contracts and native blocker DAGs;
- approved-wave dispatch to Cursor through Linear;
- exact-SHA review against issue, dependency, and Symphony context;
- post-merge as-built reconciliation and bounded downstream updates.

Cursor owns:

- product-code implementation;
- failing CI;
- human, bot, and Maestro review resolution;
- PR convergence until repository gates permit merge.

Changes-required review is published on GitHub, then linked from one Linear comment
mentioning `@Cursor`.

PR review is risk-adaptive and exact-head: it always includes the mandatory Symphony-context reviewer, then selects specialized code, test, security, and comment lenses by labels, files, and context.
Every evidence record is bound through its finite provider-kind governing
chain. All chains include provider-confirmed
Symphony→implementation→repository authority; GitHub/repository evidence
continues through the linked PR and applicable base/head/merge terminal, while
Linear and durable-manual evidence terminate at their implementation-bound
record authority. An unconfirmed or relinked terminal record is not publishable.
Review worktree cleanup is reservation-aware before and after action binding and
is never authorized by action identity alone.

Repository policy owns merge readiness: zero failing checks, at least one approval
from a human or bot, addressed review comments/threads, and every remaining
configured gate.

A Symphony closes only after its final integration/outcome-verification issue
succeeds with evidence, every approved item is completed or explicitly cancelled,
all merged PRs are merge-reconciled, active managed work and unresolved controller
debt are clear, and required follow-ups exist. Terminal implementation issues
alone are not completion.

Post-merge reconciliation stages the exact binding manifest before dispatch,
requires the reconciler to echo that manifest and map every conclusion to its
bindings, records `merge-reconciled`, completes/unlocks only the implementation
issue in a separate transition, and evaluates `symphony-completed` later.

## Linear conventions

- Control issue title: `[Symphony] <goal>`.
- Existing team statuses are used.
- Maestro phase labels live in the `maestro` label group.
- Every Cursor issue targets one repository using
  `repo:owner/repository`.
- Dependencies use native Linear `blockedBy` relations.
- Linear and GitHub are persistent state; fresh sessions recover from native
  records and the append-only journal.

## Agents

| Agent | Role |
|---|---|
| `symphony-researcher` | Bounded repository discovery |
| `code-architect` | Cross-repository contracts and DAG input |
| `symphony-reviewer` | Mandatory whole-Symphony PR lens |
| `implementation-reconciler` | Final merged reality and downstream consequences |
| `code-reviewer` | Correctness, infrastructure validators, and CI runtime tooling |
| `test-analyzer` | Behavioral acceptance evidence |
| `security-reviewer` | Risk-selected security audit |
| `comment-analyzer` | Risk-selected documentation/contract truthfulness |

There is no custom main Maestro agent and no implementation agent. Runtime
dispatch names are plugin-qualified, such as `maestro:symphony-reviewer`.

## Requirements

- Claude Code with plugin skills/agents and `/loop`.
- Superpowers plugin for process discipline.
- Connected Linear tools with issue, relation, label, comment, and Cursor
  delegation access.
- GitHub tools or authenticated `gh` for PR reads/reviews/comments.
- Cursor's Linear integration.
- Git and repository-specific validation tools.
- codebase-memory-mcp is recommended for cross-repository discovery.

## Development

Validate the local plugin:

```bash
tests/run-all.sh
claude plugin validate .
```

Use `claude --plugin-dir .` for development probes. The release process must bump
`.claude-plugin/plugin.json` before every push.

Real Linear/GitHub/Cursor validation is documented in
`tests/REAL_INTEGRATION.md`.
