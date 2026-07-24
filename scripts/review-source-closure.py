#!/usr/bin/env python3
"""Canonical review-source-closure-v1 oracle."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
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
PLUGIN_REQUIREMENTS_PATH = "review-source-requirements-v1.json"
MANDATORY_PLUGIN_SOURCES = {
    PLUGIN_REQUIREMENTS_PATH,
    "scripts/review-source-closure.py",
    "skills/symphony-review/SKILL.md",
    "references/symphony/core.md",
    "references/symphony/linear.md",
    "references/symphony/reconciliation.md",
    "references/symphony/review.md",
    "agents/symphony-reviewer.md",
}
SKILL_DEPENDENCIES = {
    "references/symphony/core.md",
    "references/symphony/linear.md",
    "references/symphony/reconciliation.md",
    "references/symphony/review.md",
}
LENS_SOURCES = {
    "maestro:code-reviewer": ["agents/code-reviewer.md"],
    "maestro:comment-analyzer": ["agents/comment-analyzer.md"],
    "maestro:security-reviewer": ["agents/security-reviewer.md"],
    "maestro:test-analyzer": ["agents/test-analyzer.md"],
}


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


def load_plugin_requirements(plugin_root: Path) -> tuple[Any, str]:
    manifest_path = resolve_contained(
        plugin_root, PLUGIN_REQUIREMENTS_PATH, "plugin requirements"
    )
    try:
        manifest_bytes = manifest_path.read_bytes()
        requirements = json.loads(manifest_bytes.decode("utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ClosureError(f"plugin requirements unavailable: {error}") from error
    if not isinstance(requirements, dict):
        raise ClosureError("plugin requirements must be an object")
    require_exact_keys(
        requirements,
        {
            "version",
            "mandatory_plugin_sources",
            "skill_dependencies",
            "lens_sources",
        },
        "plugin requirements",
    )
    if requirements["version"] != "review-source-requirements-v1":
        raise ClosureError("plugin requirements version is invalid")
    mandatory_sources = set(
        normalized_path_list(
            requirements["mandatory_plugin_sources"],
            "plugin requirements.mandatory_plugin_sources",
        )
    )
    if mandatory_sources != MANDATORY_PLUGIN_SOURCES:
        raise ClosureError("mandatory plugin source closure is incomplete")
    skill_dependencies = set(
        normalized_path_list(
            requirements["skill_dependencies"],
            "plugin requirements.skill_dependencies",
        )
    )
    if skill_dependencies != SKILL_DEPENDENCIES:
        raise ClosureError("review skill dependency closure is incomplete")
    lens_sources = requirements["lens_sources"]
    if not isinstance(lens_sources, dict):
        raise ClosureError("plugin requirements.lens_sources must be an object")
    normalized_lenses = {
        normalize_text(key, "plugin requirements lens key"): normalized_path_list(
            value, f"plugin requirements.lens_sources[{key}]"
        )
        for key, value in lens_sources.items()
    }
    if normalized_lenses != LENS_SOURCES:
        raise ClosureError("selectable lens mapping is incomplete")
    requirements_revision = (
        "review-source-requirements-v1:"
        + hashlib.sha256(manifest_bytes).hexdigest()
    )
    return requirements, requirements_revision


def git_output(repository_root: Path, *arguments: str) -> str:
    try:
        result = subprocess.run(
            ["git", "-C", str(repository_root), *arguments],
            check=True,
            capture_output=True,
            text=True,
        )
    except (OSError, subprocess.CalledProcessError) as error:
        raise ClosureError(
            f"repository root is not verifiable with git {' '.join(arguments)}"
        ) from error
    return result.stdout.strip()


def github_repository_from_remote(remote: str) -> str:
    remote = remote.strip()
    patterns = (
        r"https?://github\.com/([^/]+/[^/]+?)(?:\.git)?$",
        r"ssh://git@github\.com/([^/]+/[^/]+?)(?:\.git)?$",
        r"git@github\.com:([^/]+/[^/]+?)(?:\.git)?$",
    )
    for pattern in patterns:
        match = re.fullmatch(pattern, remote)
        if match:
            return match.group(1)
    raise ClosureError("repository origin is not a canonical GitHub repository")


def validate_repository_binding(
    repository_root: Path, expected_repository: str, expected_head: str
) -> list[str]:
    repository_root = repository_root.resolve()
    expected_repository = normalize_text(
        expected_repository, "expected repository"
    )
    if not re.fullmatch(r"[^/\s]+/[^/\s]+", expected_repository):
        raise ClosureError("expected repository must be owner/repository")
    expected_head = normalize_text(expected_head, "expected head").lower()
    if not re.fullmatch(r"[0-9a-f]{40,64}", expected_head):
        raise ClosureError("expected head must be a full Git object ID")
    top_level = Path(git_output(repository_root, "rev-parse", "--show-toplevel"))
    if top_level.resolve() != repository_root:
        raise ClosureError("repository root is not the exact Git worktree root")
    actual_head = git_output(repository_root, "rev-parse", "HEAD").lower()
    if actual_head != expected_head:
        raise ClosureError("repository worktree head differs from expected head")
    try:
        subprocess.run(
            ["git", "-C", str(repository_root), "symbolic-ref", "-q", "HEAD"],
            check=True,
            capture_output=True,
            text=True,
        )
    except subprocess.CalledProcessError:
        pass
    else:
        raise ClosureError("repository worktree must be detached at expected head")
    if git_output(repository_root, "status", "--porcelain", "--untracked-files=all"):
        raise ClosureError("repository worktree has unexpected changes")
    actual_repository = github_repository_from_remote(
        git_output(repository_root, "remote", "get-url", "origin")
    )
    if actual_repository != expected_repository:
        raise ClosureError("repository identity differs from expected repository")
    return ["repository-binding-v1", expected_repository, expected_head]


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
    expected_repository: str,
    expected_head: str,
) -> list[Any]:
    _, requirements_revision = load_plugin_requirements(plugin_root)
    repository_binding = validate_repository_binding(
        repository_root, expected_repository, expected_head
    )
    if not isinstance(descriptor, dict):
        raise ClosureError("descriptor must be an object")
    require_exact_keys(
        descriptor,
        {"version", "selected_lenses", "policy_sources", "validators"},
        "descriptor",
    )
    if descriptor["version"] != "review-source-closure-v1":
        raise ClosureError("descriptor version must be review-source-closure-v1")

    selected_lenses = descriptor["selected_lenses"]
    if not isinstance(selected_lenses, list):
        raise ClosureError("selected_lenses must be an explicit list")
    selected_lenses = sorted_unique(
        [
            normalize_text(value, f"selected_lenses[{index}]")
            for index, value in enumerate(selected_lenses)
        ]
    )
    unknown_lenses = set(selected_lenses) - set(LENS_SOURCES)
    if unknown_lenses:
        raise ClosureError(f"unknown selected lenses: {sorted(unknown_lenses)}")
    plugin_paths = set(MANDATORY_PLUGIN_SOURCES)
    for lens in selected_lenses:
        plugin_paths.update(LENS_SOURCES[lens])
    plugin_sources = source_list(
        plugin_root, sorted(plugin_paths), "plugin-source", "plugin sources"
    )
    if any(entry[2] != "present" for entry in plugin_sources):
        raise ClosureError("required plugin source is missing or unavailable")
    policy_sources = source_list(
        repository_root,
        descriptor["policy_sources"],
        "policy-source",
        "policy_sources",
    )
    validators = descriptor["validators"]
    if not isinstance(validators, list):
        raise ClosureError("validators must be an explicit list")
    validator_entries = sorted_unique(
        [
            validator_entry(repository_root, value, index)
            for index, value in enumerate(validators)
        ]
    )
    return [
        "review-source-closure-v1",
        requirements_revision,
        repository_binding,
        selected_lenses,
        plugin_sources,
        policy_sources,
        validator_entries,
    ]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--plugin-root", required=True, type=Path)
    parser.add_argument("--repository-root", required=True, type=Path)
    parser.add_argument("--expected-repository", required=True)
    parser.add_argument("--expected-head", required=True)
    parser.add_argument("--descriptor", required=True, type=Path)
    args = parser.parse_args()
    try:
        descriptor = json.loads(args.descriptor.read_text(encoding="utf-8"))
        closure = build_closure(
            args.plugin_root.resolve(),
            args.repository_root.resolve(),
            descriptor,
            args.expected_repository,
            args.expected_head,
        )
    except (ClosureError, OSError, UnicodeError, json.JSONDecodeError) as error:
        print(f"review-source-closure error: {error}", file=sys.stderr)
        return 2

    print(f"canonical\t{canonical_json(closure)}")
    print(f"revision\t{digest('review-source-closure-v1', closure)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
