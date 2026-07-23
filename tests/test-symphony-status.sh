#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")/.."
source tests/lib/assertions.sh

path=${SYMPHONY_STATUS_SKILL_PATH:-skills/symphony-status/SKILL.md}
assert_file "$path"
assert_frontmatter_value "$path" name symphony-status
assert_contains "$path" '^description: Use when '
assert_contains "$path" 'Symphony status'
assert_contains "$path" 'fresh-session recovery'
assert_contains "$path" 'drift'
assert_contains "$path" 'blocker'
assert_contains "$path" 'next-transition'

for ref in core linear reconciliation; do
  assert_contains "$path" "\\$\\{CLAUDE_PLUGIN_ROOT\\}/references/symphony/$ref.md"
done

assert_contains "$path" 'read-only'
assert_contains "$path" 'Never write'
assert_contains "$path" '^## Status output$'
assert_contains "$path" '^## Outcome$'
assert_contains "$path" '^## Approved waves$'
assert_contains "$path" '^## Discovery and unapproved planning$'
assert_contains "$path" '^## Cursor implementation and PRs$'
assert_contains "$path" '^## Ready and blocked work$'
assert_contains "$path" '^## Drift$'
assert_contains "$path" '^## Controller failures and cleanup$'
assert_contains "$path" '^## Human decisions$'
assert_contains "$path" '^## Next transitions$'
assert_contains "$path" 'Ready in deterministic order'
assert_contains "$path" 'Highest-priority expected transition'
assert_contains "$path" 'unknown'
assert_contains "$path" 'Never write'
assert_contains "$path" 'private authoritative snapshot'
assert_contains "$path" 'current native Linear/GitHub provider records'
assert_contains "$path" 'journal explains history and transitions only'
assert_contains "$path" 'partial, omitted, inaccessible, or cannot be resolved by native ID'
assert_contains "$path" 'preserve dependent values as `unknown`'
assert_contains "$path" 'name missing evidence'
assert_contains "$path" 'complete required report structure'

for observation in \
  'control issue' \
  'native status, labels, and relations' \
  'approved revisions' \
  'managed issues' \
  'dependencies' \
  'delegations' \
  'linked PR head, checks, reviews, threads, and merge state'; do
  assert_contains "$path" "$observation"
done

pass "symphony-status skill"
