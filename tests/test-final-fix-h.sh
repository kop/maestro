#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")/.."
source tests/lib/assertions.sh

core=references/symphony/core.md
linear=references/symphony/linear.md
review=references/symphony/review.md
reconcile=skills/symphony-reconcile/SKILL.md
review_skill=skills/symphony-review/SKILL.md
status_skill=skills/symphony-status/SKILL.md
failure_fixture=tests/fixtures/failure-injection-plans.tsv
matrix=tests/fixtures/state-machine-matrix.tsv

assert_contains "$core" 'maestro-review-worktree-reservation-v1'
assert_contains "$core" 'maestro-review-worktree-action-binding-v1'
assert_contains "$core" \
  'reservation.*Symphony UUID.*implementation issue UUID.*repository.*PR native ID.*base SHA.*head SHA.*contract revision.*DAG revision.*review-policy revision'
assert_contains "$core" \
  'confirm this durable journal binding before changing the local marker'
assert_contains "$review" \
  'guarded cleanup before an action identity'
assert_contains "$reconcile" \
  'reservation confirmed.*no worktree'
assert_contains "$reconcile" \
  'action binding confirmed.*marker not updated'
assert_contains "$reconcile" \
  'marker.*binding absent.*fail closed'

for case_id in \
  review_reservation_no_worktree \
  review_reservation_attached_no_closure \
  review_reservation_closure_no_binding \
  review_reservation_binding_marker_pending \
  review_reservation_marker_unjournaled \
  review_reservation_dispatch_absent \
  review_reservation_dispatch_confirmed
do
  assert_contains "$failure_fixture" "^${case_id}[[:space:]]"
done

assert_contains "$linear" 'evidence_stage.*review.*reconciliation.*both'
assert_contains "$linear" \
  'provider_record_role.*static.*plan-time'
assert_not_contains "$linear" '\$\{provider_record_role\}'
assert_contains "$core" \
  'resolution_outcome.*separately'
assert_contains "$core" \
  'exact.*unresolved.*ambiguous'
assert_contains "$review" \
  'evidence_stage.*review.*both'
assert_contains "$review" \
  'reconciliation-only unresolved binding'
assert_contains "$reconcile" \
  'resolve only.*reconciliation.*both'
assert_contains "$reconcile" \
  'post-merge evidence gating'
assert_contains "$reconcile" \
  'completion.*closeout'
assert_contains review-source-requirements-v1.json \
  'evidence-source-schema-v1.json'
assert_contains review-source-requirements-v1.json \
  'scripts/evidence-source-schema.py'

assert_contains "$review_skill" \
  'pre-review.*fully clean'
assert_contains "$review_skill" \
  'pre-publication.*fail'
assert_contains "$review_skill" \
  'untracked validation artifact'
assert_contains "$review_skill" \
  'fail.*tracked.*symlink.*submodule'
assert_contains "$review_skill" \
  'or shadow'
assert_contains "$review_skill" \
  'declared.*source path'
assert_contains "$review_skill" 'Do not run.*git clean'

assert_contains "$core" \
  'review-stale-head.*before.*review-requested'
assert_contains "$core" \
  'review-input-stale.*after.*review-requested'
assert_contains "$matrix" \
  'review-stale-head.*review-requested-is-absent'
assert_contains "$matrix" \
  $'^event\treview-stale-head\tskills/symphony-reconcile/SKILL.md'
assert_contains "$matrix" \
  'review-input-stale.*review-requested-is-confirmed'

for interval in before_github after_github; do
  for difference in acceptance base relink source capability decision head; do
    assert_contains "$failure_fixture" \
      "^review_${interval}_stale_${difference}[[:space:]]"
  done
done
assert_contains "$failure_fixture" \
  '^review_after_github_fresh_input_unresolved[[:space:]]'
assert_contains "$failure_fixture" \
  '^review_after_github_input_unchanged[[:space:]]'
assert_contains "$review_skill" \
  'After.*GitHub.*confirmed.*immediately before.*Linear'
assert_contains "$review_skill" \
  'already-published'
assert_contains "$review_skill" \
  'cannot satisfy the current Maestro pass'
assert_contains "$review_skill" \
  'old.*new.*underivable.*revision'
assert_contains "$status_skill" \
  'GitHub record referenced by.*review-input-stale'
assert_contains "$status_skill" \
  'historical.*cannot satisfy'
assert_contains "$failure_fixture" \
  '^evidence_stage_review_ignores_reconciliation_unresolved[[:space:]]'
assert_contains "$failure_fixture" \
  '^evidence_stage_reconciliation_unresolved_blocks_closeout[[:space:]]'
assert_contains "$failure_fixture" \
  '^evidence_stage_reconciliation_exact_allows_closeout[[:space:]]'

pass "Final Fix H acyclic preparation and atomic publication"
