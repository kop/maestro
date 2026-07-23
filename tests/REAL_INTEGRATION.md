# Maestro Real Integration Validation

Run this profile only in a disposable Linear project/team and disposable GitHub
repository whose branch protections and Cursor integration match production
behavior. Never use active production issues merely to test the plugin.

Report every unavailable capability as `SKIPPED: reason`; never count it as passed.

## Preconditions

- Maestro is loaded with `claude --plugin-dir .`.
- The test Linear scope permits issue, label, relation, comment, and Cursor
  delegation operations.
- The test repository permits PR comments and exposes the authenticated identity's
  review limitations.
- Cursor is configured for the repository through the Linear `repo` label group.
- A harmless fixture change can be delegated, reviewed, and merged.

## Scenario

1. Invoke `/maestro:symphony-start` for a two-issue fixture goal.
2. Confirm capability preflight reports actual approval/request-change capability.
3. Confirm the control issue, labels, issue contracts, `repo` routing, and native
   blocker relation are correct.
4. Reject the first proposed DAG revision, revise one acceptance criterion, then
   approve the new revision. Confirm the rejected revision remains in the journal.
5. Run one reconciliation pass and confirm only the unblocked issue is delegated
   to Cursor.
6. Run the same pass again and confirm no duplicate issue, delegation, or journal
   event appears.
7. Let Cursor open a PR. Confirm Maestro reviews the exact head SHA, publishes an
   allowed formal review or top-level fallback comment, and deletes every owned
   worktree.
8. Introduce one safe review finding. Confirm the GitHub record is canonical and
   the Linear follow-up mentions `@Cursor`, exact SHA, link, and required outcome.
9. Update the PR head. Confirm the old passing identity does not apply to the new
   revision.
10. Satisfy repository gates and merge through the repository's normal mechanism.
11. Confirm merge reconciliation writes actual implementation/deviations, updates
    an undispatched downstream assumption, records the merge SHA, and only then
    unlocks the blocked issue.
12. Manually change one generated label and one acceptance criterion. Confirm the
    next pass repairs the label, pauses semantic drift, and does not fight the
    manual contract edit.
13. Start a fresh Claude session and run `/maestro:symphony-status`. Confirm it
    reconstructs the same state from Linear, GitHub, and journal evidence.

## Evidence to retain

- Linear control issue and managed issue links.
- DAG approval and journal comment links.
- Cursor delegation and PR link.
- Exact review head SHA and GitHub record.
- Owned-worktree cleanup result.
- Merge SHA and post-merge issue updates.
- Fresh-session status output.
