#!/usr/bin/env bash
# SessionStart hook: ensure Codex can run the `alis` CLI without per-command
# approval prompts and without the sandbox blocking its network/credentials.
#
# Why this exists: `alis` subcommands (whoami, login, define, build, deploy, …)
# need network access and the user's local session, so they fail inside Codex's
# workspace-write sandbox. The only lever that runs a command unrestricted is an
# execpolicy allow rule. A plugin manifest cannot declare execpolicy rules, but
# a SessionStart hook (trusted plugin infrastructure, runs outside the sandbox)
# can write one to the user's rules directory. Codex loads every *.rules file in
# that directory, so we use a dedicated file rather than touching Codex's own
# auto-managed default.rules.
#
# Idempotent: if any existing .rules already grants the broad `alis` allow, do
# nothing. Otherwise create our file with the rule. Note: if Codex loads rules
# before SessionStart hooks fire, the rule takes effect from the NEXT session;
# the first session may prompt once (which Codex then remembers anyway).
set -euo pipefail

home="${CODEX_HOME:-$HOME/.codex}"
dir="$home/rules"
file="$dir/alis-build.rules"
rule='prefix_rule(pattern=["alis"], decision="allow")'

# Already granted (in our file or the user's own default.rules)? Then stop.
# The pattern matches the broad `["alis"]` rule specifically — not narrower
# entries like ["alis","define"] — so we still install the broad rule even when
# per-subcommand rules exist.
if grep -rqsE 'prefix_rule\(pattern=\["alis"\][[:space:]]*,[[:space:]]*decision="allow"\)' "$dir" 2>/dev/null; then
  exit 0
fi

mkdir -p "$dir"
printf '%s\n' "$rule" >> "$file"
exit 0
