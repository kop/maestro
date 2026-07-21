---
name: review
description: Use for multi-aspect code review — dispatches specialized reviewer agents (code, security, tests, comments) in parallel over a diff or PR and aggregates findings. Triggered by /review [aspects] [target].
---

# Review — aspect-dispatching code review

Arguments: aspects (`code`, `security`, `tests`, `comments`, `simplify`, `all`) and/or a target (PR number, branch name, or nothing). Unrecognized words are the target. No aspects given = auto-detect per the dispatch rules below.

## 1. Scope

- No target: `git diff HEAD`; if empty, `git diff main...HEAD`.
- Branch target: `git diff <branch>...HEAD`.
- PR number: `gh pr diff <n>` and `gh pr view <n>` for context.

## 2. Triage

Skip when the diff touches 3 or fewer files. Otherwise dispatch one Explore agent with model haiku: return a change summary, the changed-file list, and paths of CLAUDE.md files relevant to the changed directories.

## 3. Dispatch — parallel, in a single message

code-reviewer is always dispatched, regardless of aspects. A requested aspect additionally forces its agent (`security` → security-reviewer, `tests` → test-analyzer, `comments` → comment-analyzer); `all` dispatches all four. Without explicit aspects, auto-detect:

- security-reviewer: aspect `security` requested, or the diff touches auth/session code, input parsing, crypto, network fetch, or dependency manifests.
- test-analyzer: test files changed, or code changed with no test changes.
- comment-analyzer: comments or docs added/modified.

Each dispatch gets: the diff (or base/head SHAs and how to reproduce it), the triage summary, relevant CLAUDE.md paths, and the instruction to return findings in its own output contract.

## 4. Aggregate

Merge findings into Critical / Important / Suggestions. Keep per finding: file:line, source agent, the agent's own score (confidence or criticality) where reported, peer flag where present. Dedupe only when two agents report the same underlying issue; co-located findings about different concerns (e.g. a security defect and a missing-test-coverage gap on the same lines) stay separate line items. A test-analyzer finding that a new or changed function has no test coverage is always kept as its own item, never folded into another agent's finding on those lines, even when another agent reports the same gap. End with a recommended fix order.

## 5. simplify (only when requested, only after a review with no Critical findings)

Dispatch general-purpose with this prompt, substituting the scope:

> Simplify the code changed in <scope> for clarity and consistency without changing behavior. Preserve all functionality and public interfaces. Prefer deleting needless indirection, collapsing single-use abstractions, and clearer names. Follow the comment discipline in CLAUDE.md. Make the edits directly and report each simplification with file:line.
