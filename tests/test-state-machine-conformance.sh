#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")/.."
source tests/lib/assertions.sh

matrix=tests/fixtures/state-machine-matrix.tsv
core=references/symphony/core.md
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

assert_exact_set() {
  local expected=$1 actual=$2 description=$3
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
expected_header=$'kind\tvalue\tproducers\tconsumers\tpredicate\tnext_state\tchoice_group'
[[ "$(head -n 1 "$matrix")" == "$expected_header" ]] ||
  fail "unexpected state-machine matrix header"

# Exact finite values remain grounded in the normative protocol tables.
awk '
  /^### Journal event types$/ { table = 1; next }
  table && /^### / { exit }
  table && /^\| `[a-z0-9-]+` / {
    value = $2; gsub(/`/, "", value); print value
  }
' "$core" > "$tmp_dir/normative-events"
matrix_values event > "$tmp_dir/matrix-events"
assert_exact_set "$tmp_dir/matrix-events" "$tmp_dir/normative-events" \
  "normative journal event"

awk '
  /^### Action outcomes$/ { table = 1; next }
  table && /^### / { exit }
  table && /^\| `[a-z0-9-]+` / {
    value = $2; gsub(/`/, "", value); print value
  }
' "$core" > "$tmp_dir/normative-action-outcomes"
matrix_values action-outcome > "$tmp_dir/matrix-action-outcomes"
assert_exact_set "$tmp_dir/matrix-action-outcomes" \
  "$tmp_dir/normative-action-outcomes" "action outcome"

awk '
  /^### Failure categories and retry behavior$/ { table = 1; next }
  table && /^### / { exit }
  table && /^\| `[a-z0-9-]+` / {
    value = $2; gsub(/`/, "", value); print value
  }
' "$core" > "$tmp_dir/normative-failure-categories"
matrix_values failure-category > "$tmp_dir/matrix-failure-categories"
assert_exact_set "$tmp_dir/matrix-failure-categories" \
  "$tmp_dir/normative-failure-categories" "failure category"

awk -F'|' '
  /^### Failure categories and retry behavior$/ { table = 1; next }
  table && /^### / { exit }
  table && /^\| `[a-z0-9-]+` / {
    value = $2; behavior = $3
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", behavior)
    gsub(/`/, "", value)
    print value "\t" behavior
  }
' "$core" > "$tmp_dir/normative-failure-behavior"

awk '
  /^### Verdict mapping$/ { table = 1; next }
  table && /^## / { exit }
  table && /^\| Review `/ {
    value = $3; gsub(/`/, "", value); print value
  }
' "$core" > "$tmp_dir/normative-review-verdicts"
matrix_values review-verdict > "$tmp_dir/matrix-review-verdicts"
assert_exact_set "$tmp_dir/matrix-review-verdicts" \
  "$tmp_dir/normative-review-verdicts" "review verdict"

awk '
  /^### Verdict mapping$/ { table = 1; next }
  table && /^## / { exit }
  table && /^\| Reconciliation `/ {
    value = $3; gsub(/`/, "", value); print value
  }
' "$core" > "$tmp_dir/normative-reconciliation-verdicts"
matrix_values reconciliation-verdict > "$tmp_dir/matrix-reconciliation-verdicts"
assert_exact_set "$tmp_dir/matrix-reconciliation-verdicts" \
  "$tmp_dir/normative-reconciliation-verdicts" "reconciliation verdict"

awk '
  /^## Maestro labels$/ { labels = 1; next }
  labels && /^## / { exit }
  labels && /^maestro(:|-)[a-z]/ { print }
' "$core" > "$tmp_dir/normative-labels"
for kind in role-label phase-label risk-label; do matrix_values "$kind"; done \
  > "$tmp_dir/matrix-labels"
assert_exact_set "$tmp_dir/matrix-labels" "$tmp_dir/normative-labels" \
  "Maestro label"

# Expand the matrix to one exact operational tuple per producer/consumer path.
while IFS=$'\t' read -r kind value producers consumers predicate next choice; do
  [[ "$kind" == "kind" ]] && continue
  [[ -n "$value" && -n "$producers" && -n "$consumers" &&
     "$predicate" =~ ^[a-z0-9-]+$ && "$next" =~ ^[a-z0-9-]+$ &&
     "$choice" =~ ^([a-z0-9-]+|none)$ ]] ||
    fail "incomplete or non-normalized matrix row for $kind/$value"
  for direction in producer consumer; do
    paths=$producers
    [[ "$direction" == "consumer" ]] && paths=$consumers
    while IFS= read -r path; do
      printf '%s|%s|%s|%s|%s|%s|%s\n' \
        "$kind" "$value" "$direction" "$path" "$predicate" "$next" "$choice"
    done < <(tr ';' '\n' <<< "$paths")
  done
done < "$matrix" > "$tmp_dir/matrix-rules"

# Parse only the standardized conditional grammar. Every rule has a unique ID,
# observable normalized predicate, action, next state, and exclusivity group.
for path in skills/symphony-*/SKILL.md agents/*.md; do
  awk -F' \\| ' -v path="$path" '
    function fail_rule(message) {
      print message > "/dev/stderr"
      invalid = 1
    }
    /^rule / {
      if (NF != 5 || $1 !~ /^rule [a-z0-9-]+$/ ||
          $2 !~ /^when [a-z0-9-]+$/ ||
          $4 !~ /^next [a-z0-9-]+$/ ||
          $5 !~ /^choice ([a-z0-9-]+|none)$/) {
        fail_rule("invalid conditional rule grammar in " path ": " $0)
        next
      }
      rule = $1; sub(/^rule /, "", rule)
      predicate = $2; sub(/^when /, "", predicate)
      action = $3
      next_state = $4; sub(/^next /, "", next_state)
      choice = $5; sub(/^choice /, "", choice)
      if (seen[rule]++) fail_rule("duplicate rule identifier in " path ": " rule)

      direction = ""
      if (action ~ /^append event `/) {
        kind = "event"; direction = "producer"; prefix = "append event `"
      } else if (action ~ /^consume event `/) {
        kind = "event"; direction = "consumer"; prefix = "consume event `"
      } else if (action ~ /^emit outcome `/) {
        kind = "action-outcome"; direction = "producer"; prefix = "emit outcome `"
      } else if (action ~ /^consume outcome `/) {
        kind = "action-outcome"; direction = "consumer"; prefix = "consume outcome `"
      } else if (action ~ /^emit failure category `/) {
        kind = "failure-category"; direction = "producer"; prefix = "emit failure category `"
      } else if (action ~ /^consume failure category `/) {
        kind = "failure-category"; direction = "consumer"; prefix = "consume failure category `"
      } else if (action ~ /^apply label `/) {
        value = action; sub(/^apply label `/, "", value); sub(/`$/, "", value)
        direction = "producer"; prefix = "apply label `"
        if (value == "maestro-symphony" || value == "maestro-managed")
          kind = "role-label"
        else if (value ~ /^maestro:/) kind = "phase-label"
        else if (value ~ /^maestro-risk-/) kind = "risk-label"
        else fail_rule("unknown label in " path ": " value)
      } else if (action ~ /^read label `/) {
        value = action; sub(/^read label `/, "", value); sub(/`$/, "", value)
        direction = "consumer"; prefix = "read label `"
        if (value == "maestro-symphony" || value == "maestro-managed")
          kind = "role-label"
        else if (value ~ /^maestro:/) kind = "phase-label"
        else if (value ~ /^maestro-risk-/) kind = "risk-label"
        else fail_rule("unknown label in " path ": " value)
      } else if (action ~ /^return review verdict `/) {
        kind = "review-verdict"; direction = "producer"
        prefix = "return review verdict `"
      } else if (action ~ /^consume review verdict `/) {
        kind = "review-verdict"; direction = "consumer"
        prefix = "consume review verdict `"
      } else if (action ~ /^return reconciliation verdict `/) {
        kind = "reconciliation-verdict"; direction = "producer"
        prefix = "return reconciliation verdict `"
      } else if (action ~ /^consume reconciliation verdict `/) {
        kind = "reconciliation-verdict"; direction = "consumer"
        prefix = "consume reconciliation verdict `"
      } else {
        fail_rule("unknown operational action in " path ": " action)
        next
      }
      if (value == "") {
        value = action; sub("^" prefix, "", value); sub(/`$/, "", value)
      }
      if (value !~ /^[a-z0-9:-]+$/)
        fail_rule("non-normalized action value in " path ": " value)
      if (choice != "none") {
        key = choice SUBSEP direction SUBSEP predicate
        if (exclusive[key]++)
          fail_rule("duplicate predicate in exclusive group " choice ": " predicate)
        if (predicate == "always" || predicate == "unconditional")
          fail_rule("unconditional predicate in exclusive group " choice)
      }
      print kind "|" value "|" direction "|" path "|" predicate "|" next_state "|" choice
      value = ""
    }
    END { if (invalid) exit 1 }
  ' "$path"
done > "$tmp_dir/operational-rules" ||
  fail "conditional operational grammar validation failed"

awk -F' \\| ' '/^rule / {
  rule = $1
  sub(/^rule /, "", rule)
  print rule
}' skills/symphony-*/SKILL.md agents/*.md | sort | uniq -d \
  > "$tmp_dir/duplicate-rule-identifiers"
[[ ! -s "$tmp_dir/duplicate-rule-identifiers" ]] ||
  fail "duplicate global rule identifier: $(head -n 1 "$tmp_dir/duplicate-rule-identifiers")"

# Naked operational commands are always invalid.
if rg -n '^[[:space:]]*(append event|consume event|emit outcome|consume outcome|emit failure category|consume failure category|apply label|read label|return (review|reconciliation) verdict|consume (review|reconciliation) verdict) `' \
  skills/symphony-*/SKILL.md agents/*.md > "$tmp_dir/naked"; then
  fail "naked operational command remains: $(head -n 1 "$tmp_dir/naked")"
fi

assert_exact_set "$tmp_dir/matrix-rules" "$tmp_dir/operational-rules" \
  "predicate-bearing operational rule"

# Preserve the approved retry contract: every failure consumer carries its exact
# normative retryability behavior immediately after the conditional rule.
while IFS=$'\t' read -r category behavior; do
  awk -F'|' -v category="$category" \
    '$1 == "failure-category" && $2 == category && $3 == "consumer" {
      print category "|" behavior "|" $4
    }' behavior="$behavior" "$tmp_dir/matrix-rules"
done < "$tmp_dir/normative-failure-behavior" \
  > "$tmp_dir/expected-failure-consumer-evidence"

for path in skills/symphony-*/SKILL.md agents/*.md; do
  awk -F' \\| ' -v path="$path" '
    /^rule .* \| when [a-z0-9-]+ \| consume failure category `[a-z0-9-]+` \|/ {
      category = $3
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

# Every exclusive predicate/action/value/next/group tuple is declared by the
# normative protocol, including phase and verdict transitions.
awk -F'|' '{
  print $1 "|" $2 "|" $3 "|" $5 "|" $6 "|" $7
}' "$tmp_dir/operational-rules" | sort -u > "$tmp_dir/actual-allowed"
awk -F'|' '
  /^### Allowed predicate-to-transition sets$/ { table = 1; next }
  table && /^## / { exit }
  table && /^\| `[a-z0-9-]+` / {
    for (i = 2; i <= 7; i++) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i)
      gsub(/`/, "", $i)
    }
    if ($4 == "both") {
      print $2 "|" $3 "|producer|" $5 "|" $6 "|" $7
      print $2 "|" $3 "|consumer|" $5 "|" $6 "|" $7
    } else {
      print $2 "|" $3 "|" $4 "|" $5 "|" $6 "|" $7
    }
  }
' "$core" > "$tmp_dir/normative-allowed"
assert_exact_set "$tmp_dir/normative-allowed" "$tmp_dir/actual-allowed" \
  "normative allowed transition"

for path in references/symphony/*.md skills/symphony-*/SKILL.md agents/*.md \
  README.md; do
  assert_not_contains "$path" '^maestro-.*-(producer|consumer): '
  assert_not_contains "$path" 'dag-approved-and-materialized'
done

# The fixed control identity remains invariant across persistence and both lookup
# paths; Final Fix C must not loosen approved Fix A behavior.
for path in references/symphony/core.md references/symphony/linear.md \
  skills/symphony-start/SKILL.md; do
  assert_contains "$path" 'Control contract revision:[[:space:]]*`symphony-control-v1`'
done
assert_contains skills/symphony-start/SKILL.md \
  'Pre-create lookup.*`symphony-control-v1`'
assert_contains skills/symphony-start/SKILL.md \
  'Ambiguous-create lookup.*`symphony-control-v1`'
assert_contains skills/symphony-start/SKILL.md \
  'fourth JSON array item.*`symphony-control-v1`'
assert_contains skills/symphony-start/SKILL.md 'must not select.*revision'

if [[ "${STATE_MACHINE_CONFORMANCE_SKIP_MUTATIONS:-0}" != 1 ]]; then
  mutation_root="$tmp_dir/mutations"
  for variant in naked wrong-predicate coherent-undeclared duplicate-always undeclared \
    phase-outside verdict-outside; do
    mkdir -p "$mutation_root/$variant"
    cp -R agents references skills tests README.md "$mutation_root/$variant/"
  done

  printf '\n  append event `symphony-started`\n' >> \
    "$mutation_root/naked/skills/symphony-start/SKILL.md"
  sed -i '0,/when control-creation-is-confirmed/s//when dag-revision-is-approved/' \
    "$mutation_root/wrong-predicate/skills/symphony-start/SKILL.md"
  sed -i 's/exact-dag-proposal-is-durably-confirmed/incorrect-but-normalized-predicate/g' \
    "$mutation_root/coherent-undeclared/skills/symphony-start/SKILL.md" \
    "$mutation_root/coherent-undeclared/skills/symphony-reconcile/SKILL.md" \
    "$mutation_root/coherent-undeclared/skills/symphony-status/SKILL.md" \
    "$mutation_root/coherent-undeclared/tests/fixtures/state-machine-matrix.tsv"
  printf '\nrule injected-always-a | when always | return review verdict `pass` | next review-passed | choice review-verdict\nrule injected-always-b | when always | return review verdict `changes-required` | next review-changes-required | choice review-verdict\n' >> \
    "$mutation_root/duplicate-always/agents/implementation-reconciler.md"
  printf '\nrule injected-event | when injected-evidence-is-confirmed | append event `undeclared-injected-event` | next injected | choice none\n' >> \
    "$mutation_root/undeclared/skills/symphony-start/SKILL.md"

  sed -i '0,/next entity-complete/s//next entity-executing/' \
    "$mutation_root/phase-outside/skills/symphony-start/SKILL.md"
  sed -i 's/entity-complete/entity-executing/' \
    "$mutation_root/phase-outside/tests/fixtures/state-machine-matrix.tsv"
  sed -i '0,/next review-passed/s//next review-inconclusive/' \
    "$mutation_root/verdict-outside/skills/symphony-review/SKILL.md"
  sed -i '/^review-verdict\tpass\t/s/review-passed/review-inconclusive/' \
    "$mutation_root/verdict-outside/tests/fixtures/state-machine-matrix.tsv"

  for variant in naked wrong-predicate coherent-undeclared duplicate-always undeclared \
    phase-outside verdict-outside; do
    if (
      cd "$mutation_root/$variant"
      STATE_MACHINE_CONFORMANCE_SKIP_MUTATIONS=1 \
        tests/test-state-machine-conformance.sh >/dev/null 2>&1
    ); then
      fail "$variant conditional-grammar mutation was accepted"
    fi
  done
fi

pass "conditional Symphony state-machine conformance and mutations"
