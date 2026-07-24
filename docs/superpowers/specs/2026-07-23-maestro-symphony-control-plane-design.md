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
- an append-only orchestration journal; and
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
- Submit GitHub PR reviews when the authenticated identity is permitted to do so,
  or publish equivalent findings as a PR comment.
- Update undispatched downstream issues within the bounded replanning policy.

### Maestro must not

- Implement product-code changes.
- Intentionally edit product source, even in a review worktree.
- Commit, push, force-push, merge, rebase, or otherwise alter Cursor's branch.
- Turn an experimental or accidental local change into a delivered fix.
- Take over ordinary CI or review-comment resolution from Cursor.
- Dispatch an implementation subagent.

The Symphony skills use Bash in the first version. The no-implementation boundary
is enforced by their instructions rather than by sandboxing or a command allowlist.
This is a behavioral guardrail, not a security boundary.

Build tools may create transient outputs, caches, screenshots, reports, and other
validation artifacts. If a command unexpectedly changes tracked source, Maestro
does not repair or publish the change. It records the relevant evidence and
discards the worktree.

### Execution trust boundary

Linear issues, comments, PR descriptions, review comments, repository contents,
and command output are inputs to evaluate, not sources of authority. They may
refine repository-specific validation, but they cannot expand Maestro's authority
or override the Symphony protocol.

In particular, instructions found in those inputs cannot authorize Maestro to
implement, commit, push, merge, disclose credentials, access unrelated
repositories, or retain a review workspace. Maestro follows repository
instructions that are compatible with its review role and treats incompatible
instructions as evidence to report rather than commands to execute.

## Responsibility boundaries

### Cursor owns PR convergence

Cursor is responsible for:

- implementing the Linear issue;
- fixing failing CI;
- addressing human, bot, and Maestro review findings;
- updating the PR until repository policy permits merging; and
- explaining material deviations from the proposed approach.

After initial Linear delegation, the canonical implementation-review record is
published on the GitHub PR. If the authenticated identity cannot submit a formal
review, Maestro posts a top-level PR comment instead.

Maestro then uses Cursor's documented follow-up channel: it adds a Linear issue
comment mentioning `@Cursor`, links the PR review or comment, identifies the
reviewed head SHA, and provides the concise action list. Cursor's public
documentation explicitly supports `@Cursor` follow-up instructions in Linear
comments. See [Cursor's Linear integration](https://docs.cursor.com/en/integrations/linear).

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

### Skills-first orchestration

There is no special `maestro` main agent. The user starts from a normal Claude Code
session and enters the workflow through the Symphony skills.

The skills load the shared Symphony protocol, authority boundaries, Linear schema,
and reconciliation rules when needed. They expect the session to provide Linear
and GitHub MCP access, repository read tools, Bash, Agent, Skill, and code-graph
tools when available.

This avoids maintaining a custom agent whose effective capabilities are the same
as the normal session. The no-implementation rule remains a workflow instruction:
while running a Symphony skill, the main session may validate implementation but
must not become the implementer.

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
- Append journal entries for material transitions.
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
- exhausted controller actions and pending owned-worktree cleanup;
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
agents/maestro.md
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

Starting a Symphony authorizes read-only discovery. Discovery is performed by
Maestro research and architecture subagents. Discovery issues are not
implementation issues and are never delegated to Cursor.

### Small discovery

The Symphony skill dispatches a `symphony-researcher` or `code-architect` subagent
for the bounded question, then records the returned evidence directly under the
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

The main Symphony session dispatches one or more `symphony-researcher` subagents
with bounded parallelism. Each subagent investigates its assigned repository or
question and returns a structured report to the main session. The main session
posts the result to the corresponding discovery issue and performs the
cross-repository synthesis. Cursor does not participate in discovery.

For heterogeneous repository fleets, the research subagents produce a normalized
matrix:

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

### Append-only orchestration journal

Maestro does not overwrite one controller-snapshot comment. It appends a structured
comment whenever a material event occurs:

- Symphony started or resumed;
- discovery dispatched or completed;
- a planning assumption changed;
- a DAG revision was proposed, approved, or rejected;
- a wave or issue was dispatched;
- a PR review produced findings or passed;
- drift was detected or resolved;
- a merge was reconciled;
- downstream work was changed; or
- a wave or Symphony completed.

Each journal comment contains:

```markdown
## Maestro · <event>

Event type:
Action identity:
Attempt:
Occurred at:
Observed contract, head, or merge revision:
Outcome:
Error category:
Retryable:

Observed:
Action:
Evidence:
Decision rationale:
Affected issues or PRs:
Next expected transition:
```

The fields above form a small machine-readable envelope. `Event type`, `Outcome`,
and `Error category` use finite vocabularies defined by the shared Symphony
protocol. `Action identity` uses the native-derived identity from the Idempotency
section for idempotent controller actions and may be omitted for observational
events. `Attempt` is the one-based attempt number for a repeated controller
operation. Revision, attempt, error, and retry fields may be omitted when they do
not apply.

The journal records observable facts, evidence, decisions, and concise rationale.
It does not attempt to expose hidden model reasoning. Unchanged polling results such
as "CI still pending" do not create comments.

Confirmed mutations and reviews, ambiguous mutations, and failed mutation or
expensive-review attempts are material events and are journaled. Transient read
failures are journaled only when they materially block progress or exhaust a retry
policy. This preserves enough attempt history for fresh-session recovery without
turning the journal into a polling log.

Every reconciliation reconstructs current state from Linear, GitHub, native
relations, and the journal. `/maestro:symphony-status` synthesizes a current summary
on demand rather than relying on a mutable snapshot.

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
## Repository
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

### Cursor repository routing

Every Cursor implementation issue targets exactly one repository.

Maestro applies a Linear issue label from the Cursor-defined label group named
exactly `repo`. The child label is the GitHub repository in `owner/repository`
format. For example:

```text
repo:firebolt-db/firebolt-core
```

The issue's `Repository` section contains the same `owner/repository` value for
human readability. Before delegation, Maestro verifies that the field and issue
label agree and does not rely on Cursor's project or dashboard default repository.

Cursor's documented repository-selection order gives explicit issue text first,
then issue labels, project labels, and finally the default repository. Maestro uses
the issue-level `repo` label as its canonical routing mechanism. See
[Cursor's Linear integration](https://docs.cursor.com/en/integrations/linear).
Because `[repo=owner/repository]` text has higher priority, Maestro also scans the
issue description and comments for that syntax. A conflicting value is semantic
drift and blocks delegation until resolved.

Work spanning multiple repositories is split into one implementation issue per
repository and coordinated with native dependencies and produced/consumed
contracts. It is not delegated to Cursor as one ambiguous multi-repository issue.

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

## Observation and action model

Maestro keeps three concepts separate:

1. **Provider records** are the current native Linear and GitHub objects.
2. **Derived delivery state** is Maestro's interpretation of those records, such
   as planned, approved, delegated, PR open, merged, or merge-reconciled.
3. **Controller action attempts** are individual reads, reviews, or mutations
   performed by a reconciliation pass.

Derived delivery state does not require custom Linear statuses. It is reconstructed
from existing statuses, native relations, labels, delegations, PR state, repository
gates, action identities, and journal evidence.

An action attempt records:

```text
action identity
target native ID
preconditions and observed revision
attempted operation
outcome: confirmed | ambiguous | retryable-failure | permanent-failure
error category, when applicable
evidence needed to resolve an ambiguous outcome
```

An external implementation attempt is identified by the Linear issue UUID, Cursor
delegation, linked PR, and current PR head SHA. A replacement PR or new head SHA is
a new observed implementation revision; it does not erase earlier review evidence.

Only confirmed external evidence advances delivery state. A local tool return,
cached snapshot, timed-out mutation, or model conclusion is not by itself proof
that a Linear or GitHub transition occurred.

## Observed-state contract

Every reconciliation pass reads full native snapshots for objects it may act on.
For a managed Linear issue this includes its description, status, labels,
dependencies, project or parent scope, assignee, Cursor delegation, timestamps,
and linked PR metadata. For a linked PR this includes repository, base branch,
head SHA, draft and merged state, checks, reviews, unresolved threads, and merge
SHA when present.

The controller follows these normalization rules:

- Native UUIDs and provider values are preserved and remain authoritative.
- Human-readable identifiers are display and tie-break values, not durable map
  keys when a native UUID exists.
- Missing optional values remain unknown rather than being inferred as false.
- A failed, partial, or malformed read is insufficient evidence for a dependent
  mutation.
- An object omitted from a scoped or paginated response is not assumed deleted,
  terminal, or complete; Maestro resolves it by native ID before acting.
- A requested object that cannot be normalized is treated as a read failure, not
  silently omitted.
- State comparisons may normalize whitespace and case, but writes use current
  provider-native values and capabilities.

The shared protocol defines the minimum required fields for each reconciliation
decision. It is Linear- and GitHub-specific in the first version; Maestro does not
introduce a generic tracker-adapter abstraction.

## Idempotency

Action identity uses identifiers supplied by Linear and GitHub:

| Action | Identity |
|---|---|
| Create candidate issue | Symphony ID + DAG revision + fixed node key |
| Delegate issue | Linear issue UUID + contract revision + Cursor integration ID |
| Review PR | GitHub PR ID + head SHA + contract revision + review-policy revision |
| Reserve review worktree | Symphony UUID + implementation issue UUID + repository native identity + PR native ID + base/head SHAs + contract/DAG/policy revisions + exact `review-preparation-v1` revision |
| Reconcile merge | Canonical `reconcile-action-v1` over Symphony UUID + implementation issue UUID + repository native identity + PR native ID + merge SHA + contract revision + approved DAG revision + exact current reconciliation binding manifest revision + `reconciliation-input-v1` revision |
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
| Missing generated Maestro label | Repair automatically |
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
2. resolve every `reconciliation` and `both` requirement from the complete
   provider-confirmed governing chain into one staged canonical exact binding
   manifest before dispatch;
3. derive `reconciliation-input-v1` from the full
   Symphony/implementation/repository/PR/merge/contract/DAG identity, exact
   manifest, final diff, and resolved finding/context authority, then derive
   `reconcile-action-v1` from that input and manifest revision;
4. run `implementation-reconciler` with that manifest/input/action identity and require every
   acceptance, deviation, and follow-up conclusion to reference its exact
   bindings;
5. recompute and byte-compare the reconciliation manifest before accepting the
   result, including the exact manifest echo and conclusion-to-binding mapping;
6. record `merge-reconciled` only for a same-identity `complete` result whose
   required bindings and acceptance evidence are all exact and satisfied;
7. in a separate transition consume confirmed `merge-reconciled`, append Actual
   Implementation and deviations, apply bounded downstream updates, mark only
   the implementation issue complete, and recalculate readiness; and
8. evaluate Symphony closeout later against every closeout gate, emitting
   `symphony-completed` exactly once. A merge transition never closes the
   Symphony.

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

Immediately before delegation, Maestro performs an issue-specific dispatch
preflight against fresh Linear and GitHub observations. It verifies:

- the approved contract and DAG revision still govern the issue;
- every blocker is complete and merge-reconciled;
- the issue is in an eligible existing Linear status;
- repository text and the issue-level `repo` label agree;
- acceptance criteria and validation instructions remain complete;
- Cursor remains an available delegation target;
- no existing delegation, implementation PR, unresolved drift, or human decision
  already owns the transition; and
- the action identity has not already been confirmed.

A failed dispatch preflight skips only that issue. It does not stop merge
reconciliation, review, cleanup, discovery, or unrelated subgraphs. The journal
records a failure only when it creates a material blocker or needs human action.
The shared protocol assigns a stable reason code such as `not-approved`,
`blocker-unreconciled`, `status-ineligible`, `repository-routing-conflict`,
`contract-incomplete`, `cursor-unavailable`, `existing-implementation`,
`semantic-drift`, or `already-dispatched`.

Default limits:

```text
maximum active Cursor issues: 3
maximum active issues per repository: 1
```

Same-repository concurrency may be approved when overlap analysis demonstrates
that the work is independent.

When more issues are ready than available slots, Maestro selects them
deterministically:

1. approved wave order and topological readiness;
2. Linear priority, with unset or unknown priorities last;
3. the time readiness was first recorded, falling back to issue creation time;
4. native Linear identifier as a final tie-breaker.

Capacity exhaustion is not an error and does not create a journal comment. The
remaining ready issues stay eligible for the next reconciliation pass.

### 7. Journal and exit

Append comments for material transitions completed during the pass and end quietly
unless:

- human input is required;
- a DAG revision is ready for approval;
- material scope changed;
- a wave or Symphony completed; or
- an unrecoverable integration error occurred.

No subagent sleeps or polls. `/loop` owns repetition.

## Symphony review

### Worktree lifecycle

For an unreviewed PR head:

1. Reconstruct authoritative runtime context and mechanically derive every
   plan-time evidence binding. Caller locators and context revisions are
   assertions only.
2. Before repository bytes are needed, derive `review-preparation-v1` from the
   full Symphony/implementation/repository/PR/base/head/governance context,
   plan-time requirements and preworktree bindings, capabilities, decision
   resolutions, plugin source/policy closure, and exact-head repository source
   requirements.
3. Derive one reservation from that preparation revision. Write a
   reservation-only cleanup ledger and initial ownership marker; the initial
   marker contains no final action identity.
4. Locate or fetch the repository and create a unique review directory under a
   dedicated Maestro temporary root.
5. Add and verify a detached worktree at the exact head SHA, then derive the
   repository source closure. A differing closure makes the preparation stale.
6. Derive the final input/action, durably bind exactly one action to the
   reservation, and only then update the marker to the confirmed binding. A
   second action or historical reservation fails closed.
7. Run risk-adaptive review and validation with the worktree as the exact working
   directory.
8. At the first publication gate, after `review-requested` and before GitHub,
   rederive the complete input. A derivable change emits `review-input-stale`;
   an underivable input emits `action-failed`/`review-input-underivable` and
   claims no new eligible revision.
9. Submit or recover one GitHub PR review or top-level PR comment, then apply the
   second publication gate before Linear. Changed or underivable input makes the
   GitHub record historical, emits `review-input-stale`, and suppresses Linear.
10. Remove the expected worktree through Git and delete its owned review directory
   and transient artifacts.

Review-directory names are derived from sanitized native identifiers, never raw
issue or PR titles. Before creating, executing in, or removing a worktree, Maestro
resolves the relevant paths and verifies directory-component containment beneath
the dedicated review root. It does not rely on a string-prefix check.

Before final action binding, cleanup requires the exact confirmed reservation
plus matching ledger, reservation-only marker, containment, attachment, and
repository state. After binding, cleanup requires both that reservation and the
exact bound action identity, plus the same guarded observations. Attached
worktrees require matching Git metadata; reserved-unattached paths require proof
that no checkout, metadata, or unexpected contents exist.

Maestro never removes an unmarked, mismatched, or user-created worktree. At the
start of a later reconciliation pass it may scan the dedicated root and remove
abandoned worktrees only when the same ownership checks succeed.

If setup failed before a worktree was attached, Maestro may remove a reserved
review directory only when its ownership marker matches and the directory
contains no repository or unexpected files.

Parallel reviewers that execute commands receive separate worktrees. Diff-only
reviewers do not require one.

Cleanup runs after success, failure, or reviewer error. A failed removal is recorded
in the Symphony journal and retried on the next reconciliation pass. Maestro
removes only temporary worktrees it created for that review.

Validation commands receive an explicit time budget derived from the issue's
validation instructions or a conservative review default. No command may wait
indefinitely. Maestro checks tracked and staged changes before and after
validation. An unexpected tracked-source change invalidates any result that
depends on that change; Maestro records the evidence and discards the worktree
without publishing a patch.

### Review outcomes

#### Pass

If the authenticated identity may review the PR, submit an approving GitHub review
for the exact head SHA. Otherwise, post a top-level PR comment recording that the
Symphony review passed. In the latter case, repository merge policy must obtain its
required approval from another human or bot.

#### Changes required

If permitted, submit a request-changes review with consolidated findings. If the
PR was opened under the same identity and a formal review outcome is unavailable,
post the same findings as one top-level PR comment.

Each finding includes:

- the violated issue criterion, Symphony goal, or dependency contract;
- file and line where applicable;
- evidence from code or executed validation; and
- the required outcome, without supplying an implementation patch.

After publishing the canonical PR record, comment on the Linear implementation
issue with `@Cursor`, the reviewed head SHA, a link to the PR review or comment, and
the concise required-action list.

#### Human decision required

Submit a non-approving PR review or top-level comment that explains the decision,
then apply `maestro:needs-human` to the affected Linear issue. Do not mention
`@Cursor` unless there is a concrete implementation action Cursor can take.

Cursor receives changes-required instructions through the documented Linear
`@Cursor` follow-up and updates the PR. A new head SHA triggers another review. The
new review focuses on the delta and unresolved Symphony concerns unless scope or
the governing contract changed materially.

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

Failures use a shared taxonomy and deterministic recovery policy:

| Category | Response |
|---|---|
| `observation-failed` | Perform no dependent mutation; retry the read on a later pass |
| `observation-incomplete` | Resolve the object directly by native ID; do not infer state |
| `external-transient` | Retry the affected operation without blocking unrelated subgraphs |
| `mutation-ambiguous` | Search for the native target and action identity before any retry |
| `semantic-drift` | Pause the affected subgraph and request a contract decision |
| `review-stale-head` | Discard the unpublished result and review the new head |
| `validation-timeout` | Terminate the command, clean up, and report the review as inconclusive |
| `capability-lost` | Pause only operations requiring the missing permission or integration |
| `cleanup-failed` | Journal once and retry ownership-checked cleanup later |
| `permanent-invalid` | Apply `maestro:needs-human` and do not retry until relevant state changes |

Automatic retries that can repeat a mutation or expensive review are bounded by
the Symphony execution policy. By default, three consecutive attempts with the
same action identity and unchanged external state exhaust the retry budget. The
controller journals each attempt with its one-based attempt number, then records
one deduplicated exhaustion event, applies `maestro:needs-human` to the affected
issue or Symphony control issue, and waits for relevant state to change. Read-only
polling and inexpensive observation refreshes may continue and do not consume
this budget. Pending CI, unavailable concurrency slots, and normal Cursor
execution are not failures.

The first version supports one active `/loop` per Symphony. Idempotency reduces
damage from accidental concurrent controllers, but Linear comments do not provide
a strong compare-and-swap lock. Strong multi-controller coordination is deferred
to a daemon-backed design.

## Capability preflight

Before creating a Symphony, verify:

- Linear read and write access;
- GitHub read and PR-comment access;
- whether the authenticated GitHub identity can submit formal approvals and
  request-changes outcomes on the managed PRs;
- Cursor is installed as a Linear delegation target;
- the Linear `repo` label group and required `owner/repository` child labels exist
  or can be created;
- required repositories can be found in the available workspaces or cloned;
- temporary review worktrees can be created and removed; and
- Linear `@Cursor` comments reach the delegated agent.

Missing capabilities are reported as:

- hard blockers;
- reduced-functionality warnings; or
- repository-specific discovery work.

There is no Maestro runtime-configuration file. Repository locations are discovered
from the current workspace and additional directories, then cloned into temporary
locations when absent. Review worktrees use unique temporary directories.
Symphony-specific scope, repositories, review risks, concurrency, and execution
policy live in the control issue.

## Verification strategy

Verification is divided into three profiles:

1. **Core protocol conformance** uses deterministic local fixtures and is required
   for every release.
2. **Tool-integration conformance** is required for the supported Linear, GitHub,
   Cursor, and filesystem integrations. It exercises simulated responses,
   including partial and ambiguous failures.
3. **Real integration validation** uses disposable external artifacts and is
   recommended before production use. When credentials or permissions are absent,
   it is reported as skipped rather than passed.

### Plugin structure

- Validate manifest and agent/skill frontmatter.
- Verify `symphony-review` is `user-invocable: false`.
- Verify no custom main `maestro` agent is installed or required.
- Verify the Symphony skills prohibit implementation and never dispatch an
  implementation agent or scribe.
- Verify peer, standalone review, autopilot, and stacked-PR components are absent.
- Verify every skill uses the shared contract, journal, label, identity, and result
  formats.

### Controller scenarios

- Fully specified single-repository Symphony.
- Discovery-first heterogeneous repository fleet.
- Discovery performed by research subagents rather than Cursor.
- Multiple approved DAG waves.
- Bounded parallel dispatch.
- Stable dispatch ordering when ready work exceeds available capacity.
- Per-issue dispatch preflight failure while merge reconciliation continues.
- Re-running a pass without duplicate issues, reviews, comments, or delegations.
- Manual description, status, label, dependency, executor, and PR-link drift.
- Partial and malformed reads never being interpreted as completion.
- A missing scoped-list result being resolved by native ID before mutation.
- Ambiguous Linear and GitHub writes being searched by action identity before
  retry.
- Repeated PR head changes.
- A PR head changing during review and invalidating the unpublished result.
- Repeated identical operational failures exhausting the bounded retry budget
  without duplicate journal entries or mutations.
- Pending CI and exhausted concurrency not consuming an operational retry budget.
- Correct issue-level `repo` labels route each Cursor task to one repository.
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
- Review commands execute only from the exact owned worktree and cannot wait
  indefinitely.
- Sanitized native identifiers and canonical path checks keep worktrees beneath
  the dedicated review root.
- Missing or mismatched ownership markers prevent cleanup.
- An abandoned marker-owned worktree is safely recovered by a later pass.
- Tracked source changes are never delivered.
- Unexpected tracked changes invalidate results that depend on them.
- Pass submits approval when allowed and otherwise records a PR comment.
- Findings request changes when allowed and otherwise use a PR comment.
- Changes-required findings trigger a Linear `@Cursor` follow-up.
- Worktrees are removed after success, validation failure, and reviewer failure.
- Failed cleanup is queued and retried.

### End-to-end acceptance

The following is the recommended real integration profile. It uses disposable
Linear and GitHub artifacts where practical and reports unavailable external
capabilities explicitly.

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

Shared protocol references define the Symphony contract, issue template,
orchestration-journal events, labels, action identities, review result, and
reconciliation result once.

### Change

```text
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
agents/maestro.md
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
- Direct Cursor or coding-agent process and session management.
- Automatic code implementation by Maestro or its subagents.
- Automatic PR merge ownership.
- A daemon, webhook service, or local workflow database.
- Persistent implementation workspaces.
- A generic tracker-adapter layer.
- A repository-owned dynamic runtime configuration or shell-hook system.
- An HTTP dashboard, token-accounting service, or SSH worker pool.
- Strong multi-controller locking.
- Sandbox-enforced review isolation.
- Multiple implementation providers.
- Automatic approval of material DAG changes.

## Product description

> Maestro is a Linear- and GitHub-based control plane that discovers and plans
> cross-repository work as versioned issue DAGs, delegates approved implementation
> to external coding agents, reviews pull requests in Symphony context, and
> reconciles merged reality into downstream work.
