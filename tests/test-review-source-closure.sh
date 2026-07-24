#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")/.."
source tests/lib/assertions.sh

helper=scripts/review-source-closure.py
assert_file "$helper"
assert_executable "$helper"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
plugin_root="$tmp_dir/plugin"
repository_root="$tmp_dir/repository"
mkdir -p "$plugin_root/agents" "$repository_root/config" "$repository_root/policy"
printf 'lens bytes\n' > "$plugin_root/agents/symphony-reviewer.md"
printf '{"scripts":{"test":"node test.js"}}\n' > "$repository_root/package.json"
printf 'mode: strict\n' > "$repository_root/config/app.yml"
printf 'policy a\n' > "$repository_root/policy/a.md"
printf 'policy z\n' > "$repository_root/policy/z.md"

write_descriptor() {
  local path=$1 plugin_sources=$2 policy_sources=$3 config_sources=$4
  local implicit=${5:-true}
  printf '%s\n' \
    '{' \
    '  "version": "review-source-closure-v1",' \
    "  \"plugin_sources\": $plugin_sources," \
    "  \"policy_sources\": $policy_sources," \
    '  "validators": [' \
    '    {' \
    '      "kind": "issue-validation-command",' \
    '      "command": "npm test",' \
    "      \"config_sources\": $config_sources," \
    "      \"implicit_sources_declared\": $implicit," \
    '      "capability": {"state": "present", "name": "npm", "version": "10.9.0"}' \
    '    }' \
    '  ]' \
    '}' > "$path"
}

write_requirements() {
  local path=$1 plugin_sources=$2 policy_sources=$3 config_sources=$4
  printf '%s\n' \
    '{' \
    '  "version": "review-source-requirements-v1",' \
    "  \"plugin_sources\": $plugin_sources," \
    "  \"policy_sources\": $policy_sources," \
    '  "validators": [' \
    '    {' \
    '      "kind": "issue-validation-command",' \
    '      "command": "npm test",' \
    "      \"config_sources\": $config_sources," \
    '      "capability_name": "npm"' \
    '    }' \
    '  ]' \
    '}' > "$path"
}

revision_for() {
  local requirements=${2:-"$tmp_dir/requirements.json"}
  "$helper" --plugin-root "$plugin_root" \
    --repository-root "$repository_root" --requirements "$requirements" \
    --descriptor "$1" |
    awk -F'\t' '$1 == "revision" { print $2 }'
}

write_requirements "$tmp_dir/requirements.json" \
  '["agents/symphony-reviewer.md"]' '["policy/z.md","policy/a.md"]' \
  '["package.json","config/app.yml"]'
write_descriptor "$tmp_dir/a.json" \
  '["agents/symphony-reviewer.md"]' '["policy/z.md","policy/a.md"]' \
  '["package.json","config/app.yml"]'
write_descriptor "$tmp_dir/b.json" \
  '["agents/symphony-reviewer.md"]' '["policy/a.md","policy/z.md"]' \
  '["config/app.yml","package.json"]'

revision_a=$(revision_for "$tmp_dir/a.json")
revision_b=$(revision_for "$tmp_dir/b.json")
[[ "$revision_a" == review-source-closure-v1:* ]] ||
  fail "unexpected source-closure revision prefix"
[[ "$revision_a" == "$revision_b" ]] ||
  fail "path/order normalization changed the revision"

# The plugin source tree intentionally has no .git metadata.
[[ ! -e "$plugin_root/.git" ]] || fail "test plugin root unexpectedly has .git"
fresh_revision=$(revision_for "$tmp_dir/a.json")
[[ "$fresh_revision" == "$revision_a" ]] ||
  fail "fresh-session source closure differs"

printf 'mode: changed\n' > "$repository_root/config/app.yml"
changed_revision=$(revision_for "$tmp_dir/a.json")
[[ "$changed_revision" != "$revision_a" ]] ||
  fail "exact byte change did not change source closure"

write_descriptor "$tmp_dir/missing.json" \
  '["agents/symphony-reviewer.md"]' '[]' '["missing.json"]'
write_requirements "$tmp_dir/missing-requirements.json" \
  '["agents/symphony-reviewer.md"]' '[]' '["missing.json"]'
missing_output=$(
  "$helper" --plugin-root "$plugin_root" \
    --repository-root "$repository_root" \
    --requirements "$tmp_dir/missing-requirements.json" \
    --descriptor "$tmp_dir/missing.json"
)
missing_revision=$(awk -F'\t' '$1 == "revision" { print $2 }' <<< "$missing_output")
grep -q '"missing","missing"' <<< "$missing_output" ||
  fail "missing source sentinel absent"
printf '{}\n' > "$repository_root/missing.json"
present_revision=$(revision_for \
  "$tmp_dir/missing.json" "$tmp_dir/missing-requirements.json")
[[ "$present_revision" != "$missing_revision" ]] ||
  fail "missing-to-present did not change source closure"

assert_rejected() {
  local descriptor=$1 description=$2
  local requirements=${3:-"$tmp_dir/requirements.json"}
  if "$helper" --plugin-root "$plugin_root" \
      --repository-root "$repository_root" --requirements "$requirements" \
      --descriptor "$descriptor" \
      >/dev/null 2>&1; then
    fail "$description was accepted"
  fi
}

write_descriptor "$tmp_dir/absolute.json" \
  '["agents/symphony-reviewer.md"]' '[]' '["/etc/passwd"]'
write_requirements "$tmp_dir/absolute-requirements.json" \
  '["agents/symphony-reviewer.md"]' '[]' '["/etc/passwd"]'
assert_rejected "$tmp_dir/absolute.json" "absolute path" \
  "$tmp_dir/absolute-requirements.json"
write_descriptor "$tmp_dir/escaping.json" \
  '["agents/symphony-reviewer.md"]' '[]' '["../outside"]'
write_requirements "$tmp_dir/escaping-requirements.json" \
  '["agents/symphony-reviewer.md"]' '[]' '["../outside"]'
assert_rejected "$tmp_dir/escaping.json" "escaping path" \
  "$tmp_dir/escaping-requirements.json"
write_descriptor "$tmp_dir/glob.json" \
  '["agents/symphony-reviewer.md"]' '[]' '["config/*.yml"]'
write_requirements "$tmp_dir/glob-requirements.json" \
  '["agents/symphony-reviewer.md"]' '[]' '["config/*.yml"]'
assert_rejected "$tmp_dir/glob.json" "glob path" \
  "$tmp_dir/glob-requirements.json"
write_descriptor "$tmp_dir/implicit.json" \
  '["agents/symphony-reviewer.md"]' '[]' '[]' false
write_requirements "$tmp_dir/implicit-requirements.json" \
  '["agents/symphony-reviewer.md"]' '[]' '[]'
assert_rejected "$tmp_dir/implicit.json" "undeclared implicit source closure" \
  "$tmp_dir/implicit-requirements.json"

write_descriptor "$tmp_dir/empty.json" '[]' '[]' '[]'
write_requirements "$tmp_dir/empty-requirements.json" '[]' '[]' '[]'
assert_rejected "$tmp_dir/empty.json" \
  "descriptor that omits the mandatory reviewer" \
  "$tmp_dir/empty-requirements.json"
write_descriptor "$tmp_dir/implicit-package.json" \
  '["agents/symphony-reviewer.md"]' '["policy/z.md","policy/a.md"]' \
  '["config/app.yml"]'
assert_rejected "$tmp_dir/implicit-package.json" \
  "validator that omits required package source"

pass "review-source-closure-v1 executable oracle"
