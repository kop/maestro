#!/usr/bin/env bash

set -euo pipefail

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'PASS: %s\n' "$*"
}

assert_file() {
  local path=$1
  [[ -f "$path" ]] || fail "expected file: $path"
}

assert_not_file() {
  local path=$1
  [[ ! -e "$path" ]] || fail "expected path to be absent: $path"
}

assert_contains() {
  local path=$1
  local pattern=$2
  grep -Eq -- "$pattern" "$path" || fail "$path missing pattern: $pattern"
}

assert_not_contains() {
  local path=$1
  local pattern=$2
  if grep -Eq -- "$pattern" "$path"; then
    fail "$path unexpectedly contains pattern: $pattern"
  fi
}

assert_executable() {
  local path=$1
  [[ -x "$path" ]] || fail "expected executable: $path"
}

frontmatter_value() {
  local path=$1
  local key=$2
  awk -v key="$key" '
    NR == 1 && $0 == "---" { in_frontmatter = 1; next }
    in_frontmatter && $0 == "---" { exit }
    in_frontmatter && index($0, key ":") == 1 {
      sub("^[^:]+:[[:space:]]*", "")
      print
      exit
    }
  ' "$path"
}

assert_frontmatter_value() {
  local path=$1
  local key=$2
  local expected=$3
  local actual
  actual=$(frontmatter_value "$path" "$key")
  [[ "$actual" == "$expected" ]] ||
    fail "$path frontmatter $key expected '$expected', got '$actual'"
}
