#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")/.."
source tests/lib/assertions.sh

assert_file agents/symphony-researcher.md
assert_file agents/code-architect.md

assert_frontmatter_value agents/symphony-researcher.md name symphony-researcher
assert_frontmatter_value agents/symphony-researcher.md model sonnet
assert_frontmatter_value agents/code-architect.md name code-architect
assert_frontmatter_value agents/code-architect.md model opus

for path in agents/symphony-researcher.md agents/code-architect.md; do
  assert_not_contains "$path" '^tools:.*(Write|Edit|Agent)'
  assert_contains "$path" '\$\{CLAUDE_PLUGIN_ROOT\}/references/symphony/core.md'
  assert_contains "$path" 'must not implement'
done

assert_contains agents/symphony-researcher.md '^## Required assignment envelope$'
assert_contains agents/symphony-researcher.md '^## Result contract$'
assert_contains agents/symphony-researcher.md 'Confidence and remaining unknowns'
assert_contains agents/code-architect.md '^## Cross-repository architecture process$'
assert_contains agents/code-architect.md '^## Symphony architecture result$'
assert_contains agents/code-architect.md 'DAG recommendations'

pass "planning agents"
