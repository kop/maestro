---
name: review
description: Use for code review — dispatches reviewer agents over a diff or PR and aggregates findings. Two modes — quick (code-reviewer + 1 peer) and full (all reviewers + 3 peers). Triggered by /review [quick|full] [aspects] [target].
---

# Review — quick or full code review

Peers (non-Claude vendor reviewers via the `peer` agent) are dispatched by the orchestrator running this skill, in parallel with the Claude reviewer agents — not nested inside them. Each peer is an independent reviewer of the same diff, returning its own findings.

Two modes:

- **quick** — dispatches code-reviewer + 1 peer, no triage. Fast pass for a tight review loop (e.g. a subagent-driven-development per-task cycle).
- **full** — triage, then all four reviewer agents + 3 peers (3 different vendors), all in parallel. The thorough end-to-end gate.

Arguments: an optional mode (`quick` | `full`), optional aspects (`code`, `security`, `tests`, `comments`, `all`), and an optional target (PR number, branch name, or nothing). Unrecognized words are the target.

**Default mode when none is given: full.** A superpowers per-task review runs quick (see the wiring note in the README); a human or maestro asking for a final/branch-end review runs full.

## 1. Scope

- No target: `git diff HEAD`; if empty, `git diff main...HEAD`.
- Branch target: `git diff <branch>...HEAD`.
- PR number: `gh pr diff <n>` and `gh pr view <n>` for context.

## 2. Triage — full only

Skip entirely in quick mode. In full mode, skip when the diff touches 3 or fewer files. Otherwise dispatch one Explore agent with model haiku: return a change summary, the changed-file list, and paths of CLAUDE.md files relevant to the changed directories.

## 3. Dispatch — parallel, in a single message

Dispatch the Claude reviewer agent(s) AND the peer agent(s) together in one parallel message.

**quick:** code-reviewer + 1 peer. The peer targets the strongest non-Claude vendor (peer.md defaults to OpenAI).

**full:** all four reviewer agents — code-reviewer, security-reviewer, test-analyzer, comment-analyzer — plus 3 peers. When explicit aspects are given, narrow the Claude reviewers to code-reviewer plus the named aspects' agents instead of all four (`all` forces the complete set); still dispatch the 3 peers. The 3 peers must target 3 different vendors (e.g. OpenAI, Gemini, and Grok) so the outside opinions are genuinely diverse.

Each Claude reviewer dispatch gets: the diff (or base/head SHAs and how to reproduce it), the triage summary if any, relevant CLAUDE.md paths, and the instruction to return findings in its own output contract.

Each peer dispatch is a full, self-contained independent-review prompt: the diff (or base/head SHAs + how to reproduce it), the triage summary if any, the relevant CLAUDE.md paths, the vendor to target, and the request to return its own findings (file:line, severity, why).

## 4. Aggregate

Merge findings from the Claude reviewers and the peers into Critical / Important / Suggestions. Keep per finding: file:line, source (which reviewer agent or which vendor peer raised it), and the agent's own score (confidence or criticality) where reported. Track corroboration: a finding raised by both a Claude reviewer and a peer is higher-confidence — note the agreement across sources; surface peer-only findings too. Dedupe only when two sources report the same underlying issue (fold them into one line item noting both sources); co-located findings about different concerns (e.g. a security defect and a missing-test-coverage gap on the same lines) stay separate line items. A test-analyzer finding that a new or changed function has no test coverage is always kept as its own item, never folded into another source's finding on those lines, even when another source reports the same gap. End with a recommended fix order.
