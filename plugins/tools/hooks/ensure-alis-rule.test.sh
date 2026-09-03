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

grep -qFx '# alis-build.rules v5' "$rule"

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

# Non-destructive block commands keep the broad allow. Under Codex's on-request
# approval a prompt rule is not a prompt: a command the model did not flag for
# escalation runs silently inside the sandbox, where `alis blocks install`
# fails on DNS (ticket 4fd5150f). Only uninstall may cost the allow.
assert_decision allow alis blocks list
assert_decision allow alis blocks install arenaagent marvel.sb.arenaagent.v4 --json
assert_decision allow alis block install arenaagent --json
assert_decision allow alis blocks versions arenaagent
assert_decision allow alis blocks upgrade arenaagent --json
assert_decision allow alis blocks merge arenaagent

# Uninstall prompts through most-restrictive-wins, with flags before or after
# the verb, in both the singular and plural spelling.
assert_decision prompt alis blocks uninstall blocks/example
assert_decision prompt alis block uninstall blocks/example --json
assert_decision prompt alis blocks --json uninstall blocks/example --yes
assert_decision prompt alis blocks --json uninstall blocks/example --approve
assert_decision prompt alis block --approve uninstall blocks/example
assert_decision prompt alis blocks --yes uninstall blocks/example
assert_decision prompt alis blocks --verbose uninstall blocks/example
assert_decision prompt alis blocks --quiet uninstall blocks/example
assert_decision prompt alis blocks --instance blocks/example/instances/1 uninstall blocks/example

# Every current root persistent flag prompts when it is the first argument.
# This closes flag-order bypasses while leaving command-first forms above alone.
assert_decision prompt alis --approve build alis.os.console.v2
assert_decision prompt alis --json build alis.os.console.v2
assert_decision prompt alis --verbose blocks uninstall blocks/example
assert_decision prompt alis --help
assert_decision prompt alis -h
assert_decision prompt alis --version
assert_decision prompt alis -v
assert_decision prompt alis --json blocks uninstall blocks/example --yes
assert_decision prompt alis --json blocks uninstall blocks/example --approve
assert_decision prompt alis --json --approve blocks uninstall blocks/example --yes
