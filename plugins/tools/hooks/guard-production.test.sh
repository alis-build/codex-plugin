#!/usr/bin/env bash
# Exercise emitted hook behavior; no CLI or deployment runs in these tests.
set -euo pipefail
dir="$(cd "$(dirname "$0")" && pwd)"
hook="$dir/guard-production.sh"
for mode in default plan acceptEdits bypassPermissions; do
  result="$(jq -nc --arg mode "$mode" '{permission_mode:$mode,tool_input:{command:"alis deploy example.app.api.v1 --version 1.2.3 -e prod --confirm-production --json"}}' | bash "$hook")"
  printf '%s' "$result" | jq -e '.hookSpecificOutput | .hookEventName == "PreToolUse" and (.additionalContext | contains("explicitly approved")) and (has("permissionDecision") | not)' >/dev/null
done
# A production reveal is confirmed as a reveal of secrets, not as a deployment.
result="$(jq -nc '{tool_input:{command:"alis environment variables alis.os --reveal -e production --confirm-production --json"}}' | bash "$hook")"
printf '%s' "$result" | jq -e '.hookSpecificOutput | .hookEventName == "PreToolUse" and (.additionalContext | contains("secret") and contains("explicitly approved") and (contains("deployment") | not)) and (has("permissionDecision") | not)' >/dev/null
for command in 'alis context view --json' 'rg --confirm-production docs' 'python3 edit.py # alis --confirm-production'; do
  result="$(jq -nc --arg command "$command" '{tool_input:{command:$command}}' | bash "$hook")"
  [ -z "$result" ] || { echo 'unexpected production reminder for non-deploy input' >&2; exit 1; }
done
[ -z "$(printf '%s' 'not json' | bash "$hook")" ]
# Cmd and argv payload forms used by shell harnesses also carry the reminder.
for payload in '{"tool_input":{"cmd":"alis deploy x --confirm-production"}}' '{"tool_input":{"command":["alis","deploy","x","--confirm-production"]}}'; do
  printf '%s' "$payload" | bash "$hook" | jq -e '.hookSpecificOutput.additionalContext | length > 0' >/dev/null
done
echo 'guard-production behavior: OK'
