#!/usr/bin/env python3
"""Fixed plugin-owned authority for Symphony review source closure."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any


POLICY_VERSION = "review-source-requirements-v1"
POLICY_PATH = "review-source-requirements-v1.json"
MANDATORY_REVIEWER = "agents/symphony-reviewer.md"
MANDATORY_PLUGIN_SOURCES = (
    POLICY_PATH,
    "scripts/review_source_policy.py",
    "scripts/review-source-closure.py",
    "scripts/review-preparation.py",
    "evidence-source-schema-v1.json",
    "scripts/evidence-source-schema.py",
    "skills/symphony-review/SKILL.md",
    "references/symphony/core.md",
    "references/symphony/linear.md",
    "references/symphony/reconciliation.md",
    "references/symphony/review.md",
    MANDATORY_REVIEWER,
)
SKILL_DEPENDENCIES = (
    "references/symphony/core.md",
    "references/symphony/linear.md",
    "references/symphony/reconciliation.md",
    "references/symphony/review.md",
)
LENS_SOURCES = {
    "maestro:code-reviewer": ("agents/code-reviewer.md",),
    "maestro:comment-analyzer": ("agents/comment-analyzer.md",),
    "maestro:security-reviewer": ("agents/security-reviewer.md",),
    "maestro:test-analyzer": ("agents/test-analyzer.md",),
}


class SourcePolicyError(ValueError):
    pass


def _exact_keys(value: Any, expected: set[str], field: str) -> dict[str, Any]:
    if not isinstance(value, dict) or set(value) != expected:
        raise SourcePolicyError(f"{field} keys differ from fixed source policy")
    return value


def _exact_string_list(value: Any, expected: tuple[str, ...], field: str) -> None:
    if not isinstance(value, list) or value != list(expected):
        raise SourcePolicyError(f"{field} differs from fixed source policy")


def load_and_validate_source_policy(
    plugin_root: Path,
) -> tuple[dict[str, Any], str]:
    root = plugin_root.resolve()
    policy_path = (root / POLICY_PATH).resolve(strict=False)
    try:
        policy_path.relative_to(root)
    except ValueError as error:
        raise SourcePolicyError("source policy escapes plugin root") from error
    if policy_path.is_symlink():
        raise SourcePolicyError("source policy must not be a symlink")
    try:
        policy_bytes = policy_path.read_bytes()
        policy = json.loads(policy_bytes.decode("utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise SourcePolicyError(f"source policy unavailable: {error}") from error
    policy = _exact_keys(
        policy,
        {
            "version",
            "mandatory_plugin_sources",
            "skill_dependencies",
            "lens_sources",
        },
        "source policy",
    )
    if policy["version"] != POLICY_VERSION:
        raise SourcePolicyError("source policy version differs")
    _exact_string_list(
        policy["mandatory_plugin_sources"],
        MANDATORY_PLUGIN_SOURCES,
        "mandatory plugin sources",
    )
    _exact_string_list(
        policy["skill_dependencies"],
        SKILL_DEPENDENCIES,
        "skill dependencies",
    )
    lenses = _exact_keys(
        policy["lens_sources"],
        set(LENS_SOURCES),
        "lens sources",
    )
    for lens, expected_sources in LENS_SOURCES.items():
        _exact_string_list(
            lenses[lens],
            expected_sources,
            f"lens sources for {lens}",
        )
    if MANDATORY_REVIEWER not in policy["mandatory_plugin_sources"]:
        raise SourcePolicyError("mandatory Symphony reviewer is absent")
    revision = (
        "review-source-requirements-v1:"
        + hashlib.sha256(policy_bytes).hexdigest()
    )
    return policy, revision
