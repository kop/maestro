#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")/.."
source tests/lib/assertions.sh

for path in \
  references/symphony/core.md \
  references/symphony/linear.md \
  references/symphony/reconciliation.md \
  references/symphony/review.md
do
  assert_file "$path"
done

assert_contains references/symphony/core.md '^## Authority boundary$'
assert_contains references/symphony/core.md 'must not implement product code'
assert_contains references/symphony/core.md '^## Observation and action model$'
assert_contains references/symphony/core.md 'confirmed \| ambiguous \| retryable-failure \| permanent-failure'
assert_contains references/symphony/core.md '^## Journal event envelope$'
assert_contains references/symphony/core.md 'maestro:needs-human'

assert_contains references/symphony/linear.md '^## Control issue contract$'
assert_contains references/symphony/linear.md '^## Implementation issue contract$'
assert_contains references/symphony/linear.md 'repo:owner/repository'
assert_contains references/symphony/linear.md 'native `blockedBy`'

assert_contains references/symphony/reconciliation.md '^## Pass order$'
assert_contains references/symphony/reconciliation.md '^## Dispatch preflight$'
assert_contains references/symphony/reconciliation.md 'maximum active Cursor issues: 3'
assert_contains references/symphony/reconciliation.md 'three consecutive attempts'
assert_contains references/symphony/reconciliation.md 'Pending CI'
assert_contains references/symphony/reconciliation.md 'not failures and do not consume'

assert_contains references/symphony/review.md '^## Required review identity$'
assert_contains references/symphony/review.md '^## Owned worktree protocol$'
assert_contains references/symphony/review.md 'exact PR head SHA'
assert_contains references/symphony/review.md '@Cursor'

pass "shared Symphony protocol"
