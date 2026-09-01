#!/usr/bin/env bash
set -euo pipefail

hook_dir="$(cd "$(dirname "$0")" && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

test_home="$test_root/home"
test_codex_home="$test_root/codex"
mkdir -p "$test_home"

HOME="$test_home" CODEX_HOME="$test_codex_home" "$hook_dir/ensure-alis-rule.sh"
rule="$test_codex_home/rules/alis-build.rules"

grep -qFx '# alis-build.rules v4' "$rule"

# Re-running the hook with the current stamp must be a no-op.
before="$(cksum "$rule")"
HOME="$test_home" CODEX_HOME="$test_codex_home" "$hook_dir/ensure-alis-rule.sh"
after="$(cksum "$rule")"
if [ "$before" != "$after" ]; then
  echo "current rule file was unexpectedly regenerated" >&2
  exit 1
fi

if ! command -v codex >/dev/null 2>&1; then
  echo "codex is required for execpolicy regression checks" >&2
  exit 1
fi

assert_decision() {
  local expected="$1"
  shift
  local result actual
  result="$(codex execpolicy check --rules "$rule" -- "$@" 2>/dev/null)"
  actual="$(jq -r '.decision // "none"' <<<"$result")"
  if [ "$actual" != "$expected" ]; then
    echo "expected execpolicy decision '$expected', got '$actual': $*" >&2
    echo "$result" >&2
    exit 1
  fi
}

# Canonical, non-block CLI invocations stay unrestricted. Flags after the
# command do not trigger the root-flag rule.
assert_decision allow alis build alis.os.console.v2 --json
assert_decision allow alis deploy alis.os.console.v2 --json

# Every block-management invocation prompts through most-restrictive-wins,
# including safe-looking subcommands and flags before or after `uninstall`.
assert_decision prompt alis blocks list
assert_decision prompt alis blocks uninstall blocks/example
assert_decision prompt alis block uninstall blocks/example --json
assert_decision prompt alis blocks --json uninstall blocks/example --yes
assert_decision prompt alis blocks --json uninstall blocks/example --approve
assert_decision prompt alis block --approve uninstall blocks/example

# Every current root persistent flag prompts when it is the first argument.
# This closes flag-order bypasses while leaving command-first forms above alone.
assert_decision prompt alis --approve build alis.os.console.v2
assert_decision prompt alis --json build alis.os.console.v2
assert_decision prompt alis --help
assert_decision prompt alis -h
assert_decision prompt alis --version
assert_decision prompt alis -v
assert_decision prompt alis --json blocks uninstall blocks/example --yes
assert_decision prompt alis --json blocks uninstall blocks/example --approve
assert_decision prompt alis --json --approve blocks uninstall blocks/example --yes
