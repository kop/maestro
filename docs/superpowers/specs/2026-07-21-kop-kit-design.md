# kop-kit — personal agents & skills collection

Design spec, 2026-07-21.

## Goal

A single personal Claude Code plugin providing specialized subagents (each with a pinned model and minimal tools) and orchestration, adapted from the official `code-review`, `feature-dev`, `pr-review-toolkit`, and `security-guidance` plugins. Agents must work both standalone (dispatched directly or via `/review`) and as workers inside superpowers workflows (`brainstorming`, `writing-plans`, `subagent-driven-development`, `requesting-code-review`). Outside opinions flow through the `peer` agent, a haiku proxy over the Cursor CLI (GPT / Gemini / Grok).

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
  scribe.md              # haiku
  maestro.md             # opus
skills/
  review/SKILL.md
docs/superpowers/specs/
README.md
```

## Model policy

Three tiers plus outside escalation:

| Tier | Used for | Mechanism |
|---|---|---|
| haiku | Triage, summaries, eligibility checks; one dictated file edit | `scribe` for dictated edits; triage via built-in `Explore`/`general-purpose` with the Agent tool's per-call `model: haiku` override |
| sonnet | Implementation, test/comment analysis | `general-purpose`, `test-analyzer`, `comment-analyzer` |
| opus | Judgment: architecture blueprints, review verdicts; session orchestration | `code-architect`, `code-reviewer`, `maestro` |
| fable | Security audit | `security-reviewer` |
| peer (non-Claude) | Cross-check of final review findings, deadlocks, multiple opinions | `peer` agent — haiku proxy over the Cursor CLI, one vendor per dispatch; spawned nested by `code-reviewer` and `security-reviewer` (Claude Code ≥ 2.1.172), or directly by the main session |

## Agents

All agents except `general-purpose` are read-only: `Glob, Grep, Read` plus the minimum extras named below. `Bash` on the review agents exists only to fetch the diff (`git diff`, `gh pr diff`) for standalone use — none of them run anything else. `code-reviewer` and `security-reviewer` also get `Agent` so they can spawn `peer` as a nested subagent. The `maestro` orchestrator gets `Agent`, `Skill`, and `TodoWrite` (no `Bash`) so it can only delegate.

Tool access is an allowlist, so a restrictive `tools` field also strips the inherited MCP tools. The analysis agents that benefit from graph-level code understanding (`code-architect`, `code-reviewer`, `security-reviewer`, `test-analyzer`) therefore name the read-only `codebase-memory-mcp` tools (`search_code`, `search_graph`, `trace_path`, `get_code_snippet`, `get_architecture`, `query_graph`, `get_graph_schema`) explicitly in their allowlist — read-only only, never the indexing/`delete_project` writes. When the server is absent these entries simply don't resolve and the agent falls back to `Grep`/`Glob`/`Read`, so the dependency stays recommended, not required. Because these ship as plugin agents, the `mcpServers`, `permissionMode`, and `hooks` frontmatter fields are ignored — MCP can only reach an agent through its `tools` allowlist, which is why the grant is done there. `memory` is deliberately unused: it force-enables `Write`/`Edit`, which would break every read-only guarantee. Each agent sets a `color` for the task list; the four `/review` reviewers plus `peer` carry distinct colors (green, red, cyan, yellow, orange) so a full fan-out is legible at a glance.

### general-purpose (sonnet, all tools)

The implementer, and an override that pins the built-in `general-purpose` to sonnet even when the parent session runs opus. Prompt makes it aware of the kop-kit roster and key user skills so it delegates sideways knowledge correctly (e.g. "code discovery: codebase-memory-mcp first").

Override strategy: ship in `agents/` and verify a plugin agent named `general-purpose` shadows the built-in. If it does not, symlink it to `~/.claude/agents/general-purpose.md` (README install step); the plugin copy remains the source of truth.

### code-architect (opus, read-only + codebase-memory read tools)

From `feature-dev`. Extracts existing patterns and conventions, commits to one architecture, returns a full blueprint: components with file paths, implementation map, data flow, phased build sequence. Dispatched during superpowers brainstorming/design phases and by `maestro`.

### code-reviewer (opus, read-only + Bash + Agent + codebase-memory read tools)

Merged from the `feature-dev` and `pr-review-toolkit` reviewers (same core prompt upstream) plus the superpowers reviewer template's output contract:

- Reviews a diff (unstaged by default; base/head SHAs when given) against CLAUDE.md guidance, bugs, and quality.
- 0–100 confidence rubric; reports only findings ≥ 80. Upstream false-positive exclusion list retained.
- Absorbs the `silent-failure-hunter` and `type-design-analyzer` lenses as named checklist sections (error-handling audit; type invariant strength).
- Peer escalation: when the dispatch requests it (`peer cross-check: yes`, set by `/review` full mode), cross-checks P0/P1 findings with two non-Claude vendors via parallel nested `peer` dispatches; reports agreement/disagreement per finding. Off by default, so quick reviews and direct per-task dispatches don't escalate.
- Output: Critical / Important / Minor buckets with file:line and concrete fix — the format superpowers `receiving-code-review` consumes.

### security-reviewer (fable, read-only + Bash + Agent + codebase-memory read tools)

New; complements the passive `security-guidance` hooks with an on-demand deep audit: injection, secrets handling, authz/authn, crypto misuse, SSRF, deserialization, dependency risk. Same ≥ 80 confidence bar. Peer escalation, when the dispatch requests it, routes OpenAI-first (its flagship observed to be a strong security reviewer), second vendor optional.

### peer (haiku, Bash + Read)

Lightweight proxy over the Cursor CLI: forwards one self-contained prompt to one non-Claude vendor model (`--mode ask`, headless JSON) and relays the `.result` verbatim, plus the `session_id` for `--resume` follow-ups. Callers wanting a second + third opinion dispatch two peers in parallel, one per vendor. Every run preflights `agent --list-models` — verifying the CLI works and selecting the vendor's newest flagship by model family rather than a hardcoded ID, so consults auto-upgrade as flagships change; a CLI failure is reported verbatim, never papered over. Absorbs the former `peer` skill's read-only invocation contract and the redaction guard (secret values never leave for an outside vendor — file:line and secret type only). Haiku is deliberate: the intelligence is the vendor's; the proxy only forwards and relays.

### test-analyzer (sonnet, read-only + Bash + codebase-memory read tools)

From `pr-review-toolkit`. Behavioral test-coverage review: untested error paths, edge cases, missing negative tests; each recommended test rated 1–10 criticality with the specific regression it would catch.

### comment-analyzer (sonnet, read-only + Bash)

From `pr-review-toolkit`. Verifies every comment claim against actual code and flags comments that restate code or will go stale. Its rubric embeds the comment-discipline policy from the user's global CLAUDE.md verbatim as review rules: default is no comment; comments only for non-obvious intent/trade-offs/constraints, matching file density, fewest words; no restating code, no cross-file references, no change-narrating prose. Embedding (rather than relying on CLAUDE.md inheritance) makes the agent portable and its rubric explicit.

### scribe (haiku, Read + Edit + Write)

A mechanical hand for one dictated file edit — the write a write-free orchestrator delegates. Given an exact path and the exact content or change, it applies it verbatim (reading before editing) and reports the result, or the exact reason it could not; it brings no initiative and does nothing requiring judgment. Primary caller is maestro: subagent-driven-development's controller composes the post-review ledger line for `.superpowers/sdd/progress.md` but cannot write it, so it hands the line to scribe. Gives the haiku tier a standing agent.

### maestro (opus, read-only orchestrator)

The orchestrator identity, launched as the whole session: `claude --agent maestro`. Tools are `Read, Grep, Glob, Agent, Skill, TodoWrite` — no Edit/Write/NotebookEdit/Bash — and Claude Code enforces the allowlist by tool availability, so the session cannot produce an artifact: it reads, decides, tracks, talks to the user, and dispatches. Every file, command, commit, plan doc, and SDD ledger line is delegated to a worker. Replaces the former `/root` skill, whose HARD-GATE prose the model could forget; an allowlist cannot be. `--agent` boots the main interactive loop, so questions, menus, CLAUDE.md, and skills keep working — a dispatched subagent could not do those, which is why the orchestrator is a launch identity, not a subagent.

### Cut from upstream, and where the capability lives now

| Upstream agent | Disposition |
|---|---|
| scout / haiku steps of `code-review` | Per-dispatch `model: haiku` on built-in agents from skills |
| code-explorer | Built-in `Explore` agent + codebase-memory-mcp (`trace_path`, `get_architecture`) |
| silent-failure-hunter | Checklist section in `code-reviewer` |
| type-design-analyzer | Checklist section in `code-reviewer` |

## Skills

### /review — quick or full review

Adapted from `pr-review-toolkit`'s `/review-pr`, parallel by default. Two modes; default full.

- **quick** — dispatches only `code-reviewer`, peer cross-check off, triage skipped. The fast per-task pass.
- **full** — triage, then all four reviewer agents in parallel with peer cross-check on. The end-to-end gate.

1. **Scope**: resolve target from args — unstaged diff (default), `main...HEAD`, or PR number via `gh`.
2. **Triage** (full only): one `Explore` dispatch at `model: haiku` — change summary, changed files, relevant CLAUDE.md paths. Skipped for small diffs.
3. **Dispatch** (parallel, single message):
   - quick → `code-reviewer` alone, told `peer cross-check: no`.
   - full → `code-reviewer` + `security-reviewer` + `test-analyzer` + `comment-analyzer`, each told `peer cross-check: yes`. Explicit aspect args (`code`, `security`, `tests`, `comments`, `all`) narrow full to `code-reviewer` plus the named agents; `all` forces the complete set.
4. **Aggregate**: Critical / Important / Suggestions; peer agreement/disagreement flagged per finding. Peer escalation runs inside the reviewer agents but is driven by the skill's explicit `peer cross-check` signal, not the agent's own judgment.

The two modes map to the two review entry points. A superpowers per-task cycle dispatches the `code-reviewer` agent directly — quick by construction (single reviewer, no peer). Full is the `/review` skill invoked by a human or `maestro` at branch end; a subagent cannot invoke a fan-out skill, so full review is always a main-loop invocation.

Orchestrator mode lives in the `maestro` agent (see Agents), not a skill — a `tools` allowlist enforced at launch beats HARD-GATE prose a skill can forget.

## Superpowers wiring

Superpowers' cache cannot be edited. Integration is one line in `~/.claude/CLAUDE.md`:

> Where a superpowers skill dispatches a `general-purpose` subagent for code review, dispatch `code-reviewer` instead, filling the same template placeholders.

User instructions outrank skills, so this rewires `requesting-code-review` and SDD per-task reviews without forking superpowers.

## Dependencies

Declared in `plugin.json` if the manifest supports a dependency field; documented in the README regardless.

| Dependency | Kind | Used by |
|---|---|---|
| superpowers (plugin) | Required | Process skills governing `maestro` and review workflows; `receiving-code-review` output contract |
| security-guidance (plugin) | Recommended | Passive security coverage that `security-reviewer` complements |
| Cursor CLI (`agent` binary, authenticated) | Required for peer escalation | `peer` agent |
| codebase-memory-mcp (MCP server) | Recommended | Exploration delegation (`trace_path`, `get_architecture`); workflows fall back to `Explore` when absent |
| `gh` CLI | Required for PR-scoped `/review` | `/review` scope resolution |

## Verification points (implementation gates)

1. Plugin agent named `general-purpose` shadows the built-in → else symlink fallback.
2. `model: fable` accepted in agent frontmatter → else full model ID string.
3. `claude --agent maestro` runs the main session under the agent's `tools` allowlist as a hard restriction — Edit/Write/Bash uncallable, not merely discouraged → confirmed by headless probe; no enforcement hook needed.
4. Reviewer agents can spawn the `peer` agent as a nested subagent (Agent in their tools allowlist; Claude Code ≥ 2.1.172) → else the controller/`/review` dispatches `peer` after reviewers return.
5. `plugin.json` supports declaring a plugin dependency (superpowers) → else README-only.

## Testing

- Each agent standalone on a sample diff in a scratch repo: correct model shows in dispatch, output format matches contract, read-only agents cannot write.
- `/review` end-to-end on a branch with seeded bugs (logic bug, silent catch, stale comment, missing negative test, hardcoded secret): each lands in the right agent's findings; peer cross-check runs for P0/P1.
- `claude --agent maestro`: implementation request → the session has no Edit/Write/Bash tool to call, so it dispatches `general-purpose`; a direct edit is impossible (tool absent), not merely refused.
- Superpowers SDD task cycle: per-task review arrives from `code-reviewer`, not the generic template.

## Sources

- `anthropics/claude-code` plugins: `code-review`, `feature-dev`, `pr-review-toolkit`, `security-guidance` (kept installed).
- Local: superpowers 6.1.1, `~/.claude/skills/peer` (absorbed into the `peer` agent).
