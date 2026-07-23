# Symphony Review Protocol

Review the implementation at one exact PR revision in the context of its issue,
approved DAG, dependency contracts, downstream work, and Symphony outcome.

## Required review identity

Do not begin until the request identifies:

```text
Symphony control issue UUID
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
applicable matching decision-resolution identities and governing revisions
review input revision and confirmed review-requested event identity
review action identity
```

Missing identity makes the review `inconclusive`; it never permits guessing.

Derive the review input revision exactly as the core protocol specifies. Use the
fully qualified roster agent identifier as a lens stable key. Derive every
validator stable key from its protocol kind and normalized command/inspection
descriptor, and derive each present `review-evidence-v1:` revision from the
complete ordered agent/selector or command/configuration/capability source set.
The manifest contains every required lens and validator with an explicit
`present`, `missing`, or `unavailable` state and the matching derived evidence
revision or the literal `missing`/`unavailable` sentinel. Free-form keys,
hand-authored revisions, and omitted source revisions are invalid. Include only
confirmed decision-resolutions that exactly match the pause identity and
governing revision. The review input revision is part of the Review PR action identity:
GitHub PR native ID, head SHA, contract revision, DAG revision, review-policy
revision, and exact review input revision. Do not begin review until the matching
canonical `review-requested` record is confirmed.

## Owned worktree protocol

When any reviewer must execute commands:

1. Locate or fetch the repository without changing a user branch.
2. Create a unique directory beneath a dedicated Maestro temporary review root.
3. Derive its name from sanitized native IDs, never issue or PR titles.
4. Write an adjacent ownership marker containing Symphony UUID, repository,
   PR native ID, head SHA, and review action identity. Add the reservation to
   the cleanup ledger with attachment state `reserved-unattached`.
5. Resolve canonical paths and verify component-level containment under the root.
6. Add a detached Git worktree at the exact PR head SHA, then atomically update
   its cleanup-ledger attachment state to `attached-worktree`.
7. Run all commands with that worktree as the exact working directory.
8. Apply an explicit timeout to every command.
9. Compare tracked and staged changes before and after validation.
10. Re-read the remote PR head before publishing.
11. Clean every ledger entry through its attachment-state branch; use Git removal
    only for `attached-worktree`.

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

```markdown
## Verdict
pass | changes-required | human-decision | inconclusive

## Reviewed identity
PR:
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

Before publication, verify the remote head still equals the reviewed exact PR head
SHA. If it changed, publish nothing, classify `review-stale-head`, clean up, and
review the new SHA on a later pass.

The attachment-state cleanup branch applies on success, failure, timeout, stale head, reviewer error, and publication failure.

## Publication and Cursor follow-up

- The GitHub publication identity includes the Review PR action identity, exact PR/head channel, and exact review input revision. Embed
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
- Inconclusive: post only when the missing evidence itself requires action. A
  confirmed publication for the exact head and review input revision appends
  `review-recorded`; when publication is not warranted or is not confirmed,
  append `action-failed` and retry within policy.

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
`Maestro-Cursor-Follow-Up-Identity: <review action identity + linear-cursor-follow-up channel + review input revision>`
in this comment. Search the implementation issue for the marker before create and
after an ambiguous response. The comment links exactly one confirmed canonical GitHub record; an unresolved or duplicate GitHub record suppresses the Linear
follow-up.

The Linear follow-up publication identity includes the Review PR action identity, `linear-cursor-follow-up` channel, implementation issue UUID, and exact review input revision.

Use the actual PR, SHA, review link, and consolidated outcomes. Do not mention
`@Cursor` for a pure human decision unless Cursor has a concrete implementation
action.
