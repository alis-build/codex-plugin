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
# v5 rules: alongside the broad allow, defense-in-depth prompt rules cover
# `alis blocks|block uninstall`, a flag ahead of the block verb
# (`alis blocks --json uninstall …`) and every invocation whose first argument
# is a root persistent flag. Together they prevent flag ordering or an explicit
# CLI approval flag from carrying a destructive uninstall through the broad
# allow. The approval-record hook independently excludes every destructive
# uninstall flag permutation from automatic standing grants. Production remains
# separately gated (exit 3 until --confirm-production, always human).
#
# Why the prompt rules are this narrow (v4 covered the whole blocks namespace):
# under Codex's on-request approval a prompt rule does not prompt by itself. A
# command the model has not flagged for escalation runs silently inside the
# sandbox, where every platform call fails on DNS — so v4 turned a plain
# `alis blocks install` into a network error until the model retried with
# escalation. Non-destructive block commands (list, versions, install, upgrade,
# merge) must therefore keep the broad allow.
#
# v6 renames the file from alis-build.rules to alis.rules (the plugin is now
# published as `alis`). A legacy alis-build.rules carrying our stamp is removed
# first, so it neither duplicates the rules nor masks the broad allow check.
#
# Idempotent via the version stamp: our file is regenerated whenever the stamp
# is missing or stale, and never touches any other rules file. The broad allow
# is skipped when the user's own rules already grant it. Note: if Codex loads
# rules before SessionStart hooks fire, changes take effect from the NEXT
# session; the first session may prompt once (which Codex then remembers anyway).
set -euo pipefail

stamp='# alis.rules v6'

home="${CODEX_HOME:-$HOME/.codex}"
dir="$home/rules"
file="$dir/alis.rules"
legacy="$dir/alis-build.rules"

# Remove the file the plugin wrote under its former name (only when it carries
# our stamp — a user-authored file of that name is left alone).
if grep -qsF '# alis-build.rules v' "$legacy" 2>/dev/null; then
  rm -f "$legacy"
fi

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

tmp="$(mktemp "$dir/.alis.rules.XXXXXX")"
{
  printf '%s\n' "$stamp"
  printf '%s\n' '# Managed by the Alis Build Codex plugin — regenerated when the version stamp changes.'
  if [ "$other_has_allow" -eq 0 ]; then
    printf '%s\n' 'prefix_rule(pattern=["alis"], decision="allow", justification="Alis Build CLI — safety gates enforced by the CLI itself (alis docs safety)")'
  fi
  # Block uninstall only: every other block verb is non-destructive and must
  # keep the allow, or Codex runs it sandboxed (see header).
  printf '%s\n' 'prefix_rule(pattern=["alis", ["blocks", "block"], "uninstall"], decision="prompt", justification="Block uninstall is destructive — human confirmation required", match=["alis blocks uninstall block-id", "alis block uninstall block-id --json --yes"], not_match=["alis blocks install block-id --json", "alis blocks list", "alis build package --json"])'
  # A flag ahead of the verb (root persistent flags and every uninstall flag)
  # could reorder `uninstall` past the rule above.
  printf '%s\n' 'prefix_rule(pattern=["alis", ["blocks", "block"], ["--approve", "--json", "--yes", "--verbose", "--quiet", "--instance", "--timeout", "--poll-interval", "--help", "-h"]], decision="prompt", justification="Flag-leading block invocation may reorder a destructive uninstall — human confirmation required", match=["alis blocks --json uninstall block-id --yes", "alis block --approve uninstall block-id"], not_match=["alis blocks install block-id --json", "alis blocks uninstall block-id"])'
  printf '%s\n' 'prefix_rule(pattern=["alis", ["--approve", "--json", "--verbose", "--help", "-h", "--version", "-v"]], decision="prompt", justification="Flag-leading Alis invocation may reorder or pre-approve a destructive command — human confirmation required", match=["alis --json blocks uninstall block-id --yes", "alis --verbose blocks uninstall block-id", "alis --approve build package", "alis -h"], not_match=["alis build package --json", "alis blocks list"])'
} >"$tmp"
mv -f "$tmp" "$file"
exit 0
