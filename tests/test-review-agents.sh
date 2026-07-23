#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")/.."
source tests/lib/assertions.sh

for path in agents/symphony-reviewer.md agents/implementation-reconciler.md; do
  assert_file "$path"
  assert_frontmatter_value "$path" model opus
  assert_not_contains "$path" '^tools:.*(Write|Edit|Agent)'
  assert_contains "$path" '\$\{CLAUDE_PLUGIN_ROOT\}/references/symphony/'
  assert_contains "$path" 'must not implement'
done

assert_frontmatter_value agents/symphony-reviewer.md name symphony-reviewer
assert_contains agents/symphony-reviewer.md '^## Review process$'
assert_contains agents/symphony-reviewer.md 'downstream'
assert_contains agents/symphony-reviewer.md 'Common finding contract'

assert_frontmatter_value agents/implementation-reconciler.md name implementation-reconciler
assert_contains agents/implementation-reconciler.md '^## Reconciliation process$'
assert_contains agents/implementation-reconciler.md '^## Result contract$'
assert_contains agents/implementation-reconciler.md 'downstream-plan-change'
assert_contains agents/implementation-reconciler.md 'follow-up-required'
assert_contains agents/implementation-reconciler.md 'implementation issue UUID'
assert_contains agents/implementation-reconciler.md '^Issue UUID:$'
assert_contains agents/implementation-reconciler.md '^Merge SHA:$'

for path in \
  agents/code-reviewer.md \
  agents/security-reviewer.md \
  agents/test-analyzer.md \
  agents/comment-analyzer.md
do
  assert_file "$path"
  assert_not_contains "$path" '^tools:.*(Write|Edit|Agent)'
  assert_contains "$path" '\$\{CLAUDE_PLUGIN_ROOT\}/references/symphony/review.md'
  assert_contains "$path" 'Common finding contract'
  assert_contains "$path" 'exact PR head SHA'
done

assert_contains agents/code-reviewer.md '[Rr]endered infrastructure'
assert_contains agents/code-reviewer.md 'runtime toolchain'
assert_contains agents/security-reviewer.md 'Symphony dependency contract'
assert_contains agents/test-analyzer.md 'acceptance criterion'
assert_contains agents/comment-analyzer.md 'contract or interface documentation'

pass "contextual review agents"
