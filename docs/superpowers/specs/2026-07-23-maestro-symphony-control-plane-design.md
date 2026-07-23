# Maestro Symphony Control Plane

**Date:** 2026-07-23

## Goal

Recast Maestro from a subagent implementation orchestrator into a control plane for
planning and supervising work performed by external coding agents.

Maestro owns:

- discovery across company repositories;
- outcome and architecture planning;
- versioned Linear issue DAGs;
- delegation of approved work to Cursor through Linear;
- review of pull requests in the context of the whole Symphony;
- post-merge reconciliation of planned and delivered reality; and
- bounded updates to downstream work.

Cursor owns product-code implementation and convergence of its pull requests.

## Core concept: Symphony

A **Symphony** is a durable orchestration scope. It may represent a single epic, a
milestone, or an entire Linear project.

Every Symphony is rooted in one Linear issue:

```text
[Symphony] <goal>
```

The control issue is the restart point for a fresh Maestro session. It contains or
links to:

- the approved outcome and constraints;
- discovery evidence;
- DAG revisions and approvals;
- approved execution waves;
- the current orchestration snapshot; and
- the final as-built outcome.

The Symphony lifecycle is not a single plan-then-execute sequence. It may alternate
between discovery, planning, execution, and reconciliation:

```text
Discovery
    ↓
Plan a wave
    ↓
Approve the DAG revision
    ↓
Execute approved work
    ↓
Review and merge
    ↓
Reconcile as-built reality
    ↓
More discovery/planning or final verification
```

## Authority model

### Maestro may

- Read and update Linear.
- Read GitHub and write PR reviews and required orchestration metadata.
- Read all company repositories.
- Clone and fetch repositories.
- Check out branches and exact PR head SHAs in Maestro-owned Git worktrees.
- Run arbitrary local commands needed to validate work, including builds, tests,
  local services, Playwright, linters, and domain validators.
- Dispatch read-only research, architecture, review, and reconciliation agents.
- Delegate approved Linear issues to Cursor.
- Submit approving or request-changes GitHub PR reviews.
- Update undispatched downstream issues within the bounded replanning policy.

### Maestro must not

- Implement product-code changes.
- Intentionally edit product source, even in a review worktree.
- Commit, push, force-push, merge, rebase, or otherwise alter Cursor's branch.
- Turn an experimental or accidental local change into a delivered fix.
- Take over ordinary CI or review-comment resolution from Cursor.
- Dispatch an implementation subagent.

Maestro has Bash in the first version. The no-implementation boundary is enforced
by its instructions rather than by sandboxing or a command allowlist. This is a
behavioral guardrail, not a security boundary.

Build tools may create transient outputs, caches, screenshots, reports, and other
validation artifacts. If a command unexpectedly changes tracked source, Maestro
does not repair or publish the change. It records the relevant evidence and
discards the worktree.

## Responsibility boundaries

### Cursor owns PR convergence

Cursor is responsible for:

- implementing the Linear issue;
- fixing failing CI;
- addressing human, bot, and Maestro review findings;
- updating the PR until repository policy permits merging; and
- explaining material deviations from the proposed approach.

After initial Linear delegation, implementation feedback to Cursor is sent through
GitHub PR reviews, not through Linear comments.

### Repository policy owns merge readiness

A PR is merge-ready only when:

- it has no failing CI checks;
- it has at least one approval, whether from a human or bot;
- its review comments and threads are addressed; and
- it satisfies all other configured branch-protection, merge-queue, and repository
  gates.

Maestro does not require a human-specific approval and does not own the act of
merging. Any permitted human, bot, or automation may merge the PR.

### Maestro owns contextual judgment

Maestro reviews whether a PR:

- satisfies its Linear issue contract;
- advances the Symphony outcome;
- preserves approved constraints;
- composes with upstream and downstream tickets;
- implements cross-repository contracts correctly;
- introduces a material scope or architecture deviation; and
- leaves the remaining DAG valid.

Cursor Bugbot and other repository reviewers may assess a PR in isolation. Maestro's
distinct responsibility is to assess the PR as part of the larger delivery process.

## Superpowers composition

Maestro-specific skills adapt Superpowers discipline to a higher-level artifact:

| Superpowers behavior | Symphony adaptation |
|---|---|
| Brainstorming | Define the epic, milestone, or project outcome and compare strategies |
| Writing plans | Produce detailed Linear issues and a dependency DAG |
| Executing plans | Reconcile Linear, Cursor, GitHub PRs, and merged results |
| Code review | Review the PR against both code and Symphony context |
| Verification before completion | Verify the integrated Symphony outcome |

The adapters preserve research, explicit alternatives, approval gates, small
verifiable work units, and evidence-based completion. They do not use
`subagent-driven-development`; Linear delegation to Cursor replaces its implementer
loop.

## Plugin components

### Main agent

`agents/maestro.md` becomes the Symphony control-plane identity.

It has:

- Linear and GitHub MCP access;
- Read, Glob, Grep, Web, Bash, Agent, Skill, and task-tracking tools;
- codebase-memory graph tools when available; and
- access only to research, architecture, review, and reconciliation agents.

It has no Edit, Write, or NotebookEdit tools. Bash remains capable of writing, so
the agent instructions explicitly prohibit intentional source changes and remote
implementation mutations.

### Public skills

#### `/maestro:symphony-start`

- Create or resume the `[Symphony]` control issue.
- Run capability preflight.
- Determine whether the goal is immediately plannable.
- Run discovery when material unknowns remain.
- Apply the Superpowers-style brainstorming and planning gates.
- Create candidate Linear issues and native blocker relations.
- Present versioned DAG waves for approval.
- Materialize approved work as eligible for Cursor delegation.

#### `/maestro:symphony-reconcile`

- Perform one idempotent reconciliation pass.
- Detect manual drift.
- Reconcile newly merged work first.
- Review unreviewed PR heads.
- Continue discovery and planning.
- Delegate newly ready issues with bounded parallelism.
- Refresh the controller snapshot.
- Exit without sleeping or polling.

The intended unattended invocation is:

```text
/loop 10m /maestro:symphony-reconcile <SYMPHONY-ISSUE>
```

#### `/maestro:symphony-status`

Read-only reporting of:

- the active and approved waves;
- current Cursor work and linked PRs;
- blocked and ready issues;
- drift and human decisions;
- discovered scope changes; and
- the next expected transitions.

### Internal skill

#### `symphony-review`

`skills/symphony-review/SKILL.md` uses:

```yaml
user-invocable: false
```

It is hidden from the slash-command menu and is invoked by
`symphony-reconcile` for an unreviewed PR head. It is not advertised as a manual
review command.

### Agents

#### `symphony-researcher`

Investigates one repository or one bounded cross-repository question and returns
structured evidence, confidence, and remaining unknowns.

#### `code-architect`

Expands from a single-feature blueprint role to cross-repository architecture,
shared contracts, sequencing, and DAG input.

#### `symphony-reviewer`

Always runs for a managed PR. It checks the issue contract, Symphony goal,
dependency contracts, downstream assumptions, scope, and architecture.

#### `implementation-reconciler`

Runs after merge. It reports delivered behavior, deviations, new or changed
interfaces, operational consequences, downstream updates, follow-up work, and
acceptance-criteria evidence.

#### Risk-specific reviewers

Existing code, test, security, and comment reviewers are selected only when the
issue labels or changed files justify them. Migration and infrastructure checks are
risk lenses within the Symphony and code-review agents rather than separate agents.
Code review adds domain-validator and CI toolchain checks for relevant
infrastructure changes.

There is no peer agent. `/advisor` is sufficient for exceptional judgment calls
and is not part of the deterministic review roster.

## Components removed

The following current components conflict with the new identity or duplicate the
external-agent workflow:

```text
agents/peer.md
agents/general-purpose.md
agents/scribe.md
skills/autopilot/
skills/review/
skills/stacked-prs/
```

`skills/feedback/` remains and is updated to evaluate Symphony discovery, planning,
dispatch, contextual review, reconciliation, and drift handling.

## Discovery

`symphony-start` first classifies the goal as:

- sufficiently understood for planning; or
- requiring discovery before an implementation DAG can be approved.

Starting a Symphony authorizes read-only discovery. Discovery issues are not
implementation issues and are not delegated to Cursor.

### Small discovery

A bounded question and its result may be recorded directly under the Symphony
control issue.

### Large or multi-repository discovery

Maestro creates explicit discovery issues with:

```markdown
## Question
## Repository
## Evidence required
## Relevant integration points
## Constraints to identify
## Validation commands to discover
## Result
## Confidence and remaining unknowns
```

For heterogeneous repository fleets, researchers produce a normalized matrix:

| Repository | Stack | Integration point | Existing pattern | Shared contract impact | Validation | Confidence |
|---|---|---|---|---|---|---|

Maestro synthesizes the reports to identify:

- shared contracts;
- stack-specific adaptations;
- interface-producing work;
- independent work;
- proof-of-concept gates; and
- uncertainty that must remain represented in the DAG.

## Versioned DAG waves

The complete DAG does not need to be known at Symphony start.

Maestro may propose a stable implementation subgraph while later work remains
behind discovery or planning gates. Each material DAG expansion becomes a new
revision and requires explicit approval before its issues may be delegated to
Cursor.

### DAG construction rules

- The approved subgraph is acyclic.
- Every edge represents a real prerequisite.
- Every cross-repository edge names the consumed artifact or interface.
- Every implementation issue has observable acceptance criteria.
- Every implementation issue has validation instructions.
- Repository ownership and target location are known.
- Issues are small enough for a focused implementation and review cycle.
- Unresolved assumptions are represented as discovery gates.
- Every wave delivers a verifiable increment.
- A final integration and outcome-verification issue exists from the beginning,
  even when its details will be refined later.

Example:

```text
Discovery wave
    ↓
Shared contract + representative implementations
    ↓
Reconcile the actual interfaces
    ↓
Approve broader repository rollout
    ↓
Integration verification
```

## Linear data model

### Control-issue description

The stable description contains:

```markdown
## Outcome
## Scope
## Success criteria
## Constraints
## Out of scope
## Target Linear entities
## Execution policy
## Final as-built outcome
```

The original outcome and constraints are preserved. Completion data is appended
rather than replacing the original intent.

### Controller snapshot

Maestro maintains one editable comment:

```yaml
phase: discovery | planning | executing | verifying | complete | blocked
dag_revision: 3
approved_waves: [1, 2]
max_parallel_issues: 3
active_issues: [ABC-123, ABC-127]
pending_discovery: [ABC-140]
needs_attention: []
node_bindings:
  N01: ABC-123
  N02: ABC-127
last_reconciled_at: 2026-07-23T14:20:00+03:00
```

The snapshot is a cache for orientation, not the ultimate source of truth.
Reconciliation verifies it against Linear, GitHub, and action records.

### Labels

Maestro provisions a Linear label group named `maestro`. Its children are mutually
exclusive and may be referred to with Linear's `group:label` syntax:

```text
maestro:discovery
maestro:planning
maestro:executing
maestro:needs-human
maestro:scope-change
maestro:complete
```

Independent labels use a hyphenated namespace so they can coexist:

```text
maestro-symphony
maestro-managed
maestro-risk-security
maestro-risk-infra
maestro-risk-migration
```

Wave membership and detailed controller state do not become labels.

### Implementation issue contract

```markdown
## Objective
## Symphony contribution
## Scope
## Dependencies and consumed contracts
## Produced contracts
## Implementation constraints
## Proposed approach
## Acceptance criteria
## Validation
## Out of scope
## Expected outputs

## Actual implementation
## Deviations and decisions
## Follow-up work
```

The proposed approach is guidance, not a mandatory internal implementation.
Cursor may deviate when a different implementation is materially better, but it
must not violate constraints or acceptance criteria without escalation.

### Native identifiers and dependencies

The implementation DAG always uses native Linear issue identifiers and native
`blockedBy` relations.

A temporary, human-readable node key exists only before issue creation:

```text
SYM-42/DAG-3/N07
```

It is stored in the approved proposal and read from there; Maestro does not
regenerate or hash it. When Linear creates the issue, the controller binds the node
to the returned native ID:

```text
N07 → FB-2184
```

The approved DAG revision lists actual issue IDs and native dependency edges.

Maestro does not add redundant `relatedTo` relationships alongside blockers.

## Idempotency

Action identity uses identifiers supplied by Linear and GitHub:

| Action | Identity |
|---|---|
| Create candidate issue | Symphony ID + DAG revision + fixed node key |
| Delegate issue | Linear issue UUID + contract revision + Cursor integration ID |
| Review PR | GitHub PR ID + head SHA + contract revision + review-policy revision |
| Reconcile merge | Linear issue UUID + merge SHA |
| Update downstream issue | Downstream issue UUID + source merge SHA + target contract revision |

Human-visible action records may include a structured marker in inline code, but
they do not use model-generated random hashes. Issue keys embedded in machine
markers are avoided where they could cause Linear to create mention or relation
side effects.

The action identity is embedded in the action wherever possible. A PR review
contains its own review identity. If the write succeeds but the response is lost,
the next pass finds the existing action rather than repeating it.

Candidate issue creation includes its fixed plan-node key in the issue description.
An uncertain creation response causes Maestro to search the Symphony's candidate
issues for that key before retrying.

## Drift reconciliation

Linear is persistent shared state, not private controller storage. Human and
automation edits are expected.

At DAG approval, Maestro records the approved issue-contract revision and dependency
set. Every reconciliation compares that approved state with current Linear state.

| Drift | Response |
|---|---|
| Missing Maestro label or stale snapshot | Repair automatically |
| Clearly stale workflow status | Normalize when unambiguous |
| Objective, constraints, or acceptance criteria changed | Pause the affected subgraph |
| Dependencies added, removed, or reversed | Pause affected dispatches and show the edge diff |
| Cursor delegation removed or changed | Treat as potentially intentional |
| Issue marked Done without a reconciled merge | Do not unlock dependants |
| Linked PR changed, closed, or replaced | Re-resolve the implementation source |
| GitHub merged state disagrees with Linear | Trust the merge and reconcile Linear |

Semantic drift produces one deduplicated report and applies
`maestro:needs-human`. The user may:

1. accept the observed state as a new contract or DAG revision;
2. restore the approved state; or
3. revise the affected wave.

Maestro never repeatedly fights a human edit. Only generated or mechanically
derivable metadata is automatically repaired. Drift blocks only the affected
subgraph.

Before a mutation, Maestro re-reads the target. If it changed during the pass,
Maestro skips the action and retries on the next reconciliation.

## Reconciliation pass

Each `/maestro:symphony-reconcile` invocation performs one bounded pass.

### 1. Reconstruct observed state

Read the Symphony contract, DAG revisions, managed issues, dependencies, labels,
statuses, Cursor delegations, linked PRs, head SHAs, merged state, and existing
action identities.

### 2. Detect drift

Repair mechanical drift and pause ambiguous semantic drift before dispatching new
work.

### 3. Reconcile merges first

For each newly merged PR:

1. inspect the final diff and merge SHA;
2. run `implementation-reconciler`;
3. append Actual Implementation and deviations;
4. apply bounded downstream updates;
5. escalate material contract or DAG changes;
6. record reconciliation;
7. mark the issue complete; and
8. recalculate readiness.

GitHub's merged state wins even when Linear automation has not caught up.

### 4. Review new PR revisions

Invoke internal `symphony-review` for every unreviewed relevant head SHA.

Always run `symphony-reviewer`. Add code, test, security, migration,
infrastructure, UI, or other specialist lenses based on risk labels and changed
files.

Maestro does not triage other reviewers' comments or diagnose ordinary CI failures.
Cursor owns that loop.

### 5. Continue discovery and planning

Dispatch pending read-only research and propose a new DAG revision when enough
uncertainty has been removed.

### 6. Dispatch ready implementation issues

An issue is ready only when:

```text
it belongs to an approved DAG revision
AND every blocker is complete and merge-reconciled
AND its contract revision is approved
AND repository and validation instructions are known
AND it has no unresolved drift or human decision
AND it has no existing Cursor dispatch
```

Default limits:

```text
maximum active Cursor issues: 3
maximum active issues per repository: 1
```

Same-repository concurrency may be approved when overlap analysis demonstrates
that the work is independent.

### 7. Update and exit

Refresh the controller snapshot and end quietly unless:

- human input is required;
- a DAG revision is ready for approval;
- material scope changed;
- a wave or Symphony completed; or
- an unrecoverable integration error occurred.

No subagent sleeps or polls. `/loop` owns repetition.

## Symphony review

### Worktree lifecycle

For an unreviewed PR head:

1. Locate or fetch the repository.
2. Create a detached worktree at the exact head SHA beneath the configured Maestro
   review root.
3. Read repository instructions from that revision.
4. Run risk-adaptive review and validation.
5. Confirm that findings apply to the original head SHA.
6. Submit one GitHub PR review.
7. Remove every worktree and transient artifact.
8. Run `git worktree prune` where appropriate.

Parallel reviewers that execute commands receive separate worktrees. Diff-only
reviewers do not require one.

Cleanup runs after success, failure, or reviewer error. A failed removal is recorded
in a cleanup queue and retried on the next reconciliation pass. Maestro removes
only worktrees under its configured review root.

### Review outcomes

#### Pass

Submit an approving GitHub PR review for the exact head SHA.

#### Changes required

Submit a request-changes review with consolidated findings. Each finding includes:

- the violated issue criterion, Symphony goal, or dependency contract;
- file and line where applicable;
- evidence from code or executed validation; and
- the required outcome, without supplying an implementation patch.

#### Human decision required

Submit a non-approving PR review that explains the decision, then apply
`maestro:needs-human` to the affected Linear issue.

Cursor responds by updating the PR. A new head SHA triggers another review. The new
review focuses on the delta and unresolved Symphony concerns unless scope or the
governing contract changed materially.

## Post-merge reconciliation

Merged does not mean Done.

The implementation reconciler compares:

- the approved issue;
- its governing DAG revision;
- the final PR and merge SHA;
- resolved Maestro findings;
- upstream and downstream issues; and
- the Symphony outcome.

It produces:

```text
delivered outcome
implementation summary
deviations
interfaces created or changed
operational and migration consequences
acceptance-criteria evidence
downstream issue updates
follow-up work
documentation consequences
```

### Bounded replanning

Maestro may automatically update undispatched downstream issues' context, proposed
approach, validation, and dependency notes when the merged implementation changes
their assumptions.

Maestro must request approval before:

- changing an objective;
- changing scope;
- changing acceptance criteria;
- materially restructuring the DAG;
- altering already-running work; or
- accepting a strategic deviation.

Local deviations are recorded and execution continues. Contract deviations update
affected undispatched work. Scope discoveries create proposed follow-up work.
Strategic deviations pause the affected subgraph.

## Operational failures

Reconciliation follows read-check-act-recheck:

- A failed Linear or GitHub read prevents dependent mutations.
- One failed repository does not halt unaffected subgraphs.
- A timeout is never treated as proof that a write failed.
- An uncertain write is resolved by searching for its native target and action
  identity.
- A target changed during the pass is skipped.
- The next `/loop` pass retries recoverable failures.

The first version supports one active `/loop` per Symphony. Idempotency reduces
damage from accidental concurrent controllers, but Linear comments do not provide
a strong compare-and-swap lock. Strong multi-controller coordination is deferred
to a daemon-backed design.

## Capability preflight

Before creating a Symphony, verify:

- Linear read and write access;
- GitHub read access and the ability to submit approving and request-changes
  reviews from an identity permitted to review the managed repositories;
- Cursor is installed as a Linear delegation target;
- configured company workspace roots exist;
- the review root can be created and cleaned;
- required repositories can be read or cloned; and
- the session is running under the Maestro agent.

Missing capabilities are reported as:

- hard blockers;
- reduced-functionality warnings; or
- repository-specific discovery work.

## Runtime configuration

Environment-specific values live in a small user-level configuration:

```yaml
workspace_roots:
  - /path/to/company/repos
review_root: /path/to/maestro/reviews
cursor_linear_agent: Cursor
default_max_parallel_cursor: 3
default_max_per_repository: 1
```

Symphony-specific scope, repositories, review risks, concurrency, and execution
policy live in the control issue.

## Verification strategy

### Plugin structure

- Validate manifest and agent/skill frontmatter.
- Verify `symphony-review` is `user-invocable: false`.
- Verify Maestro has no Edit, Write, NotebookEdit, implementation agent, or scribe.
- Verify peer, standalone review, autopilot, and stacked-PR components are absent.
- Verify every skill uses the shared contract, label, identity, and result formats.

### Controller scenarios

- Fully specified single-repository Symphony.
- Discovery-first heterogeneous repository fleet.
- Multiple approved DAG waves.
- Bounded parallel dispatch.
- Re-running a pass without duplicate issues, reviews, comments, or delegations.
- Manual description, status, label, dependency, executor, and PR-link drift.
- Repeated PR head changes.
- CI failure without Maestro attempting a fix.
- Bot approval satisfying the approval requirement.
- Merge preceding Linear automation.
- Safe downstream reconciliation.
- Strategic deviation pausing only the affected subgraph.
- Fresh-session recovery from the Symphony issue and external state.

### Review-worktree scenarios

- Exact head SHA is checked out.
- Repository instructions are read from that revision.
- Playwright and other repository-specific validation can run.
- Tracked source changes are never delivered.
- Pass submits approval.
- Findings submit request changes.
- Worktrees are removed after success, validation failure, and reviewer failure.
- Failed cleanup is queued and retried.

### End-to-end acceptance

From a fresh session:

1. start with a broad multi-repository goal;
2. perform discovery;
3. propose and approve one DAG wave;
4. delegate ready work to Cursor;
5. review a PR in Symphony context;
6. observe its merge;
7. reconcile downstream issues; and
8. resume from another fresh session without duplicating an action.

## Repository reshaping

### Add

```text
agents/
├── symphony-researcher.md
├── symphony-reviewer.md
└── implementation-reconciler.md

skills/
├── symphony-start/SKILL.md
├── symphony-reconcile/SKILL.md
├── symphony-status/SKILL.md
└── symphony-review/SKILL.md
```

Shared protocol references define the Symphony contract, issue template, controller
snapshot, labels, action identities, review result, and reconciliation result once.

### Change

```text
agents/maestro.md
agents/code-architect.md
agents/code-reviewer.md
agents/security-reviewer.md
agents/test-analyzer.md
agents/comment-analyzer.md
skills/feedback/SKILL.md
README.md
.claude-plugin/plugin.json
.claude-plugin/marketplace.json
```

### Remove

```text
agents/peer.md
agents/general-purpose.md
agents/scribe.md
skills/autopilot/
skills/review/
skills/stacked-prs/
```

The release workflow must bump `.claude-plugin/plugin.json` before every push.

## Non-goals for the first version

- A direct Cursor MCP integration.
- Automatic code implementation by Maestro or its subagents.
- Automatic PR merge ownership.
- A daemon, webhook service, or local workflow database.
- Strong multi-controller locking.
- Sandbox-enforced review isolation.
- Multiple implementation providers.
- Automatic approval of material DAG changes.

## Product description

> Maestro is a Linear- and GitHub-based control plane that discovers and plans
> cross-repository work as versioned issue DAGs, delegates approved implementation
> to external coding agents, reviews pull requests in Symphony context, and
> reconciles merged reality into downstream work.
