#!/usr/bin/env bash
# The PostToolUse secrets warning: what the person and the model are told when
# a tool call carries secret-looking values. Every value here is a made-up
# shape, never a real credential; the Stripe one is assembled so no scanner
# reads the source as a key.
set -euo pipefail
dir="$(cd "$(dirname "$0")" && pwd)"
hook="$dir/warn-secrets.sh"
test_home="$(mktemp -d)"
trap 'rm -rf "$test_home"' EXIT

stripe="sk_live_$(printf 'FAKE%.0s' 1 2 3 4 5)0000"
linear="lin_api_FAKEFAKEFAKEFAKEFAKE0000"

run_hook() { # $1 = session, $2 = command, $3 = stdout
  jq -nc --arg s "$1" --arg c "$2" --arg o "$3" \
    '{session_id:$s, hook_event_name:"PostToolUse", tool_name:"Bash", tool_input:{command:$c}, tool_response:{stdout:$o, stderr:""}}' \
    | HOME="$test_home" bash "$hook"
}

# A leaked key warns the person (systemMessage) and the model (additionalContext), never with the value.
result="$(run_hook s1 'cat .env' "$stripe")"
printf '%s' "$result" | jq -e '.hookSpecificOutput | .hookEventName == "PostToolUse" and (.additionalContext | contains("stripe") and contains("rotate"))' >/dev/null
printf '%s' "$result" | jq -e '.systemMessage | startswith("alis: ") and contains("secret")' >/dev/null
case "$result" in *"$stripe"*) echo 'the warning carried the value' >&2; exit 1 ;; esac

# The same value in the same session warns once; a new value still warns.
[ -z "$(run_hook s1 'cat .env' "$stripe")" ] || { echo 'a value already warned about warned again' >&2; exit 1; }
run_hook s1 'cat .env' "$stripe
$linear" | jq -e '.hookSpecificOutput.additionalContext | contains("linear") and (contains("stripe") | not)' >/dev/null

# Rows an alis environment reveal printed count as revealed, for that command only.
revealed='{"environments":[{"environmentId":"production","envs":[{"name":"DB_PASSWORD","value":"FAKE-long-value-abcdefghij"}]}],"revealed":true}'
run_hook s2 'alis environment variables alis.os --reveal --json' "$revealed" | jq -e '.hookSpecificOutput.additionalContext | contains("revealed")' >/dev/null
[ -z "$(run_hook s2 'cat out.json' "$revealed")" ] || { echo 'name/value JSON from another command was reported' >&2; exit 1; }

# The masked default output is silent.
[ -z "$(run_hook s3 'alis environment variables alis.os' 'DB_PASSWORD   ••••••••')" ] || { echo 'masked output was reported' >&2; exit 1; }
[ -z "$(run_hook s3 'alis environment variables alis.os --json' '{"environments":[{"envs":[{"name":"DB_PASSWORD","set":true}]}],"revealed":false}')" ] || { echo 'names-only JSON was reported' >&2; exit 1; }

# Clean output, a missing response and a non-JSON payload are silent.
[ -z "$(run_hook s4 'echo ok' 'ok')" ]
[ -z "$(printf '{"hook_event_name":"PostToolUse","tool_name":"Bash"}' | HOME="$test_home" bash "$hook")" ]
[ -z "$(printf 'not json' | HOME="$test_home" bash "$hook")" ]

# The hook is registered on PostToolUse.
jq -e 'any(.hooks.PostToolUse[].hooks[]; .command == "${PLUGIN_ROOT}/hooks/warn-secrets.sh")' "$dir/hooks.json" >/dev/null || {
  echo 'warn-secrets.sh must run on PostToolUse' >&2; exit 1; }
echo 'warn-secrets behavior: OK'
