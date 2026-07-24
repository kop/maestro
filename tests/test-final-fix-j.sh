#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")/.."
source tests/lib/assertions.sh

core=references/symphony/core.md
reconciliation=references/symphony/reconciliation.md
design=docs/superpowers/specs/2026-07-23-maestro-symphony-control-plane-design.md
plan=docs/superpowers/plans/2026-07-23-maestro-symphony-control-plane.md
reconciler=agents/implementation-reconciler.md
reducer=tests/lib/failure-injection-reducer.sh

assert_contains "$core" 'Reserve review worktree.*review-preparation-v1'
assert_contains "$core" 'Reconcile merge.*reconciliation binding manifest revision.*reconciliation-input-v1'
assert_contains "$design" 'Reserve review worktree.*review-preparation-v1'
assert_contains "$design" 'Reconcile merge.*reconciliation binding manifest revision.*reconciliation-input-v1'
assert_contains "$plan" 'Reserve review worktree.*review-preparation-v1'
assert_contains "$plan" 'Reconcile merge.*reconciliation binding manifest revision.*reconciliation-input-v1'

assert_not_contains "$core" 'Reconcile merge \| Linear issue UUID \+ merge SHA \|'
assert_not_contains "$design" 'Reconcile merge \| Linear issue UUID \+ merge SHA \|'
assert_not_contains "$plan" 'Reconcile merge \| Linear issue UUID \+ merge SHA \|'

assert_contains "$reconciliation" 'reconciliation-input-v1'
assert_contains "$reconciliation" 'staged binding manifest before dispatch'
assert_contains "$reconciliation" 'byte-for-byte manifest echo'
assert_contains "$reconciliation" 'exact conclusion-to-binding mapping'
assert_contains "$reconciler" '^Symphony UUID:'
assert_contains "$reconciler" '^Repository native identity:'
assert_contains "$reconciler" '^Reconciliation input revision:'
assert_contains "$reconciler" '^Reconcile action identity:'

assert_contains "$plan" 'staged binding manifest before reconciler dispatch'
assert_contains "$plan" 'exact manifest echo and conclusion-to-binding mapping'
assert_contains "$plan" 'required transition order is `merge-reconciled`'
assert_contains "$plan" 'later `symphony-completed`'
assert_contains "$plan" 'reservation-aware pre-binding and post-binding cleanup'
assert_contains "$plan" '^Reconciliation binding manifest revision:'
assert_contains "$plan" 'Requirement keys.*Exact binding references'
assert_contains "$plan" 'one-to-one reservation.*action journal binding'
assert_contains "$plan" 'action identity alone never'
assert_not_contains "$plan" '2\. Run `implementation-reconciler`\.'
assert_not_contains "$plan" '8\. Mark complete and recalculate readiness\.'
assert_not_contains "$plan" '^3\. Read and match the ownership marker\.$'
assert_not_contains "$plan" 'envelope and manifest/revision'

assert_not_contains "$reducer" '^bound_attached_cleanup_is_safe\(\)'
assert_not_contains "$reducer" '^bound_unattached_cleanup_is_safe\(\)'
assert_not_contains tests/fixtures/failure-injection-plans.tsv \
  'marker=match;action_identity=match;attachment='
assert_contains "$reducer" 'reservation_attached_cleanup_is_safe'
assert_contains "$reducer" 'bound_review_attached_cleanup_is_safe'

assert_contains review-source-requirements-v1.json 'scripts/review_source_policy.py'
assert_contains scripts/review-source-closure.py \
  'from review_source_policy import'
assert_contains scripts/review-preparation.py \
  'from review_source_policy import'
assert_contains evidence-source-schema-v1.json '"governing_relationships"'

pass "Final Fix J governing authority synchronization"
