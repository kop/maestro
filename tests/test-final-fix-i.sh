#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")/.."
source tests/lib/assertions.sh
source tests/lib/failure-injection-reducer.sh

reducer=tests/lib/failure-injection-reducer.sh
core=references/symphony/core.md
reconciliation=references/symphony/reconciliation.md
reconcile_skill=skills/symphony-reconcile/SKILL.md
review_skill=skills/symphony-review/SKILL.md
matrix=tests/fixtures/state-machine-matrix.tsv
design=docs/superpowers/specs/2026-07-23-maestro-symphony-control-plane-design.md
plan=docs/superpowers/plans/2026-07-23-maestro-symphony-control-plane.md

weak_dispatch=$(reduce_controller_state \
  'surface=review-preparation;worktree=verified;closure=derived;request_event=recorded;dispatch=confirmed;ownership=reconciler')
[[ "$weak_dispatch" != *transfer-review-worktree-ownership* ]] ||
  fail "legacy review dispatch bypass remained executable"

for weak_review_state in \
  'surface=review;head=same;prior_revision=r1;input_revision=r2;prior_result=inconclusive;request_event=absent;current_result=absent' \
  'surface=review;head=same;prior_revision=r1;input_revision=r2;prior_result=inconclusive;request_event=recorded;current_result=absent' \
  'surface=review;head=same;prior_revision=r1;input_revision=r2;prior_result=pass;request_event=recorded;current_result=absent' \
  'surface=review;head=same;prior_revision=a1;input_revision=a2;prior_result=inconclusive;acceptance_manifest=changed-keyed;request_event=recorded;current_result=absent'
do
  weak_review=$(reduce_controller_state "$weak_review_state")
  [[ "$weak_review" != *$'allowed_mutations\tdispatch-review'* &&
     "$weak_review" != *$'journal_events\treview-requested'* ]] ||
    fail "legacy review surface bypassed authoritative preparation"
done

full_dispatch=$(reduce_controller_state \
  'surface=review-preparation;preparation=current;reservation=current-confirmed;worktree=attached;worktree_verification=exact;closure=derived-current;action_binding=confirmed-one-to-one;journal_binding=match;marker=bound-match;request_event=recorded;dispatch=absent;ownership=reconciler')
[[ "$full_dispatch" == *$'allowed_mutations\tdispatch-review'* ]] ||
  fail "full authoritative preparation could not dispatch review"

full_request=$(reduce_controller_state \
  'surface=review-preparation;preparation=current;reservation=current-confirmed;worktree=attached;worktree_verification=exact;closure=derived-current;action_binding=confirmed-one-to-one;journal_binding=match;marker=bound-match;request_event=absent;ownership=reconciler')
[[ "$full_request" == *$'journal_events\treview-requested'* &&
   "$full_request" != *$'allowed_mutations\tdispatch-review'* ]] ||
  fail "review request did not pass through authoritative preparation"

full_transfer=$(reduce_controller_state \
  'surface=review-preparation;preparation=current;reservation=current-confirmed;worktree=attached;worktree_verification=exact;closure=derived-current;action_binding=confirmed-one-to-one;journal_binding=match;marker=bound-match;request_event=recorded;dispatch=confirmed;ownership=reconciler')
[[ "$full_transfer" == *$'allowed_mutations\ttransfer-review-worktree-ownership'* ]] ||
  fail "full authoritative dispatch could not transfer cleanup ownership"

second_action=$(reduce_controller_state \
  'surface=review-preparation;preparation=current;reservation=current-confirmed;worktree=attached;worktree_verification=exact;closure=derived-current;action_binding=conflicting-second-action;journal_binding=conflict;marker=bound-match;request_event=absent;ownership=reconciler')
[[ "$second_action" != *update-marker* &&
   "$second_action" != *dispatch-review* ]] ||
  fail "one reservation authorized a second review action"

prebinding_cleanup=$(reduce_controller_state \
  'surface=cleanup;binding=absent;reservation=current-confirmed;ledger=reservation-match;containment=proved;marker=reservation-match;attachment=reserved-unattached;git_metadata=absent;checkout=absent;contents=expected')
[[ "$prebinding_cleanup" == *$'allowed_mutations\tfilesystem-remove-reservation'* ]] ||
  fail "reservation-only cleanup was not executable before binding"

prebinding_attached_cleanup=$(reduce_controller_state \
  'surface=cleanup;binding=absent;reservation=current-confirmed;ledger=reservation-match;containment=proved;marker=reservation-match;attachment=attached-worktree;git_metadata=match;contents=expected')
[[ "$prebinding_attached_cleanup" == *$'allowed_mutations\tgit-worktree-remove,filesystem-remove-transients'* ]] ||
  fail "reservation-only attached-worktree cleanup was not executable"

postbinding_cleanup=$(reduce_controller_state \
  'surface=cleanup;binding=confirmed-one-to-one;reservation=current-confirmed;bound_action=current-match;ledger=reservation-action-match;containment=proved;marker=bound-match;attachment=attached-worktree;git_metadata=match;contents=expected')
[[ "$postbinding_cleanup" == *$'allowed_mutations\tgit-worktree-remove,filesystem-remove-transients'* ]] ||
  fail "post-binding cleanup did not require reservation plus action"

for mismatch in \
  'reservation=historical;ledger=reservation-match;marker=reservation-match' \
  'reservation=current-confirmed;ledger=mismatch;marker=reservation-match' \
  'reservation=current-confirmed;ledger=reservation-match;marker=mismatch' \
  'reservation=current-confirmed;ledger=reservation-match;marker=reservation-match;containment=failed' \
  'reservation=current-confirmed;ledger=reservation-match;marker=reservation-match;attachment=ambiguous'
do
  output=$(reduce_controller_state \
    "surface=cleanup;binding=absent;$mismatch;containment=proved;attachment=reserved-unattached;git_metadata=absent;checkout=absent;contents=expected")
  [[ "$output" == *$'allowed_mutations\tnone'* ]] ||
    fail "reservation-only cleanup mismatch authorized deletion: $mismatch"
done

unconfirmed_marker=$(reduce_controller_state \
  'surface=cleanup;binding=absent;reservation=current-confirmed;ledger=reservation-match;containment=proved;marker=bound-action;attachment=attached-worktree;git_metadata=match;contents=expected')
[[ "$unconfirmed_marker" == *$'allowed_mutations\tnone'* ]] ||
  fail "marker claiming unconfirmed action authorized cleanup"

weak_reconcile=$(reduce_controller_state \
  'surface=reconciler;merge=observed;merge_reconciled=absent;verdict=complete')
[[ "$weak_reconcile" != *merge-reconciled* &&
   "$weak_reconcile" != *complete-implementation* ]] ||
  fail "legacy merge reconciliation bypass remained executable"

reconciled=$(reduce_controller_state \
  'surface=merge-reconciliation;merge=observed;binding_manifest=exact-current;manifest_recompute=exact-current-match;reconciler_result=validated-same-identity;reconciler_echo=complete-exact;conclusion_mapping=exact;reconciliation_identity=current-match;acceptance=satisfied;verdict=complete;merge_reconciled=absent')
[[ "$reconciled" == *$'allowed_mutations\tpersist-merge-reconciliation'* &&
   "$reconciled" == *$'journal_events\tmerge-reconciled'* &&
   "$reconciled" != *complete-implementation* ]] ||
  fail "authoritative merge reconciliation was not isolated from completion"

for invalid_binding in unresolved ambiguous missing unavailable omitted stale mismatched; do
  output=$(reduce_controller_state \
    "surface=merge-reconciliation;merge=observed;binding_manifest=$invalid_binding;reconciler_result=validated-same-identity;acceptance=satisfied;verdict=complete;merge_reconciled=absent")
  [[ "$output" != *$'journal_events\tmerge-reconciled'* &&
     "$output" != *complete-implementation* ]] ||
    fail "$invalid_binding staged binding authorized merge reconciliation"
done

for invalid_reconciliation in \
  'manifest_recompute=mismatch;reconciler_echo=complete-exact;conclusion_mapping=exact;reconciliation_identity=current-match' \
  'manifest_recompute=exact-current-match;reconciler_echo=omitted;conclusion_mapping=exact;reconciliation_identity=current-match' \
  'manifest_recompute=exact-current-match;reconciler_echo=complete-exact;conclusion_mapping=mismatched;reconciliation_identity=current-match' \
  'manifest_recompute=exact-current-match;reconciler_echo=complete-exact;conclusion_mapping=exact;reconciliation_identity=historical'
do
  output=$(reduce_controller_state \
    "surface=merge-reconciliation;merge=observed;binding_manifest=exact-current;$invalid_reconciliation;reconciler_result=validated-same-identity;acceptance=satisfied;verdict=complete;merge_reconciled=absent")
  [[ "$output" != *$'journal_events\tmerge-reconciled'* ]] ||
    fail "invalid reconciliation manifest/result authorized merge reconciliation: $invalid_reconciliation"
done

historical_reconciliation=$(reduce_controller_state \
  'surface=merge-reconciliation;merge=observed;binding_manifest=historical;reconciliation_identity=historical;merge_reconciled=recorded')
[[ "$historical_reconciliation" != *$'next_state_verdict\tmerge-reconciled-confirmed'* ]] ||
  fail "historical merge reconciliation was accepted as current"

completion=$(reduce_controller_state \
  'surface=implementation-completion;merge_reconciled=confirmed;completion_event=absent')
[[ "$completion" == *$'allowed_mutations\tcomplete-implementation,update-downstream'* &&
   "$completion" == *$'journal_events\timplementation-completed'* ]] ||
  fail "confirmed merge reconciliation did not authorize separate completion"

premature_completion=$(reduce_controller_state \
  'surface=implementation-completion;merge_reconciled=absent;completion_event=absent')
[[ "$premature_completion" != *complete-implementation* ]] ||
  fail "implementation completed before merge-reconciled confirmation"

closeout=$(reduce_controller_state \
  'surface=symphony-closeout;integration=confirmed;required_work=complete-or-approved-cancelled;merges=reconciled;active_work=absent;blockers=absent;cleanup_debt=absent;followups=confirmed;closeout_event=absent')
[[ "$closeout" == *$'allowed_mutations\tfinalize-control-outcome,apply-control-complete'* &&
   "$closeout" == *$'journal_events\tsymphony-completed'* &&
   "$closeout" != *merge-reconciled* ]] ||
  fail "separate Symphony closeout transition is incomplete"

duplicate_closeout=$(reduce_controller_state \
  'surface=symphony-closeout;integration=confirmed;required_work=complete-or-approved-cancelled;merges=reconciled;active_work=absent;blockers=absent;cleanup_debt=absent;followups=confirmed;closeout_event=recorded')
[[ "$duplicate_closeout" == *$'journal_events\tnone'* &&
   "$duplicate_closeout" == *duplicate-symphony-completed* ]] ||
  fail "Symphony closeout was not exactly once"

before_github_underivable=$(reduce_controller_state \
  'surface=review-publication;interval=before-github;review_requested=confirmed;reviewed_input=r1;fresh_input=underivable;fresh_derivation=failed;worktree=owned')
[[ "$before_github_underivable" == *$'category\treview-input-underivable'* &&
   "$before_github_underivable" == *$'journal_events\taction-failed'* &&
   "$before_github_underivable" != *$'next_state_verdict\tnew-review-input-eligible'* ]] ||
  fail "pre-GitHub underivable input claimed a new eligible revision"

pre_request_context_stale=$(reduce_controller_state \
  'surface=github;publication=pending;preparation=stale;review_requested=absent')
[[ "$pre_request_context_stale" == *$'category\treview-stale-head'* &&
   "$pre_request_context_stale" == *$'journal_events\treview-stale-head'* &&
   "$pre_request_context_stale" != *review-input-stale* ]] ||
  fail "pre-request context/preparation change was not review-stale-head"

after_github_underivable=$(reduce_controller_state \
  'surface=review-publication;interval=after-github;github_record=confirmed;review_requested=confirmed;reviewed_input=r1;fresh_input=underivable;fresh_derivation=failed;worktree=owned')
[[ "$after_github_underivable" == *$'category\treview-input-stale'* &&
   "$after_github_underivable" == *github-record-historical* &&
   "$after_github_underivable" != *$'next_state_verdict\tnew-review-input-eligible'* ]] ||
  fail "post-GitHub underivable input claimed a new eligible revision"

assert_not_contains "$reducer" 'surface\]:-\}" == "reconciler"'
assert_not_contains "$reducer" 'close-symphony'
assert_contains "$core" 'review-preparation-v1'
assert_contains "$core" 'one reservation.*one.*review action'
assert_contains "$reconciliation" \
  'canonical.*reconciliation.*binding manifest'
assert_contains "$reconcile_skill" \
  'recompute.*binding manifest.*before.*accept'
assert_contains "$matrix" 'symphony-completed'

for authority in "$design" "$plan"; do
  assert_contains "$authority" 'review-preparation-v1'
  assert_contains "$authority" 'reservation-only'
  assert_contains "$authority" 'authoritative.*runtime context'
  assert_contains "$authority" 'reconciliation.*both'
  assert_contains "$authority" 'before GitHub'
  assert_contains "$authority" 'before Linear'
  assert_not_contains "$authority" \
    'marker containing.*review action identity'
  assert_not_contains "$authority" \
    'ownership marker.*review action identity'
done

assert_contains "$review_skill" 'review-input-underivable'

pass "Final Fix I authoritative binding and single controller path"
