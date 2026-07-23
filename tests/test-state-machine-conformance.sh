#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")/.."
source tests/lib/assertions.sh

matrix=tests/fixtures/state-machine-matrix.tsv
core=references/symphony/core.md
linear=references/symphony/linear.md
start=skills/symphony-start/SKILL.md
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

assert_exact_set() {
  local expected=$1
  local actual=$2
  local description=$3
  sort -u "$expected" > "$tmp_dir/expected"
  sort -u "$actual" > "$tmp_dir/actual"
  if ! diff -u "$tmp_dir/expected" "$tmp_dir/actual"; then
    fail "$description set differs"
  fi
}

matrix_values() {
  local kind=$1
  awk -F'\t' -v kind="$kind" 'NR > 1 && $1 == kind { print $2 }' "$matrix"
}

assert_file "$matrix"
expected_header=$'kind\tvalue\tproducers\tconsumers'
[[ "$(head -n 1 "$matrix")" == "$expected_header" ]] ||
  fail "unexpected state-machine matrix header"

# Parse exact finite sets from the normative tables.
awk '
  /^### Journal event types$/ { table = 1; next }
  table && /^### / { exit }
  table && /^\| `[a-z0-9-]+` / {
    value = $2
    gsub(/`/, "", value)
    print value
  }
' "$core" > "$tmp_dir/normative-events"
matrix_values event > "$tmp_dir/matrix-events"
assert_exact_set "$tmp_dir/matrix-events" "$tmp_dir/normative-events" \
  "normative journal event"

awk '
  /^### Action outcomes$/ { table = 1; next }
  table && /^### / { exit }
  table && /^\| `[a-z0-9-]+` / {
    value = $2
    gsub(/`/, "", value)
    print value
  }
' "$core" > "$tmp_dir/normative-action-outcomes"
matrix_values action-outcome > "$tmp_dir/matrix-action-outcomes"
assert_exact_set "$tmp_dir/matrix-action-outcomes" \
  "$tmp_dir/normative-action-outcomes" "action outcome"

awk -F'|' '
  /^### Failure categories and retry behavior$/ { table = 1; next }
  table && /^### / { exit }
  table && /^\| `[a-z0-9-]+` / {
    value = $2
    behavior = $3
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", behavior)
    gsub(/`/, "", value)
    print value "\t" behavior
  }
' "$core" > "$tmp_dir/normative-failure-behavior"
cut -f1 "$tmp_dir/normative-failure-behavior" > \
  "$tmp_dir/normative-failure-categories"
matrix_values failure-category > "$tmp_dir/matrix-failure-categories"
assert_exact_set "$tmp_dir/matrix-failure-categories" \
  "$tmp_dir/normative-failure-categories" "failure category"

awk '
  /^### Verdict mapping$/ { table = 1; next }
  table && /^## / { exit }
  table && /^\| Review `/ {
    value = $3
    gsub(/`/, "", value)
    print value
  }
' "$core" > "$tmp_dir/normative-review-verdicts"
matrix_values review-verdict > "$tmp_dir/matrix-review-verdicts"
assert_exact_set "$tmp_dir/matrix-review-verdicts" \
  "$tmp_dir/normative-review-verdicts" "review verdict"

awk '
  /^### Verdict mapping$/ { table = 1; next }
  table && /^## / { exit }
  table && /^\| Reconciliation `/ {
    value = $3
    gsub(/`/, "", value)
    print value
  }
' "$core" > "$tmp_dir/normative-reconciliation-verdicts"
matrix_values reconciliation-verdict > "$tmp_dir/matrix-reconciliation-verdicts"
assert_exact_set "$tmp_dir/matrix-reconciliation-verdicts" \
  "$tmp_dir/normative-reconciliation-verdicts" "reconciliation verdict"

# Parse every declared Maestro label and the exact phase/risk subsets.
awk '
  /^## Maestro labels$/ { labels = 1; next }
  labels && /^## / { exit }
  labels && /^maestro(:|-)[a-z]/ { print }
' "$core" > "$tmp_dir/normative-labels"
for kind in role-label phase-label risk-label; do
  matrix_values "$kind"
done > "$tmp_dir/matrix-labels"
assert_exact_set "$tmp_dir/matrix-labels" "$tmp_dir/normative-labels" \
  "Maestro label"

awk -F'|' '
  /^## Entity-scoped phase transitions$/ { table = 1; next }
  table && /^## / { exit }
  table && /^\| (Control|Discovery|Implementation) issue \| `maestro:/ {
    value = $3
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
    gsub(/`/, "", value)
    print value
  }
' "$core" > "$tmp_dir/normative-phase-labels"
matrix_values phase-label > "$tmp_dir/matrix-phase-labels"
assert_exact_set "$tmp_dir/matrix-phase-labels" \
  "$tmp_dir/normative-phase-labels" "phase label"

awk '
  /^## Maestro risk-label mapping$/ { table = 1; next }
  table && /^## / { exit }
  table && /^\| `maestro-risk-/ {
    value = $2
    gsub(/`/, "", value)
    print value
  }
' "$core" > "$tmp_dir/normative-risk-labels"
matrix_values risk-label > "$tmp_dir/matrix-risk-labels"
assert_exact_set "$tmp_dir/matrix-risk-labels" \
  "$tmp_dir/normative-risk-labels" "risk label"

# The matrix indexes exact operational instructions, not detached declarations.
while IFS=$'\t' read -r kind value producers consumers; do
  [[ "$kind" == "kind" ]] && continue
  [[ -n "$value" && -n "$producers" && -n "$consumers" ]] ||
    fail "incomplete matrix row for $kind/$value"
  for direction in producer consumer; do
    paths=$producers
    [[ "$direction" == "consumer" ]] && paths=$consumers
    while IFS= read -r path; do
      printf '%s|%s|%s|%s\n' "$kind" "$value" "$direction" "$path"
    done < <(tr ';' '\n' <<< "$paths")
  done
done < "$matrix" > "$tmp_dir/matrix-edges"

event_producer='^append event `([a-z0-9-]+)`$'
event_consumer='^consume event `([a-z0-9-]+)`$'
outcome_producer='^emit outcome `([a-z0-9-]+)`$'
outcome_consumer='^consume outcome `([a-z0-9-]+)`$'
failure_producer='^emit failure category `([a-z0-9-]+)`$'
failure_consumer='^consume failure category `([a-z0-9-]+)`$'
label_producer='^apply label `([a-z0-9:-]+)`$'
label_consumer='^read label `([a-z0-9:-]+)`$'
review_producer='^return review verdict `([a-z0-9-]+)`$'
review_consumer='^consume review verdict `([a-z0-9-]+)`$'
reconciliation_producer='^return reconciliation verdict `([a-z0-9-]+)`$'
reconciliation_consumer='^consume reconciliation verdict `([a-z0-9-]+)`$'

for path in skills/symphony-*/SKILL.md agents/*.md; do
  while IFS= read -r line; do
    if [[ "$line" =~ $event_producer ]]; then
      printf 'event|%s|producer|%s\n' "${BASH_REMATCH[1]}" "$path"
    elif [[ "$line" =~ $event_consumer ]]; then
      printf 'event|%s|consumer|%s\n' "${BASH_REMATCH[1]}" "$path"
    elif [[ "$line" =~ $outcome_producer ]]; then
      printf 'action-outcome|%s|producer|%s\n' "${BASH_REMATCH[1]}" "$path"
    elif [[ "$line" =~ $outcome_consumer ]]; then
      printf 'action-outcome|%s|consumer|%s\n' "${BASH_REMATCH[1]}" "$path"
    elif [[ "$line" =~ $failure_producer ]]; then
      printf 'failure-category|%s|producer|%s\n' "${BASH_REMATCH[1]}" "$path"
    elif [[ "$line" =~ $failure_consumer ]]; then
      printf 'failure-category|%s|consumer|%s\n' "${BASH_REMATCH[1]}" "$path"
    elif [[ "$line" =~ $label_producer ]]; then
      case "${BASH_REMATCH[1]}" in
        maestro-symphony|maestro-managed) kind=role-label ;;
        maestro:*) kind=phase-label ;;
        maestro-risk-*) kind=risk-label ;;
        *) fail "unknown label grammar value ${BASH_REMATCH[1]} in $path" ;;
      esac
      printf '%s|%s|producer|%s\n' "$kind" "${BASH_REMATCH[1]}" "$path"
    elif [[ "$line" =~ $label_consumer ]]; then
      case "${BASH_REMATCH[1]}" in
        maestro-symphony|maestro-managed) kind=role-label ;;
        maestro:*) kind=phase-label ;;
        maestro-risk-*) kind=risk-label ;;
        *) fail "unknown label grammar value ${BASH_REMATCH[1]} in $path" ;;
      esac
      printf '%s|%s|consumer|%s\n' "$kind" "${BASH_REMATCH[1]}" "$path"
    elif [[ "$line" =~ $review_producer ]]; then
      printf 'review-verdict|%s|producer|%s\n' "${BASH_REMATCH[1]}" "$path"
    elif [[ "$line" =~ $review_consumer ]]; then
      printf 'review-verdict|%s|consumer|%s\n' "${BASH_REMATCH[1]}" "$path"
    elif [[ "$line" =~ $reconciliation_producer ]]; then
      printf 'reconciliation-verdict|%s|producer|%s\n' \
        "${BASH_REMATCH[1]}" "$path"
    elif [[ "$line" =~ $reconciliation_consumer ]]; then
      printf 'reconciliation-verdict|%s|consumer|%s\n' \
        "${BASH_REMATCH[1]}" "$path"
    fi
  done < "$path"
done > "$tmp_dir/operational-edges"
assert_exact_set "$tmp_dir/matrix-edges" "$tmp_dir/operational-edges" \
  "operational producer/consumer path edge"

# Each failure consumer carries the normative retryability rule as adjacent
# operational evidence, so retry behavior cannot drift from the finite table.
while IFS=$'\t' read -r category behavior; do
  awk -F'|' -v category="$category" \
    '$1 == "failure-category" && $2 == category && $3 == "consumer" {
      print $4
    }' "$tmp_dir/matrix-edges" | while IFS= read -r path; do
    printf '%s|%s|%s\n' "$category" "$behavior" "$path"
  done
done < "$tmp_dir/normative-failure-behavior" > \
  "$tmp_dir/expected-failure-consumer-evidence"

for path in skills/symphony-*/SKILL.md agents/*.md; do
  awk -v path="$path" '
    /^consume failure category `[a-z0-9-]+`$/ {
      category = $0
      sub(/^consume failure category `/, "", category)
      sub(/`$/, "", category)
      if ((getline evidence) <= 0 || evidence !~ /^Retryability: /) {
        print "missing|" category "|" path
        next
      }
      sub(/^Retryability: /, "", evidence)
      print category "|" evidence "|" path
    }
  ' "$path"
done > "$tmp_dir/actual-failure-consumer-evidence"
assert_exact_set "$tmp_dir/expected-failure-consumer-evidence" \
  "$tmp_dir/actual-failure-consumer-evidence" \
  "failure-category retryability evidence"

for path in references/symphony/*.md skills/symphony-*/SKILL.md agents/*.md \
  README.md; do
  assert_not_contains "$path" '^maestro-.*-(producer|consumer): '
done

# One fixed control contract revision governs persistence and both lookup paths.
for path in "$core" "$linear" "$start"; do
  assert_contains "$path" 'Control contract revision:[[:space:]]*`symphony-control-v1`'
done
assert_contains "$start" 'Pre-create lookup.*`symphony-control-v1`'
assert_contains "$start" 'Ambiguous-create lookup.*`symphony-control-v1`'
assert_contains "$start" 'fourth JSON array item.*`symphony-control-v1`'
assert_contains "$start" 'persist.*`symphony-control-v1`'
assert_contains "$start" 'must not select.*revision'

for path in references/symphony/*.md skills/symphony-*/SKILL.md agents/*.md \
  README.md; do
  assert_not_contains "$path" 'dag-approved-and-materialized'
done

# Prove both directions: an undeclared actual emission and a missing real
# partial-recovery consumer edge must each be rejected.
if [[ "${STATE_MACHINE_CONFORMANCE_SKIP_MUTATIONS:-0}" != 1 ]]; then
  mutation_root="$tmp_dir/mutations"
  mkdir -p "$mutation_root/injected" "$mutation_root/removed"
  cp -R agents references skills tests README.md "$mutation_root/injected/"
  cp -R agents references skills tests README.md "$mutation_root/removed/"

  printf '\nappend event `undeclared-injected-event`\n' >> \
    "$mutation_root/injected/skills/symphony-start/SKILL.md"
  if (
    cd "$mutation_root/injected"
    STATE_MACHINE_CONFORMANCE_SKIP_MUTATIONS=1 \
      tests/test-state-machine-conformance.sh >/dev/null 2>&1
  ); then
    fail "undeclared actual event emission mutation was accepted"
  fi

  sed -i '/^consume event `dag-approved`$/d' \
    "$mutation_root/removed/skills/symphony-start/SKILL.md"
  if (
    cd "$mutation_root/removed"
    STATE_MACHINE_CONFORMANCE_SKIP_MUTATIONS=1 \
      tests/test-state-machine-conformance.sh >/dev/null 2>&1
  ); then
    fail "removed start partial-recovery consumer mutation was accepted"
  fi
fi

pass "operational Symphony state-machine conformance and mutations"
