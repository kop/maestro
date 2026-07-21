---
name: review
description: Use for code review — dispatches reviewer agents over a diff or PR and aggregates findings. Two modes — quick (code-reviewer only) and full (all reviewers + peer cross-check). Triggered by /review [quick|full] [aspects] [target].
---

# Review — quick or full code review

Two modes:

- **quick** — dispatches only code-reviewer, no peer cross-check, no triage. Fast pass for a tight review loop (e.g. a subagent-driven-development per-task cycle).
- **full** — triage, then all four reviewer agents in parallel, each with peer cross-check. The thorough end-to-end gate.

Arguments: an optional mode (`quick` | `full`), optional aspects (`code`, `security`, `tests`, `comments`, `all`), and an optional target (PR number, branch name, or nothing). Unrecognized words are the target.

**Default mode when none is given: full.** A superpowers per-task review runs quick (see the wiring note in the README); a human or maestro asking for a final/branch-end review runs full.

## 1. Scope

- No target: `git diff HEAD`; if empty, `git diff main...HEAD`.
- Branch target: `git diff <branch>...HEAD`.
- PR number: `gh pr diff <n>` and `gh pr view <n>` for context.

## 2. Triage — full only

Skip entirely in quick mode. In full mode, skip when the diff touches 3 or fewer files. Otherwise dispatch one Explore agent with model haiku: return a change summary, the changed-file list, and paths of CLAUDE.md files relevant to the changed directories.

## 3. Dispatch — parallel, in a single message

**quick:** dispatch code-reviewer alone. Tell it explicitly: **peer cross-check: no.**

**full:** dispatch all four reviewer agents — code-reviewer, security-reviewer, test-analyzer, comment-analyzer. When explicit aspects are given, narrow to code-reviewer plus the named aspects' agents instead of all four (`all` forces the complete set). Tell every dispatched reviewer explicitly: **peer cross-check: yes.**

Each dispatch gets: the diff (or base/head SHAs and how to reproduce it), the triage summary if any, relevant CLAUDE.md paths, the explicit peer cross-check instruction, and the instruction to return findings in its own output contract.

## 4. Aggregate

Merge findings into Critical / Important / Suggestions. Keep per finding: file:line, source agent, the agent's own score (confidence or criticality) where reported, peer flag where present. Dedupe only when two agents report the same underlying issue; co-located findings about different concerns (e.g. a security defect and a missing-test-coverage gap on the same lines) stay separate line items. A test-analyzer finding that a new or changed function has no test coverage is always kept as its own item, never folded into another agent's finding on those lines, even when another agent reports the same gap. End with a recommended fix order.
