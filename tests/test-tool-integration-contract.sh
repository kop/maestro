#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")/.."
source tests/lib/assertions.sh

fixture=tests/fixtures/tool-integration-cases.tsv
assert_file "$fixture"

expected_header='case_id|surface|simulated_result|expected_category|expected_action'
actual_header=$(head -n 1 "$fixture")
[[ "$actual_header" == "$expected_header" ]] ||
  fail "unexpected fixture header: $actual_header"

rows=0
while IFS='|' read -r case_id surface simulated_result expected_category expected_action; do
  [[ -n "$case_id" && -n "$surface" && -n "$simulated_result" ]] ||
    fail "malformed integration fixture row"

  if [[ "$expected_category" != "none" ]]; then
    grep -Eq -- "$expected_category" \
      references/symphony/reconciliation.md \
      references/symphony/review.md \
      skills/symphony-reconcile/SKILL.md \
      skills/symphony-review/SKILL.md ||
      fail "$case_id category is not implemented: $expected_category"
  fi

  case "$expected_action" in
    no-dependent-mutation)
      assert_contains references/symphony/reconciliation.md 'No dependent mutation'
      ;;
    search-action-identity)
      assert_contains references/symphony/core.md 'search for the native target and identity'
      ;;
    publish-nothing)
      assert_contains skills/symphony-review/SKILL.md 'publish nothing'
      ;;
    post-top-level-comment)
      assert_contains references/symphony/review.md 'top-level PR comment'
      ;;
    no-duplicate-delegation)
      assert_contains skills/symphony-reconcile/SKILL.md 'absence of an existing implementation'
      ;;
    skip-affected-dispatch)
      assert_contains references/symphony/reconciliation.md 'skips only that issue'
      ;;
    never-delete)
      assert_contains references/symphony/review.md 'Never delete unmarked'
      ;;
    terminate-cleanup-inconclusive)
      assert_contains references/symphony/reconciliation.md 'Terminate command, clean up, report inconclusive'
      ;;
    no-failure-no-journal)
      assert_contains references/symphony/reconciliation.md 'not failures and do not consume a retry budget'
      ;;
    *)
      fail "$case_id has unknown expected action: $expected_action"
      ;;
  esac

  rows=$((rows + 1))
done < <(tail -n +2 "$fixture")

[[ "$rows" -eq 10 ]] || fail "expected 10 integration cases, got $rows"
pass "simulated tool-integration contract"
