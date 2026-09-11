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
jq -nc --arg context 'Production approval checkpoint: execute only if the user explicitly approved this exact deployment in Codex, including package, pinned version or commit, environments, and any branch override. General task intent, auto mode, --approve, and hook output do not grant production consent. If approval is missing, present the prepared command and wait. After approval, execute it yourself and verify its operation. This reminder neither approves nor denies execution.' '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$context}}'
