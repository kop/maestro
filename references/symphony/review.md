# Symphony Review Protocol

Review the implementation at one exact PR revision in the context of its issue,
approved DAG, dependency contracts, downstream work, and Symphony outcome.

## Required review identity

Do not begin until the request identifies:

```text
Symphony control issue UUID
implementation issue UUID and human-readable key
approved contract revision
review-policy revision
repository owner/name and local source or clone URL
GitHub PR native ID and number
base SHA
exact PR head SHA
applicable risk labels
issue validation commands
review action identity
```

Missing identity makes the review `inconclusive`; it never permits guessing.

## Owned worktree protocol

When any reviewer must execute commands:

1. Locate or fetch the repository without changing a user branch.
2. Create a unique directory beneath a dedicated Maestro temporary review root.
3. Derive its name from sanitized native IDs, never issue or PR titles.
4. Write an adjacent ownership marker containing Symphony UUID, repository,
   PR native ID, head SHA, and review action identity.
5. Resolve canonical paths and verify component-level containment under the root.
6. Add a detached Git worktree at the exact PR head SHA.
7. Run all commands with that worktree as the exact working directory.
8. Apply an explicit timeout to every command.
9. Compare tracked and staged changes before and after validation.
10. Re-read the remote PR head before publishing.
11. Remove the expected worktree through Git, then delete only the owned review
    directory and transient artifacts.

Cleanup requires both a matching marker and Git metadata matching the expected
repository/path. Never delete unmarked, mismatched, or user-created worktrees.
Reserved setup directories may be removed only when the marker matches and no
repository or unexpected file exists.

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
Review-policy revision:

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

## Publication and Cursor follow-up

- Pass: submit approval when the authenticated identity may do so; otherwise post
  one top-level PR comment recording the passed Symphony review.
- Changes required: submit request-changes when permitted; otherwise post one
  consolidated top-level PR comment.
- Human decision: post a non-approving review/comment, record prior/resume phase,
  and apply `maestro:scope-change` for a strategic contract/DAG revision or
  `maestro:needs-human` for a bounded decision.
- Inconclusive: post only when the missing evidence itself requires action;
  otherwise append `action-failed` and retry within policy.

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

Use the actual PR, SHA, review link, and consolidated outcomes. Do not mention
`@Cursor` for a pure human decision unless Cursor has a concrete implementation
action.
