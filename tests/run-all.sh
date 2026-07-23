#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")/.."

tests=(
  tests/test-protocol.sh
  tests/test-state-machine-invariants.sh
  tests/test-state-machine-conformance.sh
  tests/test-recovery-protocol.sh
  tests/test-final-fix-d.sh
  tests/test-planning-agents.sh
  tests/test-review-agents.sh
  tests/test-symphony-start.sh
  tests/test-symphony-review.sh
  tests/test-symphony-reconcile.sh
  tests/test-symphony-status.sh
  tests/test-review-cleanup-attachment.sh
  tests/test-tool-integration-contract.sh
  tests/test-failure-injection-reducer.sh
  tests/test-package.sh
)

for test_path in "${tests[@]}"; do
  "$test_path"
done

claude plugin validate .
