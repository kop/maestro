# Symphony Review Protocol

Review the implementation at one exact PR revision in the context of its issue,
approved DAG, dependency contracts, downstream work, and Symphony outcome.

## Required review identity

Do not begin until the request identifies:

```text
Symphony UUID and control issue UUID
implementation issue UUID and human-readable key
approved contract revision
approved DAG revision
review-policy revision
repository owner/name and local source or clone URL
GitHub PR native ID and number
base SHA
exact PR head SHA
applicable risk labels
issue validation commands
complete required lens/validator evidence manifest
plugin-owned review-source-requirements-v1 exact-byte revision
review-source-closure-v1 descriptor and revision
complete plan-time evidence requirements
complete runtime acceptance-evidence binding manifest and revision
owned exact-head worktree ledger and confirmed cleanup ownership transfer
applicable matching decision-resolution identities and governing revisions
review input revision and confirmed review-requested event identity
review action identity
```

Missing identity makes the review `inconclusive`; it never permits guessing.

Derive the review input revision exactly as the core protocol specifies. Run the
fixed `review-source-closure-v1` algorithm over only declared exact source paths
and the plugin-owned manifest at its fixed plugin-relative path.
Use the fully qualified roster agent identifier as a lens stable key, derive
every validator key from its finite kind and normalized command, and resolve
exactly one typed runtime binding for every contract
`evidence_requirement_key`. Resolve every locator template only from freshly
confirmed native state; zero or multiple matches are non-publishable.
The manifest contains every required lens and validator with an explicit
`present`, `missing`, or `unavailable` state and the matching derived evidence
revision or the literal `missing`/`unavailable` sentinel. Free-form keys,
hand-authored revisions, and omitted source revisions are invalid. Include only
confirmed decision-resolutions that exactly match the pause identity and
governing revision. The review input revision is part of the Review PR action identity:
Symphony UUID, implementation issue UUID, GitHub PR native ID, base SHA, head
SHA, contract revision, DAG revision, review-policy revision, and exact review
input revision. Do not begin review until the matching
canonical `review-requested` record is confirmed.

## Owned worktree protocol

Reconciliation prepares one owned isolated detached worktree before source
closure or `review-requested`: it confirms repository/PR/base/head identity,
creates the ledger/marker, verifies containment and attachment, verifies the
GitHub repository identity and exact detached HEAD, then derives repository
closure from that root. Review accepts only that exact ledger entry after a
confirmed cleanup-ownership transfer. Before any use it revalidates marker,
repository, `git rev-parse HEAD`, detached state, and clean tracked/staged state.
If dispatch fails before transfer, reconciliation retains ownership and performs
guarded cleanup. If dispatch succeeds, review owns cleanup on every exit.

Run all commands with the transferred worktree as the exact working directory,
apply explicit timeouts, and compare tracked/staged changes before and after
validation.

Every cleanup-ledger entry records the repository, canonical owned path, marker,
expected action identity, and explicit attachment state. Cleanup branches on
that recorded state:

- `attached-worktree` requires a matching marker and expected action identity,
  canonical-path containment, and Git worktree metadata matching the expected
  repository and canonical path. Remove through Git first, then remove only
  expected owned transient artifacts.
- `reserved-unattached` requires a matching marker and expected action identity,
  canonical-path containment, a fresh proof that attachment state is false, and
  proof that no repository/worktree metadata, checkout, unexpected file, or
  unexpected contents exists. Remove only the known empty reservation and marker
  artifacts; Git metadata is neither expected nor required.

Never delete unmarked, mismatched, ambiguous, or user-created worktrees or
reservations. Marker mismatch, unexpected contents, ambiguous attachment,
containment failure, or Git metadata mismatch emits `cleanup-failed`, retains the
exact owned path, and permits retry only after a new safe observation.

Unexpected tracked changes invalidate evidence that depends on them. Record the
observation, publish no patch, and discard the worktree. Build caches, screenshots,
reports, and other transient validation artifacts are allowed only inside the
owned review directory or worktree and are deleted afterward.

## Required review lenses

Always run `symphony-reviewer`. Add risk reviewers based on issue labels, changed
files, and repository context:

- `code-reviewer` for correctness, error handling, compatibility, and code quality;
- `test-analyzer` when behavior or tests changed;
- `security-reviewer` for security-sensitive surfaces or
  `maestro-risk-security`;
- `comment-analyzer` when comments or public documentation materially changed.

Infrastructure review must run the relevant available validator against rendered
output: Kubernetes/Helm, Docker, and GitHub Actions validation are evidence, not
optional polish. CI workflow review also verifies that every invoked tool,
component, target, binary, credential assumption, and runner capability is
actually provisioned.

Reviewers return findings only; they never edit.

### Risk-label mapping

Risk labels are deterministic roster selectors, not advisory decorations:

| Label | Required review behavior |
|---|---|
| `maestro-risk-security` | Select the security lens in addition to contextual review |
| `maestro-risk-infra` | Select code review plus available rendered infrastructure/workflow validators and runtime-toolchain checks |
| `maestro-risk-migration` | Select contextual + code + test lenses and require migration/rollback/compatibility evidence |

For `maestro-risk-migration`, add security only when a trust boundary also requires
security review. File and context inference may add lenses but must not remove a
label-selected lens.

## Common finding contract

Every reviewer returns:

Reviewed identity repeats Symphony UUID, Implementation issue UUID, PR native ID, Base SHA, Head SHA, contract revision, DAG revision, review-policy revision, review input revision, and review action identity.

```markdown
## Verdict
pass | changes-required | human-decision | inconclusive

## Reviewed identity
Symphony UUID:
Implementation issue UUID:
PR native ID:
PR number:
Base SHA:
Head SHA:
Contract revision:
DAG revision:
Review-policy revision:
Review input revision:
Review action identity:

## Findings
- Severity:
  Confidence:
  Location:
  Violated contract or criterion:
  Evidence:
  Required outcome:

## Validation evidence
- Command or inspection:
  Result:

## Uncertainties
- Evidence that could not be obtained:
```

Omit the finding item when none exists, but never omit reviewed identity or
validation evidence. Findings request outcomes, not implementation patches.

## Aggregate decision

Deduplicate the same underlying problem while preserving corroborating sources.
Different concerns on the same line remain separate. A required specialist
`human-decision` or `inconclusive` result prevents a passing aggregate.

Immediately before publication, freshly rederive the complete review context,
all evidence-template bindings, acceptance binding manifest, exact-head
repository/plugin closure, capability state, decision-resolution revision, and
complete review-input revision. Compare canonical bytes byte-for-byte with the
reviewed input. Any difference publishes neither GitHub nor Linear follow-up,
records `review-input-stale` with old/new revisions, cleans up, and makes only
the new input eligible. An underivable fresh input fails closed with
`action-failed`.

The attachment-state cleanup branch applies on success, failure, timeout, stale head, reviewer error, and publication failure.

## Publication and Cursor follow-up

- The GitHub publication identity repeats the complete review context, exact review input revision, Review PR action identity, and exact channel. Embed
  `Maestro-GitHub-Review-Publication-Identity: <publication identity>`,
  `Maestro-Review-Input-Revision: <review input revision>` and
  `Maestro-Review-Action-Identity: <review action identity>` in every GitHub
  review or fallback PR comment. Search the full publication identity on the
  exact PR/head before publication and after an ambiguous response before
  retrying.
- Pass: submit approval when the authenticated identity may do so; otherwise post
  one top-level PR comment recording the passed Symphony review.
- Changes required: submit request-changes when permitted; otherwise post one
  consolidated top-level PR comment.
- Human decision: post a non-approving review/comment, record prior/resume phase,
  and apply `maestro:scope-change` for a strategic contract/DAG revision or
  `maestro:needs-human` for a bounded decision.
- Inconclusive: a durable `inconclusive` publication requires every verdict-relevant missing item in a stable acceptance manifest.
  Every item has a criterion/evidence-requirement key, finite source kind,
  approved locator template, exact runtime binding entry, and
  `missing`/`unavailable` state whose binding can later change. A confirmed durable `inconclusive` publication
  for the complete context appends `review-recorded`. Any unkeyed or free-form missing evidence is unpublished and appends `action-failed`; bounded recovery applies and no publication identity is consumed.

For changes required, add one Linear issue comment after the canonical GitHub
record:

```markdown
@Cursor Please address the Symphony review for PR #482.

Reviewed head: 7db3f18
Review: https://github.example/review-link

Required outcomes:
1. Preserve the consumed API contract documented in the issue.
2. Add evidence for the backward-compatibility acceptance criterion.
```

Embed
`Maestro-Cursor-Follow-Up-Identity: <complete linear publication identity>`
in this comment. Search the implementation issue for the marker before create and
after an ambiguous response. The comment links exactly one confirmed canonical GitHub record; an unresolved or duplicate GitHub record suppresses the Linear
follow-up.

The Linear follow-up publication identity repeats the complete review context, exact review input revision, Review PR action identity, and `linear-cursor-follow-up` channel.

Use the actual PR, SHA, review link, and consolidated outcomes. Do not mention
`@Cursor` for a pure human decision unless Cursor has a concrete implementation
action.
