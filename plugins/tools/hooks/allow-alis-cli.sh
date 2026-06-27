#!/usr/bin/env bash
# PreToolUse hook: auto-approve `alis` CLI invocations so Codex can run the Alis
# Build command-line tool without an approval prompt on every call.
#
# Why this exists: Codex's execpolicy prompts for shell commands unless a
# matching `prefix_rule(..., decision="allow")` exists in the user's
# `~/.codex/rules/*.rules`. Those rules are user/project-scoped and cannot be
# shipped by a plugin. A PreToolUse hook is the plugin-native equivalent: it
# inspects the pending `exec_command` call and returns
# `permissionDecision: "allow"` for clean `alis ...` invocations, so the rule
# travels with the plugin to everyone who installs it.
#
# Safety: we ONLY auto-approve a single, simple `alis <subcommand> ...` command.
# If the command chains or redirects (|, &&, ||, ;, &, >, <, backtick, $(...),
# newline) we emit NOTHING and exit 0, letting Codex's normal approval flow take
# over. This prevents `alis define && rm -rf /`-style smuggling from riding on
# the allow. The matcher in hooks.json restricts this hook to `exec_command`.
#
# Scope: by default every `alis` subcommand is auto-approved. To restrict, set
# ALIS_ALLOWED_SUBCMDS to a space-separated allowlist (e.g. "define build
# deploy operations"); any other subcommand then falls through to a prompt.
#
# Reads the hook payload (JSON) on stdin and writes the hook response to stdout.
set -euo pipefail

# Without jq we cannot parse the payload; emit nothing and exit 0 so the call
# proceeds through Codex's normal approval flow (graceful degradation).
command -v jq >/dev/null 2>&1 || exit 0

payload="$(cat)"
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.cmd // empty' 2>/dev/null || true)"
[ -n "$cmd" ] || exit 0

# Reject anything that splits into multiple shell segments or redirects. We keep
# this conservative: a legitimately-quoted metacharacter just means the user
# gets a normal prompt this once, which is safe degradation.
case "$cmd" in
  *'|'* | *'&'* | *';'* | *'<'* | *'>'* | *'`'* | *'$('* | *$'\n'*)
    exit 0
    ;;
esac

# First token must be exactly `alis`; capture the subcommand (second token).
read -r first sub _rest <<EOF
$cmd
EOF
[ "$first" = "alis" ] || exit 0

# Optional allowlist of subcommands.
if [ -n "${ALIS_ALLOWED_SUBCMDS:-}" ]; then
  allowed=0
  for s in $ALIS_ALLOWED_SUBCMDS; do
    [ "$s" = "$sub" ] && { allowed=1; break; }
  done
  [ "$allowed" -eq 1 ] || exit 0
fi

# Approve the call. permissionDecisionReason is surfaced in Codex for audit.
jq -nc '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "allow",
    permissionDecisionReason: "Auto-approved alis CLI command (Alis Build plugin)"
  }
}'
