#!/usr/bin/env bash
set -euo pipefail

hook_dir="$(cd "$(dirname "$0")" && pwd)"
test_home="$(mktemp -d)"
trap 'rm -rf "$test_home"' EXIT

record="$test_home/.alis/agent-approval.json"

run_string_command() {
  local cmd="$1"
  local payload
  payload="$(jq -nc --arg command "$cmd" '{session_id:"thread-123", permission_mode:"dontAsk", tool_input:{command:$command}}')"
  HOME="$test_home" "$hook_dir/record-agent-approval.sh" <<<"$payload"
}

assert_recorded() {
  local cmd="$1"
  run_string_command "$cmd"
  jq -e --arg command "$cmd" '
    .version == 1 and
    .harness == "codex" and
    .permission_mode == "dontAsk" and
    .session_id == "thread-123" and
    .command == $command
  ' "$record" >/dev/null
}

assert_not_recorded() {
  local cmd="$1"

  # Seed a prior grant so the assertion also proves that an uninstall command
  # invalidates records written by older, vulnerable plugin versions.
  assert_recorded "alis whoami"
  run_string_command "$cmd"
  if [ -e "$record" ]; then
    echo "destructive command unexpectedly retained an approval record: $cmd" >&2
    exit 1
  fi
}

# Ordinary commands, including safe block operations and unrelated uses of the
# word "uninstall", continue to receive the normal standing-grant record.
assert_recorded "alis build alis.os.console.v2 --json"
assert_recorded "alis --json blocks list"
assert_recorded "alis ask uninstall blocks"

# Persistent flags are valid in multiple positions. None of these destructive
# spellings may receive an automatic standing grant.
destructive_commands=(
  "alis blocks uninstall blocks/example"
  "alis block uninstall blocks/example"
  "alis --json blocks uninstall blocks/example"
  "alis --approve --json blocks uninstall blocks/example"
  "alis --json blocks --approve uninstall blocks/example"
  "alis blocks --json uninstall blocks/example"
  "alis blocks uninstall --json blocks/example"
  "alis blocks uninstall blocks/example --yes"
  "alis blocks --json uninstall blocks/example --approve"
  "alis --json blocks uninstall blocks/example --approve"
  'alis "blocks" "uninstall" blocks/example'
  'alis blo\cks un\install blocks/example'
  "alis \$'blocks' \$'uninstall' blocks/example"
)
for cmd in "${destructive_commands[@]}"; do
  assert_not_recorded "$cmd"
done

# Array-shaped shell payloads are normalised by the hook, and must receive the
# same protection as string-shaped payloads.
assert_recorded "alis whoami"
array_payload='{"session_id":"thread-123","permission_mode":"dontAsk","tool_input":{"command":["alis","--json","blocks","uninstall","blocks/example"]}}'
HOME="$test_home" "$hook_dir/record-agent-approval.sh" <<<"$array_payload"
if [ -e "$record" ]; then
  echo "array-shaped destructive command unexpectedly retained an approval record" >&2
  exit 1
fi

assert_recorded "alis build alis.os.console.v2 --json"
before="$(cksum "$record")"
chained='{"session_id":"thread-123","permission_mode":"dontAsk","tool_input":{"command":"alis build --json && echo unsafe"}}'
HOME="$test_home" "$hook_dir/record-agent-approval.sh" <<<"$chained"
after="$(cksum "$record")"

if [[ "$before" != "$after" ]]; then
  echo "chained command unexpectedly replaced the approval record" >&2
  exit 1
fi

# The production guard runs first so its deny is decided before the observer
# records anything; both match Codex's canonical Bash hook tool name.
jq -e '
  (.hooks.PreToolUse | map(select(.matcher == "^Bash$"))) == [{
    matcher: "^Bash$",
    hooks: [{
      type: "command",
      command: "${PLUGIN_ROOT}/hooks/guard-production.sh",
      timeout: 5
    }, {
      type: "command",
      command: "${PLUGIN_ROOT}/hooks/record-agent-approval.sh",
      timeout: 5
    }]
  }]
' "$hook_dir/hooks.json" >/dev/null || {
  echo "PreToolUse must run the production guard then the approval observer on Codex's canonical Bash hook tool name" >&2
  exit 1
}
