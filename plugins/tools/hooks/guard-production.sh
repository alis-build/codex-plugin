#!/usr/bin/env bash
# PreToolUse hook (shell tool): deny any `alis` command that carries
# --confirm-production.
#
# Why this exists: the alis CLI's production gate is a flag. It exits 3 until
# the command is re-run with --confirm-production, and the DBD primer tells the
# agent that flag is the user's decision — never add it yourself. That primer
# is the only thing standing between a "push and deploy it" prompt and a
# production rollout, and it is delivered by a SessionStart hook that can
# silently fail (a Codex Desktop app-server keeps the plugin paths it loaded at
# launch; a later plugin upgrade prunes that cache directory, so every hook
# script of the old version is gone). The execpolicy rules cannot help either:
# prefix rules match argv prefixes, and the flag sits after a variable package
# id. This hook is the deterministic backstop.
#
# Codex hooks support permissionDecision allow|deny; "ask" is parsed but not
# yet honoured, so the only human-in-the-loop primitive is a deny whose reason
# hands the exact command to the user to run in their own terminal. That is
# the contract the CLI documents (alis docs safety): production confirmation
# comes from a human, regardless of harness or reviewer mode.
#
# Fail-closed on the signal, fail-open on everything else: a payload we cannot
# parse is scanned as raw text; a command without both `alis` and the flag
# exits 0 with no output, so ordinary commands never pay for this hook.
set -euo pipefail

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || exit 0

cmd=""
if command -v jq >/dev/null 2>&1; then
  cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty | if type == "array" then join(" ") else . end' 2>/dev/null || true)"
fi
# No jq, or a payload shape jq could not read: inspect the raw text instead.
[ -n "$cmd" ] || cmd="$payload"

case "$cmd" in
  *--confirm-production*) ;;
  *) exit 0 ;;
esac
# The flag only means something on an alis invocation; a stray mention in a
# grep or echo is not a deploy.
printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]_.-])alis([[:space:]]|$)' || exit 0

reason='Blocked by the Alis Build plugin: --confirm-production is a human-only confirmation and must never be added by the agent. Do not retry or reword it. Show the user this exact command to run themselves in a terminal, then wait for them to confirm it completed:'
reason="$reason $cmd"

if command -v jq >/dev/null 2>&1; then
  jq -nc --arg reason "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
else
  escaped="${reason//\\/\\\\}"
  escaped="${escaped//\"/\\\"}"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$escaped"
fi
exit 0
