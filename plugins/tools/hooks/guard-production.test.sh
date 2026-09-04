#!/usr/bin/env bash
set -euo pipefail

hook_dir="$(cd "$(dirname "$0")" && pwd)"
hook="$hook_dir/guard-production.sh"

run_hook() {
  local payload="$1"
  "$hook" <<<"$payload"
}

string_payload() {
  jq -nc --arg command "$1" '{session_id:"thread-123", permission_mode:"dontAsk", tool_name:"Bash", tool_input:{command:$command}}'
}

array_payload() {
  printf '%s\n' "$@" | jq -R -s -c 'split("\n") | map(select(length > 0)) | {session_id:"thread-123", tool_name:"Bash", tool_input:{command:.}}'
}

assert_denied() {
  local label="$1" payload="$2" out
  out="$(run_hook "$payload")"
  if ! jq -e '.hookSpecificOutput.hookEventName == "PreToolUse" and .hookSpecificOutput.permissionDecision == "deny"' <<<"$out" >/dev/null 2>&1; then
    echo "expected a deny for: $label" >&2
    echo "$out" >&2
    exit 1
  fi
  # The reason must hand the exact command to the human and forbid a retry.
  if ! jq -e '.hookSpecificOutput.permissionDecisionReason | test("human-only") and test("Do not retry")' <<<"$out" >/dev/null 2>&1; then
    echo "deny reason is missing the hand-to-human instruction for: $label" >&2
    echo "$out" >&2
    exit 1
  fi
}

assert_silent() {
  local label="$1" payload="$2" out
  out="$(run_hook "$payload")"
  if [ -n "$out" ]; then
    echo "expected no output for: $label" >&2
    echo "$out" >&2
    exit 1
  fi
}

# Every production spelling the CLI accepts is denied, wherever the flag sits.
assert_denied "build --deploy" "$(string_payload 'alis build boltfast.hr.performance.v1 --deploy -e 1y2ozvpstlpqx --confirm-production --json')"
assert_denied "deploy" "$(string_payload 'alis deploy boltfast.hr.performance.v1 --version 1.3.2 --confirm-production --json')"
assert_denied "environment set" "$(string_payload 'alis environment set boltfast.hr.1y2ozvpstlpqx KEY=value --confirm-production --yes --json')"
assert_denied "flag first" "$(string_payload 'alis --confirm-production deploy pkg')"
assert_denied "absolute binary" "$(string_payload '/usr/local/bin/alis deploy pkg --confirm-production')"
assert_denied "env prefix" "$(string_payload 'ALIS_APPROVE=1 alis deploy pkg --confirm-production')"
assert_denied "chained" "$(string_payload 'git push && alis deploy pkg --confirm-production --json')"
assert_denied "argv array" "$(array_payload alis deploy pkg --confirm-production --json)"

# The deny reason carries the command verbatim so the user can paste it.
out="$(run_hook "$(string_payload 'alis deploy pkg --version 1.3.2 --confirm-production --json')")"
jq -e '.hookSpecificOutput.permissionDecisionReason | endswith("alis deploy pkg --version 1.3.2 --confirm-production --json")' <<<"$out" >/dev/null

# A payload jq cannot parse still trips on the raw text.
assert_denied "raw text" '{"tool_input":{"command":"alis deploy pkg --confirm-production"'

# Everything else stays silent: the flag alone (no alis), alis alone, mentions
# in unrelated commands, and non-shell payloads.
assert_silent "no flag" "$(string_payload 'alis deploy boltfast.hr.performance.v1 --json')"
assert_silent "production env without flag" "$(string_payload 'alis build pkg --deploy -e prod --json')"
assert_silent "flag without alis" "$(string_payload 'echo --confirm-production')"
assert_silent "grep for the flag" "$(string_payload 'rg -n "confirm-production" docs/')"
assert_silent "word containing alis" "$(string_payload 'realistic --confirm-production')"
assert_silent "empty payload" ''
assert_silent "no command" "$(jq -nc '{session_id:"thread-123", tool_name:"Read", tool_input:{file_path:"/tmp/x"}}')"

echo "guard-production: OK"
