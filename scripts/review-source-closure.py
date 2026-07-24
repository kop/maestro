#!/usr/bin/env python3
"""Canonical review-source-closure-v1 oracle."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import stat
import subprocess
import sys
import unicodedata
from pathlib import Path, PurePosixPath
from typing import Any

from review_source_policy import (
    LENS_SOURCES,
    MANDATORY_PLUGIN_SOURCES,
    SourcePolicyError,
    load_and_validate_source_policy,
)

VALIDATOR_KINDS = {
    "issue-validation-command",
    "kubernetes-helm-render",
    "docker-build-runtime",
    "github-actions-workflow",
}
CAPABILITY_STATES = {"present", "missing", "unavailable"}
SOURCE_CLOSURE_PHASES = {"pre-review", "pre-publication"}
GLOB_CHARACTERS = {"*", "?", "["}


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
    cursor = root.resolve()
    for component in PurePosixPath(relative_path).parts:
        cursor /= component
        if cursor.is_symlink():
            raise ClosureError(f"{field} must not traverse a symlink")
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
    try:
        return load_and_validate_source_policy(plugin_root)
    except SourcePolicyError as error:
        raise ClosureError(str(error)) from error


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
    actual_repository = github_repository_from_remote(
        git_output(repository_root, "remote", "get-url", "origin")
    )
    if actual_repository != expected_repository:
        raise ClosureError("repository identity differs from expected repository")
    return ["repository-binding-v1", expected_repository, expected_head]


def git_status_entries(repository_root: Path) -> list[tuple[str, str]]:
    try:
        result = subprocess.run(
            [
                "git",
                "-C",
                str(repository_root),
                "status",
                "--porcelain=v1",
                "-z",
                "--untracked-files=all",
                "--ignored=matching",
                "--ignore-submodules=none",
            ],
            check=True,
            capture_output=True,
        )
        output = result.stdout.decode("utf-8")
    except (OSError, UnicodeError, subprocess.CalledProcessError) as error:
        raise ClosureError("repository worktree state is not verifiable") from error
    entries = []
    for record in output.split("\0"):
        if not record:
            continue
        if len(record) < 4 or record[2] != " ":
            raise ClosureError("repository worktree status is ambiguous")
        entries.append((record[:2], record[3:]))
    return entries


def paths_overlap_or_shadow(artifact: str, authority: str) -> bool:
    artifact_path = PurePosixPath(artifact)
    authority_path = PurePosixPath(authority)
    artifact_parts = tuple(part.casefold() for part in artifact_path.parts)
    authority_parts = tuple(part.casefold() for part in authority_path.parts)
    if artifact_parts == authority_parts:
        return True
    if (
        artifact_parts == authority_parts[: len(artifact_parts)]
        or authority_parts == artifact_parts[: len(authority_parts)]
    ):
        return True
    if artifact_parts[:-1] == authority_parts[:-1]:
        artifact_name = artifact_parts[-1]
        authority_name = authority_parts[-1]
        if (
            artifact_name == authority_name
            or artifact_name.startswith(authority_name + ".")
            or authority_name.startswith(artifact_name + ".")
        ):
            return True
    return False


def validate_artifact_path(path: str, authority_paths: set[str]) -> None:
    if any(
        paths_overlap_or_shadow(path, authority_path)
        for authority_path in authority_paths
    ):
        raise ClosureError(
            "validation artifact aliases, contains, or shadows a declared source"
        )


def validate_artifact_tree(
    repository_root: Path,
    path: str,
    authority_paths: set[str],
    authority_identities: set[tuple[int, int]],
) -> None:
    path = normalize_relative_path(path.rstrip("/"), "validation artifact")
    validate_artifact_path(path, authority_paths)
    artifact = repository_root / path
    try:
        artifact_stat = artifact.lstat()
    except OSError as error:
        raise ClosureError("validation artifact is not inspectable") from error
    if stat.S_ISLNK(artifact_stat.st_mode):
        raise ClosureError("validation artifact must not be a symlink")
    if stat.S_ISREG(artifact_stat.st_mode):
        if (artifact_stat.st_dev, artifact_stat.st_ino) in authority_identities:
            raise ClosureError("validation artifact is a hard-link alias of a source")
        return
    if not stat.S_ISDIR(artifact_stat.st_mode):
        raise ClosureError("validation artifact is not a regular file or directory")
    try:
        children = sorted(os.scandir(artifact), key=lambda entry: entry.name)
    except OSError as error:
        raise ClosureError("validation artifact directory is not inspectable") from error
    for child in children:
        child_path = (PurePosixPath(path) / child.name).as_posix()
        validate_artifact_tree(
            repository_root,
            child_path,
            authority_paths,
            authority_identities,
        )


def source_file_identities(
    root: Path,
    entries: list[list[str]],
) -> set[tuple[int, int]]:
    identities = set()
    for entry in entries:
        if entry[2] != "present":
            continue
        try:
            source_stat = (root / entry[1]).lstat()
        except OSError as error:
            raise ClosureError("declared source identity is not inspectable") from error
        if not stat.S_ISREG(source_stat.st_mode):
            raise ClosureError("declared source identity is not a regular file")
        identities.add((source_stat.st_dev, source_stat.st_ino))
    return identities


def validate_worktree_phase(
    repository_root: Path,
    phase: str,
    authority_paths: set[str],
    authority_identities: set[tuple[int, int]],
    implicit_sources_forbidden: bool,
) -> None:
    phase = normalize_text(phase, "phase")
    if phase not in SOURCE_CLOSURE_PHASES:
        raise ClosureError("phase is not finite")
    entries = git_status_entries(repository_root)
    if phase == "pre-review":
        if entries:
            raise ClosureError("pre-review worktree must be fully clean")
        return
    if not implicit_sources_forbidden:
        raise ClosureError("pre-publication implicit source discovery is possible")
    for state, raw_path in entries:
        if state not in {"??", "!!"}:
            raise ClosureError(
                "pre-publication tracked, staged, symlink, or submodule mutation"
            )
        validate_artifact_tree(
            repository_root,
            raw_path,
            authority_paths,
            authority_identities,
        )


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
    phase: str,
) -> list[Any]:
    _, requirements_revision = load_plugin_requirements(plugin_root)
    repository_binding = validate_repository_binding(
        repository_root, expected_repository, expected_head
    )
    if not isinstance(descriptor, dict):
        raise ClosureError("descriptor must be an object")
    require_exact_keys(
        descriptor,
        {
            "version",
            "selected_lenses",
            "repository_sources",
            "policy_sources",
            "implicit_sources_declared",
            "validators",
        },
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
    repository_sources = source_list(
        repository_root,
        descriptor["repository_sources"],
        "repository-source",
        "repository_sources",
    )
    if descriptor["implicit_sources_declared"] is not True:
        raise ClosureError("descriptor has undeclared implicit repository sources")
    validators = descriptor["validators"]
    if not isinstance(validators, list):
        raise ClosureError("validators must be an explicit list")
    validator_entries = sorted_unique(
        [
            validator_entry(repository_root, value, index)
            for index, value in enumerate(validators)
        ]
    )
    authority_paths = {
        entry[1]
        for entry in plugin_sources + repository_sources + policy_sources
    }
    authority_identities = source_file_identities(plugin_root, plugin_sources)
    authority_identities.update(
        source_file_identities(
            repository_root,
            repository_sources + policy_sources,
        )
    )
    for validator in validator_entries:
        authority_paths.update(entry[1] for entry in validator[4])
        authority_identities.update(
            source_file_identities(repository_root, validator[4])
        )
    validate_worktree_phase(
        repository_root,
        phase,
        authority_paths,
        authority_identities,
        descriptor["implicit_sources_declared"] is True
        and all(
            value.get("implicit_sources_declared") is True
            for value in validators
            if isinstance(value, dict)
        ),
    )
    return [
        "review-source-closure-v1",
        requirements_revision,
        repository_binding,
        selected_lenses,
        plugin_sources,
        repository_sources,
        policy_sources,
        validator_entries,
    ]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--plugin-root", required=True, type=Path)
    parser.add_argument("--repository-root", required=True, type=Path)
    parser.add_argument("--expected-repository", required=True)
    parser.add_argument("--expected-head", required=True)
    parser.add_argument(
        "--phase",
        required=True,
        choices=sorted(SOURCE_CLOSURE_PHASES),
    )
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
            args.phase,
        )
    except (ClosureError, OSError, UnicodeError, json.JSONDecodeError) as error:
        print(f"review-source-closure error: {error}", file=sys.stderr)
        return 2

    print(f"canonical\t{canonical_json(closure)}")
    print(f"revision\t{digest('review-source-closure-v1', closure)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
