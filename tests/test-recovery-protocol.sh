#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")/.."
source tests/lib/assertions.sh

core=references/symphony/core.md
linear=references/symphony/linear.md
review=references/symphony/review.md
reconcile=skills/symphony-reconcile/SKILL.md
status=skills/symphony-status/SKILL.md
integration=tests/REAL_INTEGRATION.md

for event in dag-rejected decision-resolved; do
  assert_contains "$core" '\| `'"$event"'` \|'
  assert_contains skills/symphony-start/SKILL.md "$event"
  assert_contains "$reconcile" "$event"
  assert_contains "$status" "$event"
done

assert_contains "$core" 'exact rejected DAG/contract revision'
assert_contains "$core" 'proposal action identity'
assert_contains "$core" 'superseded or may be revised'
assert_contains "$core" 'accept-observed-as-revision'
assert_contains "$core" 'restore-approved-state'
assert_contains "$core" 'revise-affected-wave'
assert_contains "$core" 'confirmed resume phase'
assert_contains "$core" 'decision-resolved.*before.*remov'
assert_contains "$status" 'Resolved historical pauses'
assert_contains "$status" 'Rejected DAG revisions'

assert_contains "$core" 'Create discovery issue'
assert_contains "$core" 'Symphony UUID.*discovery revision.*fixed discovery'
assert_contains "$linear" 'Maestro-Discovery-Creation-Identity'
assert_contains "$linear" 'fixed approved/planned.*question key'
assert_contains "$linear" 'before create and after an ambiguous'
assert_contains skills/symphony-start/SKILL.md 'Maestro-Discovery-Creation-Identity'
assert_contains skills/symphony-start/SKILL.md 'discovery revision.*fixed discovery'
assert_contains "$core" 'Create required follow-up issue'
assert_contains "$core" 'source implementation issue UUID.*source merge SHA.*fixed follow-up key'
assert_contains "$linear" 'Maestro-Follow-Up-Creation-Identity'
assert_contains "$reconcile" 'Maestro-Follow-Up-Creation-Identity'
assert_contains "$reconcile" 'source implementation issue UUID.*source merge SHA.*fixed follow-up key'
assert_contains "$review" 'Maestro-Review-Action-Identity'
assert_contains "$review" 'exact PR/head.*before publication.*after an ambiguous'
assert_contains "$review" 'Maestro-Cursor-Follow-Up-Identity'
assert_contains "$review" 'exactly one confirmed canonical GitHub record'
assert_contains skills/symphony-review/SKILL.md 'Maestro-Review-Action-Identity'
assert_contains skills/symphony-review/SKILL.md 'Maestro-Cursor-Follow-Up-Identity'

for family in discovery-issue required-follow-up github-review-record \
  linear-cursor-follow-up; do
  assert_contains tests/fixtures/failure-injection-plans.tsv \
    "^${family}_ambiguous[[:space:]]"
done

assert_contains "$integration" 'final integration/outcome-verification issue'
assert_contains "$integration" 'closeout is blocked'
assert_contains "$integration" 'decision-resolved'
assert_contains "$integration" 'Final as-built outcome'
assert_contains "$integration" 'exactly one `symphony-completed`'
assert_contains "$integration" 'control-only `maestro:complete`'
assert_contains "$integration" 'fresh session'
assert_contains "$integration" 'historical rejected/resolved'

pass "durable Symphony recovery and external-record identities"
