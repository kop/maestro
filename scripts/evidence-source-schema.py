#!/usr/bin/env python3
"""Canonical evidence requirement and runtime binding schema oracle."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import unicodedata
from pathlib import Path
from typing import Any


SCHEMA_PATH = "evidence-source-schema-v1.json"
EVIDENCE_STAGES = {"review", "reconciliation", "both"}
BINDING_TOKENS = {
    "current_implementation_issue",
    "current_linked_pr",
    "current_base",
    "current_head",
    "current_merge",
}
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


class SchemaError(ValueError):
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


def exact_keys(value: Any, expected: set[str], field: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise SchemaError(f"{field} must be an object")
    if set(value) != expected:
        raise SchemaError(
            f"{field} keys differ: expected {sorted(expected)}, got {sorted(value)}"
        )
    return value


def text(value: Any, field: str) -> str:
    if not isinstance(value, str):
        raise SchemaError(f"{field} must be a string")
    normalized = " ".join(
        unicodedata.normalize(
            "NFC", value.replace("\r\n", "\n").replace("\r", "\n")
        ).split()
    )
    if not normalized:
        raise SchemaError(f"{field} must not be empty")
    return normalized


def load_schema(plugin_root: Path) -> dict[str, Any]:
    plugin_root = plugin_root.resolve()
    schema_path = (plugin_root / SCHEMA_PATH).resolve()
    try:
        schema_path.relative_to(plugin_root)
        schema = json.loads(schema_path.read_text(encoding="utf-8"))
    except (ValueError, OSError, UnicodeError, json.JSONDecodeError) as error:
        raise SchemaError(f"evidence source schema unavailable: {error}") from error
    exact_keys(
        schema,
        {
            "version",
            "evidence_stages",
            "binding_tokens",
            "resolution_outcomes",
            "observable_states",
            "source_kinds",
        },
        "schema",
    )
    if schema["version"] != "evidence-source-schema-v1":
        raise SchemaError("schema version is invalid")
    if set(schema["evidence_stages"]) != EVIDENCE_STAGES:
        raise SchemaError("schema evidence stages are incomplete")
    if set(schema["binding_tokens"]) != BINDING_TOKENS:
        raise SchemaError("schema binding-token vocabulary is incomplete")
    if set(schema["resolution_outcomes"]) != RESOLUTION_OUTCOMES:
        raise SchemaError("schema resolution outcomes are incomplete")
    if set(schema["observable_states"]) != OBSERVABLE_STATES:
        raise SchemaError("schema observable states are incomplete")
    if not isinstance(schema["source_kinds"], dict):
        raise SchemaError("schema source_kinds must be an object")
    if set(schema["source_kinds"]) != SOURCE_KINDS:
        raise SchemaError("schema source-kind closure is incomplete")
    for source_kind, definition in schema["source_kinds"].items():
        exact_keys(definition, {"variants"}, f"source_kinds.{source_kind}")
        variants = definition["variants"]
        if not isinstance(variants, list) or not variants:
            raise SchemaError(f"source_kinds.{source_kind}.variants must be non-empty")
        for index, variant in enumerate(variants):
            field = f"source_kinds.{source_kind}.variants[{index}]"
            exact_keys(
                variant,
                {
                    "stages",
                    "provider_record_roles",
                    "locator_template_shape",
                    "provider_locator_shape",
                },
                field,
            )
            if not isinstance(variant["stages"], list) or not variant["stages"]:
                raise SchemaError(f"{field}.stages must be non-empty")
            if not set(variant["stages"]) <= EVIDENCE_STAGES:
                raise SchemaError(f"{field}.stages contains an unknown stage")
            if not isinstance(variant["provider_record_roles"], list) or not all(
                isinstance(role, str) and role
                for role in variant["provider_record_roles"]
            ):
                raise SchemaError(f"{field}.provider_record_roles is invalid")
            template_shape = variant["locator_template_shape"]
            provider_shape = variant["provider_locator_shape"]
            if (
                not isinstance(template_shape, list)
                or not isinstance(provider_shape, list)
                or len(template_shape) != len(provider_shape)
            ):
                raise SchemaError(f"{field} locator shapes differ")
            for position, (template_slot, provider_slot) in enumerate(
                zip(template_shape, provider_shape)
            ):
                validate_shape_pair(
                    template_slot,
                    provider_slot,
                    f"{field}.shape[{position}]",
                )
    return schema


def split_slot(value: Any, field: str) -> tuple[str, str | None]:
    if not isinstance(value, str) or not value:
        raise SchemaError(f"{field} must be a slot string")
    if ":" not in value:
        if value != "role":
            raise SchemaError(f"{field} has an unknown slot")
        return value, None
    kind, name = value.split(":", 1)
    if not name:
        raise SchemaError(f"{field} has an empty slot value")
    return kind, name


def validate_shape_pair(template: Any, provider: Any, field: str) -> None:
    template_kind, template_name = split_slot(template, f"{field}.template")
    provider_kind, provider_name = split_slot(provider, f"{field}.provider")
    expected = {
        "literal": "literal",
        "token": "binding",
        "selector": "selector",
        "role": "role",
    }.get(template_kind)
    if expected != provider_kind:
        raise SchemaError(f"{field} template/provider slot kinds differ")
    if template_kind == "token" and template_name not in BINDING_TOKENS:
        raise SchemaError(f"{field} contains an unknown binding token")
    if template_kind != "literal" and template_name != provider_name:
        raise SchemaError(f"{field} template/provider slot names differ")
    if template_kind == "literal":
        valid_literal_pair = (
            template_name == "locator-template-v1"
            and provider_name == "resolved-locator-v1"
        ) or template_name == provider_name
        if not valid_literal_pair:
            raise SchemaError(f"{field} literal values differ")


def validate_selector(value: Any, name: str, field: str) -> str:
    normalized = text(value, field)
    if "${" in normalized:
        raise SchemaError(f"{field} must be a static selector")
    if name == "repository" and not re.fullmatch(r"[^/\s]+/[^/\s]+", normalized):
        raise SchemaError(f"{field} must be owner/repository")
    if name == "repository_path":
        if (
            normalized.startswith("/")
            or "\\" in normalized
            or ".." in Path(normalized).parts
        ):
            raise SchemaError(f"{field} must be a safe repository-relative path")
    return normalized


def shape_matches(
    values: Any,
    shape: list[str],
    role: str,
    field: str,
    template_values: list[Any] | None = None,
) -> bool:
    if not isinstance(values, list) or len(values) != len(shape):
        return False
    try:
        for index, (value, slot) in enumerate(zip(values, shape)):
            kind, name = split_slot(slot, f"{field}.shape[{index}]")
            item_field = f"{field}[{index}]"
            if kind == "literal":
                if value != name:
                    return False
            elif kind == "token":
                if value != "${" + str(name) + "}":
                    return False
            elif kind == "binding":
                text(value, item_field)
                if "${" in value:
                    return False
            elif kind == "role":
                if value != role:
                    return False
            elif kind == "selector":
                selector = validate_selector(value, str(name), item_field)
                if template_values is not None and selector != template_values[index]:
                    return False
            else:
                return False
    except SchemaError:
        return False
    return True


def canonical_requirement(
    schema: dict[str, Any], value: Any
) -> tuple[list[Any], str, dict[str, Any]]:
    requirement = exact_keys(
        value,
        {
            "criterion_key",
            "required_outcome",
            "evidence_stage",
            "source_kind",
            "provider_record_role",
            "locator_template",
        },
        "requirement",
    )
    criterion_key = text(requirement["criterion_key"], "criterion_key")
    required_outcome = text(requirement["required_outcome"], "required_outcome")
    stage = text(requirement["evidence_stage"], "evidence_stage")
    if stage not in EVIDENCE_STAGES:
        raise SchemaError("evidence_stage is not finite")
    source_kind = text(requirement["source_kind"], "source_kind")
    if source_kind not in SOURCE_KINDS:
        raise SchemaError("source_kind is not finite")
    role = text(requirement["provider_record_role"], "provider_record_role")
    matches = []
    for variant in schema["source_kinds"][source_kind]["variants"]:
        if (
            stage in variant["stages"]
            and role in variant["provider_record_roles"]
            and shape_matches(
                requirement["locator_template"],
                variant["locator_template_shape"],
                role,
                "locator_template",
            )
        ):
            matches.append(variant)
    if len(matches) != 1:
        raise SchemaError("requirement does not match exactly one source-kind variant")
    canonical = [
        "maestro-evidence-requirement-key-v1",
        criterion_key,
        required_outcome,
        stage,
        source_kind,
        role,
        requirement["locator_template"],
    ]
    return canonical, digest("evidence-requirement-key-v1", canonical), matches[0]


def canonical_binding(schema: dict[str, Any], value: Any) -> tuple[list[Any], bool]:
    binding = exact_keys(
        value,
        {
            "requirement",
            "resolved_locator",
            "binding_context_revision",
            "resolution_outcome",
            "evidence_state",
            "provider_record_id",
            "provider_revision",
        },
        "binding",
    )
    requirement, requirement_key, variant = canonical_requirement(
        schema, binding["requirement"]
    )
    resolution = text(binding["resolution_outcome"], "resolution_outcome")
    if resolution not in RESOLUTION_OUTCOMES:
        raise SchemaError("resolution_outcome is not finite")
    state = text(binding["evidence_state"], "evidence_state")
    if state not in OBSERVABLE_STATES:
        raise SchemaError("evidence_state is not finite")
    record_id = text(binding["provider_record_id"], "provider_record_id")
    provider_revision = text(binding["provider_revision"], "provider_revision")
    if state == "present":
        if record_id in OBSERVABLE_STATES or provider_revision in OBSERVABLE_STATES:
            raise SchemaError("present binding requires provider identity/revision")
    elif record_id != state or provider_revision != state:
        raise SchemaError("non-present binding sentinels must match observable state")
    if resolution == "unresolved" and state != "missing":
        raise SchemaError("unresolved binding must use missing state and sentinels")
    if resolution == "ambiguous" and state != "unavailable":
        raise SchemaError("ambiguous binding must use unavailable state and sentinels")
    role = binding["requirement"]["provider_record_role"]
    if not shape_matches(
        binding["resolved_locator"],
        variant["provider_locator_shape"],
        role,
        "resolved_locator",
        binding["requirement"]["locator_template"],
    ):
        raise SchemaError("resolved locator does not match provider locator shape")
    has_unresolved = "unresolved" in binding["resolved_locator"]
    if resolution == "exact" and has_unresolved:
        raise SchemaError("exact binding contains an unresolved locator")
    if resolution == "unresolved" and not has_unresolved:
        raise SchemaError("unresolved binding lacks an unresolved locator")
    context_revision = text(
        binding["binding_context_revision"], "binding_context_revision"
    )
    canonical = [
        "maestro-acceptance-evidence-binding-v1",
        requirement[1],
        requirement_key,
        requirement[4],
        requirement[6],
        binding["resolved_locator"],
        context_revision,
        resolution,
        state,
        record_id,
        provider_revision,
    ]
    return canonical, resolution == "exact"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--plugin-root", required=True, type=Path)
    subparsers = parser.add_subparsers(dest="mode", required=True)
    for mode in ("requirement", "binding"):
        subparser = subparsers.add_parser(mode)
        subparser.add_argument("--input", required=True, type=Path)
    args = parser.parse_args()
    try:
        schema = load_schema(args.plugin_root)
        value = json.loads(args.input.read_text(encoding="utf-8"))
        if args.mode == "requirement":
            canonical, key, _ = canonical_requirement(schema, value)
            print(f"canonical\t{canonical_json(canonical)}")
            print(f"key\t{key}")
        else:
            canonical, publishable = canonical_binding(schema, value)
            print(f"canonical\t{canonical_json(canonical)}")
            print(
                "revision\t"
                + digest("acceptance-evidence-binding-v1", canonical)
            )
            print(f"publishable\t{str(publishable).lower()}")
    except (SchemaError, OSError, UnicodeError, json.JSONDecodeError) as error:
        print(f"evidence-source-schema error: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
