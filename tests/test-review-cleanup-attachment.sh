#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")/.."
source tests/lib/assertions.sh

for path in references/symphony/review.md skills/symphony-review/SKILL.md; do
  assert_contains "$path" 'reserved-unattached'
  assert_contains "$path" 'attached-worktree'
  assert_contains "$path" 'attachment state'
  assert_contains "$path" 'expected action identity'
  assert_contains "$path" 'no repository/worktree metadata'
  assert_contains "$path" 'unexpected (file|contents)'
  assert_contains "$path" 'success, failure, timeout, stale head, reviewer error, and publication failure'
  assert_contains "$path" 'retry only after a new safe observation'
done

assert_contains skills/symphony-review/SKILL.md \
  'Git worktree metadata matches the expected repository and canonical path'
assert_contains skills/symphony-review/SKILL.md \
  'Remove only the known empty reservation and marker artifacts'
assert_contains skills/symphony-review/SKILL.md \
  'retain the exact owned path'

pass "review cleanup attachment-state branches"
