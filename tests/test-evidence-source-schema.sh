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
ambiguous_binding="$tmp_dir/ambiguous-binding.json"
unresolved_binding="$tmp_dir/unresolved-binding.json"
python3 - "$exact_binding" "$ambiguous_binding" "$unresolved_binding" <<'PY'
import copy
import json
import sys

values = {
    "symphony": "symphony-1",
    "current_implementation_issue": "issue-1",
    "repository": "owner/repo",
    "current_linked_pr": "pr-1",
    "current_base": "base-1",
    "current_head": "head-1",
    "current_merge": "merge-1",
}

def context(values):
    locators = {
        "symphony": ["authoritative-context-v1", "linear-issue", values["symphony"], "symphony-control"],
        "current_implementation_issue": ["authoritative-context-v1", "linear-issue", values["current_implementation_issue"], "implementation-of", values["symphony"]],
        "repository": ["authoritative-context-v1", "github-repository", values["repository"], "repository-for", values["current_implementation_issue"]],
        "current_linked_pr": ["authoritative-context-v1", "github-pr", values["repository"], values["current_linked_pr"], "linked-to", values["current_implementation_issue"]],
        "current_base": ["authoritative-context-v1", "github-pr", values["repository"], values["current_linked_pr"], "base", values["current_base"]],
        "current_head": ["authoritative-context-v1", "github-pr", values["repository"], values["current_linked_pr"], "head", values["current_head"]],
        "current_merge": ["authoritative-context-v1", "github-pr", values["repository"], values["current_linked_pr"], "merge", values["current_merge"]],
    }
    return {
        field: {
            "value": value,
            "provider_locator": locators[field],
            "provider_state": "missing" if value == "unresolved" else "present",
            "provider_record_id": "missing" if value == "unresolved" else f"context-record:{field}",
            "provider_revision": "missing" if value == "unresolved" else f"context-revision:{field}",
            "provider_evidence": "missing" if value == "unresolved" else f"context-evidence:{field}",
        }
        for field, value in values.items()
    }

requirement = {
    "criterion_key": "criterion-v1:criterion",
    "required_outcome": "compatibility evidence",
    "evidence_stage": "review",
    "source_kind": "github-check-run",
    "provider_record_role": "integration-check",
    "locator_template": ["locator-template-v1", "github-check-run", "owner/repo", "${current_head}", "integration-check", "integration"],
}
resolved = ["resolved-locator-v1", "github-check-run", "owner/repo", "head-1", "integration-check", "integration"]
result = {
    "resolved_locator": resolved,
    "evidence_state": "present",
    "provider_record_id": "check-1",
    "provider_revision": "attempt-1",
    "provider_evidence": "evidence-v1:proof-1",
}
exact = {
    "requirement": requirement,
    "runtime_context": context(values),
    "provider_query": {"resolved_locator": resolved},
    "provider_results": [result],
}
ambiguous = copy.deepcopy(exact)
ambiguous["provider_results"].append({
    **result,
    "provider_record_id": "check-2",
    "provider_revision": "attempt-2",
    "provider_evidence": "evidence-v1:proof-2",
})
unresolved_values = copy.deepcopy(values)
unresolved_values["current_head"] = "unresolved"
unresolved_locator = copy.deepcopy(resolved)
unresolved_locator[3] = "unresolved"
unresolved = {
    "requirement": requirement,
    "runtime_context": context(unresolved_values),
    "provider_query": {"resolved_locator": unresolved_locator},
    "provider_results": [],
}
for path, value in zip(sys.argv[1:], (exact, ambiguous, unresolved)):
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(value, handle, separators=(",", ":"))
PY

exact_output=$("$helper" --plugin-root . binding --input "$exact_binding")
ambiguous_output=$("$helper" --plugin-root . binding --input "$ambiguous_binding")
unresolved_output=$("$helper" --plugin-root . binding --input "$unresolved_binding")
exact_revision=$(awk -F'\t' '$1 == "revision" { print $2 }' <<< "$exact_output")
ambiguous_revision=$(awk -F'\t' '$1 == "revision" { print $2 }' <<< "$ambiguous_output")
[[ "$exact_revision" != "$ambiguous_revision" ]] ||
  fail "resolution outcome does not change canonical binding digest"
[[ "$(awk -F'\t' '$1 == "publishable" { print $2 }' <<< "$exact_output")" == true ]] ||
  fail "exact binding is not publishable"
[[ "$(awk -F'\t' '$1 == "publishable" { print $2 }' <<< "$ambiguous_output")" == false ]] ||
  fail "ambiguous binding is publishable"
[[ "$(awk -F'\t' '$1 == "publishable" { print $2 }' <<< "$unresolved_output")" == false ]] ||
  fail "unresolved binding is publishable"

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
if len(binding) != 12 or binding[7] != "exact" or binding[8] != "present":
    raise SystemExit("canonical binding does not separate resolution and evidence state")
PY

pass "plugin-owned finite evidence source schema"
