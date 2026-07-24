#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")/.."
source tests/lib/assertions.sh

acceptance_fixture=tests/fixtures/evidence-requirement-binding-cases.tsv
context_fixture=tests/fixtures/review-context-identity-cases.tsv
publication_fixture=tests/fixtures/review-publication-identity-cases.tsv
failure_fixture=tests/fixtures/failure-injection-plans.tsv
core=references/symphony/core.md
linear=references/symphony/linear.md
review=references/symphony/review.md
review_skill=skills/symphony-review/SKILL.md
reconcile=skills/symphony-reconcile/SKILL.md

assert_file "$acceptance_fixture"
[[ "$(head -n 1 "$acceptance_fixture")" == \
  $'case_id\tsource_kind\tcanonical_criterion\tcanonical_requirement_template\tcanonical_binding_template\tbinding_state\tresolution_status\tpublishable\tstable_group' ]] ||
  fail "unexpected acceptance-evidence fixture header"
acceptance_rows=0
while IFS=$'\t' read -r case_id source_kind canonical_criterion \
    requirement_template binding_template binding_state resolution_status \
    publishable stable_group; do
  [[ "$case_id" == "case_id" ]] && continue
  criterion_digest=$(printf '%s' "$canonical_criterion" | sha256sum |
    awk '{ print $1 }')
  criterion_key="criterion-v1:$criterion_digest"
  canonical_requirement=${requirement_template//@CRITERION@/$criterion_key}
  requirement_digest=$(printf '%s' "$canonical_requirement" | sha256sum |
    awk '{ print $1 }')
  requirement_key="evidence-requirement-key-v1:$requirement_digest"
  canonical_binding=${binding_template//@REQUIREMENT@/$requirement_key}
  binding_digest=$(printf '%s' "$canonical_binding" | sha256sum |
    awk '{ print $1 }')
  [[ "$requirement_key" == evidence-requirement-key-v1:* ]] ||
    fail "$case_id requirement key differs"
  [[ "acceptance-evidence-binding-v1:$binding_digest" == \
     acceptance-evidence-binding-v1:* ]] ||
    fail "$case_id binding revision differs"
  acceptance_rows=$((acceptance_rows + 1))
done < "$acceptance_fixture"
[[ "$acceptance_rows" -eq 25 ]] ||
  fail "expected twenty-five acceptance-evidence binding rows"

assert_contains "$linear" 'criterion_key'
assert_contains "$linear" 'evidence_requirement_key'
assert_contains "$linear" 'criterion semantics'
assert_contains "$linear" 'required outcome/evidence role'
assert_contains "$linear" 'issue contract revision'
assert_contains "$linear" \
  'linear-issue.*linear-comment.*linear-document.*github-pr.*github-comment.*github-review.*github-check-run.*github-artifact.*repository-file.*repository-commit.*manual-validation'
assert_contains "$linear" 'locator template'
assert_contains "$linear" 'untyped URL'
assert_contains "$linear" 'never revision'
assert_contains "$core" 'maestro-acceptance-evidence-binding-manifest-v1'
assert_contains "$core" 'acceptance evidence binding manifest.*review-evidence-v1'
assert_contains "$core" 'acceptance evidence binding manifest.*review-input-v1'
assert_contains "$review" 'unkeyed.*free-form.*action-failed'
assert_contains "$review" 'durable.*inconclusive.*stable.*manifest'

assert_file "$context_fixture"
[[ "$(head -n 1 "$context_fixture")" == \
  $'case_id\tcanonical_input\texpected_revision' ]] ||
  fail "unexpected review-context fixture header"
context_rows=0
while IFS=$'\t' read -r case_id canonical_input expected_revision; do
  [[ "$case_id" == "case_id" ]] && continue
  digest=$(printf '%s' "$canonical_input" | sha256sum | awk '{ print $1 }')
  [[ "$expected_revision" == "review-input-v1:$digest" ]] ||
    fail "$case_id review-context revision differs"
  context_rows=$((context_rows + 1))
done < "$context_fixture"
[[ "$context_rows" -eq 6 ]] || fail "expected six review-context rows"
initial=$(awk -F'\t' '$1 == "context_initial" { print $3 }' "$context_fixture")
fresh=$(awk -F'\t' '$1 == "context_fresh_session" { print $3 }' "$context_fixture")
[[ "$initial" == "$fresh" ]] || fail "review context is not reproducible"
for changed_case in base_moved symphony_relinked implementation_relinked pr_relinked; do
  [[ "$initial" != \
     "$(awk -F'\t' -v case_id="$changed_case" '$1 == case_id { print $3 }' "$context_fixture")" ]] ||
    fail "$changed_case did not change review input revision"
done

assert_file "$publication_fixture"
publication_rows=0
while IFS=$'\t' read -r case_id expected_action expected_github expected_linear; do
  [[ "$case_id" == "case_id" ]] && continue
  input_revision=$(awk -F'\t' -v id="$case_id" '$1 == id { print $3 }' \
    "$context_fixture")
  case "$case_id" in
    context_initial|context_fresh_session)
      symphony=symphony-1 implementation=impl-1 pr=pr-101 base=base-1 head=head-1
      ;;
    base_moved)
      symphony=symphony-1 implementation=impl-1 pr=pr-101 base=base-2 head=head-1
      ;;
    symphony_relinked)
      symphony=symphony-2 implementation=impl-1 pr=pr-101 base=base-1 head=head-1
      ;;
    implementation_relinked)
      symphony=symphony-1 implementation=impl-2 pr=pr-101 base=base-1 head=head-1
      ;;
    pr_relinked)
      symphony=symphony-1 implementation=impl-1 pr=pr-202 base=base-1 head=head-1
      ;;
    *) fail "unknown publication identity case $case_id" ;;
  esac
  action_tuple="[\"maestro-review-action-v1\",\"$symphony\",\"$implementation\",\"$pr\",\"$base\",\"$head\",\"contract-1\",\"dag-1\",\"review-policy-v1\",\"$input_revision\"]"
  action_digest=$(printf '%s' "$action_tuple" | sha256sum | awk '{ print $1 }')
  action_identity="review-action-v1:$action_digest"
  [[ "$action_identity" == "$expected_action" ]] ||
    fail "$case_id action identity differs"
  github_tuple="[\"maestro-review-github-publication-v1\",\"$symphony\",\"$implementation\",\"$pr\",\"$base\",\"$head\",\"contract-1\",\"dag-1\",\"review-policy-v1\",\"$input_revision\",\"$action_identity\",\"github-review\"]"
  github_digest=$(printf '%s' "$github_tuple" | sha256sum | awk '{ print $1 }')
  [[ "review-github-publication-v1:$github_digest" == "$expected_github" ]] ||
    fail "$case_id GitHub publication identity differs"
  linear_tuple="[\"maestro-review-linear-publication-v1\",\"$symphony\",\"$implementation\",\"$pr\",\"$base\",\"$head\",\"contract-1\",\"dag-1\",\"review-policy-v1\",\"$input_revision\",\"$action_identity\",\"linear-cursor-follow-up\"]"
  linear_digest=$(printf '%s' "$linear_tuple" | sha256sum | awk '{ print $1 }')
  [[ "review-linear-publication-v1:$linear_digest" == "$expected_linear" ]] ||
    fail "$case_id Linear publication identity differs"
  publication_rows=$((publication_rows + 1))
done < "$publication_fixture"
[[ "$publication_rows" -eq 6 ]] ||
  fail "expected six review publication identity rows"
initial_publications=$(awk -F'\t' '$1 == "context_initial" { print $0 }' \
  "$publication_fixture")
fresh_publications=$(awk -F'\t' '$1 == "context_fresh_session" { print $0 }' \
  "$publication_fixture")
[[ "${initial_publications#context_initial}" == \
   "${fresh_publications#context_fresh_session}" ]] ||
  fail "publication identities are not fresh-session stable"
for changed_case in base_moved symphony_relinked implementation_relinked pr_relinked; do
  changed_publications=$(awk -F'\t' -v id="$changed_case" '$1 == id { print $0 }' \
    "$publication_fixture")
  [[ "${initial_publications#context_initial}" != \
     "${changed_publications#"$changed_case"}" ]] ||
    fail "$changed_case did not change all publication identities"
done

assert_contains "$core" \
  'maestro-review-input-v1.*Symphony UUID.*implementation issue UUID.*GitHub PR native ID.*base SHA.*head SHA.*contract revision.*DAG revision.*review-policy revision'
assert_contains "$core" 'maestro-review-action-v1'
assert_contains "$core" 'maestro-review-github-publication-v1'
assert_contains "$core" 'maestro-review-linear-publication-v1'
assert_contains "$core" 'review-action-v1:<lowercase SHA-256 hex>'
assert_contains "$core" 'review-github-publication-v1:<lowercase SHA-256 hex>'
assert_contains "$core" 'review-linear-publication-v1:<lowercase SHA-256 hex>'
assert_contains "$review" \
  'Reviewed identity.*Symphony UUID.*Implementation issue UUID.*PR native ID.*Base SHA.*Head SHA'
assert_contains "$review_skill" \
  'Reject a result.*Symphony UUID.*implementation issue UUID.*PR native ID.*base SHA.*head SHA'
assert_contains "$review_skill" \
  'Maestro-Cursor-Follow-Up-Identity: <complete linear publication identity>'
assert_contains "$reconcile" \
  'base SHA movement.*relink.*non-authoritative.*eligible'

assert_contains "$core" 'review-source-closure-v1'
assert_contains "$core" 'exact file bytes.*SHA-256'
assert_contains "$core" 'explicit empty list'
assert_contains "$core" 'reject.*absolute.*escaping.*glob'
assert_contains "$core" 'implicit source closure'
assert_contains "$core" 'action-failed'
assert_contains "$core" 'plugin-owned manifest'
assert_contains "$review" 'review-source-requirements-v1'
assert_contains "$review_skill" 'authoritative review-source requirements'
assert_contains "$core" 'scripts/review-source-closure.py'
assert_contains tests/fixtures/review-evidence-revision-cases.tsv \
  'maestro-review-evidence-v1.*review-source-closure-v1:.*acceptance-evidence-v1:'
assert_contains tests/fixtures/review-input-revision-cases.tsv \
  'maestro-review-input-v1","symphony-'

for case_id in \
  review_acceptance_r1_published \
  review_acceptance_r2_request_missing \
  review_acceptance_r2_eligible \
  review_acceptance_r2_pass \
  review_acceptance_provider_revision_r3 \
  review_unkeyed_missing_unpublished \
  review_actionable_missing_without_manifest_unpublished
do
  assert_contains "$failure_fixture" "^${case_id}[[:space:]]"
done

pass "Final Fix F complete review evidence closure"
