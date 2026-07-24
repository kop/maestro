#!/usr/bin/env python3
"""Canonical review-source-closure-v1 oracle."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
import unicodedata
from pathlib import Path, PurePosixPath
from typing import Any


VALIDATOR_KINDS = {
    "issue-validation-command",
    "kubernetes-helm-render",
    "docker-build-runtime",
    "github-actions-workflow",
}
CAPABILITY_STATES = {"present", "missing", "unavailable"}
GLOB_CHARACTERS = {"*", "?", "["}
MANDATORY_PLUGIN_SOURCE = "agents/symphony-reviewer.md"


class ClosureError(ValueError):
    pass


def canonical_json(value: Any) -> str:
    return json.dumps(
        value,
        ensure_ascii=False,
        separators=(",", ":"),
        allow_nan=False,
    )


def digest(prefix: str, value: Any) -> str:
    encoded = canonical_json(value).encode("utf-8")
    return f"{prefix}:{hashlib.sha256(encoded).hexdigest()}"


def normalize_text(value: Any, field: str) -> str:
    if not isinstance(value, str):
        raise ClosureError(f"{field} must be a string")
    value = unicodedata.normalize("NFC", value.replace("\r\n", "\n").replace("\r", "\n"))
    normalized = " ".join(value.split())
    if not normalized:
        raise ClosureError(f"{field} must not be empty")
    return normalized


def normalize_relative_path(value: Any, field: str) -> str:
    if not isinstance(value, str):
        raise ClosureError(f"{field} must be a string")
    value = unicodedata.normalize("NFC", value)
    if "\\" in value:
        raise ClosureError(f"{field} must use forward slashes")
    if any(character in value for character in GLOB_CHARACTERS):
        raise ClosureError(f"{field} must not contain glob syntax")
    path = PurePosixPath(value)
    if path.is_absolute():
        raise ClosureError(f"{field} must be repository-relative")
    if ".." in path.parts:
        raise ClosureError(f"{field} must not escape its root")
    normalized = path.as_posix()
    while normalized.startswith("./"):
        normalized = normalized[2:]
    if normalized in {"", "."}:
        raise ClosureError(f"{field} must name one exact file")
    return normalized


def resolve_contained(root: Path, relative_path: str, field: str) -> Path:
    root = root.resolve()
    candidate = (root / relative_path).resolve(strict=False)
    try:
        candidate.relative_to(root)
    except ValueError as error:
        raise ClosureError(f"{field} resolves outside its root") from error
    return candidate


def source_entry(root: Path, value: Any, kind: str, field: str) -> list[str]:
    relative_path = normalize_relative_path(value, field)
    path = resolve_contained(root, relative_path, field)
    if not path.exists():
        return [kind, relative_path, "missing", "missing"]
    if not path.is_file():
        return [kind, relative_path, "unavailable", "unavailable"]
    try:
        content_digest = hashlib.sha256(path.read_bytes()).hexdigest()
    except OSError:
        return [kind, relative_path, "unavailable", "unavailable"]
    return [kind, relative_path, "present", f"sha256:{content_digest}"]


def sorted_unique(items: list[Any]) -> list[Any]:
    keyed: dict[bytes, Any] = {}
    for item in items:
        key = canonical_json(item).encode("utf-8")
        keyed[key] = item
    return [keyed[key] for key in sorted(keyed)]


def require_exact_keys(value: dict[str, Any], expected: set[str], field: str) -> None:
    actual = set(value)
    if actual != expected:
        raise ClosureError(
            f"{field} keys differ: expected {sorted(expected)}, got {sorted(actual)}"
        )


def source_list(root: Path, values: Any, kind: str, field: str) -> list[Any]:
    if not isinstance(values, list):
        raise ClosureError(f"{field} must be an explicit list")
    entries = [
        source_entry(root, value, kind, f"{field}[{index}]")
        for index, value in enumerate(values)
    ]
    return sorted_unique(entries)


def normalized_path_list(values: Any, field: str) -> list[str]:
    if not isinstance(values, list):
        raise ClosureError(f"{field} must be an explicit list")
    paths = [
        normalize_relative_path(value, f"{field}[{index}]")
        for index, value in enumerate(values)
    ]
    return sorted_unique(paths)


def validator_requirement(value: Any, index: int) -> list[Any]:
    field = f"requirements.validators[{index}]"
    if not isinstance(value, dict):
        raise ClosureError(f"{field} must be an object")
    require_exact_keys(
        value,
        {"kind", "command", "config_sources", "capability_name"},
        field,
    )
    kind = normalize_text(value["kind"], f"{field}.kind")
    if kind not in VALIDATOR_KINDS:
        raise ClosureError(f"{field}.kind is not finite")
    command = normalize_text(value["command"], f"{field}.command")
    configs = normalized_path_list(
        value["config_sources"], f"{field}.config_sources"
    )
    capability_name = normalize_text(
        value["capability_name"], f"{field}.capability_name"
    )
    key_input = ["maestro-review-validator-key-v1", kind, command]
    return [
        "validator-requirement",
        kind,
        digest("review-validator-key-v1", key_input),
        command,
        configs,
        capability_name,
    ]


def build_requirements(requirements: Any) -> list[Any]:
    if not isinstance(requirements, dict):
        raise ClosureError("requirements must be an object")
    require_exact_keys(
        requirements,
        {"version", "plugin_sources", "policy_sources", "validators"},
        "requirements",
    )
    if requirements["version"] != "review-source-requirements-v1":
        raise ClosureError(
            "requirements version must be review-source-requirements-v1"
        )
    plugin_sources = normalized_path_list(
        requirements["plugin_sources"], "requirements.plugin_sources"
    )
    if MANDATORY_PLUGIN_SOURCE not in plugin_sources:
        raise ClosureError(
            f"requirements must include mandatory {MANDATORY_PLUGIN_SOURCE}"
        )
    policy_sources = normalized_path_list(
        requirements["policy_sources"], "requirements.policy_sources"
    )
    validators = requirements["validators"]
    if not isinstance(validators, list):
        raise ClosureError("requirements.validators must be an explicit list")
    validator_requirements = sorted_unique(
        [validator_requirement(value, index) for index, value in enumerate(validators)]
    )
    return [
        "review-source-requirements-v1",
        plugin_sources,
        policy_sources,
        validator_requirements,
    ]


def validator_entry(repository_root: Path, value: Any, index: int) -> list[Any]:
    field = f"validators[{index}]"
    if not isinstance(value, dict):
        raise ClosureError(f"{field} must be an object")
    require_exact_keys(
        value,
        {
            "kind",
            "command",
            "config_sources",
            "implicit_sources_declared",
            "capability",
        },
        field,
    )
    kind = normalize_text(value["kind"], f"{field}.kind")
    if kind not in VALIDATOR_KINDS:
        raise ClosureError(f"{field}.kind is not finite")
    command = normalize_text(value["command"], f"{field}.command")
    if value["implicit_sources_declared"] is not True:
        raise ClosureError(f"{field} has undeclared implicit source closure")
    configs = source_list(
        repository_root,
        value["config_sources"],
        "validator-config",
        f"{field}.config_sources",
    )

    capability = value["capability"]
    if not isinstance(capability, dict):
        raise ClosureError(f"{field}.capability must be an object")
    require_exact_keys(capability, {"state", "name", "version"}, f"{field}.capability")
    state = normalize_text(capability["state"], f"{field}.capability.state")
    if state not in CAPABILITY_STATES:
        raise ClosureError(f"{field}.capability.state is not finite")
    name = normalize_text(capability["name"], f"{field}.capability.name")
    version = normalize_text(capability["version"], f"{field}.capability.version")
    if state == "present" and version in {"missing", "unavailable"}:
        raise ClosureError(f"{field}.capability present state needs a version")
    if state != "present" and version != state:
        raise ClosureError(f"{field}.capability sentinel does not match state")

    key_input = ["maestro-review-validator-key-v1", kind, command]
    stable_key = digest("review-validator-key-v1", key_input)
    return [
        "validator",
        kind,
        stable_key,
        command,
        configs,
        ["validator-capability", name, state, version],
    ]


def build_closure(
    plugin_root: Path,
    repository_root: Path,
    descriptor: Any,
    requirements: Any,
) -> list[Any]:
    required = build_requirements(requirements)
    if not isinstance(descriptor, dict):
        raise ClosureError("descriptor must be an object")
    require_exact_keys(
        descriptor,
        {"version", "plugin_sources", "policy_sources", "validators"},
        "descriptor",
    )
    if descriptor["version"] != "review-source-closure-v1":
        raise ClosureError("descriptor version must be review-source-closure-v1")

    plugin_sources = source_list(
        plugin_root, descriptor["plugin_sources"], "plugin-source", "plugin_sources"
    )
    actual_plugin_paths = [entry[1] for entry in plugin_sources]
    if actual_plugin_paths != required[1]:
        raise ClosureError("plugin_sources differ from authoritative requirements")
    policy_sources = source_list(
        repository_root,
        descriptor["policy_sources"],
        "policy-source",
        "policy_sources",
    )
    actual_policy_paths = [entry[1] for entry in policy_sources]
    if actual_policy_paths != required[2]:
        raise ClosureError("policy_sources differ from authoritative requirements")
    validators = descriptor["validators"]
    if not isinstance(validators, list):
        raise ClosureError("validators must be an explicit list")
    validator_entries = sorted_unique(
        [
            validator_entry(repository_root, value, index)
            for index, value in enumerate(validators)
        ]
    )
    actual_validator_requirements = sorted_unique(
        [
            [
                "validator-requirement",
                entry[1],
                entry[2],
                entry[3],
                [config[1] for config in entry[4]],
                entry[5][1],
            ]
            for entry in validator_entries
        ]
    )
    if actual_validator_requirements != required[3]:
        raise ClosureError("validators differ from authoritative requirements")
    requirements_revision = digest("review-source-requirements-v1", required)
    return [
        "review-source-closure-v1",
        requirements_revision,
        plugin_sources,
        policy_sources,
        validator_entries,
    ]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--plugin-root", required=True, type=Path)
    parser.add_argument("--repository-root", required=True, type=Path)
    parser.add_argument("--requirements", required=True, type=Path)
    parser.add_argument("--descriptor", required=True, type=Path)
    args = parser.parse_args()
    try:
        descriptor = json.loads(args.descriptor.read_text(encoding="utf-8"))
        requirements = json.loads(args.requirements.read_text(encoding="utf-8"))
        closure = build_closure(
            args.plugin_root.resolve(),
            args.repository_root.resolve(),
            descriptor,
            requirements,
        )
    except (ClosureError, OSError, UnicodeError, json.JSONDecodeError) as error:
        print(f"review-source-closure error: {error}", file=sys.stderr)
        return 2

    print(f"canonical\t{canonical_json(closure)}")
    print(f"revision\t{digest('review-source-closure-v1', closure)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
