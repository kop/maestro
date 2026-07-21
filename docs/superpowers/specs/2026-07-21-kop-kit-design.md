# kop-kit — personal agents & skills collection

Design spec, 2026-07-21.

## Goal

A single personal Claude Code plugin providing specialized subagents (each with a pinned model and minimal tools) and orchestration skills, adapted from the official `code-review`, `feature-dev`, `pr-review-toolkit`, and `security-guidance` plugins. Agents must work both standalone (dispatched directly or via `/review`) and as workers inside superpowers workflows (`brainstorming`, `writing-plans`, `subagent-driven-development`, `requesting-code-review`). Outside opinions flow through the `peer` agent, a haiku proxy over the Cursor CLI (GPT / Gemini / Grok).

Non-goals:
- No port of the `/feature-dev` 7-phase command — superpowers owns the feature pipeline.
- No reimplementation of `security-guidance` hooks — that plugin stays installed for passive coverage.
- No `commands/` directory — skills are `/name`-invocable.

## Packaging

Repo: `~/code/kop/claude-code` → `github.com/kop/claude-code`. The repo is its own single-entry marketplace, installable on any machine via `claude plugin marketplace add`.

```
.claude-plugin/
  plugin.json            # name: kop-kit
  marketplace.json
agents/
  general-purpose.md     # sonnet
  code-architect.md      # opus
  code-reviewer.md       # opus
  security-reviewer.md   # fable
  test-analyzer.md       # sonnet
  comment-analyzer.md    # sonnet
  peer.md                # haiku
skills/
  root/SKILL.md
  review/SKILL.md
hooks/
  hooks.json             # /root enforcement (PreToolUse)
  root-guard.sh
docs/superpowers/specs/
README.md
```

## Model policy

Three tiers plus outside escalation:

| Tier | Used for | Mechanism |
|---|---|---|
| haiku | Triage, summaries, eligibility checks, confidence scoring | No standing agent — skills dispatch built-in `Explore`/`general-purpose` with the Agent tool's per-call `model: haiku` override |
| sonnet | Implementation, test/comment analysis, simplification | `general-purpose`, `test-analyzer`, `comment-analyzer` |
| opus | Judgment: architecture blueprints, review verdicts | `code-architect`, `code-reviewer` |
| fable | Security audit | `security-reviewer` |
| peer (non-Claude) | Cross-check of final review findings, deadlocks, multiple opinions | `peer` agent — haiku proxy over the Cursor CLI, one vendor per dispatch; spawned nested by `code-reviewer` and `security-reviewer` (Claude Code ≥ 2.1.172), or directly by the main session |

## Agents

All agents except `general-purpose` are read-only: `Glob, Grep, Read` plus the minimum extras named below. Reviewer roles additionally get `Bash` and `Agent` so they can spawn `peer` as a nested subagent.

### general-purpose (sonnet, all tools)

The implementer, and an override that pins the built-in `general-purpose` to sonnet even when the parent session runs opus. Prompt makes it aware of the kop-kit roster and key user skills so it delegates sideways knowledge correctly (e.g. "code discovery: codebase-memory-mcp first").

Override strategy: ship in `agents/` and verify a plugin agent named `general-purpose` shadows the built-in. If it does not, symlink it to `~/.claude/agents/general-purpose.md` (README install step); the plugin copy remains the source of truth.

### code-architect (opus, read-only)

From `feature-dev`. Extracts existing patterns and conventions, commits to one architecture, returns a full blueprint: components with file paths, implementation map, data flow, phased build sequence. Dispatched during superpowers brainstorming/design phases and by `/root`.

### code-reviewer (opus, read-only + Bash + Agent)

Merged from the `feature-dev` and `pr-review-toolkit` reviewers (same core prompt upstream) plus the superpowers reviewer template's output contract:

- Reviews a diff (unstaged by default; base/head SHAs when given) against CLAUDE.md guidance, bugs, and quality.
- 0–100 confidence rubric; reports only findings ≥ 80. Upstream false-positive exclusion list retained.
- Absorbs the `silent-failure-hunter` and `type-design-analyzer` lenses as named checklist sections (error-handling audit; type invariant strength).
- Peer escalation: for final/pre-merge reviews, cross-checks P0/P1 findings with two non-Claude vendors via parallel nested `peer` dispatches; reports agreement/disagreement per finding.
- Output: Critical / Important / Minor buckets with file:line and concrete fix — the format superpowers `receiving-code-review` consumes.

### security-reviewer (fable, read-only + Bash + Agent)

New; complements the passive `security-guidance` hooks with an on-demand deep audit: injection, secrets handling, authz/authn, crypto misuse, SSRF, deserialization, dependency risk. Same ≥ 80 confidence bar. Peer escalation routes to `gpt-5.6-sol-xhigh` first (observed to be a strong security reviewer), second vendor optional.

### peer (haiku, Bash + Read)

Lightweight proxy over the Cursor CLI: forwards one self-contained prompt to one non-Claude vendor model (`--mode ask`, headless JSON) and relays the `.result` verbatim, plus the `session_id` for `--resume` follow-ups. Callers wanting a second + third opinion dispatch two peers in parallel, one per vendor. Absorbs the former `peer` skill's vendor table, read-only invocation contract, and the redaction guard (secret values never leave for an outside vendor — file:line and secret type only). Haiku is deliberate: the intelligence is the vendor's; the proxy only forwards and relays.

### test-analyzer (sonnet, read-only)

From `pr-review-toolkit`. Behavioral test-coverage review: untested error paths, edge cases, missing negative tests; each recommended test rated 1–10 criticality with the specific regression it would catch.

### comment-analyzer (sonnet, read-only)

From `pr-review-toolkit`. Verifies every comment claim against actual code and flags comments that restate code or will go stale. Its rubric embeds the comment-discipline policy from the user's global CLAUDE.md verbatim as review rules: default is no comment; comments only for non-obvious intent/trade-offs/constraints, matching file density, fewest words; no restating code, no cross-file references, no change-narrating prose. Embedding (rather than relying on CLAUDE.md inheritance) makes the agent portable and its rubric explicit.

### Cut from upstream, and where the capability lives now

| Upstream agent | Disposition |
|---|---|
| scout / haiku steps of `code-review` | Per-dispatch `model: haiku` on built-in agents from skills |
| code-explorer | Built-in `Explore` agent + codebase-memory-mcp (`trace_path`, `get_architecture`) |
| silent-failure-hunter | Checklist section in `code-reviewer` |
| type-design-analyzer | Checklist section in `code-reviewer` |
| code-simplifier | Prompt embedded in `/review` `simplify` aspect, dispatched to `general-purpose` |

## Skills

### /review — aspect-dispatching review

Adapted from `pr-review-toolkit`'s `/review-pr`, parallel by default.

1. **Scope**: resolve target from args — unstaged diff (default), `main...HEAD`, or PR number via `gh`.
2. **Triage**: one `Explore` dispatch at `model: haiku` — change summary, changed files, relevant CLAUDE.md paths. Skipped for small diffs.
3. **Dispatch** (parallel, single message), aspects from args (`code`, `security`, `tests`, `comments`, `simplify`, `all`) or auto-detected:
   - `code-reviewer` — always
   - `security-reviewer` — `security` aspect, or auto when auth/input-handling/crypto/dependency files are touched
   - `test-analyzer` — tests changed, or code changed without tests
   - `comment-analyzer` — comments/docs added or modified
4. **Aggregate**: Critical / Important / Suggestions; peer agreement/disagreement flagged per finding. Peer escalation happens inside the reviewer agents, not the skill.
5. **simplify** (optional, after a passing review): dispatch `general-purpose` with the simplifier prompt embedded in this skill.

### /root — orchestrator mode

Main-session skill (not an agent: subagents are non-interactive and lose superpowers context).

- Turns the session into a pure orchestrator: prohibited from Edit/Write/NotebookEdit and implementation Bash; allowed to dispatch agents, read reports, and talk to the user.
- Delegation map: explore → `Explore`/codebase-memory-mcp · design → `code-architect` · implement → `general-purpose` · review → `/review` roster · security → `security-reviewer` · opinions/deadlock → `peer`.
- Subordinate to superpowers process skills: brainstorming/writing-plans/SDD decide what happens; `/root` forces who does it.
- Mode persists until the user ends it.

**Enforcement hook**: `PreToolUse` hook shipped with the plugin. The skill toggles a session-scoped marker file; while present, the hook denies Edit/Write/NotebookEdit and mutating Bash from the main session. Implementation gate: verify the hook can distinguish main-session tool calls from subagent tool calls (else it would block dispatched implementers); if it cannot, ship `/root` instruction-only with HARD-GATE prose and drop the hook.

## Superpowers wiring

Superpowers' cache cannot be edited. Integration is one line in `~/.claude/CLAUDE.md`:

> Where a superpowers skill dispatches a `general-purpose` subagent for code review, dispatch `code-reviewer` instead, filling the same template placeholders.

User instructions outrank skills, so this rewires `requesting-code-review` and SDD per-task reviews without forking superpowers.

## Dependencies

Declared in `plugin.json` if the manifest supports a dependency field; documented in the README regardless.

| Dependency | Kind | Used by |
|---|---|---|
| superpowers (plugin) | Required | Process skills governing `/root` and review workflows; `receiving-code-review` output contract |
| security-guidance (plugin) | Recommended | Passive security coverage that `security-reviewer` complements |
| Cursor CLI (`agent` binary, authenticated) | Required for peer escalation | `peer` agent |
| codebase-memory-mcp (MCP server) | Recommended | Exploration delegation (`trace_path`, `get_architecture`); workflows fall back to `Explore` when absent |
| `gh` CLI | Required for PR-scoped `/review` | `/review` scope resolution |

## Verification points (implementation gates)

1. Plugin agent named `general-purpose` shadows the built-in → else symlink fallback.
2. `model: fable` accepted in agent frontmatter → else full model ID string.
3. `/root` hook can distinguish main-session from subagent tool calls → else instruction-only.
4. Reviewer agents can spawn the `peer` agent as a nested subagent (Agent in their tools allowlist; Claude Code ≥ 2.1.172) → else the controller/`/review` dispatches `peer` after reviewers return.
5. `plugin.json` supports declaring a plugin dependency (superpowers) → else README-only.

## Testing

- Each agent standalone on a sample diff in a scratch repo: correct model shows in dispatch, output format matches contract, read-only agents cannot write.
- `/review` end-to-end on a branch with seeded bugs (logic bug, silent catch, stale comment, missing negative test, hardcoded secret): each lands in the right agent's findings; peer cross-check runs for P0/P1.
- `/root` session: implementation request → main session refuses to edit, dispatches `general-purpose`; hook (if shipped) blocks a direct main-session Edit but not the subagent's.
- Superpowers SDD task cycle: per-task review arrives from `code-reviewer`, not the generic template.

## Sources

- `anthropics/claude-code` plugins: `code-review`, `feature-dev`, `pr-review-toolkit`, `security-guidance` (kept installed).
- Local: superpowers 6.1.1, `~/.claude/skills/peer` (absorbed into the `peer` agent).
