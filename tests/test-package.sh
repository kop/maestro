#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")/.."
source tests/lib/assertions.sh

for path in \
  agents/general-purpose.md \
  agents/maestro.md \
  agents/peer.md \
  agents/scribe.md \
  skills/autopilot \
  skills/review \
  skills/stacked-prs
do
  assert_not_file "$path"
done

assert_file skills/feedback/SKILL.md
assert_contains skills/feedback/SKILL.md 'Symphony'
assert_contains skills/feedback/SKILL.md 'discovery'
assert_contains skills/feedback/SKILL.md 'DAG'
assert_contains skills/feedback/SKILL.md 'Cursor'
assert_contains skills/feedback/SKILL.md 'merge reconciliation'
assert_not_contains skills/feedback/SKILL.md 'peer'
assert_not_contains skills/feedback/SKILL.md 'scribe'
assert_not_contains skills/feedback/SKILL.md 'autopilot'

pass "plugin reshaping"
