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
# v2 rules: alongside the broad allow, a prompt rule for
# `alis blocks|block uninstall …` — execpolicy's most-restrictive-wins keeps the
# destructive uninstall on a human prompt (double-keying) even though the broad
# allow matches too. Prefix rules cannot match flags at arbitrary positions, so
# `--confirm-production` / `--approve` cannot be carved out here; the CLI's own
# gates cover production (exit 3 until --confirm-production, always human).
#
# Idempotent via the version stamp: our file is regenerated whenever the stamp
# is missing or stale, and never touches any other rules file. The broad allow
# is skipped when the user's own rules already grant it. Note: if Codex loads
# rules before SessionStart hooks fire, changes take effect from the NEXT
# session; the first session may prompt once (which Codex then remembers anyway).
set -euo pipefail

stamp='# alis-build.rules v2'

home="${CODEX_HOME:-$HOME/.codex}"
dir="$home/rules"
file="$dir/alis-build.rules"

# Current version already installed? Then stop.
grep -qsF "$stamp" "$file" 2>/dev/null && exit 0

mkdir -p "$dir"

# Does any OTHER rules file already grant the broad `alis` allow? The pattern
# matches the broad `["alis"]` rule specifically — not narrower entries like
# ["alis","define"] — so we still install the broad rule even when
# per-subcommand rules exist.
other_has_allow=0
if grep -rqsE 'prefix_rule\(pattern=\["alis"\]' --exclude="$(basename "$file")" "$dir" 2>/dev/null; then
  other_has_allow=1
fi

tmp="$(mktemp "$dir/.alis-build.rules.XXXXXX")"
{
  printf '%s\n' "$stamp"
  printf '%s\n' '# Managed by the Alis Build Codex plugin — regenerated when the version stamp changes.'
  if [ "$other_has_allow" -eq 0 ]; then
    printf '%s\n' 'prefix_rule(pattern=["alis"], decision="allow", justification="Alis Build CLI — safety gates enforced by the CLI itself (alis docs safety)")'
  fi
  printf '%s\n' 'prefix_rule(pattern=["alis", ["blocks", "block"], "uninstall"], decision="prompt", justification="Destructive uninstall — double-key confirmation")'
} >"$tmp"
mv -f "$tmp" "$file"
exit 0
