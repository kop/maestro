#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")/.."
source tests/lib/assertions.sh
source tests/lib/failure-injection-reducer.sh

fixture=tests/fixtures/failure-injection-plans.tsv
assert_file "$fixture"
expected_header=$'case_id\tstate\tcategory\trequired_reads\tallowed_mutations\tjournal_events\tsuppressed_actions\tnext_state_verdict'
[[ "$(head -n 1 "$fixture")" == "$expected_header" ]] ||
  fail "unexpected failure-injection fixture header"

expected_plan() {
  local category=$1 reads=$2 mutations=$3 events=$4 suppressed=$5 next=$6
  printf 'category\t%s\n' "$category"
  printf 'required_reads\t%s\n' "$reads"
  printf 'allowed_mutations\t%s\n' "$mutations"
  printf 'journal_events\t%s\n' "$events"
  printf 'suppressed_actions\t%s\n' "$suppressed"
  printf 'next_state_verdict\t%s\n' "$next"
}

reverse_predicates() {
  tr ';' '\n' <<< "$1" | awk '{ row[NR] = $0 } END {
    for (i = NR; i > 0; i--) {
      printf "%s%s", row[i], i == 1 ? ORS : ";"
    }
  }'
}

assert_reduction() {
  local case_id=$1 state=$2 category=$3 reads=$4 mutations=$5 events=$6
  local suppressed=$7 next=$8 variant=${9:-original}
  local expected actual
  expected=$(expected_plan \
    "$category" "$reads" "$mutations" "$events" "$suppressed" "$next")
  actual=$(reduce_controller_state "$state")
  [[ "$actual" == "$expected" ]] ||
    fail "$case_id ($variant) reducer output differs"$'\n'"$actual"
}

reduce_fixture_rows() {
  local case_id state plan
  while IFS=$'\t' read -r case_id state _; do
    [[ "$case_id" == "case_id" ]] && continue
    plan=$(reduce_controller_state "$state" | tr '\n' '|')
    printf '%s\t%s\n' "$state" "$plan"
  done
}

rows=0
while IFS=$'\t' read -r case_id state category reads mutations events suppressed next; do
  [[ "$case_id" == "case_id" ]] && continue
  [[ -n "$case_id" && -n "$state" && -n "$next" ]] ||
    fail "malformed failure-injection fixture row"

  assert_reduction "$case_id" "$state" "$category" "$reads" "$mutations" \
    "$events" "$suppressed" "$next"

  reordered=$(reverse_predicates "$state")
  assert_reduction "$case_id" "$reordered" "$category" "$reads" "$mutations" \
    "$events" "$suppressed" "$next" reordered

  first_predicate=${state%%;*}
  duplicated="$reordered;$first_predicate"
  assert_reduction "$case_id" "$duplicated" "$category" "$reads" "$mutations" \
    "$events" "$suppressed" "$next" duplicated

  rows=$((rows + 1))
done < "$fixture"

[[ "$rows" -eq 103 ]] || fail "expected 103 failure-injection rows, got $rows"

# Fixture order and duplicate rows cannot affect the state-derived decision set.
baseline=$(reduce_fixture_rows < "$fixture" | sort -u)
reordered=$({
  head -n 1 "$fixture"
  tail -n +2 "$fixture" | sort -r
} | reduce_fixture_rows | sort -u)
duplicated=$({
  cat "$fixture"
  sed -n '2p' "$fixture"
} | reduce_fixture_rows | sort -u)
[[ "$baseline" == "$reordered" ]] ||
  fail "reordered fixture rows changed decisions"
[[ "$baseline" == "$duplicated" ]] ||
  fail "duplicate fixture rows changed decisions"

# Negative oracle checks: unsafe/wrong mutation expectations must not compare
# equal to the reducer's state-derived branch.
actual_marker=$(reduce_controller_state \
  'surface=cleanup;containment=proved;marker=mismatch')
wrong_marker=$(expected_plan cleanup-failed canonical-path,ownership-marker \
  filesystem-delete cleanup-failed git-worktree-remove cleanup-complete)
[[ "$actual_marker" != "$wrong_marker" ]] ||
  fail "marker mismatch incorrectly permits deletion"

actual_unapproved=$(reduce_controller_state \
  'surface=dag;proposal=recorded;approval=absent')
wrong_unapproved=$(expected_plan none dag-proposed,dag-approved \
  linear-create-missing-node dag-materialized none dag-materialized)
[[ "$actual_unapproved" != "$wrong_unapproved" ]] ||
  fail "unapproved DAG incorrectly permits materialization"

premature_edge=$(reduce_controller_state \
  'surface=dag;approval=recorded;node=missing')
premature_edge_mutations=$(awk -F'\t' \
  '$1 == "allowed_mutations" { print $2 }' <<< "$premature_edge")
[[ "$premature_edge_mutations" == "linear-create-missing-node" ]] ||
  fail "missing DAG node permitted premature edge creation"

premature_materialization=$(reduce_controller_state \
  'surface=dag;approval=recorded;nodes=bound;edge=confirmed;edge_binding=missing')
[[ "$premature_materialization" != *$'journal_events\tdag-materialized'* ]] ||
  fail "missing edge binding permitted premature materialization"

unsafe_attached=$(reduce_controller_state \
  'surface=cleanup;containment=proved;marker=match;attachment=attached-worktree;git_metadata=match;contents=expected')
[[ "$unsafe_attached" == *$'category\tcleanup-failed'* &&
   "$unsafe_attached" == *$'allowed_mutations\tnone'* ]] ||
  fail "attached cleanup without action identity was not suppressed"

recorded_exhaustion_unchanged=$(reduce_controller_state \
  'surface=controller;failure=observation-incomplete;attempts=exhausted;state_changed=false;exhaustion_event=recorded;action_identity=stable')
expected_exhaustion_unchanged=$(expected_plan observation-incomplete \
  action-journal,relevant-state none none further-mutation needs-human)
[[ "$recorded_exhaustion_unchanged" == "$expected_exhaustion_unchanged" ]] ||
  fail "unchanged exhausted state did not remain suppressed"

unconfirmed_exhaustion_change=$(reduce_controller_state \
  'surface=controller;failure=observation-incomplete;attempts=exhausted;state_changed=true;state_change_observation=unconfirmed;exhaustion_event=recorded;action_identity=stable')
[[ "$unconfirmed_exhaustion_change" == *$'allowed_mutations\tnone'* &&
   "$unconfirmed_exhaustion_change" == *$'next_state_verdict\tneeds-human'* ]] ||
  fail "unconfirmed state change escaped retry exhaustion"

for unsafe_timeout_state in \
  'surface=validation;command=timed-out;owned_path=known;cleanup_state=missing' \
  'surface=validation;command=timed-out;owned_path=known;containment=proved;marker=mismatch;attachment=attached-worktree;git_metadata=match;contents=expected' \
  'surface=validation;command=timed-out;owned_path=known;containment=proved;marker=match;action_identity=match;attachment=ambiguous;contents=expected'
do
  unsafe_timeout=$(reduce_controller_state "$unsafe_timeout_state")
  [[ "$unsafe_timeout" == *$'category\tvalidation-timeout'* &&
     "$unsafe_timeout" == *$'allowed_mutations\tterminate-command'* &&
     "$unsafe_timeout" == *$'journal_events\taction-failed,cleanup-failed'* &&
     "$unsafe_timeout" == *$'suppressed_actions\treview-publication,filesystem-delete,git-worktree-remove'* &&
     "$unsafe_timeout" == *$'next_state_verdict\tinconclusive-cleanup-debt-retain-exact-path'* ]] ||
    fail "unsafe timeout authorized cleanup or lost cleanup debt"
done

unexpected_contents=$(reduce_controller_state \
  'surface=cleanup;containment=proved;marker=match;action_identity=match;attachment=attached-worktree;git_metadata=match;contents=unexpected')
[[ "$unexpected_contents" == *$'required_reads\tcanonical-path,ownership-marker,attachment-state,repository-metadata,directory-contents'* &&
   "$unexpected_contents" == *$'allowed_mutations\tnone'* ]] ||
  fail "unexpected attached contents did not suppress deletion"

timeout_deletion_rows=0
while IFS=$'\t' read -r case_id _ _ _ mutations _; do
  [[ "$case_id" == validation_timeout_* ]] || continue
  if [[ "$mutations" == *filesystem-remove* ||
        "$mutations" == *git-worktree-remove* ]]; then
    case "$case_id" in
      validation_timeout_attached_owned|validation_timeout_unattached_owned|\
      validation_timeout_exhausted_*_attached|\
      validation_timeout_exhausted_*_unattached)
        timeout_deletion_rows=$((timeout_deletion_rows + 1))
        ;;
      *)
        fail "$case_id unexpectedly authorizes timeout cleanup"
        ;;
    esac
  fi
done < "$fixture"
[[ "$timeout_deletion_rows" -eq 10 ]] ||
  fail "expected only ten ownership-proven timeout cleanup plans"

combined_timeout=$(reduce_controller_state \
  'surface=validation;command=timed-out;owned_path=known;containment=proved;marker=match;action_identity=match;attachment=attached-worktree;git_metadata=match;contents=expected;attempts=exhausted;state_changed=false;exhaustion_event=absent;entity_uuid=issue-validation-attached;retry_action_identity=validation-action-attached;failure_category=validation-timeout;prior_phase=entity-executing;pause_resume_phase=entity-executing;pause_identity=retry-pause-v1:c34493f991967f277e52a49218b9f70d9317932a4b6e3428de48e26eea3efb3e')
[[ "$combined_timeout" == *$'category\tvalidation-timeout'* &&
   "$combined_timeout" == *$'allowed_mutations\tterminate-command,git-worktree-remove,filesystem-remove-transients,apply-needs-human'* &&
   "$combined_timeout" == *$'journal_events\taction-failed,retry-exhausted'* &&
   "$combined_timeout" == *$'suppressed_actions\treview-publication,further-mutation'* &&
   "$combined_timeout" == *$'next_state_verdict\tinconclusive-cleanup-complete-needs-human'* ]] ||
  fail "generic exhaustion took precedence over validation timeout"

combined_changed_timeout=$(reduce_controller_state \
  'surface=validation;command=timed-out;owned_path=known;containment=proved;marker=match;action_identity=match;attachment=reserved-unattached;git_metadata=absent;checkout=absent;contents=expected;attempts=exhausted;state_changed=true;state_change_observation=confirmed;exhaustion_event=recorded;retry_identity=stable;pause_identity=retry-pause-direct;resolution_event=recorded;resolution_pause_identity=retry-pause-direct;resolution_match=exact;disposition=resume-after-confirmed-external-state-change;resume_phase=confirmed')
[[ "$combined_changed_timeout" == *$'allowed_mutations\tterminate-command,filesystem-remove-reservation,resume-prior-phase,bounded-retry'* &&
   "$combined_changed_timeout" != *$'allowed_mutations\tbounded-retry'* ]] ||
  fail "state-change recovery canceled timeout termination/cleanup"

combined_changed_timeout_unresolved=$(reduce_controller_state \
  'surface=validation;command=timed-out;owned_path=known;containment=proved;marker=match;action_identity=match;attachment=reserved-unattached;git_metadata=absent;checkout=absent;contents=expected;attempts=exhausted;state_changed=true;state_change_observation=confirmed;exhaustion_event=recorded;retry_identity=stable;pause_identity=retry-pause-direct-unresolved;resolution_event=absent')
[[ "$combined_changed_timeout_unresolved" == *$'allowed_mutations\tterminate-command,filesystem-remove-reservation'* &&
   "$combined_changed_timeout_unresolved" == *$'suppressed_actions\treview-publication,git-worktree-remove,resume-prior-phase,bounded-retry,remove-needs-human,duplicate-retry-exhausted,unbounded-retry'* &&
   "$combined_changed_timeout_unresolved" == *$'next_state_verdict\tinconclusive-cleanup-complete-needs-human-await-matching-resolution'* ]] ||
  fail "state change without exact durable resolution escaped timeout pause"

first_reconcile=$(reduce_controller_state \
  'surface=reconciler;merge=observed;verdict=inconclusive')
later_reconcile=$(reduce_controller_state \
  'surface=reconciler;merge=observed;prior_reconcile=inconclusive;merge_reconciled=absent;verdict=complete')
repeated_reconcile=$(reduce_controller_state \
  'surface=reconciler;merge=observed;merge_reconciled=recorded;verdict=complete')
[[ "$first_reconcile" == *$'journal_events\tmerge-observed,action-failed'* &&
   "$later_reconcile" == *$'journal_events\tmerge-reconciled'* &&
   "$later_reconcile" == *$'suppressed_actions\tduplicate-merge-observed'* &&
   "$repeated_reconcile" == *$'journal_events\tnone'* &&
   "$repeated_reconcile" == *duplicate-merge-reconciled* ]] ||
  fail "merge-observed/inconclusive recovery did not reconcile exactly once"

assert_not_contains tests/lib/failure-injection-reducer.sh 'case_id'
assert_contains tests/REAL_INTEGRATION.md \
  'disposable real integration.*runtime validation gate'

pass "state-predicate failure-injection reducer"
