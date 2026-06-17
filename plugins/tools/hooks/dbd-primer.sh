#!/usr/bin/env bash
# SessionStart hook: inject the Alis Build DBD primer into the session context,
# but only for sessions working inside an Alis Build workspace (~/alis.build/...).
# Whatever this script prints to stdout is added to Codex's context.
#
# Codex does not expose a CODEX_PROJECT_DIR env var, so the working directory is
# read from the `cwd` field of the hook payload (JSON on stdin), falling back to
# the current directory. Codex sets PLUGIN_ROOT for plugin-bundled hooks.
set -euo pipefail

payload="$(cat)"
project_dir="$PWD"
if command -v jq >/dev/null 2>&1; then
  cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null || true)"
  [ -n "$cwd" ] && project_dir="$cwd"
fi

case "$project_dir" in
  */alis.build | */alis.build/*)
    cat "${PLUGIN_ROOT}/context/dbd-primer.md"
    ;;
  *)
    # Not an Alis Build workspace: inject nothing.
    :
    ;;
esac
