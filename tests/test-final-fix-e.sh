#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")/.."
source tests/lib/assertions.sh

review_fixture=tests/fixtures/review-input-revision-cases.tsv
evidence_fixture=tests/fixtures/review-evidence-revision-cases.tsv
reconcile_fixture=tests/fixtures/reconciliation-verdict-cases.tsv
failure_fixture=tests/fixtures/failure-injection-plans.tsv
matrix=tests/fixtures/state-machine-matrix.tsv
core=references/symphony/core.md
review_ref=references/symphony/review.md
review_skill=skills/symphony-review/SKILL.md
reconcile=skills/symphony-reconcile/SKILL.md
start=skills/symphony-start/SKILL.md
reconciler=agents/implementation-reconciler.md

assert_file "$review_fixture"
[[ "$(head -n 1 "$review_fixture")" == \
  $'case_id\tscenario\tcanonical_input\texpected_revision' ]] ||
  fail "unexpected review-input revision fixture header"
review_rows=0
while IFS=$'\t' read -r case_id scenario canonical_input expected_revision; do
  [[ "$case_id" == "case_id" ]] && continue
  digest=$(printf '%s' "$canonical_input" | sha256sum | awk '{ print $1 }')
  [[ "$expected_revision" == "review-input-v1:$digest" ]] ||
    fail "$case_id review input digest differs"
  review_rows=$((review_rows + 1))
done < "$review_fixture"
[[ "$review_rows" -eq 8 ]] || fail "expected eight review revision rows"

r1=$(awk -F'\t' '$1 == "evidence_r1_initial" { print $4 }' "$review_fixture")
r2=$(awk -F'\t' '$1 == "evidence_r2_initial" { print $4 }' "$review_fixture")
h1=$(awk -F'\t' '$1 == "decision_r1_initial" { print $4 }' "$review_fixture")
h2=$(awk -F'\t' '$1 == "decision_r2_initial" { print $4 }' "$review_fixture")
[[ "$r1" != "$r2" && "$h1" != "$h2" ]] ||
  fail "changed evidence/resolution did not change review input revision"
assert_contains "$review_fixture" '"missing","missing"'

assert_file "$evidence_fixture"
[[ "$(head -n 1 "$evidence_fixture")" == \
  $'case_id\tkind\tcanonical_key\tstable_key\tcanonical_evidence\texpected_revision' ]] ||
  fail "unexpected review-evidence revision fixture header"
evidence_rows=0
while IFS=$'\t' read -r case_id kind canonical_key stable_key canonical_evidence expected_revision; do
  [[ "$case_id" == "case_id" ]] && continue
  if [[ "$kind" == "lens" ]]; then
    [[ "$canonical_key" == "literal:$stable_key" ]] ||
      fail "$case_id lens stable key is not the fully qualified literal"
  else
    key_digest=$(printf '%s' "$canonical_key" | sha256sum | awk '{ print $1 }')
    [[ "$stable_key" == "review-validator-key-v1:$key_digest" ]] ||
      fail "$case_id validator stable key digest differs"
  fi
  digest=$(printf '%s' "$canonical_evidence" | sha256sum | awk '{ print $1 }')
  [[ "$expected_revision" == "review-evidence-v1:$digest" ]] ||
    fail "$case_id review evidence digest differs"
  evidence_rows=$((evidence_rows + 1))
done < "$evidence_fixture"
[[ "$evidence_rows" -eq 6 ]] || fail "expected six evidence revision rows"
lens_initial=$(awk -F'\t' '$1 == "lens_initial" { print $6 }' "$evidence_fixture")
lens_fresh=$(awk -F'\t' '$1 == "lens_fresh_session" { print $6 }' "$evidence_fixture")
validator_r1=$(awk -F'\t' '$1 == "validator_r1_initial" { print $6 }' "$evidence_fixture")
validator_r1_fresh=$(awk -F'\t' '$1 == "validator_r1_fresh_session" { print $6 }' "$evidence_fixture")
validator_r2=$(awk -F'\t' '$1 == "validator_r2_initial" { print $6 }' "$evidence_fixture")
[[ "$lens_initial" == "$lens_fresh" &&
   "$validator_r1" == "$validator_r1_fresh" &&
   "$validator_r1" != "$validator_r2" ]] ||
  fail "review evidence revision is not fresh-session stable/change-sensitive"

assert_contains "$core" 'review-input-v1:'
assert_contains "$core" 'maestro-review-evidence-v1'
assert_contains "$core" 'Lens stable keys.*fully qualified'
assert_contains "$core" 'Validator stable keys.*maestro-review-validator-key-v1'
assert_contains "$core" 'validator command.*configuration.*capability'
assert_contains "$core" 'Validator kinds are exactly'
assert_contains "$core" 'review-source-closure-v1'
assert_contains "$core" 'selected_lenses'
assert_contains "$core" 'policy_sources'
assert_contains "$core" 'validators'
assert_contains "$core" 'validator-config'
assert_contains "$core" 'fixed literal `review-evidence-v1`'
assert_contains "$review_ref" 'Maestro-Review-Input-Revision'
assert_contains "$review_ref" 'missing.*unavailable'
assert_contains "$review_ref" 'review input revision.*Review PR action identity'
assert_contains "$review_ref" 'GitHub publication identity.*review input revision'
assert_contains "$review_ref" 'Linear.*publication identity.*review input revision'
assert_contains "$review_skill" 'consume event `review-requested`'
assert_contains "$reconcile" 'append event `review-requested`'
assert_contains "$reconcile" 'current review input revision'
assert_contains "$reconcile" 'older revision.*neither satisfies nor blocks'
assert_contains "$reconcile" 'merge-ready.*current.*review input revision'

for case_id in \
  review_r1_inconclusive_published \
  review_r2_request_missing \
  review_r2_evidence_eligible \
  review_r2_pass_published \
  review_r2_same_revision_suppressed \
  review_human_r1_paused \
  review_human_resolution_r2_eligible \
  review_human_stale_resolution_paused \
  review_inconclusive_unpublished \
  review_changes_required_unchanged_wait \
  review_older_pass_not_current \
  review_inconclusive_same_revision_suppressed \
  review_human_claimed_r2_stale_resolution
do
  assert_contains "$failure_fixture" "^${case_id}[[:space:]]"
done

assert_file "$reconcile_fixture"
[[ "$(head -n 1 "$reconcile_fixture")" == \
  $'case_id\tdecision_required\tmissing_identity_or_evidence\tcomplete_and_evidenced\texpected_verdict' ]] ||
  fail "unexpected reconciliation-verdict fixture header"
reconciliation_rows=0
while IFS=$'\t' read -r case_id decision missing complete expected; do
  [[ "$case_id" == "case_id" ]] && continue
  if [[ "$decision" == "present" ]]; then
    actual=human-decision
  elif [[ "$missing" == "present" ]]; then
    actual=inconclusive
  elif [[ "$complete" == "present" ]]; then
    actual=complete
  else
    actual=invalid
  fi
  [[ "$actual" == "$expected" ]] ||
    fail "$case_id reconciliation verdict: expected $expected, got $actual"
  reconciliation_rows=$((reconciliation_rows + 1))
done < "$reconcile_fixture"
[[ "$reconciliation_rows" -eq 8 ]] ||
  fail "expected eight exhaustive reconciliation cases"

declare -A reconciliation_predicate=(
  [human-decision]=aggregate-reconciliation-decision-is-required
  [inconclusive]=aggregate-reconciliation-decision-is-not-required-and-identity-or-required-evidence-is-missing
  [complete]=aggregate-reconciliation-decision-is-not-required-and-identity-or-required-evidence-is-present-and-complete-is-evidenced
)
for verdict in human-decision inconclusive complete; do
  actual_predicate=$(awk -F'\t' -v verdict="$verdict" \
    '$1 == "reconciliation-verdict" && $2 == verdict { print $5 }' "$matrix")
  [[ "$actual_predicate" == "${reconciliation_predicate[$verdict]}" ]] ||
    fail "$verdict does not use its disjoint reconciliation predicate"
done
assert_contains "$reconciler" \
  'Normalize.*decision required.*identity or required evidence missing.*complete and evidenced'
assert_contains "$reconciler" \
  'unsatisfied acceptance criterion.*needs disposition.*decision required'
assert_contains tests/test-state-machine-conformance.sh \
  'reconciliation-precedence-regression'

start_path=skills/symphony-start/SKILL.md
needs_predicate=entity-scoped-pause-is-confirmed-and-strategic-authority-is-not-required
scope_predicate=entity-scoped-pause-is-confirmed-and-strategic-authority-is-required
assert_contains "$matrix" \
  "^phase-label[[:space:]]+maestro:needs-human[[:space:]].*${needs_predicate}"
assert_contains "$matrix" \
  "^phase-label[[:space:]]+maestro:scope-change[[:space:]].*${start_path}.*${scope_predicate}"
assert_contains "$start" 'apply label `maestro:scope-change`'
assert_contains "$start" 'matching.*decision-resolved.*before.*remov'
assert_contains "$failure_fixture" \
  '^strategic_pause_missing_label_fresh_session[[:space:]]'
assert_contains "$failure_fixture" \
  '^bounded_pause_missing_label_fresh_session[[:space:]]'

pass "Final Fix E review revision and precedence contracts"
