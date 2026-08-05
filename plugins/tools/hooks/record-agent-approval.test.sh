#!/usr/bin/env bash
set -euo pipefail

hook_dir="$(cd "$(dirname "$0")" && pwd)"
test_home="$(mktemp -d)"
trap 'rm -rf "$test_home"' EXIT

payload='{"session_id":"thread-123","permission_mode":"dontAsk","tool_input":{"command":"alis build alis.os.console.v2 --json"}}'
HOME="$test_home" "$hook_dir/record-agent-approval.sh" <<<"$payload"

record="$test_home/.alis/agent-approval.json"
jq -e '
  .version == 1 and
  .harness == "codex" and
  .permission_mode == "dontAsk" and
  .session_id == "thread-123" and
  .command == "alis build alis.os.console.v2 --json"
' "$record" >/dev/null

before="$(cksum "$record")"
chained='{"session_id":"thread-123","permission_mode":"dontAsk","tool_input":{"command":"alis build --json && echo unsafe"}}'
HOME="$test_home" "$hook_dir/record-agent-approval.sh" <<<"$chained"
after="$(cksum "$record")"

if [[ "$before" != "$after" ]]; then
  echo "chained command unexpectedly replaced the approval record" >&2
  exit 1
fi
