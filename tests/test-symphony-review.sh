#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")/.."
source tests/lib/assertions.sh

path=skills/symphony-review/SKILL.md
assert_file "$path"
assert_frontmatter_value "$path" name symphony-review
assert_frontmatter_value "$path" user-invocable false

for ref in core linear reconciliation review; do
  assert_contains "$path" "\\$\\{CLAUDE_PLUGIN_ROOT\\}/references/symphony/$ref.md"
done

assert_contains "$path" '^## Validate review identity$'
assert_contains "$path" '^## Accept the prepared exact-head worktree$'
assert_contains "$path" 'ownership marker'
assert_contains "$path" 'component-level containment'
assert_contains "$path" 'exact PR head SHA'
assert_contains "$path" 'time-bounded'
assert_contains "$path" 'tracked and staged'
assert_contains "$path" 'maestro:symphony-reviewer'
assert_contains "$path" 'maestro:code-reviewer'
assert_contains "$path" 'maestro:security-reviewer'
assert_contains "$path" 'maestro:test-analyzer'
assert_contains "$path" 'maestro:comment-analyzer'
assert_contains "$path" 'runtime toolchain'
assert_contains "$path" 'review-stale-head'
assert_contains "$path" '@Cursor'
assert_contains "$path" '^## Cleanup guarantee$'
assert_contains "$path" 'Never implement the fix'
assert_contains "$path" 'transferred exact-head worktree'
assert_contains "$path" 'explicit timeout'
assert_contains "$path" '[Ii]mmediately before and after each command'
assert_contains "$path" 'validation-timeout'
assert_contains "$path" 'terminate the command'
assert_contains "$path" 'required validation commands'
assert_contains "$path" 'required acceptance evidence'
assert_contains "$path" 'complete current review context'
assert_contains "$path" 'publish neither the GitHub record nor Linear'
assert_contains "$path" 'Repository CI, review, and merge gates are not prerequisites'

pass "symphony-review skill"
