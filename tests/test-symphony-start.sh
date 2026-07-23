#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")/.."
source tests/lib/assertions.sh

path=skills/symphony-start/SKILL.md
assert_file "$path"
assert_frontmatter_value "$path" name symphony-start
assert_frontmatter_value "$path" disable-model-invocation true
assert_contains "$path" '^description: Use when.*epic'
assert_contains "$path" '^description: Use when.*milestone'
assert_contains "$path" '^description: Use when.*Linear project'
assert_contains "$path" '^description: Use when.*broader goal'
assert_contains "$path" '^description: Use when.*\[Symphony\].*issue'
assert_not_contains "$path" '^description:.*(capability preflight|repository discovery|materializ)'

for ref in core linear reconciliation; do
  assert_contains "$path" "\\$\\{CLAUDE_PLUGIN_ROOT\\}/references/symphony/$ref.md"
done

assert_contains "$path" '^## Capability preflight$'
assert_contains "$path" '^## Discovery gate$'
assert_contains "$path" 'maestro:symphony-researcher'
assert_contains "$path" 'maestro:code-architect'
assert_contains "$path" '^## Approval gate$'
assert_contains "$path" 'Do not delegate'
assert_contains "$path" 'native `blockedBy`'
assert_contains "$path" 'repo:owner/repository'
assert_contains "$path" 'Superpowers'
assert_contains "$path" 'Do not use'
assert_contains "$path" 'subagent-driven-development'
assert_contains "$path" 'native status'
assert_contains "$path" 'Preserve the current native status unless a transition is unambiguous'
assert_contains "$path" 'stop before discovery, planning, or materialization and request a user decision'
assert_contains "$path" 'Continue only after an explicit decision or a clearly permitted existing-workflow transition'
assert_contains "$path" 'Do not invent a Maestro status'

pass "symphony-start skill"
