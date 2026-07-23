#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")/.."
source tests/lib/assertions.sh

path=skills/symphony-reconcile/SKILL.md
assert_file "$path"
assert_frontmatter_value "$path" name symphony-reconcile
assert_frontmatter_value "$path" disable-model-invocation true

for ref in core linear reconciliation review; do
  assert_contains "$path" "\\$\\{CLAUDE_PLUGIN_ROOT\\}/references/symphony/$ref.md"
done

assert_contains "$path" '^## 1. Reconstruct observed state$'
assert_contains "$path" '^## 2. Detect drift$'
assert_contains "$path" '^## 3. Reconcile merges first$'
assert_contains "$path" 'maestro:implementation-reconciler'
assert_contains "$path" '^## 4. Review new PR heads$'
assert_contains "$path" 'maestro:symphony-review'
assert_contains "$path" '^## 5. Continue discovery and planning$'
assert_contains "$path" '^## 6. Dispatch ready implementation issues$'
assert_contains "$path" 'Dispatch preflight'
assert_contains "$path" 'maximum active Cursor issues.*3'
assert_contains "$path" 'Linear priority'
assert_contains "$path" '^## 7. Journal and exit$'
assert_contains "$path" '[Nn]ever sleep'
assert_contains "$path" 'does not diagnose ordinary'
assert_contains "$path" 'CI failures'
assert_contains "$path" 'three consecutive attempts'

pass "symphony-reconcile skill"
