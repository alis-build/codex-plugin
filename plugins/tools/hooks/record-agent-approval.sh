#!/usr/bin/env bash
# PreToolUse hook (shell tool): record pending `alis` CLI invocations at
# ~/.alis/agent-approval.json for the alis CLI's approval gate.
#
# OBSERVER ONLY — this hook never emits a permissionDecision. On Codex, shell
# approval is owned by execpolicy rules (see ensure-alis-rule.sh); a hook allow
# cannot lift the sandbox, so there is nothing useful to decide here. What a
# hook CAN do is run outside the sandbox and record the harness state the alis
# CLI reads: a fresh record in an auto-accept permission mode, matching the
# exact command, counts as a standing user grant for non-production approvals
# (production deploys always require explicit human approval via
# --confirm-production, regardless of harness).
#
# The permission mode is taken from the payload as-is (permission_mode when
# present, else approval_policy); the CLI decides which values count as an
# auto-accept mode per harness. Everything here is best-effort: any parse
# failure or unexpected payload shape exits 0 with no output.
set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

payload="$(cat)"

# The shell tool's command may be a plain string or an argv array; normalise to
# one string. Empty → not a shell call we understand.
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty | if type == "array" then join(" ") else . end' 2>/dev/null || true)"
[ -n "$cmd" ] || exit 0

# Only record a clean, single command whose first token is `alis`. Chained or
# redirected commands are not a single alis invocation and never match the
# CLI's argv check anyway.
case "$cmd" in
  *'|'* | *'&'* | *';'* | *'<'* | *'>'* | *'`'* | *'$('* | *$'\n'*)
    exit 0
    ;;
esac
read -r first _rest <<EOF
$cmd
EOF
[ "$first" = "alis" ] || exit 0

mode="$(printf '%s' "$payload" | jq -r '.permission_mode // .approval_policy // "default"' 2>/dev/null || echo default)"
sid="$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null || true)"
if mkdir -p "$HOME/.alis" 2>/dev/null && tmp="$(mktemp "$HOME/.alis/.agent-approval.XXXXXX" 2>/dev/null)"; then
  if jq -nc --arg m "$mode" --arg s "$sid" --arg c "$cmd" \
      '{version: 1, harness: "codex", permission_mode: $m, session_id: $s, command: $c, written_at: (now | todate)}' \
      >"$tmp" 2>/dev/null; then
    chmod 600 "$tmp" 2>/dev/null || true
    mv -f "$tmp" "$HOME/.alis/agent-approval.json" 2>/dev/null || rm -f "$tmp"
  else
    rm -f "$tmp"
  fi
fi
exit 0
