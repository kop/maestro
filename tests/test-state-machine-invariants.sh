#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")/.."
source tests/lib/assertions.sh

core=references/symphony/core.md
linear=references/symphony/linear.md
reconciliation=references/symphony/reconciliation.md
start=skills/symphony-start/SKILL.md
reconcile=skills/symphony-reconcile/SKILL.md

assert_order() {
  local path=$1
  local first=$2
  local second=$3
  local first_line second_line
  first_line=$(grep -nEm1 -- "$first" "$path" | cut -d: -f1)
  second_line=$(grep -nEm1 -- "$second" "$path" | cut -d: -f1)
  [[ -n "$first_line" && -n "$second_line" && "$first_line" -lt "$second_line" ]] ||
    fail "$path does not order '$first' before '$second'"
}

# Durable proposal, approval, binding, relation, and materialization authority.
for path in "$core" "$linear" "$start"; do
  assert_contains "$path" 'dag-proposed'
  assert_contains "$path" 'dag-approved'
  assert_contains "$path" 'dag-node-bound'
  assert_contains "$path" 'dag-edge-bound'
  assert_contains "$path" 'dag-materialized'
done
assert_order "$start" 'dag-proposed' 'request explicit user approval'
assert_order "$start" 'dag-approved' 'Create or resume each candidate'
assert_contains "$start" 'proposal action identity'
assert_contains "$start" 'approval evidence'
assert_contains "$start" 'approved'
assert_contains "$start" 'DAG revision'
assert_contains "$start" 'fixed node key'
assert_contains "$start" 'search the embedded action'
assert_contains "$start" 'identity before retry'
assert_contains "$start" 'immediately append'
assert_contains "$start" 'dag-node-bound'
assert_contains "$start" 'both endpoints.*bound'
assert_contains "$start" 'fresh pass.*resume'
for path in references/symphony/*.md skills/symphony-*/SKILL.md agents/*.md \
  README.md; do
  assert_not_contains "$path" 'dag-approved-and-materialized'
done

# Merge reconciliation is gated by the reconciler's exact verdict and evidence.
for path in "$reconciliation" "$reconcile"; do
  assert_contains "$path" 'reconciler identity'
  assert_contains "$path" 'acceptance-evidence table'
  assert_contains "$path" 'verdict `complete`'
  assert_contains "$path" '`human-decision`'
  assert_contains "$path" '`inconclusive`'
  assert_contains "$path" 'downstream blockers.*locked'
  assert_contains "$path" 'merged remains distinct'
  assert_contains "$path" 'merge-reconciled'
done
assert_contains "$reconcile" 'every acceptance criterion satisfied'
assert_contains "$reconcile" 'evidenced'
assert_contains "$reconcile" 'leave.*unreconciled'

# New control issues have deterministic, searchable creation identities.
for path in "$core" "$linear" "$start"; do
  assert_contains "$path" 'native target Linear scope'
  assert_contains "$path" 'UUID'
  assert_contains "$path" 'normalized'
  assert_contains "$path" 'requested goal'
  assert_contains "$path" 'control-contract revision'
  assert_contains "$path" '[Ee]mbed'
  assert_contains "$path" 'creation identity'
  assert_contains "$path" 'native target scope'
  assert_contains "$path" 'embedded identity'
  assert_contains "$path" 'title'
  assert_contains "$path" 'never'
  assert_contains "$path" 'sufficient'
done
assert_contains "$core" 'Create control issue'
assert_contains "$core" 'random/model-generated'

# Symphony closeout is outcome-verification gated, not terminal-count gated.
for path in "$linear" "$reconciliation" "$reconcile"; do
  assert_contains "$path" 'Symphony closeout'
  assert_contains "$path" 'final integration/outcome-verification'
  assert_contains "$path" 'succeeded with.*evidence'
  assert_contains "$path" 'all merged PRs.*merge-reconciled'
  assert_contains "$path" 'no unresolved semantic drift'
  assert_contains "$path" 'Final'
  assert_contains "$path" 'as-built'
  assert_contains "$path" 'outcome'
  assert_contains "$path" 'symphony-completed'
  assert_contains "$path" 'maestro:complete'
  assert_contains "$path" 'terminal'
  assert_contains "$path" 'must not'
  assert_contains "$path" 'close the Symphony'
done
assert_contains README.md 'outcome-verification'

# Entity-scoped phase rules preserve pause semantics and separate completion.
assert_contains "$core" '^## Entity-scoped phase transitions$'
assert_contains "$core" 'Control issue.*maestro:complete.*symphony-completed'
assert_contains "$core" 'Discovery issue.*maestro:complete.*discovery-recorded.*discovery-completed'
assert_contains "$core" 'Implementation issue.*maestro:complete.*merge-reconciled'
assert_contains "$core" 'Never implies Symphony completion'
assert_contains "$core" 'Prior/resume phase'
assert_contains "$core" 'needs-human.*bounded'
assert_contains "$core" 'scope-change.*strategic'
assert_contains "$reconciliation" '^## Entity-scoped managed issue completion$'
assert_contains "$reconciliation" 'discovery-completed'
assert_contains "$reconciliation" 'issue-cancelled'
assert_contains "$reconciliation" 'implementation issue.*never.*Symphony'
assert_contains "$start" 'discovery-completed'
assert_contains "$start" 'discovery issue only'
assert_contains "$reconcile" 'implementation issue only'
assert_contains skills/symphony-status/SKILL.md 'entity-scoped authority'

pass "durable Symphony state-machine invariants"
