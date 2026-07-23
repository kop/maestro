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

for path in \
  agents/code-architect.md \
  agents/code-reviewer.md \
  agents/comment-analyzer.md \
  agents/implementation-reconciler.md \
  agents/security-reviewer.md \
  agents/symphony-researcher.md \
  agents/symphony-reviewer.md \
  agents/test-analyzer.md \
  skills/feedback/SKILL.md \
  skills/symphony-start/SKILL.md \
  skills/symphony-reconcile/SKILL.md \
  skills/symphony-status/SKILL.md \
  skills/symphony-review/SKILL.md
do
  assert_file "$path"
done

assert_contains .claude-plugin/plugin.json '"version":[[:space:]]*"0\.2\.0"'
assert_contains .claude-plugin/plugin.json 'Linear and GitHub control plane'
assert_contains .claude-plugin/marketplace.json '"description"'

assert_contains README.md '/maestro:symphony-start'
assert_contains README.md '/maestro:symphony-reconcile'
assert_contains README.md '/maestro:symphony-status'
assert_contains README.md '@Cursor'
assert_contains README.md '0\.2\.0'
assert_contains README.md 'epic, milestone, Linear project, broader goal, or existing Symphony issue'
assert_contains README.md 'Planning is discovery-first'
assert_contains README.md 'research and architecture subagents gather evidence'
assert_contains README.md 'before proposing approved waves'
assert_contains README.md 'one bounded, idempotent pass'
assert_contains README.md '/loop owns repetition'
assert_contains README.md 'no subagent sleeps or polls'
assert_contains README.md 'risk-adaptive and exact-head'
assert_contains README.md 'mandatory Symphony-context reviewer'
assert_contains README.md 'code, test, security, and comment lenses'
assert_contains README.md 'labels, files, and context'
assert_not_contains README.md '/review \[quick\|full\]'
assert_not_contains README.md '/autopilot'
assert_not_contains README.md 'stacked-prs'
assert_not_contains README.md 'peer agent'
assert_not_contains README.md 'claude --agent maestro'

for path in tests/*.sh tests/lib/*.sh; do
  assert_executable "$path"
done

pass "final plugin package"
