#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")/.."
source tests/lib/assertions.sh

helper=scripts/review-preparation.py
fixture=tests/fixtures/review-preparation-cases.tsv
assert_file "$helper"
assert_executable "$helper"
assert_file "$fixture"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

python3 - "$helper" "$fixture" "$tmp_dir" <<'PY'
import copy
import json
import pathlib
import shutil
import subprocess
import sys

helper, fixture, tmp_dir = sys.argv[1:]
tmp_dir = pathlib.Path(tmp_dir)
plugin_root = tmp_dir / "plugin-root"
manifest = json.loads(
    pathlib.Path("review-source-requirements-v1.json").read_text(encoding="utf-8")
)
source_paths = set(manifest["mandatory_plugin_sources"])
source_paths.update(manifest["skill_dependencies"])
for paths in manifest["lens_sources"].values():
    source_paths.update(paths)
for relative in source_paths:
    destination = plugin_root / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(relative, destination)
base = {
    "review_identity": {
        "symphony": "symphony-1",
        "implementation_issue": "issue-1",
        "repository": "owner/repo",
        "pr": "pr-101",
        "base": "base-1",
        "head": "head-1",
        "contract_revision": "contract-v1:one",
        "dag_revision": "dag-v1:one",
        "review_policy_revision": "review-policy-v1:one",
    },
    "evidence_requirements": [
        [
            "maestro-evidence-requirement-key-v1",
            "criterion-v1:criterion",
            "compatibility evidence",
            "review",
            "github-check-run",
            "integration-check",
            [
                "locator-template-v1",
                "github-check-run",
                "owner/repo",
                "${current_head}",
                "integration-check",
                "integration",
            ],
        ]
    ],
    "preworktree_bindings": [
        [
            "maestro-acceptance-evidence-binding-v1",
            "criterion-v1:criterion",
            "",
            "github-check-run",
            [
                "locator-template-v1",
                "github-check-run",
                "owner/repo",
                "${current_head}",
                "integration-check",
                "integration",
            ],
            [
                "resolved-locator-v1",
                "github-check-run",
                "owner/repo",
                "head-1",
                "integration-check",
                "integration",
            ],
            "evidence-binding-context-v1:" + "b" * 64,
            "exact",
            "present",
            "check-1",
            "attempt-1",
            "evidence-v1:proof-1",
        ]
    ],
    "capabilities": [["capability", "git", "present", "2.45.0"]],
    "decision_resolutions": [
        ["decision-resolution", "pause-1", "resolution-1", "contract-v1:one"]
    ],
    "repository_source_requirements": [
        ["repository-source-requirement", "package.json"]
    ],
}
requirement_key = "evidence-requirement-key-v1:" + __import__("hashlib").sha256(
    json.dumps(base["evidence_requirements"][0], separators=(",", ":")).encode()
).hexdigest()
base["preworktree_bindings"][0][2] = requirement_key


def invoke(case_id, value, expect_ok=True, root=plugin_root):
    path = tmp_dir / f"{case_id}.json"
    path.write_text(
        json.dumps(value, separators=(",", ":")),
        encoding="utf-8",
    )
    result = subprocess.run(
        [helper, "--plugin-root", str(root), "--input", str(path)],
        text=True,
        capture_output=True,
    )
    if expect_ok and result.returncode:
        raise SystemExit(f"{case_id}: valid preparation rejected: {result.stderr}")
    if not expect_ok and result.returncode == 0:
        raise SystemExit(f"{case_id}: invalid preparation accepted")
    if not expect_ok:
        return {}
    return dict(line.split("\t", 1) for line in result.stdout.splitlines())


changes = {
    "none": lambda value: None,
    "evidence": lambda value: value["preworktree_bindings"].__setitem__(
        0,
        [
            *value["preworktree_bindings"][0][:-3],
            "check-2",
            "attempt-2",
            "evidence-v1:proof-2",
        ],
    ),
    "capability": lambda value: value["capabilities"].append(
        ["capability", "helm", "present", "3.17.0"]
    ),
    "decision": lambda value: value["decision_resolutions"].append(
        ["decision-resolution", "pause-2", "resolution-2", "contract-v1:one"]
    ),
    "plugin": lambda value: None,
    "base": lambda value: value["review_identity"].__setitem__("base", "base-2"),
    "relink": lambda value: value["review_identity"].__setitem__(
        "implementation_issue", "issue-2"
    ),
    "repository-requirements": lambda value: value[
        "repository_source_requirements"
    ].append(["repository-source-requirement", "pyproject.toml"]),
}

baseline = None
for line in pathlib.Path(fixture).read_text(encoding="utf-8").splitlines()[1:]:
    case_id, change, expected_same = line.split("\t")
    value = copy.deepcopy(base)
    changes[change](value)
    root = plugin_root
    if change == "plugin":
        root = tmp_dir / "changed-plugin-root"
        shutil.copytree(plugin_root, root)
        with (root / "references/symphony/review.md").open(
            "a", encoding="utf-8"
        ) as handle:
            handle.write("\nchanged plugin policy\n")
    output = invoke(case_id, value, root=root)
    reservation = output["reservation"]
    preparation = output["preparation"]
    if not reservation.startswith("review-worktree-reservation-v1:"):
        raise SystemExit(f"{case_id}: reservation prefix differs")
    if not preparation.startswith("review-preparation-v1:"):
        raise SystemExit(f"{case_id}: preparation prefix differs")
    if baseline is None:
        baseline = reservation
    if (reservation == baseline) != (expected_same == "true"):
        raise SystemExit(f"{case_id}: reservation generation equality differs")

for field in base:
    invalid = copy.deepcopy(base)
    del invalid[field]
    invoke(f"missing-{field}", invalid, expect_ok=False)

for field in base["review_identity"]:
    invalid = copy.deepcopy(base)
    del invalid["review_identity"][field]
    invoke(f"missing-identity-{field}", invalid, expect_ok=False)

historical = copy.deepcopy(base)
historical["historical_reservation"] = "review-worktree-reservation-v1:old"
invoke("caller-selected-historical", historical, expect_ok=False)

for field, malformed in {
    "evidence_requirements": [["maestro-evidence-requirement-key-v1"]],
    "preworktree_bindings": [["maestro-acceptance-evidence-binding-v1"]],
    "capabilities": [["capability"]],
    "decision_resolutions": [["decision-resolution"]],
    "repository_source_requirements": [["repository-source-requirement", "../escape"]],
}.items():
    invalid = copy.deepcopy(base)
    invalid[field] = malformed
    invoke(f"malformed-{field}", invalid, expect_ok=False)

omitted_binding = copy.deepcopy(base)
omitted_binding["preworktree_bindings"] = []
invoke("omitted-current-binding", omitted_binding, expect_ok=False)

wrong_context_prefix = copy.deepcopy(base)
wrong_context_prefix["preworktree_bindings"][0][6] = "attacker-v1:" + "b" * 64
invoke("wrong-binding-context-prefix", wrong_context_prefix, expect_ok=False)

spelling = copy.deepcopy(base)
spelling["capabilities"][0][1] = "  git  "
if invoke("canonical-capability-spelling", spelling)["reservation"] != baseline:
    raise SystemExit("equivalent capability spelling changed reservation")
PY

pass "pre-worktree review preparation and reservation identity"
