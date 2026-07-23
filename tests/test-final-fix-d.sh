#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")/.."
source tests/lib/assertions.sh

verdict_fixture=tests/fixtures/review-verdict-cases.tsv
identity_fixture=tests/fixtures/identity-reproduction-cases.tsv
matrix=tests/fixtures/state-machine-matrix.tsv
core=references/symphony/core.md
linear=references/symphony/linear.md
start=skills/symphony-start/SKILL.md
reconcile=skills/symphony-reconcile/SKILL.md
status=skills/symphony-status/SKILL.md
reconciler=agents/implementation-reconciler.md

assert_file "$verdict_fixture"
[[ "$(head -n 1 "$verdict_fixture")" == \
  $'case_id\tstrategic_decision\tactionable_defect\tmissing_required_evidence\texpected_verdict' ]] ||
  fail "unexpected review-verdict fixture header"

verdict_rows=0
while IFS=$'\t' read -r case_id strategic defect missing expected; do
  [[ "$case_id" == "case_id" ]] && continue
  if [[ "$strategic" == "present" ]]; then
    actual=human-decision
  elif [[ "$defect" == "present" ]]; then
    actual=changes-required
  elif [[ "$missing" == "present" ]]; then
    actual=inconclusive
  else
    actual=pass
  fi
  [[ "$actual" == "$expected" ]] ||
    fail "$case_id review verdict: expected $expected, got $actual"
  verdict_rows=$((verdict_rows + 1))
done < "$verdict_fixture"
[[ "$verdict_rows" -eq 4 ]] || fail "expected four mixed review cases"

declare -A verdict_predicate=(
  [human-decision]=aggregate-strategic-decision-is-present
  [changes-required]=aggregate-strategic-decision-is-absent-and-actionable-defect-is-present
  [inconclusive]=aggregate-strategic-decision-and-actionable-defect-are-absent-and-required-evidence-is-missing
  [pass]=aggregate-strategic-decision-actionable-defect-and-required-evidence-are-absent
)
for verdict in human-decision changes-required inconclusive pass; do
  actual_predicate=$(awk -F'\t' -v verdict="$verdict" \
    '$1 == "review-verdict" && $2 == verdict { print $5 }' "$matrix")
  [[ "$actual_predicate" == "${verdict_predicate[$verdict]}" ]] ||
    fail "$verdict does not use its disjoint normalized aggregate predicate"
done
assert_contains "$core" 'strategic decision.*actionable defect.*required evidence'
assert_contains skills/symphony-review/SKILL.md \
  'Normalize.*strategic decision.*actionable defect.*required evidence'

assert_file "$identity_fixture"
[[ "$(head -n 1 "$identity_fixture")" == \
  $'case_id\tfamily\tcanonical_input\texpected_key' ]] ||
  fail "unexpected identity-reproduction fixture header"
identity_rows=0
while IFS=$'\t' read -r case_id family canonical_input expected_key; do
  [[ "$case_id" == "case_id" ]] && continue
  digest=$(printf '%s' "$canonical_input" | sha256sum | awk '{ print $1 }')
  [[ "$expected_key" == *":$digest" ]] ||
    fail "$case_id canonical identity digest differs"
  identity_rows=$((identity_rows + 1))
done < "$identity_fixture"
[[ "$identity_rows" -eq 8 ]] || fail "expected eight identity reproduction rows"
for family in cancellation decision discovery follow-up integration merge; do
  assert_contains "$identity_fixture" \
    "closeout_initial.*\\[\"${family}\""
done

assert_contains "$core" 'Unicode NFC'
assert_contains "$core" 'RFC 8259'
assert_contains "$core" 'UTF-8 bytes.*SHA-256.*lowercase hexadecimal'
assert_contains "$linear" 'discovery-v1:'
assert_contains "$linear" 'question-v1:'
assert_contains "$linear" 'confirmed `discovery-requested`'
assert_contains "$reconciler" '^  Follow-up key: follow-up-v1:'
assert_contains "$linear" 'follow-up-v1:'
assert_contains "$linear" 'evidence-v1:'
assert_contains "$linear" 'sort.*canonical evidence'
assert_contains "$linear" 'fail closed.*multiple'

for case_id in \
  discovery_identity_ambiguous_reproduced \
  discovery_identity_ambiguous_multiple \
  follow_up_identity_ambiguous_reproduced \
  follow_up_identity_ambiguous_multiple \
  closeout_identity_ambiguous_reproduced \
  closeout_identity_ambiguous_multiple
do
  assert_contains tests/fixtures/failure-injection-plans.tsv "^${case_id}[[:space:]]"
done

assert_contains "$start" 'consume event `semantic-drift-detected`'
assert_contains "$start" 'apply label `maestro:needs-human`'
assert_contains "$start" 'matching.*decision-resolved.*before.*resume'
start_path='skills/symphony-start/SKILL.md'
assert_contains "$matrix" \
  "^event[[:space:]]+semantic-drift-detected[[:space:]].*${start_path}"
assert_contains "$matrix" \
  "^phase-label[[:space:]]+maestro:needs-human[[:space:]].*${start_path}"

for case_id in \
  retry_exhausted_state_changed_unresolved \
  retry_exhausted_state_changed_resolved \
  retry_exhausted_state_changed_stale_resolution \
  exhaustion_status_unresolved \
  exhaustion_status_resolved_historical \
  exhaustion_status_wrong_disposition \
  exhaustion_status_missing_resume_phase \
  retry_exhausted_missing_pause_identity \
  validation_timeout_exhausted_missing_pause_identity_attached \
  reconcile_complete_after_inconclusive \
  reconcile_already_complete
do
  assert_contains tests/fixtures/failure-injection-plans.tsv "^${case_id}[[:space:]]"
done

assert_contains "$core" 'resume-after-confirmed-external-state-change'
assert_contains "$reconcile" \
  'merged PR.*lacking.*confirmed `merge-reconciled`'
assert_not_contains "$reconcile" \
  'merged PR lacking a confirmed merge action identity'
assert_contains "$status" 'Resolved historical retry exhaustion'
assert_contains "$status" 'Unresolved retry exhaustion debt'

pass "Final Fix D deterministic verdict and recovery contracts"
