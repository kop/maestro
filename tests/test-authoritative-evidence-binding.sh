#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")/.."
source tests/lib/assertions.sh

helper=scripts/evidence-source-schema.py
fixture=tests/fixtures/evidence-binding-context-cases.tsv
assert_executable "$helper"
assert_file "$fixture"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

python3 - "$helper" "$fixture" "$tmp_dir" <<'PY'
import copy
import json
import pathlib
import subprocess
import sys
import unicodedata

helper, fixture, tmp_dir = sys.argv[1:]
tmp_dir = pathlib.Path(tmp_dir)
header = (
    "case_id\ttoken\tevidence_stage\tsource_kind\tprovider_record_role\t"
    "locator_template\tresolved_locator"
)
lines = pathlib.Path(fixture).read_text(encoding="utf-8").splitlines()
if lines[0] != header:
    raise SystemExit("unexpected authoritative binding fixture header")

context = {
    "symphony": "symphony-1",
    "current_implementation_issue": "issue-77",
    "repository": "owner/repo",
    "current_linked_pr": "pr-101",
    "current_base": "base-1",
    "current_head": "head-1",
    "current_merge": "merge-1",
}

def confirmed_context(values):
    values = copy.deepcopy(values)
    locators = {
        "symphony": [
            "authoritative-context-v1",
            "linear-issue",
            values["symphony"],
            "symphony-control",
        ],
        "current_implementation_issue": [
            "authoritative-context-v1",
            "linear-issue",
            values["current_implementation_issue"],
            "implementation-of",
            values["symphony"],
        ],
        "repository": [
            "authoritative-context-v1",
            "github-repository",
            values["repository"],
            "repository-for",
            values["current_implementation_issue"],
        ],
        "current_linked_pr": [
            "authoritative-context-v1",
            "github-pr",
            values["repository"],
            values["current_linked_pr"],
            "linked-to",
            values["current_implementation_issue"],
        ],
        "current_base": [
            "authoritative-context-v1",
            "github-pr",
            values["repository"],
            values["current_linked_pr"],
            "base",
            values["current_base"],
        ],
        "current_head": [
            "authoritative-context-v1",
            "github-pr",
            values["repository"],
            values["current_linked_pr"],
            "head",
            values["current_head"],
        ],
        "current_merge": [
            "authoritative-context-v1",
            "github-pr",
            values["repository"],
            values["current_linked_pr"],
            "merge",
            values["current_merge"],
        ],
    }
    return {
        field: {
            "value": value,
            "provider_locator": locators[field],
            "provider_state": "missing" if value == "unresolved" else "present",
            "provider_record_id": (
                "missing" if value == "unresolved" else f"context-record:{field}"
            ),
            "provider_revision": (
                "missing" if value == "unresolved" else f"context-revision:{field}"
            ),
            "provider_evidence": (
                "missing" if value == "unresolved" else f"context-evidence:{field}"
            ),
        }
        for field, value in values.items()
    }


def invoke(mode, value, expect_ok=True):
    path = tmp_dir / f"input-{invoke.counter}.json"
    invoke.counter += 1
    path.write_text(
        json.dumps(value, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    result = subprocess.run(
        [helper, "--plugin-root", ".", mode, "--input", str(path)],
        text=True,
        capture_output=True,
    )
    if expect_ok and result.returncode:
        raise SystemExit(f"{mode} rejected valid input: {result.stderr}")
    if not expect_ok and result.returncode == 0:
        raise SystemExit(f"{mode} accepted invalid input: {value!r}")
    if not expect_ok:
        return {}
    return dict(line.split("\t", 1) for line in result.stdout.splitlines())


invoke.counter = 0


def requirement(stage, kind, role, locator, criterion="criterion-v1:criterion"):
    return {
        "criterion_key": criterion,
        "required_outcome": "compatibility evidence",
        "evidence_stage": stage,
        "source_kind": kind,
        "provider_record_role": role,
        "locator_template": locator,
    }


def binding(req, resolved, runtime_context=None, results=None, assertions=None):
    runtime_context = confirmed_context(runtime_context or context)
    resolved = copy.deepcopy(resolved)
    result = {
        "requirement": req,
        "runtime_context": runtime_context,
        "provider_query": {"resolved_locator": resolved},
        "provider_results": results
        if results is not None
        else [
            {
                "resolved_locator": resolved,
                "evidence_state": "present",
                "provider_record_id": "record-1",
                "provider_revision": "revision-1",
                "provider_evidence": "evidence-v1:proof-1",
            }
        ],
    }
    if assertions is not None:
        result["assertions"] = assertions
    return result


cases = {}
for line in lines[1:]:
    case_id, token, stage, kind, role, raw_template, raw_resolved = line.split("\t")
    req = requirement(stage, kind, role, json.loads(raw_template))
    resolved = json.loads(raw_resolved)
    output = invoke("binding", binding(req, resolved))
    canonical = json.loads(output["canonical"])
    if canonical[5] != resolved or canonical[7] != "exact":
        raise SystemExit(f"{case_id}: oracle did not derive exact locator/outcome")
    if output["publishable"] != "true":
        raise SystemExit(f"{case_id}: authoritative exact binding not publishable")
    cases[case_id] = (req, resolved, canonical)

invoke(
    "binding",
    {
        **binding(cases["head_sha"][0], cases["head_sha"][1]),
        "runtime_context": copy.deepcopy(context),
    },
    expect_ok=False,
)
unconfirmed_relink = binding(cases["head_sha"][0], cases["head_sha"][1])
unconfirmed_relink["runtime_context"]["current_head"]["value"] = "unrelated-head"
invoke("binding", unconfirmed_relink, expect_ok=False)

unresolved_governance_values = copy.deepcopy(context)
unresolved_governance_values["symphony"] = "unresolved"
unresolved_governance = invoke(
    "binding",
    binding(
        cases["head_sha"][0],
        cases["head_sha"][1],
        unresolved_governance_values,
    ),
)
if unresolved_governance["publishable"] != "false":
    raise SystemExit("unresolved selected Symphony context was publishable")

missing_head_confirmation = binding(cases["head_sha"][0], cases["head_sha"][1])
missing_head_confirmation["runtime_context"]["current_head"].update(
    {
        "provider_state": "missing",
        "provider_record_id": "missing",
        "provider_revision": "missing",
        "provider_evidence": "missing",
    }
)
missing_head = invoke("binding", missing_head_confirmation)
if missing_head["publishable"] != "false":
    raise SystemExit("unconfirmed selected head context was publishable")

head_req, head_locator, head_canonical = cases["head_sha"]
same_context_requirement = copy.deepcopy(head_req)
same_context_requirement["criterion_key"] = "criterion-v1:another-criterion"
same_context_output = invoke(
    "binding",
    binding(same_context_requirement, head_locator),
)
if json.loads(same_context_output["canonical"])[6] != head_canonical[6]:
    raise SystemExit("requirement identity contaminated binding context revision")

unrelated = copy.deepcopy(context)
unrelated["current_merge"] = "merge-unrelated"
unrelated_output = invoke("binding", binding(head_req, head_locator, unrelated))
if json.loads(unrelated_output["canonical"])[6] != head_canonical[6]:
    raise SystemExit("unselected runtime context changed binding context revision")

changed_head = copy.deepcopy(context)
changed_head["current_head"] = "head-2"
changed_locator = copy.deepcopy(head_locator)
changed_locator[3] = "head-2"
changed_output = invoke(
    "binding",
    binding(head_req, changed_locator, changed_head),
)
if json.loads(changed_output["canonical"])[6] == head_canonical[6]:
    raise SystemExit("selected authoritative head did not change context revision")

asserted = binding(
    head_req,
    head_locator,
    assertions={
        "resolved_locator": head_locator,
        "binding_context_revision": head_canonical[6],
    },
)
invoke("binding", asserted)
fabricated = copy.deepcopy(asserted)
fabricated["assertions"]["binding_context_revision"] = "evidence-binding-context-v1:fabricated"
invoke("binding", fabricated, expect_ok=False)
fabricated = copy.deepcopy(asserted)
fabricated["assertions"]["resolved_locator"][3] = "unrelated-head"
invoke("binding", fabricated, expect_ok=False)

query_mismatch = binding(head_req, head_locator)
query_mismatch["provider_query"]["resolved_locator"][3] = "unrelated-head"
invoke("binding", query_mismatch, expect_ok=False)
result_mismatch = binding(head_req, head_locator)
result_mismatch["provider_results"][0]["resolved_locator"][3] = "unrelated-head"
invoke("binding", result_mismatch, expect_ok=False)

missing_context = copy.deepcopy(context)
missing_context["current_head"] = "unresolved"
unresolved_locator = copy.deepcopy(head_locator)
unresolved_locator[3] = "unresolved"
unresolved = invoke(
    "binding",
    binding(head_req, unresolved_locator, missing_context, results=[]),
)
unresolved_canonical = json.loads(unresolved["canonical"])
if unresolved_canonical[7:9] != ["unresolved", "missing"]:
    raise SystemExit("missing token did not derive unresolved/missing binding")
if unresolved["publishable"] != "false":
    raise SystemExit("underivable token was publishable")

no_result = invoke("binding", binding(head_req, head_locator, results=[]))
if json.loads(no_result["canonical"])[7:9] != ["unresolved", "missing"]:
    raise SystemExit("missing provider lookup did not derive unresolved/missing")

multiple = binding(head_req, head_locator)
multiple["provider_results"].append(
    {
        "resolved_locator": head_locator,
        "evidence_state": "present",
        "provider_record_id": "record-2",
        "provider_revision": "revision-2",
        "provider_evidence": "evidence-v1:proof-2",
    }
)
ambiguous = invoke("binding", multiple)
if json.loads(ambiguous["canonical"])[7:9] != ["ambiguous", "unavailable"]:
    raise SystemExit("multiple provider matches did not derive ambiguous/unavailable")

for field in context:
    missing = binding(head_req, head_locator)
    del missing["runtime_context"][field]
    invoke("binding", missing, expect_ok=False)

whitespace_a = requirement(
    "review",
    "github-check-run",
    "integration-check",
    [
        "locator-template-v1",
        "github-check-run",
        "owner/repo",
        "${current_head}",
        "integration-check",
        " integration   check ",
    ],
    criterion=" criterion-v1:criterion ",
)
whitespace_b = copy.deepcopy(whitespace_a)
whitespace_b["criterion_key"] = "criterion-v1:criterion"
whitespace_b["locator_template"][-1] = "integration check"
key_a = invoke("requirement", whitespace_a)["key"]
key_b = invoke("requirement", whitespace_b)["key"]
if key_a != key_b:
    raise SystemExit("equivalent normalized requirement spellings changed key")

nfd = copy.deepcopy(whitespace_b)
nfd["locator_template"][-1] = unicodedata.normalize("NFD", "intégration")
nfc = copy.deepcopy(whitespace_b)
nfc["locator_template"][-1] = unicodedata.normalize("NFC", "intégration")
if invoke("requirement", nfd)["key"] != invoke("requirement", nfc)["key"]:
    raise SystemExit("NFC-equivalent selector spellings changed key")

path_a = requirement(
    "review",
    "repository-file",
    "compatibility-report",
    [
        "locator-template-v1",
        "repository-file",
        "owner/repo",
        "${current_head}",
        "compatibility-report",
        "./reports/./compatibility.json",
    ],
)
path_b = copy.deepcopy(path_a)
path_b["locator_template"][-1] = "reports/compatibility.json"
if invoke("requirement", path_a)["key"] != invoke("requirement", path_b)["key"]:
    raise SystemExit("redundant safe path components changed requirement key")
path_changed = copy.deepcopy(path_b)
path_changed["locator_template"][-1] = "reports/migration.json"
if invoke("requirement", path_b)["key"] == invoke("requirement", path_changed)["key"]:
    raise SystemExit("meaningful repository path change did not change key")

for unsafe in (
    "/reports/compatibility.json",
    "../reports/compatibility.json",
    "reports/*.json",
    r"reports\compatibility.json",
):
    invalid = copy.deepcopy(path_b)
    invalid["locator_template"][-1] = unsafe
    invoke("requirement", invalid, expect_ok=False)
PY

pass "authoritative runtime evidence binding context"
