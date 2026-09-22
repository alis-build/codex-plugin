#!/usr/bin/env bash
# PreToolUse reminder, not an attestation of conversational user consent.
# Never emits allow/deny or turns auto mode into production approval.
set -euo pipefail
payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // .tool_input.cmd // empty | if type == "array" then join(" ") elif type == "string" then . else empty end' 2>/dev/null || true)"
case "$cmd" in *--confirm-production*) ;; *) exit 0 ;; esac
# Canonical standalone calls only. File edits and searches are not deployments.
# Wrapped calls still rely on Codex review and the CLI gate.
printf '%s' "$cmd" | grep -Eq '^[[:space:]]*alis[[:space:]]' || exit 0
case "$cmd" in
  *--reveal*)
    # A production reveal: the values land in the transcript for good.
    context='Production secrets checkpoint: execute only if the user explicitly approved revealing the secret values of this exact production environment in Codex, naming the product, environment and any --name filter. The values will land in the session transcript; the plugin warns afterwards and cannot remove them. General task intent, auto mode, --approve, and hook output do not grant production consent. If approval is missing, present the prepared command and wait. This reminder neither approves nor denies execution.' ;;
  *)
    context='Production approval checkpoint: execute only if the user explicitly approved this exact deployment in Codex, including package, pinned version or commit, environments, and any branch override. General task intent, auto mode, --approve, and hook output do not grant production consent. If approval is missing, present the prepared command and wait. After approval, execute it yourself and verify its operation. This reminder neither approves nor denies execution.' ;;
esac
jq -nc --arg context "$context" '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$context}}'
