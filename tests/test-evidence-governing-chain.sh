#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")/.."
source tests/lib/assertions.sh

helper=scripts/evidence-source-schema.py
fixture=tests/fixtures/evidence-stage-cases.tsv
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

helper, fixture, tmp_dir = sys.argv[1:]
tmp_dir = pathlib.Path(tmp_dir)
schema = json.loads(pathlib.Path("evidence-source-schema-v1.json").read_text())

expected_relationships = {
    "symphony-implementation": (
        "symphony",
        "current_implementation_issue",
        "current_implementation_issue",
    ),
    "implementation-repository": (
        "current_implementation_issue",
        "repository",
        "repository",
    ),
    "implementation-linked-pr": (
        "repository",
        "current_linked_pr",
        "current_linked_pr",
    ),
    "linked-pr-base": (
        "current_linked_pr",
        "current_base",
        "current_base",
    ),
    "linked-pr-head": (
        "current_linked_pr",
        "current_head",
        "current_head",
    ),
    "linked-pr-merge": (
        "current_linked_pr",
        "current_merge",
        "current_merge",
    ),
}
if set(schema.get("governing_relationships", {})) != set(expected_relationships):
    raise SystemExit("schema does not own the complete finite governing relationship set")
if schema.get("provider_confirmation_fields") != [
    "provider_state",
    "provider_record_id",
    "provider_revision",
    "provider_evidence",
]:
    raise SystemExit("schema does not own the provider identity/revision proof fields")
for name, (source, target, governs) in expected_relationships.items():
    definition = schema["governing_relationships"][name]
    if (
        definition.get("from_context") != source
        or definition.get("to_context") != target
        or definition.get("governs") != governs
        or not definition.get("provider_locator_shape")
    ):
        raise SystemExit(f"{name}: incomplete governing relationship definition")

context_values = {
    "symphony": "symphony-1",
    "current_implementation_issue": "issue-77",
    "repository": "owner/repo",
    "current_linked_pr": "pr-101",
    "current_base": "base-1",
    "current_head": "head-1",
    "current_merge": "merge-1",
}


def context_locator(field, values):
    if field == "symphony":
        return ["authoritative-context-v1", "linear-issue", values[field], "symphony-control"]
    if field == "current_implementation_issue":
        return [
            "authoritative-context-v1", "linear-issue", values[field],
            "implementation-of", values["symphony"],
        ]
    if field == "repository":
        return [
            "authoritative-context-v1", "github-repository", values[field],
            "repository-for", values["current_implementation_issue"],
        ]
    if field == "current_linked_pr":
        return [
            "authoritative-context-v1", "github-pr", values["repository"], values[field],
            "linked-to", values["current_implementation_issue"],
        ]
    role = {
        "current_base": "base",
        "current_head": "head",
        "current_merge": "merge",
    }[field]
    return [
        "authoritative-context-v1", "github-pr", values["repository"],
        values["current_linked_pr"], role, values[field],
    ]


def confirmed_context(values=context_values):
    return {
        field: {
            "value": value,
            "provider_locator": context_locator(field, values),
            "provider_state": "present",
            "provider_record_id": f"context-record:{field}",
            "provider_revision": f"context-revision:{field}",
            "provider_evidence": f"context-evidence:{field}",
        }
        for field, value in values.items()
    }


def relationship_locator(name, values=context_values):
    if name == "symphony-implementation":
        identities = [values["symphony"], values["current_implementation_issue"]]
    elif name == "implementation-repository":
        identities = [values["current_implementation_issue"], values["repository"]]
    elif name == "implementation-linked-pr":
        identities = [
            values["current_implementation_issue"],
            values["repository"],
            values["current_linked_pr"],
        ]
    else:
        terminal = expected_relationships[name][1]
        identities = [
            values["repository"],
            values["current_linked_pr"],
            values[terminal],
        ]
    return ["authoritative-relationship-v1", name, *identities]


def confirmation(name, revision=None):
    source, target, governs = expected_relationships[name]
    return {
        "from_context": source,
        "to_context": target,
        "governs": governs,
        "provider_locator": relationship_locator(name),
        "provider_state": "present",
        "provider_record_id": f"relationship-record:{name}",
        "provider_revision": revision or f"relationship-revision:{name}",
        "provider_evidence": f"relationship-evidence:{name}",
    }


def confirmed_relationships():
    return {name: [confirmation(name)] for name in expected_relationships}


def invoke(value, expect_ok=True):
    path = tmp_dir / f"input-{invoke.counter}.json"
    invoke.counter += 1
    path.write_text(json.dumps(value, separators=(",", ":")), encoding="utf-8")
    result = subprocess.run(
        [helper, "--plugin-root", ".", "binding", "--input", str(path)],
        text=True,
        capture_output=True,
    )
    if expect_ok and result.returncode:
        raise SystemExit(f"binding rejected valid chain envelope: {result.stderr}")
    if not expect_ok and result.returncode == 0:
        raise SystemExit("binding accepted invalid chain envelope")
    if not expect_ok:
        return {}
    return dict(line.split("\t", 1) for line in result.stdout.splitlines())


invoke.counter = 0


def resolved_locator(locator):
    replacements = {
        "${current_implementation_issue}": context_values["current_implementation_issue"],
        "${current_linked_pr}": context_values["current_linked_pr"],
        "${current_base}": context_values["current_base"],
        "${current_head}": context_values["current_head"],
        "${current_merge}": context_values["current_merge"],
    }
    return [
        "resolved-locator-v1" if value == "locator-template-v1" else replacements.get(value, value)
        for value in locator
    ]


def binding(stage, kind, role, locator):
    resolved = resolved_locator(locator)
    return {
        "requirement": {
            "criterion_key": f"criterion-v1:{kind}:{role}",
            "required_outcome": "provider-confirmed compatibility",
            "evidence_stage": stage,
            "source_kind": kind,
            "provider_record_role": role,
            "locator_template": locator,
        },
        "runtime_context": confirmed_context(),
        "runtime_relationships": confirmed_relationships(),
        "provider_query": {"resolved_locator": resolved},
        "provider_results": [{
            "resolved_locator": resolved,
            "evidence_state": "present",
            "provider_record_id": f"terminal-record:{kind}:{role}",
            "provider_revision": "terminal-revision:1",
            "provider_evidence": "evidence-v1:terminal-proof",
        }],
    }


lines = pathlib.Path(fixture).read_text(encoding="utf-8").splitlines()
cases = []
for line in lines[1:]:
    case_id, stage, kind, role, locator, valid, _, _ = line.split("\t")
    if valid == "true":
        cases.append((case_id, binding(stage, kind, role, json.loads(locator))))
cases.append((
    "github_pr_base",
    binding(
        "review",
        "github-pr",
        "linked-pr-base",
        [
            "locator-template-v1", "github-pr", "owner/repo",
            "${current_linked_pr}", "linked-pr-base", "base-sha",
            "${current_base}",
        ],
    ),
))

seen_kinds = set()
seen_tokens = set()
for case_id, value in cases:
    kind = value["requirement"]["source_kind"]
    seen_kinds.add(kind)
    variant_matches = []
    for variant in schema["source_kinds"][kind]["variants"]:
        if (
            value["requirement"]["evidence_stage"] in variant["stages"]
            and value["requirement"]["provider_record_role"] in variant["provider_record_roles"]
        ):
            variant_matches.append(variant)
    if len(variant_matches) != 1:
        raise SystemExit(f"{case_id}: test could not identify one schema variant")
    contract = variant_matches[0].get("governing_context")
    if not isinstance(contract, dict):
        raise SystemExit(f"{case_id}: schema variant lacks governing_context")
    if set(contract) != {"required_entries", "required_relationships", "terminal_context"}:
        raise SystemExit(f"{case_id}: governing_context keys are not exact")
    required_entries = contract["required_entries"]
    required_relationships = contract["required_relationships"]
    terminal_context = contract["terminal_context"]
    seen_tokens.add(terminal_context)
    if required_entries[:3] != [
        "symphony", "current_implementation_issue", "repository"
    ]:
        raise SystemExit(f"{case_id}: governing chain omits Symphony/issue/repository")
    relationship_names = [entry["edge"] for entry in required_relationships]
    if relationship_names[:2] != [
        "symphony-implementation", "implementation-repository"
    ]:
        raise SystemExit(f"{case_id}: governing chain omits its authority root edges")
    for entry in required_relationships:
        definition = schema["governing_relationships"][entry["edge"]]
        if entry.get("governs") != definition["governs"]:
            raise SystemExit(f"{case_id}: edge does not declare its governed token")

    exact = invoke(value)
    canonical = json.loads(exact["canonical"])
    if exact["publishable"] != "true" or canonical[7] != "exact":
        raise SystemExit(f"{case_id}: complete governing chain was not exact")
    base_revision = canonical[6]

    for field in required_entries:
        severed = copy.deepcopy(value)
        severed["runtime_context"][field].update({
            "provider_state": "missing",
            "provider_record_id": "missing",
            "provider_revision": "missing",
            "provider_evidence": "missing",
        })
        if invoke(severed)["publishable"] != "false":
            raise SystemExit(f"{case_id}: missing {field} entry was publishable")

    for edge in relationship_names:
        severed = copy.deepcopy(value)
        severed["runtime_relationships"][edge] = []
        output = invoke(severed)
        if output["publishable"] != "false" or json.loads(output["canonical"])[7] != "unresolved":
            raise SystemExit(f"{case_id}: severed {edge} was not unresolved")

        multiple = copy.deepcopy(value)
        second = confirmation(edge, revision=f"relationship-revision:{edge}:other")
        second["provider_record_id"] += ":other"
        multiple["runtime_relationships"][edge].append(second)
        output = invoke(multiple)
        if output["publishable"] != "false" or json.loads(output["canonical"])[7] != "ambiguous":
            raise SystemExit(f"{case_id}: multiply confirmed {edge} was not ambiguous")

        relinked = copy.deepcopy(value)
        relinked["runtime_relationships"][edge][0]["provider_locator"][-1] = "unrelated"
        output = invoke(relinked)
        if output["publishable"] != "false" or json.loads(output["canonical"])[7] != "ambiguous":
            raise SystemExit(f"{case_id}: relinked {edge} was not ambiguous")

    changed = copy.deepcopy(value)
    changed_edge = relationship_names[-1]
    changed["runtime_relationships"][changed_edge][0]["provider_revision"] += ":2"
    changed_output = invoke(changed)
    changed_canonical = json.loads(changed_output["canonical"])
    if changed_output["publishable"] != "true":
        raise SystemExit(f"{case_id}: valid relationship revision change was rejected")
    if changed_canonical[6] == base_revision:
        raise SystemExit(f"{case_id}: relationship revision did not change context digest")

if seen_kinds != set(schema["source_kinds"]):
    raise SystemExit("governing-chain matrix did not cover every finite source kind")
if seen_tokens != set(schema["binding_tokens"]):
    raise SystemExit("governing-chain matrix did not cover every runtime token")

# A raw terminal record from an unrelated PR must not satisfy the current chain.
unrelated = copy.deepcopy(next(value for case_id, value in cases if case_id == "github_check_review"))
unrelated["runtime_relationships"]["linked-pr-head"][0]["provider_locator"][-2] = "pr-unrelated"
output = invoke(unrelated)
if output["publishable"] != "false" or json.loads(output["canonical"])[7] != "ambiguous":
    raise SystemExit("unrelated PR terminal evidence satisfied the current chain")
PY

echo "governing evidence-chain tests passed"
