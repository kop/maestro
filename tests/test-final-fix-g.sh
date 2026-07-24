#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")/.."
source tests/lib/assertions.sh

binding_fixture=tests/fixtures/evidence-requirement-binding-cases.tsv
failure_fixture=tests/fixtures/failure-injection-plans.tsv
plugin_manifest=review-source-requirements-v1.json
core=references/symphony/core.md
linear=references/symphony/linear.md
review=references/symphony/review.md
review_skill=skills/symphony-review/SKILL.md
reconcile=skills/symphony-reconcile/SKILL.md
schema_helper=scripts/evidence-source-schema.py

assert_file "$binding_fixture"
assert_executable "$schema_helper"
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
expected_header=$'case_id\tsource_kind\tcanonical_criterion\tcanonical_requirement_template\tcanonical_binding_template\tbinding_state\tresolution_status\tpublishable\tstable_group'
[[ "$(head -n 1 "$binding_fixture")" == "$expected_header" ]] ||
  fail "unexpected evidence requirement/binding fixture header"

declare -A source_kinds=()
declare -A first_requirement=()
declare -A first_binding=()
declare -A first_contract=()
declare -A first_input=()
declare -A case_requirement=()
rows=0
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
  locator_template=$(python3 -c \
    'import json,sys; print(json.dumps(json.loads(sys.argv[1])[6], separators=(",", ":")))' \
    "$canonical_requirement")
  canonical_binding=${binding_template//@REQUIREMENT@/$requirement_key}
  canonical_binding=${canonical_binding//@CRITERION@/$criterion_key}
  canonical_binding=${canonical_binding//@SOURCE_KIND@/$source_kind}
  canonical_binding=${canonical_binding//@LOCATOR_TEMPLATE@/$locator_template}
  canonical_binding=${canonical_binding//@RESOLUTION@/$resolution_status}
  binding_digest=$(printf '%s' "$canonical_binding" | sha256sum |
    awk '{ print $1 }')
  binding_revision="acceptance-evidence-binding-v1:$binding_digest"
  contract_tuple="[\"maestro-implementation-contract-v1\",\"node-api\",\"$requirement_key\"]"
  contract_digest=$(printf '%s' "$contract_tuple" | sha256sum | awk '{ print $1 }')
  contract_revision="implementation-contract-v1:$contract_digest"
  input_tuple="[\"maestro-review-input-v1\",\"$binding_revision\"]"
  input_digest=$(printf '%s' "$input_tuple" | sha256sum | awk '{ print $1 }')
  input_revision="review-input-v1:$input_digest"

  [[ "$canonical_requirement" == *'"maestro-evidence-requirement-key-v1"'* ]] ||
    fail "$case_id missing canonical requirement tuple"
  [[ "$canonical_requirement" == *'"locator-template-v1"'* ]] ||
    fail "$case_id missing locator template"
  [[ "$canonical_requirement" != *linear-issue-77* &&
     "$canonical_requirement" != *linear-issue-88* &&
     "$canonical_requirement" != *pr-101* &&
     "$canonical_requirement" != *pr-202* &&
     "$canonical_requirement" != *head-1* &&
     "$canonical_requirement" != *head-2* &&
     "$canonical_requirement" != *merge-1* &&
     "$canonical_requirement" != *check-run-* &&
     "$canonical_requirement" != *artifact-* ]] ||
    fail "$case_id plan-time requirement contains a runtime native identity"
  [[ "$canonical_binding" == *'"maestro-acceptance-evidence-binding-v1"'* ]] ||
    fail "$case_id missing canonical runtime binding tuple"
  python3 - "$case_id" "$canonical_binding" "$criterion_key" \
      "$requirement_key" "$source_kind" "$locator_template" "$binding_state" \
      "$resolution_status" <<'PY'
import json
import sys

(
    case_id,
    raw,
    criterion_key,
    requirement_key,
    source_kind,
    raw_template,
    state,
    resolution,
) = sys.argv[1:]
binding = json.loads(raw)
template = json.loads(raw_template)
if len(binding) != 11:
    raise SystemExit(f"{case_id}: binding must have exactly 11 fields, got {len(binding)}")
expected_prefix = [
    "maestro-acceptance-evidence-binding-v1",
    criterion_key,
    requirement_key,
    source_kind,
    template,
]
if binding[:5] != expected_prefix:
    raise SystemExit(f"{case_id}: binding identity/template prefix is not canonical")
if len(binding[5]) != len(template):
    raise SystemExit(
        f"{case_id}: resolved locator does not replace template tokens one-for-one"
    )
if any("${" in str(value) for value in binding[5]):
    raise SystemExit(f"{case_id}: resolved locator retains an unresolved template token")
if state not in {"present", "missing", "unavailable"}:
    raise SystemExit(f"{case_id}: invalid finite observable state {state!r}")
if binding[7] != resolution:
    raise SystemExit(f"{case_id}: canonical binding omits resolution outcome")
if binding[8] != state:
    raise SystemExit(f"{case_id}: binding state field differs from fixture state")
if state == "present":
    if binding[9] in {"missing", "unavailable"} or binding[10] in {
        "missing",
        "unavailable",
    }:
        raise SystemExit(f"{case_id}: present binding uses a state sentinel")
elif binding[9:] != [state, state]:
    raise SystemExit(f"{case_id}: non-present binding lacks matching state sentinels")
if resolution not in {"exact", "unresolved", "ambiguous"}:
    raise SystemExit(f"{case_id}: invalid resolution status {resolution!r}")
locator_unresolved = "unresolved" in binding[5]
if resolution == "exact" and locator_unresolved:
    raise SystemExit(f"{case_id}: exact resolution contains an unresolved locator")
if resolution == "unresolved" and not locator_unresolved:
    raise SystemExit(f"{case_id}: unresolved resolution lacks an explicit sentinel")
PY

  binding_input="$tmp_dir/$case_id.json"
  python3 - "$canonical_requirement" "$canonical_binding" > "$binding_input" <<'PY'
import json
import sys

requirement = json.loads(sys.argv[1])
binding = json.loads(sys.argv[2])
context = {
    "symphony": "symphony-1",
    "current_implementation_issue": "issue-unselected",
    "repository": "owner/repo",
    "current_linked_pr": "pr-unselected",
    "current_base": "base-unselected",
    "current_head": "head-unselected",
    "current_merge": "merge-unselected",
}
for index, item in enumerate(requirement[6]):
    if isinstance(item, str) and item.startswith("${") and item.endswith("}"):
        context[item[2:-1]] = binding[5][index]
locators = {
    "symphony": ["authoritative-context-v1", "linear-issue", context["symphony"], "symphony-control"],
    "current_implementation_issue": ["authoritative-context-v1", "linear-issue", context["current_implementation_issue"], "implementation-of", context["symphony"]],
    "repository": ["authoritative-context-v1", "github-repository", context["repository"], "repository-for", context["current_implementation_issue"]],
    "current_linked_pr": ["authoritative-context-v1", "github-pr", context["repository"], context["current_linked_pr"], "linked-to", context["current_implementation_issue"]],
    "current_base": ["authoritative-context-v1", "github-pr", context["repository"], context["current_linked_pr"], "base", context["current_base"]],
    "current_head": ["authoritative-context-v1", "github-pr", context["repository"], context["current_linked_pr"], "head", context["current_head"]],
    "current_merge": ["authoritative-context-v1", "github-pr", context["repository"], context["current_linked_pr"], "merge", context["current_merge"]],
}
context = {
    field: {
        "value": value,
        "provider_locator": locators[field],
        "provider_state": "missing" if value == "unresolved" else "present",
        "provider_record_id": "missing" if value == "unresolved" else f"context-record:{field}",
        "provider_revision": "missing" if value == "unresolved" else f"context-revision:{field}",
        "provider_evidence": "missing" if value == "unresolved" else f"context-evidence:{field}",
    }
    for field, value in context.items()
}
if binding[7] == "exact":
    evidence = binding[10] if binding[8] == "present" else binding[8]
    results = [{
        "resolved_locator": binding[5],
        "evidence_state": binding[8],
        "provider_record_id": binding[9],
        "provider_revision": binding[10],
        "provider_evidence": evidence,
    }]
elif binding[7] == "ambiguous":
    results = [
        {
            "resolved_locator": binding[5],
            "evidence_state": "present",
            "provider_record_id": f"ambiguous-record-{index}",
            "provider_revision": f"ambiguous-revision-{index}",
            "provider_evidence": f"evidence-v1:ambiguous-{index}",
        }
        for index in (1, 2)
    ]
else:
    results = []
json.dump(
    {
        "requirement": {
            "criterion_key": requirement[1],
            "required_outcome": requirement[2],
            "evidence_stage": requirement[3],
            "source_kind": requirement[4],
            "provider_record_role": requirement[5],
            "locator_template": requirement[6],
        },
        "runtime_context": context,
        "provider_query": {"resolved_locator": binding[5]},
        "provider_results": results,
    },
    sys.stdout,
    separators=(",", ":"),
)
PY
  oracle_output=$("$schema_helper" --plugin-root . binding --input "$binding_input") ||
    fail "$case_id was rejected by the plugin-owned evidence oracle"
  oracle_canonical=$(awk -F'\t' '$1 == "canonical" { print $2 }' <<< "$oracle_output")
  oracle_publishable=$(awk -F'\t' '$1 == "publishable" { print $2 }' <<< "$oracle_output")
  python3 - "$case_id" "$canonical_binding" "$oracle_canonical" <<'PY'
import json
import sys

case_id, fixture_raw, oracle_raw = sys.argv[1:]
fixture = json.loads(fixture_raw)
oracle = json.loads(oracle_raw)
if len(oracle) != 12:
    raise SystemExit(f"{case_id}: authoritative binding must have 12 fields")
if oracle[:6] != fixture[:6] or oracle[7:11] != fixture[7:11]:
    raise SystemExit(f"{case_id}: fixture semantics differ from authoritative oracle")
PY
  [[ "$oracle_publishable" == "$publishable" ]] ||
    fail "$case_id fixture publishability differs from oracle"

  source_kinds["$source_kind"]=1
  case_requirement["$case_id"]=$requirement_key
  if [[ -n "${first_requirement[$stable_group]+present}" ]]; then
    if [[ "$stable_group" != changed_* &&
          "$stable_group" != unresolved &&
          "$stable_group" != ambiguous ]]; then
      [[ "${first_requirement[$stable_group]}" == "$requirement_key" ]] ||
        fail "$case_id changed stable requirement key during runtime binding"
      [[ "${first_binding[$stable_group]}" != "$binding_revision" ]] ||
        fail "$case_id runtime change did not change binding revision"
      [[ "${first_contract[$stable_group]}" == "$contract_revision" ]] ||
        fail "$case_id runtime binding changed approved contract revision"
      [[ "${first_input[$stable_group]}" != "$input_revision" ]] ||
        fail "$case_id runtime binding did not change review input revision"
    fi
  else
    first_requirement["$stable_group"]=$requirement_key
    first_binding["$stable_group"]=$binding_revision
    first_contract["$stable_group"]=$contract_revision
    first_input["$stable_group"]=$input_revision
  fi

  if [[ "$resolution_status" == unresolved ||
        "$resolution_status" == ambiguous ]]; then
    [[ "$publishable" == false ]] ||
      fail "$case_id unresolved/ambiguous binding is publishable"
  fi
  rows=$((rows + 1))
done < "$binding_fixture"
[[ "$rows" -eq 25 ]] ||
  fail "expected 25 plan-to-runtime binding rows, got $rows"

for source_kind in \
  linear-issue linear-comment linear-document \
  github-pr github-comment github-review github-check-run github-artifact \
  repository-file repository-commit manual-validation
do
  [[ -n "${source_kinds[$source_kind]+present}" ]] ||
    fail "missing finite source-kind fixture: $source_kind"
done

baseline_check=${case_requirement[github_check_head1]}
for changed_case in \
  github_check_semantics_changed \
  github_check_stage_changed \
  github_check_selector_changed
do
  [[ "$baseline_check" != "${case_requirement[$changed_case]}" ]] ||
    fail "$changed_case did not change requirement key"
done

assert_contains "$linear" 'evidence_requirement_key'
assert_contains "$linear" 'locator template'
assert_contains "$linear" \
  'current_implementation_issue.*current_linked_pr.*current_base.*current_head.*current_merge'
assert_not_contains "$linear" '\$\{provider_record_role\}'
assert_contains "$linear" 'provider_record_role.*static'
assert_contains "$linear" \
  'approved contract.*never contain.*issue UUID.*PR native ID.*head SHA.*check-run ID.*comment ID.*artifact ID.*commit SHA'
assert_contains "$core" 'maestro-acceptance-evidence-binding-v1'
assert_contains "$core" 'maestro-evidence-binding-context-v1'
assert_contains "$core" 'binding context revision'
assert_contains "$core" 'ambiguous.*non-publishable'
assert_contains "$review_skill" \
  '[Rr]esolve.*evidence requirement.*freshly confirmed native state'

for case_id in \
  review_publish_stale_acceptance \
  review_publish_stale_base \
  review_publish_stale_relink \
  review_publish_stale_source \
  review_publish_stale_capability \
  review_publish_stale_decision \
  review_publish_stale_head \
  review_publish_fresh_input_unresolved \
  review_binding_unresolved \
  review_binding_ambiguous \
  review_dispatch_failed_before_transfer \
  review_dispatch_transfers_worktree
do
  assert_contains "$failure_fixture" "^${case_id}[[:space:]]"
done
assert_contains "$review_skill" 'Immediately before.*GitHub.*publication'
assert_contains "$review_skill" \
  'fresh.*review context.*evidence templates.*acceptance-evidence manifest.*source closure.*capability.*decision-resolution.*review-input-v1'
assert_contains "$review_skill" 'byte-for-byte'
assert_contains "$review_skill" \
  'review-input-stale.*old.*new.*revision'
assert_contains "$review_skill" \
  'publish neither.*GitHub.*Linear'
assert_not_contains "$review_skill" \
  'return cleanup ownership to reconciliation'
assert_contains "$review_skill" \
  'After confirmed transfer, review retains cleanup ownership and cleans on every exit'
assert_contains "$review_skill" \
  'Reconciliation records.*review-stale-head.*only when'
assert_contains "$review_skill" \
  'After review begins, every'
assert_contains "$review_skill" \
  'review-input-stale.*never.*review-stale-head'
assert_contains "$reconcile" 'review-input-stale.*new.*eligible'

assert_file "$plugin_manifest"
assert_contains "$plugin_manifest" 'review-source-requirements-v1.json'
assert_contains "$plugin_manifest" 'scripts/review-source-closure.py'
assert_contains "$plugin_manifest" 'scripts/review-preparation.py'
assert_contains "$plugin_manifest" 'evidence-source-schema-v1.json'
assert_contains "$plugin_manifest" 'scripts/evidence-source-schema.py'
assert_contains "$plugin_manifest" 'skills/symphony-review/SKILL.md'
assert_contains "$plugin_manifest" 'agents/symphony-reviewer.md'
assert_contains "$plugin_manifest" 'references/symphony/core.md'
assert_contains "$plugin_manifest" 'references/symphony/linear.md'
assert_contains "$plugin_manifest" 'references/symphony/reconciliation.md'
assert_contains "$plugin_manifest" 'references/symphony/review.md'

python3 - "$plugin_manifest" "$review_skill" <<'PY'
import json
import re
import sys

manifest = json.load(open(sys.argv[1], encoding="utf-8"))
skill = open(sys.argv[2], encoding="utf-8").read()
declared_dependencies = set(
    re.findall(r"\$\{CLAUDE_PLUGIN_ROOT\}/([^`]+)", skill)
)
manifest_dependencies = set(manifest["skill_dependencies"])
if declared_dependencies != manifest_dependencies:
    raise SystemExit(
        f"skill dependency closure differs: {declared_dependencies!r} "
        f"!= {manifest_dependencies!r}"
    )
roster = skill.split("## Select the risk-adaptive roster", 1)[1].split("\n## ", 1)[0]

def selectable_lenses(text):
    return set(re.findall(r"`(maestro:[a-z0-9-]+)`", text)) - {
        "maestro:symphony-reviewer"
    }

declared_lenses = selectable_lenses(roster)
manifest_lenses = set(manifest["lens_sources"])
if declared_lenses != manifest_lenses:
    raise SystemExit(
        f"selectable lens closure differs: {declared_lenses!r} "
        f"!= {manifest_lenses!r}"
    )
mutated_lenses = selectable_lenses(
    roster + "\n- `maestro:performance-reviewer` for performance-sensitive changes.\n"
)
if mutated_lenses == manifest_lenses:
    raise SystemExit("generic lens conformance failed to detect a new selectable lens")
mandatory = set(manifest["mandatory_plugin_sources"])
required = {
    "review-source-requirements-v1.json",
    "scripts/review-source-closure.py",
    "scripts/review-preparation.py",
    "evidence-source-schema-v1.json",
    "scripts/evidence-source-schema.py",
    "skills/symphony-review/SKILL.md",
    "agents/symphony-reviewer.md",
} | manifest_dependencies
if mandatory != required:
    raise SystemExit(f"mandatory plugin closure differs: {mandatory!r} != {required!r}")
PY

assert_contains "$core" \
  'plugin-owned.*review-source-requirements-v1.json'
assert_contains "$core" \
  'owned.*worktree.*before.*source closure.*review-requested'
assert_contains "$reconcile" \
  'git rev-parse HEAD.*expected head SHA'
assert_contains "$review_skill" \
  'before use, revalidate'
assert_contains "$review_skill" \
  'repository identity.*detached attachment state'
assert_contains "$reconcile" \
  '[Oo]wnership transfer occurs only after confirmed dispatch'
assert_contains "$reconcile" \
  'cleanup-ledger owner update'

pass "Final Fix G plan-time requirements and exact-head closure"
