#!/usr/bin/env python3
"""Canonical evidence requirement and runtime binding schema oracle."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import unicodedata
from pathlib import Path, PurePosixPath
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
RUNTIME_CONTEXT_FIELDS = {
    "symphony",
    "current_implementation_issue",
    "repository",
    "current_linked_pr",
    "current_base",
    "current_head",
    "current_merge",
}
RUNTIME_CONTEXT_ORDER = (
    "symphony",
    "repository",
    "current_implementation_issue",
    "current_linked_pr",
    "current_base",
    "current_head",
    "current_merge",
)
GLOB_CHARACTERS = {"*", "?", "["}
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
    if name == "repository_path":
        if not isinstance(value, str):
            raise SchemaError(f"{field} must be a string")
        normalized = unicodedata.normalize("NFC", value.strip())
        if (
            not normalized
            or normalized.startswith("/")
            or "\\" in normalized
            or any(character in normalized for character in GLOB_CHARACTERS)
        ):
            raise SchemaError(f"{field} must be a safe repository-relative path")
        path = PurePosixPath(normalized)
        if ".." in path.parts:
            raise SchemaError(f"{field} must be a safe repository-relative path")
        normalized = path.as_posix()
        while normalized.startswith("./"):
            normalized = normalized[2:]
        if normalized in {"", "."}:
            raise SchemaError(f"{field} must name one repository-relative path")
        return normalized
    normalized = text(value, field)
    if "${" in normalized:
        raise SchemaError(f"{field} must be a static selector")
    if name == "repository" and not re.fullmatch(r"[^/\s]+/[^/\s]+", normalized):
        raise SchemaError(f"{field} must be owner/repository")
    return normalized


def canonical_locator(
    values: Any,
    shape: list[str],
    role: str,
    field: str,
) -> list[Any]:
    if not isinstance(values, list) or len(values) != len(shape):
        raise SchemaError(f"{field} does not match its finite shape")
    canonical = []
    for index, (value, slot) in enumerate(zip(values, shape)):
        kind, name = split_slot(slot, f"{field}.shape[{index}]")
        item_field = f"{field}[{index}]"
        if kind == "literal":
            if value != name:
                raise SchemaError(f"{item_field} literal differs")
            canonical.append(name)
        elif kind == "token":
            token = "${" + str(name) + "}"
            if value != token:
                raise SchemaError(f"{item_field} token differs")
            canonical.append(token)
        elif kind == "role":
            if value != role:
                raise SchemaError(f"{item_field} role differs")
            canonical.append(role)
        elif kind == "selector":
            canonical.append(validate_selector(value, str(name), item_field))
        else:
            raise SchemaError(f"{item_field} is not a plan-time locator slot")
    return canonical


def requirement_variant(
    schema: dict[str, Any],
    stage: str,
    source_kind: str,
    role: str,
    locator: Any,
) -> tuple[dict[str, Any], list[Any]]:
    matches = []
    for variant in schema["source_kinds"][source_kind]["variants"]:
        if stage not in variant["stages"] or role not in variant["provider_record_roles"]:
            continue
        try:
            canonical = canonical_locator(
                locator,
                variant["locator_template_shape"],
                role,
                "locator_template",
            )
        except SchemaError:
            continue
        matches.append((variant, canonical))
    if len(matches) != 1:
        raise SchemaError("requirement does not match exactly one source-kind variant")
    return matches[0]


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
    variant, locator = requirement_variant(
        schema,
        stage,
        source_kind,
        role,
        requirement["locator_template"],
    )
    canonical = [
        "maestro-evidence-requirement-key-v1",
        criterion_key,
        required_outcome,
        stage,
        source_kind,
        role,
        locator,
    ]
    return canonical, digest("evidence-requirement-key-v1", canonical), variant


def authoritative_context_locator(
    field: str,
    values: dict[str, str],
) -> list[str]:
    if field == "symphony":
        return [
            "authoritative-context-v1",
            "linear-issue",
            values[field],
            "symphony-control",
        ]
    if field == "current_implementation_issue":
        return [
            "authoritative-context-v1",
            "linear-issue",
            values[field],
            "implementation-of",
            values["symphony"],
        ]
    if field == "repository":
        return [
            "authoritative-context-v1",
            "github-repository",
            values[field],
            "repository-for",
            values["current_implementation_issue"],
        ]
    if field == "current_linked_pr":
        return [
            "authoritative-context-v1",
            "github-pr",
            values["repository"],
            values[field],
            "linked-to",
            values["current_implementation_issue"],
        ]
    role = {
        "current_base": "base",
        "current_head": "head",
        "current_merge": "merge",
    }[field]
    return [
        "authoritative-context-v1",
        "github-pr",
        values["repository"],
        values["current_linked_pr"],
        role,
        values[field],
    ]


def canonical_runtime_context(value: Any) -> dict[str, list[Any]]:
    context = exact_keys(value, RUNTIME_CONTEXT_FIELDS, "runtime_context")
    values = {}
    for field in RUNTIME_CONTEXT_ORDER:
        confirmation = exact_keys(
            context[field],
            {
                "value",
                "provider_locator",
                "provider_state",
                "provider_record_id",
                "provider_revision",
                "provider_evidence",
            },
            f"runtime_context.{field}",
        )
        if field == "repository":
            values[field] = validate_selector(
                confirmation["value"],
                "repository",
                f"runtime_context.{field}.value",
            )
        else:
            values[field] = text(
                confirmation["value"],
                f"runtime_context.{field}.value",
            )
    canonical = {}
    for field in RUNTIME_CONTEXT_ORDER:
        confirmation = context[field]
        locator = authoritative_context_locator(field, values)
        if confirmation["provider_locator"] != locator:
            raise SchemaError(
                f"runtime_context.{field} provider locator differs from governing context"
            )
        record_id = text(
            confirmation["provider_record_id"],
            f"runtime_context.{field}.provider_record_id",
        )
        revision = text(
            confirmation["provider_revision"],
            f"runtime_context.{field}.provider_revision",
        )
        evidence = text(
            confirmation["provider_evidence"],
            f"runtime_context.{field}.provider_evidence",
        )
        state = text(
            confirmation["provider_state"],
            f"runtime_context.{field}.provider_state",
        )
        if state not in OBSERVABLE_STATES:
            raise SchemaError(f"runtime_context.{field} state is not finite")
        if state == "present":
            if values[field] == "unresolved" or any(
                item in OBSERVABLE_STATES | {"unresolved"}
                for item in (record_id, revision, evidence)
            ):
                raise SchemaError(
                    f"runtime_context.{field} lacks provider confirmation"
                )
        elif (record_id, revision, evidence) != (state, state, state):
            raise SchemaError(
                f"runtime_context.{field} state sentinels differ"
            )
        canonical[field] = [
            values[field],
            locator,
            state,
            record_id,
            revision,
            evidence,
        ]
    return canonical


def derive_locator_and_context(
    requirement: list[Any],
    variant: dict[str, Any],
    context: dict[str, list[Any]],
) -> tuple[list[Any], str, bool]:
    template = requirement[6]
    selected = {"symphony": context["symphony"]}
    resolved = []
    for index, (template_slot, provider_slot) in enumerate(
        zip(
            variant["locator_template_shape"],
            variant["provider_locator_shape"],
        )
    ):
        template_kind, template_name = split_slot(
            template_slot, f"template shape[{index}]"
        )
        provider_kind, provider_name = split_slot(
            provider_slot, f"provider shape[{index}]"
        )
        if provider_kind == "literal":
            resolved.append(provider_name)
        elif provider_kind == "role":
            resolved.append(requirement[5])
        elif provider_kind == "selector":
            selector = template[index]
            if provider_name == "repository":
                if selector != context["repository"][0]:
                    raise SchemaError(
                        "requirement repository differs from authoritative context"
                    )
                selected["repository"] = context["repository"]
            resolved.append(selector)
        elif provider_kind == "binding":
            if template_kind != "token" or template_name != provider_name:
                raise SchemaError("binding slot differs from template token")
            selected[str(provider_name)] = context[str(provider_name)]
            resolved.append(context[str(provider_name)][0])
        else:
            raise SchemaError("provider locator shape contains an unknown slot")
    selected_pairs = [
        [field, selected[field]]
        for field in RUNTIME_CONTEXT_ORDER
        if field in selected
    ]
    canonical_context = [
        "maestro-evidence-binding-context-v1",
        selected_pairs,
    ]
    selected_unresolved = any(
        confirmation[0] == "unresolved" or confirmation[2] != "present"
        for confirmation in selected.values()
    )
    return (
        resolved,
        digest("evidence-binding-context-v1", canonical_context),
        selected_unresolved,
    )


def canonical_provider_result(
    value: Any,
    derived_locator: list[Any],
    index: int,
) -> tuple[str, str, str, str]:
    result = exact_keys(
        value,
        {
            "resolved_locator",
            "evidence_state",
            "provider_record_id",
            "provider_revision",
            "provider_evidence",
        },
        f"provider_results[{index}]",
    )
    if result["resolved_locator"] != derived_locator:
        raise SchemaError("provider result locator differs from derived locator")
    state = text(result["evidence_state"], f"provider_results[{index}].evidence_state")
    if state not in OBSERVABLE_STATES:
        raise SchemaError("provider result state is not finite")
    record_id = text(
        result["provider_record_id"],
        f"provider_results[{index}].provider_record_id",
    )
    revision = text(
        result["provider_revision"],
        f"provider_results[{index}].provider_revision",
    )
    evidence = text(
        result["provider_evidence"],
        f"provider_results[{index}].provider_evidence",
    )
    if state == "present":
        if any(
            item in OBSERVABLE_STATES
            for item in (record_id, revision, evidence)
        ):
            raise SchemaError("present provider result requires identity/revision/evidence")
    elif (record_id, revision, evidence) != (state, state, state):
        raise SchemaError("non-present provider result sentinels must match state")
    return state, record_id, revision, evidence


def canonical_binding(schema: dict[str, Any], value: Any) -> tuple[list[Any], bool]:
    if not isinstance(value, dict):
        raise SchemaError("binding must be an object")
    required_keys = {
        "requirement",
        "runtime_context",
        "provider_query",
        "provider_results",
    }
    if set(value) not in (required_keys, required_keys | {"assertions"}):
        raise SchemaError("binding keys differ from authoritative input schema")
    binding = value
    requirement, requirement_key, variant = canonical_requirement(
        schema, binding["requirement"]
    )
    context = canonical_runtime_context(binding["runtime_context"])
    resolved_locator, context_revision, context_unresolved = derive_locator_and_context(
        requirement,
        variant,
        context,
    )
    query = exact_keys(
        binding["provider_query"],
        {"resolved_locator"},
        "provider_query",
    )
    if query["resolved_locator"] != resolved_locator:
        raise SchemaError("provider query locator differs from derived locator")
    results = binding["provider_results"]
    if not isinstance(results, list):
        raise SchemaError("provider_results must be a list")
    token_unresolved = any(value == "unresolved" for value in resolved_locator)
    if token_unresolved and results:
        raise SchemaError("unresolved runtime token cannot have provider results")
    canonical_results = [
        canonical_provider_result(result, resolved_locator, index)
        for index, result in enumerate(results)
    ]
    if token_unresolved or context_unresolved or not canonical_results:
        resolution = "unresolved"
        state = record_id = provider_revision = provider_evidence = "missing"
    elif len(canonical_results) > 1:
        resolution = "ambiguous"
        state = record_id = provider_revision = provider_evidence = "unavailable"
    else:
        resolution = "exact"
        state, record_id, provider_revision, provider_evidence = canonical_results[0]
    assertions = binding.get("assertions")
    if assertions is not None:
        assertions = exact_keys(
            assertions,
            {"resolved_locator", "binding_context_revision"},
            "assertions",
        )
        if assertions["resolved_locator"] != resolved_locator:
            raise SchemaError("asserted locator differs from derived locator")
        if assertions["binding_context_revision"] != context_revision:
            raise SchemaError("asserted context revision differs from derived revision")
    canonical = [
        "maestro-acceptance-evidence-binding-v1",
        requirement[1],
        requirement_key,
        requirement[4],
        requirement[6],
        resolved_locator,
        context_revision,
        resolution,
        state,
        record_id,
        provider_revision,
        provider_evidence,
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
