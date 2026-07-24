#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")/.."
source tests/lib/assertions.sh

helper=scripts/review-source-closure.py
manifest_name=review-source-requirements-v1.json
assert_file "$helper"
assert_executable "$helper"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
plugin_root="$tmp_dir/plugin"
repository_root="$tmp_dir/repository"
mkdir -p \
  "$plugin_root/scripts" \
  "$plugin_root/skills/symphony-review" \
  "$plugin_root/references/symphony" \
  "$plugin_root/agents" \
  "$repository_root/config" \
  "$repository_root/policy"

mandatory_sources=(
  review-source-requirements-v1.json
  scripts/review-source-closure.py
  evidence-source-schema-v1.json
  scripts/evidence-source-schema.py
  skills/symphony-review/SKILL.md
  references/symphony/core.md
  references/symphony/linear.md
  references/symphony/reconciliation.md
  references/symphony/review.md
  agents/symphony-reviewer.md
)
for path in "${mandatory_sources[@]:1}"; do
  printf 'authoritative bytes for %s\n' "$path" > "$plugin_root/$path"
done
for lens in code-reviewer comment-analyzer security-reviewer test-analyzer; do
  printf 'lens bytes for %s\n' "$lens" > "$plugin_root/agents/$lens.md"
done

printf '%s\n' \
  '{' \
  '  "version": "review-source-requirements-v1",' \
  '  "mandatory_plugin_sources": [' \
  '    "review-source-requirements-v1.json",' \
  '    "scripts/review-source-closure.py",' \
  '    "evidence-source-schema-v1.json",' \
  '    "scripts/evidence-source-schema.py",' \
  '    "skills/symphony-review/SKILL.md",' \
  '    "references/symphony/core.md",' \
  '    "references/symphony/linear.md",' \
  '    "references/symphony/reconciliation.md",' \
  '    "references/symphony/review.md",' \
  '    "agents/symphony-reviewer.md"' \
  '  ],' \
  '  "skill_dependencies": [' \
  '    "references/symphony/core.md",' \
  '    "references/symphony/linear.md",' \
  '    "references/symphony/reconciliation.md",' \
  '    "references/symphony/review.md"' \
  '  ],' \
  '  "lens_sources": {' \
  '    "maestro:code-reviewer": ["agents/code-reviewer.md"],' \
  '    "maestro:comment-analyzer": ["agents/comment-analyzer.md"],' \
  '    "maestro:security-reviewer": ["agents/security-reviewer.md"],' \
  '    "maestro:test-analyzer": ["agents/test-analyzer.md"]' \
  '  }' \
  '}' > "$plugin_root/$manifest_name"

printf '{"scripts":{"test":"node test.js"}}\n' > "$repository_root/package.json"
printf 'mode: strict\n' > "$repository_root/config/app.yml"
printf 'policy a\n' > "$repository_root/policy/a.md"
printf 'policy z\n' > "$repository_root/policy/z.md"
printf 'artifacts/\ngenerated/\n' > "$repository_root/.gitignore"
git -C "$repository_root" init -q
git -C "$repository_root" config user.email test@example.com
git -C "$repository_root" config user.name "Closure Test"
git -C "$repository_root" remote add origin https://github.com/owner/repo.git
git -C "$repository_root" add .
git -C "$repository_root" commit -qm initial
expected_head=$(git -C "$repository_root" rev-parse HEAD)
git -C "$repository_root" checkout -q --detach "$expected_head"

write_descriptor() {
  local path=$1 selected_lenses=$2 policy_sources=$3 config_sources=$4
  local implicit=${5:-true}
  local repository_sources=${6:-'[".gitignore"]'}
  printf '%s\n' \
    '{' \
    '  "version": "review-source-closure-v1",' \
    "  \"selected_lenses\": $selected_lenses," \
    "  \"repository_sources\": $repository_sources," \
    "  \"policy_sources\": $policy_sources," \
    "  \"implicit_sources_declared\": $implicit," \
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

revision_for() {
  local descriptor=$1 root=${2:-"$repository_root"}
  local head=${3:-"$expected_head"} repository=${4:-owner/repo}
  local phase=${5:-pre-review}
  "$helper" \
    --plugin-root "$plugin_root" \
    --repository-root "$root" \
    --expected-repository "$repository" \
    --expected-head "$head" \
    --phase "$phase" \
    --descriptor "$descriptor" |
    awk -F'\t' '$1 == "revision" { print $2 }'
}

write_descriptor "$tmp_dir/a.json" \
  '["maestro:code-reviewer"]' '["policy/z.md","policy/a.md"]' \
  '["package.json","config/app.yml"]'
write_descriptor "$tmp_dir/b.json" \
  '["maestro:code-reviewer"]' '["policy/a.md","policy/z.md"]' \
  '["config/app.yml","package.json"]'

revision_a=$(revision_for "$tmp_dir/a.json")
revision_b=$(revision_for "$tmp_dir/b.json")
[[ "$revision_a" == review-source-closure-v1:* ]] ||
  fail "unexpected source-closure revision prefix"
[[ "$revision_a" == "$revision_b" ]] ||
  fail "path/order normalization changed the revision"
[[ ! -e "$plugin_root/.git" ]] ||
  fail "test plugin root unexpectedly has .git"
fresh_revision=$(revision_for "$tmp_dir/a.json")
[[ "$fresh_revision" == "$revision_a" ]] ||
  fail "fresh-session source closure differs"

write_descriptor "$tmp_dir/all-lenses.json" \
  '["maestro:code-reviewer","maestro:comment-analyzer","maestro:security-reviewer","maestro:test-analyzer"]' \
  '["policy/a.md","policy/z.md"]' '["config/app.yml","package.json"]'
all_lenses_revision=$(revision_for "$tmp_dir/all-lenses.json")

for path in \
  "${mandatory_sources[@]}" \
  agents/code-reviewer.md \
  agents/comment-analyzer.md \
  agents/security-reviewer.md \
  agents/test-analyzer.md
do
  original=$(<"$plugin_root/$path")
  if [[ "$path" == "$manifest_name" ]]; then
    printf '%s\n\n' "$original" > "$plugin_root/$path"
  else
    printf '%s\nchanged\n' "$original" > "$plugin_root/$path"
  fi
  changed_revision=$(revision_for "$tmp_dir/all-lenses.json")
  [[ "$changed_revision" != "$all_lenses_revision" ]] ||
    fail "byte change in $path did not change source closure"
  printf '%s\n' "$original" > "$plugin_root/$path"
done

printf 'mode: changed\n' > "$repository_root/config/app.yml"
git -C "$repository_root" add config/app.yml
git -C "$repository_root" commit -qm config-change
expected_head=$(git -C "$repository_root" rev-parse HEAD)
changed_revision=$(revision_for "$tmp_dir/a.json")
[[ "$changed_revision" != "$revision_a" ]] ||
  fail "exact repository byte/head change did not change source closure"

assert_rejected() {
  local descriptor=$1 description=$2
  local root=${3:-"$repository_root"} head=${4:-"$expected_head"}
  local repository=${5:-owner/repo}
  local phase=${6:-pre-review}
  if "$helper" \
      --plugin-root "$plugin_root" \
      --repository-root "$root" \
      --expected-repository "$repository" \
      --expected-head "$head" \
      --phase "$phase" \
      --descriptor "$descriptor" >/dev/null 2>&1; then
    fail "$description was accepted"
  fi
}

write_descriptor "$tmp_dir/unknown-lens.json" \
  '["maestro:unknown-reviewer"]' '["policy/a.md","policy/z.md"]' \
  '["config/app.yml","package.json"]'
assert_rejected "$tmp_dir/unknown-lens.json" "unknown selected lens"

printf '%s\n' \
  '{"version":"review-source-closure-v1","plugin_sources":["agents/symphony-reviewer.md"],"selected_lenses":[],"repository_sources":[],"policy_sources":[],"implicit_sources_declared":true,"validators":[]}' \
  > "$tmp_dir/minimal.json"
assert_rejected "$tmp_dir/minimal.json" "caller-authored one-file plugin closure"

write_descriptor "$tmp_dir/implicit.json" \
  '["maestro:code-reviewer"]' '["policy/a.md","policy/z.md"]' \
  '["config/app.yml","package.json"]' false
assert_rejected "$tmp_dir/implicit.json" "undeclared implicit source closure"

write_descriptor "$tmp_dir/absolute.json" \
  '["maestro:code-reviewer"]' '["policy/a.md","policy/z.md"]' \
  '["/etc/passwd"]'
assert_rejected "$tmp_dir/absolute.json" "absolute path"
write_descriptor "$tmp_dir/escaping.json" \
  '["maestro:code-reviewer"]' '["policy/a.md","policy/z.md"]' \
  '["../outside"]'
assert_rejected "$tmp_dir/escaping.json" "escaping path"
write_descriptor "$tmp_dir/glob.json" \
  '["maestro:code-reviewer"]' '["policy/a.md","policy/z.md"]' \
  '["config/*.yml"]'
assert_rejected "$tmp_dir/glob.json" "glob path"

printf 'unexpected\n' > "$repository_root/untracked.txt"
assert_rejected "$tmp_dir/a.json" "untracked exact-head worktree"
safe_artifact_revision=$(revision_for \
  "$tmp_dir/a.json" "$repository_root" "$expected_head" owner/repo pre-publication)
[[ "$safe_artifact_revision" == "$changed_revision" ]] ||
  fail "safe pre-publication artifact changed source closure"
rm "$repository_root/untracked.txt"

mkdir -p "$repository_root/artifacts"
printf 'ignored safe artifact\n' > "$repository_root/artifacts/report.txt"
ignored_artifact_revision=$(revision_for \
  "$tmp_dir/a.json" "$repository_root" "$expected_head" owner/repo pre-publication)
[[ "$ignored_artifact_revision" == "$changed_revision" ]] ||
  fail "safe ignored pre-publication artifact changed source closure"
rm "$repository_root/artifacts/report.txt"
rmdir "$repository_root/artifacts"

printf 'tracked mutation\n' >> "$repository_root/config/app.yml"
assert_rejected "$tmp_dir/a.json" "tracked pre-publication mutation" \
  "$repository_root" "$expected_head" owner/repo pre-publication
git -C "$repository_root" restore config/app.yml

printf 'staged mutation\n' >> "$repository_root/config/app.yml"
git -C "$repository_root" add config/app.yml
assert_rejected "$tmp_dir/a.json" "staged pre-publication mutation" \
  "$repository_root" "$expected_head" owner/repo pre-publication
git -C "$repository_root" restore --staged --worktree config/app.yml

mkdir -p "$repository_root/artifacts"
ln -s ../policy/a.md "$repository_root/artifacts/policy-link"
assert_rejected "$tmp_dir/a.json" "untracked symlink validation artifact" \
  "$repository_root" "$expected_head" owner/repo pre-publication
rm "$repository_root/artifacts/policy-link"
rmdir "$repository_root/artifacts"

write_descriptor "$tmp_dir/missing-source.json" \
  '["maestro:code-reviewer"]' '["generated/policy.md"]' \
  '["config/app.yml","package.json"]'
mkdir -p "$repository_root/generated"
printf 'ignored shadow\n' > "$repository_root/generated/policy.md"
assert_rejected "$tmp_dir/missing-source.json" "ignored declared-source path" \
  "$repository_root" "$expected_head" owner/repo pre-publication
rm "$repository_root/generated/policy.md"
rmdir "$repository_root/generated"

printf 'shadow\n' > "$repository_root/policy/a.md.cache"
assert_rejected "$tmp_dir/a.json" "untracked source-shadowing path" \
  "$repository_root" "$expected_head" owner/repo pre-publication
rm "$repository_root/policy/a.md.cache"

mkdir -p "$repository_root/Policy"
printf 'case-folded shadow\n' > "$repository_root/Policy/a.md"
assert_rejected "$tmp_dir/a.json" "case-folded directory source shadow" \
  "$repository_root" "$expected_head" owner/repo pre-publication
rm "$repository_root/Policy/a.md"
rmdir "$repository_root/Policy"

printf 'ancestor\n' > "$repository_root/generated"
assert_rejected "$tmp_dir/missing-source.json" "untracked source ancestor" \
  "$repository_root" "$expected_head" owner/repo pre-publication
rm "$repository_root/generated"

mkdir -p "$repository_root/generated/policy.md"
printf 'descendant\n' > "$repository_root/generated/policy.md/cache"
assert_rejected "$tmp_dir/missing-source.json" "untracked source descendant" \
  "$repository_root" "$expected_head" owner/repo pre-publication
rm "$repository_root/generated/policy.md/cache"
rmdir "$repository_root/generated/policy.md"
rmdir "$repository_root/generated"

printf 'safe\n' > "$repository_root/validation-report.txt"
assert_rejected "$tmp_dir/implicit.json" "implicit discovery with artifact" \
  "$repository_root" "$expected_head" owner/repo pre-publication
rm "$repository_root/validation-report.txt"

printf '%s\n' \
  '{"version":"review-source-closure-v1","selected_lenses":[],"repository_sources":[],"policy_sources":[],"implicit_sources_declared":false,"validators":[]}' \
  > "$tmp_dir/empty-implicit.json"
printf 'implicit\n' > "$repository_root/pyproject.toml"
assert_rejected "$tmp_dir/empty-implicit.json" \
  "vacuous implicit-source declaration with no validators" \
  "$repository_root" "$expected_head" owner/repo pre-publication
rm "$repository_root/pyproject.toml"

write_descriptor "$tmp_dir/repository-source.json" \
  '["maestro:code-reviewer"]' '["policy/a.md","policy/z.md"]' \
  '["config/app.yml","package.json"]' true '[".gitignore","pyproject.toml"]'
printf 'declared repository evidence\n' > "$repository_root/pyproject.toml"
assert_rejected "$tmp_dir/repository-source.json" \
  "artifact at declared repository source path" \
  "$repository_root" "$expected_head" owner/repo pre-publication
rm "$repository_root/pyproject.toml"

ln "$repository_root/.gitignore" "$repository_root/repository-hardlink-report"
assert_rejected "$tmp_dir/a.json" "hard link alias of repository source" \
  "$repository_root" "$expected_head" owner/repo pre-publication
rm "$repository_root/repository-hardlink-report"

ln "$plugin_root/references/symphony/core.md" \
  "$repository_root/plugin-hardlink-report"
assert_rejected "$tmp_dir/a.json" "hard link alias of plugin source" \
  "$repository_root" "$expected_head" owner/repo pre-publication
rm "$repository_root/plugin-hardlink-report"

mkdir -p "$repository_root/scripts"
printf 'distinct plugin source shadow\n' \
  > "$repository_root/scripts/review-source-closure.py.cache"
assert_rejected "$tmp_dir/a.json" "lexical shadow of plugin source" \
  "$repository_root" "$expected_head" owner/repo pre-publication
rm "$repository_root/scripts/review-source-closure.py.cache"
rmdir "$repository_root/scripts"

regular_source_head=$expected_head
rm "$repository_root/policy/a.md"
ln -s z.md "$repository_root/policy/a.md"
git -C "$repository_root" add policy/a.md
git -C "$repository_root" commit -qm symlink-authority
expected_head=$(git -C "$repository_root" rev-parse HEAD)
git -C "$repository_root" checkout -q --detach "$expected_head"
assert_rejected "$tmp_dir/a.json" "committed symlink declared source"
git -C "$repository_root" checkout -q --detach "$regular_source_head"
expected_head=$regular_source_head

submodule_root="$tmp_dir/submodule"
mkdir -p "$submodule_root"
git -C "$submodule_root" init -q
git -C "$submodule_root" config user.email test@example.com
git -C "$submodule_root" config user.name "Closure Test"
printf 'submodule\n' > "$submodule_root/input.txt"
git -C "$submodule_root" add input.txt
git -C "$submodule_root" commit -qm initial
git -C "$repository_root" -c protocol.file.allow=always submodule add -q \
  "$submodule_root" vendor/submodule
git -C "$repository_root" commit -qam submodule
expected_head=$(git -C "$repository_root" rev-parse HEAD)
git -C "$repository_root" checkout -q --detach "$expected_head"
printf 'changed\n' >> "$repository_root/vendor/submodule/input.txt"
assert_rejected "$tmp_dir/a.json" "dirty submodule at pre-publication" \
  "$repository_root" "$expected_head" owner/repo pre-publication
git -C "$repository_root/vendor/submodule" restore input.txt
printf 'phase boundary\n' > "$repository_root/phase-marker.txt"
git -C "$repository_root" add phase-marker.txt
git -C "$repository_root" commit -qm phase-boundary
expected_head=$(git -C "$repository_root" rev-parse HEAD)
git -C "$repository_root" checkout -q --detach "$expected_head"

old_head=$(git -C "$repository_root" rev-parse HEAD~1)
assert_rejected "$tmp_dir/a.json" "wrong expected head" \
  "$repository_root" "$old_head"

unrelated_root="$tmp_dir/unrelated"
mkdir -p "$unrelated_root/config" "$unrelated_root/policy"
printf '{}\n' > "$unrelated_root/package.json"
printf 'mode: strict\n' > "$unrelated_root/config/app.yml"
printf 'policy a\n' > "$unrelated_root/policy/a.md"
printf 'policy z\n' > "$unrelated_root/policy/z.md"
git -C "$unrelated_root" init -q
git -C "$unrelated_root" config user.email test@example.com
git -C "$unrelated_root" config user.name "Closure Test"
git -C "$unrelated_root" remote add origin https://github.com/other/repo.git
git -C "$unrelated_root" add .
git -C "$unrelated_root" commit -qm unrelated
unrelated_head=$(git -C "$unrelated_root" rev-parse HEAD)
assert_rejected "$tmp_dir/a.json" "unrelated repository root" \
  "$unrelated_root" "$unrelated_head"

plain_root="$tmp_dir/plain"
mkdir -p "$plain_root"
assert_rejected "$tmp_dir/a.json" "unverifiable repository root" \
  "$plain_root" "$expected_head"

git -C "$repository_root" checkout -q --detach "$old_head"
assert_rejected "$tmp_dir/a.json" "detached wrong-head worktree" \
  "$repository_root" "$expected_head"

pass "review-source-closure-v1 plugin-owned exact-head oracle"
