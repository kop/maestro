#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")/.."
source tests/lib/assertions.sh

helper=scripts/evidence-source-schema.py
schema=evidence-source-schema-v1.json
fixture=tests/fixtures/evidence-stage-cases.tsv

assert_file "$helper"
assert_executable "$helper"
assert_file "$schema"
assert_file "$fixture"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

expected_header=$'case_id\tevidence_stage\tsource_kind\tprovider_record_role\tlocator_template\tvalid\treview_selected\treconciliation_selected'
[[ "$(head -n 1 "$fixture")" == "$expected_header" ]] ||
  fail "unexpected evidence-stage fixture header"

declare -A requirement_keys=()
rows=0
while IFS=$'\t' read -r case_id evidence_stage source_kind role locator \
    valid review_selected reconciliation_selected; do
  [[ "$case_id" == case_id ]] && continue
  input="$tmp_dir/$case_id.json"
  if [[ "$role" == "@MISSING@" ]]; then
    printf '{"criterion_key":"criterion-v1:criterion","required_outcome":"compatibility evidence","evidence_stage":"%s","source_kind":"%s","locator_template":%s}\n' \
      "$evidence_stage" "$source_kind" "$locator" > "$input"
  else
    printf '{"criterion_key":"criterion-v1:criterion","required_outcome":"compatibility evidence","evidence_stage":"%s","source_kind":"%s","provider_record_role":"%s","locator_template":%s}\n' \
      "$evidence_stage" "$source_kind" "$role" "$locator" > "$input"
  fi
  if [[ "$valid" == true ]]; then
    output=$("$helper" --plugin-root . requirement --input "$input") ||
      fail "$case_id valid requirement was rejected"
    canonical=$(awk -F'\t' '$1 == "canonical" { print $2 }' <<< "$output")
    key=$(awk -F'\t' '$1 == "key" { print $2 }' <<< "$output")
    [[ "$canonical" == *"\"$evidence_stage\",\"$source_kind\",\"$role\""* ]] ||
      fail "$case_id canonical requirement omits stage/kind/static role"
    [[ "$key" == evidence-requirement-key-v1:* ]] ||
      fail "$case_id has unexpected requirement key"
    requirement_keys["$case_id"]=$key
  elif "$helper" --plugin-root . requirement --input "$input" \
      >/dev/null 2>&1; then
    fail "$case_id invalid requirement was accepted"
  fi

  if [[ "$valid" == true ]]; then
    if [[ "$evidence_stage" == review || "$evidence_stage" == both ]]; then
      [[ "$review_selected" == true ]] ||
        fail "$case_id is missing from review-stage selection"
    else
      [[ "$review_selected" == false ]] ||
        fail "$case_id incorrectly enters review-stage selection"
    fi
    if [[ "$evidence_stage" == reconciliation || "$evidence_stage" == both ]]; then
      [[ "$reconciliation_selected" == true ]] ||
        fail "$case_id is missing from reconciliation-stage selection"
    else
      [[ "$reconciliation_selected" == false ]] ||
        fail "$case_id incorrectly enters reconciliation-stage selection"
    fi
  fi
  rows=$((rows + 1))
done < "$fixture"
[[ "$rows" -eq 20 ]] || fail "expected 20 evidence-stage cases, got $rows"

role_changed="$tmp_dir/role-changed.json"
printf '%s\n' \
  '{"criterion_key":"criterion-v1:criterion","required_outcome":"compatibility evidence","evidence_stage":"review","source_kind":"repository-commit","provider_record_role":"implementation-merge","locator_template":["locator-template-v1","repository-commit","owner/repo","${current_head}","implementation-merge"]}' \
  > "$role_changed"
if "$helper" --plugin-root . requirement --input "$role_changed" \
    >/dev/null 2>&1; then
  fail "stage-invalid changed provider role was accepted"
fi

exact_binding="$tmp_dir/exact-binding.json"
exact_unavailable_binding="$tmp_dir/exact-unavailable-binding.json"
ambiguous_binding="$tmp_dir/ambiguous-binding.json"
unresolved_binding="$tmp_dir/unresolved-binding.json"
printf '%s\n' \
  '{"requirement":{"criterion_key":"criterion-v1:criterion","required_outcome":"compatibility evidence","evidence_stage":"review","source_kind":"github-check-run","provider_record_role":"integration-check","locator_template":["locator-template-v1","github-check-run","owner/repo","${current_head}","integration-check","integration"]},"resolved_locator":["resolved-locator-v1","github-check-run","owner/repo","head-1","integration-check","integration"],"binding_context_revision":"evidence-binding-context-v1:ctx","resolution_outcome":"exact","evidence_state":"present","provider_record_id":"check-1","provider_revision":"attempt-1"}' \
  > "$exact_binding"
printf '%s\n' \
  '{"requirement":{"criterion_key":"criterion-v1:criterion","required_outcome":"compatibility evidence","evidence_stage":"review","source_kind":"github-check-run","provider_record_role":"integration-check","locator_template":["locator-template-v1","github-check-run","owner/repo","${current_head}","integration-check","integration"]},"resolved_locator":["resolved-locator-v1","github-check-run","owner/repo","head-1","integration-check","integration"],"binding_context_revision":"evidence-binding-context-v1:ctx","resolution_outcome":"exact","evidence_state":"unavailable","provider_record_id":"unavailable","provider_revision":"unavailable"}' \
  > "$exact_unavailable_binding"
printf '%s\n' \
  '{"requirement":{"criterion_key":"criterion-v1:criterion","required_outcome":"compatibility evidence","evidence_stage":"review","source_kind":"github-check-run","provider_record_role":"integration-check","locator_template":["locator-template-v1","github-check-run","owner/repo","${current_head}","integration-check","integration"]},"resolved_locator":["resolved-locator-v1","github-check-run","owner/repo","head-1","integration-check","integration"],"binding_context_revision":"evidence-binding-context-v1:ctx","resolution_outcome":"ambiguous","evidence_state":"unavailable","provider_record_id":"unavailable","provider_revision":"unavailable"}' \
  > "$ambiguous_binding"
printf '%s\n' \
  '{"requirement":{"criterion_key":"criterion-v1:criterion","required_outcome":"compatibility evidence","evidence_stage":"review","source_kind":"github-check-run","provider_record_role":"integration-check","locator_template":["locator-template-v1","github-check-run","owner/repo","${current_head}","integration-check","integration"]},"resolved_locator":["resolved-locator-v1","github-check-run","owner/repo","unresolved","integration-check","integration"],"binding_context_revision":"evidence-binding-context-v1:ctx","resolution_outcome":"unresolved","evidence_state":"missing","provider_record_id":"missing","provider_revision":"missing"}' \
  > "$unresolved_binding"

exact_output=$("$helper" --plugin-root . binding --input "$exact_binding")
exact_unavailable_output=$("$helper" --plugin-root . binding --input "$exact_unavailable_binding")
ambiguous_output=$("$helper" --plugin-root . binding --input "$ambiguous_binding")
unresolved_output=$("$helper" --plugin-root . binding --input "$unresolved_binding")
exact_revision=$(awk -F'\t' '$1 == "revision" { print $2 }' <<< "$exact_unavailable_output")
ambiguous_revision=$(awk -F'\t' '$1 == "revision" { print $2 }' <<< "$ambiguous_output")
[[ "$exact_revision" != "$ambiguous_revision" ]] ||
  fail "resolution outcome does not change canonical binding digest"
[[ "$(awk -F'\t' '$1 == "publishable" { print $2 }' <<< "$exact_output")" == true ]] ||
  fail "exact binding is not publishable"
[[ "$(awk -F'\t' '$1 == "publishable" { print $2 }' <<< "$ambiguous_output")" == false ]] ||
  fail "ambiguous binding is publishable"
[[ "$(awk -F'\t' '$1 == "publishable" { print $2 }' <<< "$unresolved_output")" == false ]] ||
  fail "unresolved binding is publishable"

invalid_ambiguous="$tmp_dir/invalid-ambiguous-present.json"
invalid_unresolved="$tmp_dir/invalid-unresolved-unavailable.json"
sed \
  's/"resolution_outcome":"exact"/"resolution_outcome":"ambiguous"/' \
  "$exact_binding" > "$invalid_ambiguous"
sed \
  's/"evidence_state":"missing","provider_record_id":"missing","provider_revision":"missing"/"evidence_state":"unavailable","provider_record_id":"unavailable","provider_revision":"unavailable"/' \
  "$unresolved_binding" > "$invalid_unresolved"
for invalid in "$invalid_ambiguous" "$invalid_unresolved"; do
  if "$helper" --plugin-root . binding --input "$invalid" >/dev/null 2>&1; then
    fail "$(basename "$invalid") invalid resolution/state pair was accepted"
  fi
done

python3 - "$schema" "$exact_output" <<'PY'
import json
import sys

schema = json.load(open(sys.argv[1], encoding="utf-8"))
expected_kinds = {
    "linear-issue",
    "linear-comment",
    "linear-document",
    "github-pr",
    "github-comment",
    "github-review",
    "github-check-run",
    "github-artifact",
    "repository-file",
    "repository-commit",
    "manual-validation",
}
if set(schema["source_kinds"]) != expected_kinds:
    raise SystemExit("evidence source schema kind set is not exhaustive")
if set(schema["evidence_stages"]) != {"review", "reconciliation", "both"}:
    raise SystemExit("evidence stage set is not finite")
canonical = next(
    line.split("\t", 1)[1]
    for line in sys.argv[2].splitlines()
    if line.startswith("canonical\t")
)
binding = json.loads(canonical)
if len(binding) != 11 or binding[7] != "exact" or binding[8] != "present":
    raise SystemExit("canonical binding does not separate resolution and evidence state")
PY

pass "plugin-owned finite evidence source schema"
