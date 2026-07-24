#!/usr/bin/env python3
"""Canonical pre-worktree review preparation and reservation oracle."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import unicodedata
from pathlib import Path, PurePosixPath
from typing import Any

from review_source_policy import (
    LENS_SOURCES,
    MANDATORY_PLUGIN_SOURCES,
    SKILL_DEPENDENCIES,
    SourcePolicyError,
    load_and_validate_source_policy,
)

TOP_LEVEL_FIELDS = {
    "review_identity",
    "evidence_requirements",
    "preworktree_bindings",
    "capabilities",
    "decision_resolutions",
    "repository_source_requirements",
}
IDENTITY_FIELDS = {
    "symphony",
    "implementation_issue",
    "repository",
    "pr",
    "base",
    "head",
    "contract_revision",
    "dag_revision",
    "review_policy_revision",
}
IDENTITY_ORDER = (
    "symphony",
    "implementation_issue",
    "repository",
    "pr",
    "base",
    "head",
    "contract_revision",
    "dag_revision",
    "review_policy_revision",
)
EVIDENCE_STAGES = {"review", "reconciliation", "both"}
RESOLUTION_OUTCOMES = {"exact", "unresolved", "ambiguous"}
OBSERVABLE_STATES = {"present", "missing", "unavailable"}
SOURCE_KINDS = {
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
CONTEXT_REVISION_RE = re.compile(r"evidence-binding-context-v1:[0-9a-f]{64}")


class PreparationError(ValueError):
    pass


def canonical_json(value: Any) -> str:
    return json.dumps(
        value,
        ensure_ascii=False,
        separators=(",", ":"),
        allow_nan=False,
    )


def digest(prefix: str, value: Any) -> str:
    return (
        prefix
        + ":"
        + hashlib.sha256(canonical_json(value).encode("utf-8")).hexdigest()
    )


def text(value: Any, field: str) -> str:
    if not isinstance(value, str):
        raise PreparationError(f"{field} must be a string")
    normalized = " ".join(
        unicodedata.normalize(
            "NFC",
            value.replace("\r\n", "\n").replace("\r", "\n"),
        ).split()
    )
    if not normalized:
        raise PreparationError(f"{field} must not be empty")
    return normalized


def exact_object(value: Any, keys: set[str], field: str) -> dict[str, Any]:
    if not isinstance(value, dict) or set(value) != keys:
        raise PreparationError(f"{field} keys differ from the canonical schema")
    return value


def canonical_string_list(value: Any, field: str) -> list[str]:
    if not isinstance(value, list):
        raise PreparationError(f"{field} must be a list")
    return [text(item, f"{field}[{index}]") for index, item in enumerate(value)]


def safe_repository_path(value: Any, field: str) -> str:
    if not isinstance(value, str):
        raise PreparationError(f"{field} must be a string")
    normalized = unicodedata.normalize("NFC", value.strip())
    if (
        not normalized
        or normalized.startswith("/")
        or "\\" in normalized
        or any(character in normalized for character in ("*", "?", "["))
    ):
        raise PreparationError(f"{field} must be a safe repository-relative path")
    path = PurePosixPath(normalized)
    if ".." in path.parts:
        raise PreparationError(f"{field} must be a safe repository-relative path")
    normalized = path.as_posix()
    while normalized.startswith("./"):
        normalized = normalized[2:]
    if normalized in {"", "."}:
        raise PreparationError(f"{field} must name a repository-relative path")
    return normalized


def sorted_unique(items: list[list[Any]], field: str) -> list[list[Any]]:
    keyed = {}
    for item in items:
        key = canonical_json(item).encode("utf-8")
        if key in keyed:
            raise PreparationError(f"{field} contains a duplicate canonical entry")
        keyed[key] = item
    return [keyed[key] for key in sorted(keyed)]


def canonical_requirements(value: Any) -> tuple[list[list[Any]], dict[str, list[Any]]]:
    if not isinstance(value, list):
        raise PreparationError("evidence_requirements must be a list")
    canonical = []
    by_key = {}
    for index, item in enumerate(value):
        field = f"evidence_requirements[{index}]"
        if not isinstance(item, list) or len(item) != 7:
            raise PreparationError(f"{field} must be a complete canonical requirement")
        if item[0] != "maestro-evidence-requirement-key-v1":
            raise PreparationError(f"{field} prefix differs")
        criterion = text(item[1], f"{field}.criterion")
        outcome = text(item[2], f"{field}.required_outcome")
        stage = text(item[3], f"{field}.evidence_stage")
        source_kind = text(item[4], f"{field}.source_kind")
        role = text(item[5], f"{field}.provider_record_role")
        if stage not in EVIDENCE_STAGES or source_kind not in SOURCE_KINDS:
            raise PreparationError(f"{field} finite value differs")
        locator = canonical_string_list(item[6], f"{field}.locator")
        if source_kind == "repository-file":
            locator[-1] = safe_repository_path(locator[-1], f"{field}.repository_path")
        entry = [
            "maestro-evidence-requirement-key-v1",
            criterion,
            outcome,
            stage,
            source_kind,
            role,
            locator,
        ]
        key = digest("evidence-requirement-key-v1", entry)
        if key in by_key:
            raise PreparationError("evidence_requirements contains a duplicate key")
        by_key[key] = entry
        canonical.append(entry)
    return sorted_unique(canonical, "evidence_requirements"), by_key


def canonical_bindings(
    value: Any,
    requirements: dict[str, list[Any]],
) -> list[list[Any]]:
    if not isinstance(value, list):
        raise PreparationError("preworktree_bindings must be a list")
    canonical = []
    seen_requirements = set()
    for index, item in enumerate(value):
        field = f"preworktree_bindings[{index}]"
        if not isinstance(item, list) or len(item) != 12:
            raise PreparationError(f"{field} must be a complete canonical binding")
        if item[0] != "maestro-acceptance-evidence-binding-v1":
            raise PreparationError(f"{field} prefix differs")
        criterion = text(item[1], f"{field}.criterion")
        requirement_key = text(item[2], f"{field}.requirement_key")
        if requirement_key not in requirements:
            raise PreparationError(f"{field} does not match a current requirement")
        requirement = requirements[requirement_key]
        source_kind = text(item[3], f"{field}.source_kind")
        template = canonical_string_list(item[4], f"{field}.locator_template")
        resolved = canonical_string_list(item[5], f"{field}.resolved_locator")
        context_revision = text(item[6], f"{field}.binding_context_revision")
        resolution = text(item[7], f"{field}.resolution_outcome")
        state = text(item[8], f"{field}.observable_state")
        record_id = text(item[9], f"{field}.provider_record_id")
        provider_revision = text(item[10], f"{field}.provider_revision")
        provider_evidence = text(item[11], f"{field}.provider_evidence")
        if (
            criterion != requirement[1]
            or source_kind != requirement[4]
            or template != requirement[6]
        ):
            raise PreparationError(f"{field} differs from its requirement")
        if not CONTEXT_REVISION_RE.fullmatch(context_revision):
            raise PreparationError(f"{field} context revision is not canonical")
        if resolution not in RESOLUTION_OUTCOMES or state not in OBSERVABLE_STATES:
            raise PreparationError(f"{field} finite state differs")
        if resolution == "unresolved" and state != "missing":
            raise PreparationError(f"{field} unresolved state differs")
        if resolution == "ambiguous" and state != "unavailable":
            raise PreparationError(f"{field} ambiguous state differs")
        if state == "present":
            if any(
                sentinel in OBSERVABLE_STATES
                for sentinel in (record_id, provider_revision, provider_evidence)
            ):
                raise PreparationError(f"{field} present evidence is incomplete")
        elif (record_id, provider_revision, provider_evidence) != (
            state,
            state,
            state,
        ):
            raise PreparationError(f"{field} state sentinels differ")
        if requirement_key in seen_requirements:
            raise PreparationError("preworktree_bindings has multiple current bindings")
        seen_requirements.add(requirement_key)
        canonical.append(
            [
                "maestro-acceptance-evidence-binding-v1",
                criterion,
                requirement_key,
                source_kind,
                template,
                resolved,
                context_revision,
                resolution,
                state,
                record_id,
                provider_revision,
                provider_evidence,
            ]
        )
    if seen_requirements != set(requirements):
        raise PreparationError(
            "preworktree_bindings must cover every current evidence requirement"
        )
    return sorted_unique(canonical, "preworktree_bindings")


def canonical_capabilities(value: Any) -> list[list[Any]]:
    if not isinstance(value, list):
        raise PreparationError("capabilities must be a list")
    entries = []
    names = set()
    for index, item in enumerate(value):
        field = f"capabilities[{index}]"
        if not isinstance(item, list) or len(item) != 4 or item[0] != "capability":
            raise PreparationError(f"{field} must be a complete capability")
        name = text(item[1], f"{field}.name")
        state = text(item[2], f"{field}.state")
        revision = text(item[3], f"{field}.revision")
        if state not in OBSERVABLE_STATES:
            raise PreparationError(f"{field} state differs")
        if state != "present" and revision != state:
            raise PreparationError(f"{field} sentinel differs")
        if name in names:
            raise PreparationError("capabilities contains a duplicate name")
        names.add(name)
        entries.append(["capability", name, state, revision])
    return sorted_unique(entries, "capabilities")


def canonical_decisions(value: Any) -> list[list[Any]]:
    if not isinstance(value, list):
        raise PreparationError("decision_resolutions must be a list")
    entries = []
    pause_ids = set()
    for index, item in enumerate(value):
        field = f"decision_resolutions[{index}]"
        if (
            not isinstance(item, list)
            or len(item) != 4
            or item[0] != "decision-resolution"
        ):
            raise PreparationError(f"{field} must be a complete decision resolution")
        entry = ["decision-resolution"] + [
            text(item[position], f"{field}[{position}]")
            for position in range(1, 4)
        ]
        if entry[1] in pause_ids:
            raise PreparationError("decision_resolutions contains a duplicate pause")
        pause_ids.add(entry[1])
        entries.append(entry)
    return sorted_unique(entries, "decision_resolutions")


def canonical_repository_requirements(value: Any) -> list[list[Any]]:
    if not isinstance(value, list):
        raise PreparationError("repository_source_requirements must be a list")
    entries = []
    for index, item in enumerate(value):
        field = f"repository_source_requirements[{index}]"
        if (
            not isinstance(item, list)
            or len(item) != 2
            or item[0] != "repository-source-requirement"
        ):
            raise PreparationError(f"{field} must be a complete source requirement")
        entries.append(
            [
                "repository-source-requirement",
                safe_repository_path(item[1], f"{field}.path"),
            ]
        )
    return sorted_unique(entries, "repository_source_requirements")


def plugin_source_closure(plugin_root: Path) -> tuple[list[Any], str]:
    root = plugin_root.resolve()
    try:
        load_and_validate_source_policy(root)
    except SourcePolicyError as error:
        raise PreparationError(str(error)) from error
    paths = set(MANDATORY_PLUGIN_SOURCES)
    paths.update(SKILL_DEPENDENCIES)
    for lens_paths in LENS_SOURCES.values():
        paths.update(lens_paths)
    entries = []
    for raw_path in sorted(paths):
        relative = safe_repository_path(raw_path, "plugin source path")
        source = (root / relative).resolve()
        try:
            source.relative_to(root)
        except ValueError as error:
            raise PreparationError("plugin source escapes plugin root") from error
        if not source.is_file() or source.is_symlink():
            raise PreparationError(f"plugin source is unavailable: {relative}")
        try:
            content_digest = hashlib.sha256(source.read_bytes()).hexdigest()
        except OSError as error:
            raise PreparationError(f"plugin source is unreadable: {relative}") from error
        entries.append(["plugin-source", relative, "present", f"sha256:{content_digest}"])
    canonical = ["maestro-plugin-source-closure-v1", entries]
    return canonical, digest("plugin-source-closure-v1", canonical)


def derive(
    value: Any,
    plugin_root: Path,
) -> tuple[list[Any], str, list[Any], str, str]:
    preparation = exact_object(value, TOP_LEVEL_FIELDS, "preparation input")
    identity = exact_object(
        preparation["review_identity"],
        IDENTITY_FIELDS,
        "review_identity",
    )
    identity_values = [
        text(identity[field], f"review_identity.{field}")
        for field in IDENTITY_ORDER
    ]
    repository = identity_values[2]
    if not re.fullmatch(r"[^/\s]+/[^/\s]+", repository):
        raise PreparationError("review_identity.repository must be owner/repository")
    requirements, requirements_by_key = canonical_requirements(
        preparation["evidence_requirements"]
    )
    bindings = canonical_bindings(
        preparation["preworktree_bindings"],
        requirements_by_key,
    )
    _, plugin_revision = plugin_source_closure(plugin_root)
    preparation_canonical = [
        "maestro-review-preparation-v1",
        *identity_values,
        requirements,
        bindings,
        canonical_capabilities(preparation["capabilities"]),
        canonical_decisions(preparation["decision_resolutions"]),
        plugin_revision,
        canonical_repository_requirements(
            preparation["repository_source_requirements"]
        ),
    ]
    preparation_revision = digest(
        "review-preparation-v1",
        preparation_canonical,
    )
    reservation_canonical = [
        "maestro-review-worktree-reservation-v1",
        *identity_values,
        preparation_revision,
    ]
    reservation = digest(
        "review-worktree-reservation-v1",
        reservation_canonical,
    )
    return (
        preparation_canonical,
        preparation_revision,
        reservation_canonical,
        reservation,
        plugin_revision,
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--plugin-root", required=True, type=Path)
    parser.add_argument("--input", required=True, type=Path)
    args = parser.parse_args()
    try:
        value = json.loads(args.input.read_text(encoding="utf-8"))
        canonical, preparation, reservation_canonical, reservation, plugin_revision = (
            derive(value, args.plugin_root)
        )
    except (
        OSError,
        UnicodeError,
        json.JSONDecodeError,
        PreparationError,
    ) as error:
        print(f"review-preparation error: {error}", file=sys.stderr)
        return 2
    print(f"canonical\t{canonical_json(canonical)}")
    print(f"preparation\t{preparation}")
    print(f"plugin_source_closure\t{plugin_revision}")
    print(f"reservation_canonical\t{canonical_json(reservation_canonical)}")
    print(f"reservation\t{reservation}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
