#!/usr/bin/env bash
# SessionStart hook: inject the Alis Build DBD primer into the session.
#
# Workspace-gated: the full primer (context/dbd-primer.md — mental model,
# skills contract, execution contract) is for sessions doing DBD work, i.e.
# running inside an alis.build workspace (same gate as
# inject-service-context.sh). Outside a workspace, a machine with the alis CLI
# installed still gets the compressed digest (context/dbd-digest.md) so skill
# routing has minimal context; a machine with neither emits nothing — zero
# tokens for unrelated projects.
#
# ALIS_PRIMER overrides the gate: full | digest | off.
#
# A missing digest falls back to the full primer; a missing primer emits
# nothing. Either way we exit 0 so the session proceeds unmodified (graceful
# degradation, like the sibling hooks). Codex sets PLUGIN_ROOT for
# plugin-bundled hooks; the working directory is read from CODEX_PROJECT_DIR
# when set, falling back to the hook's $PWD.
set -euo pipefail

primer="${PLUGIN_ROOT:-}/context/dbd-primer.md"
digest="${PLUGIN_ROOT:-}/context/dbd-digest.md"

dir="${CODEX_PROJECT_DIR:-$PWD}"
in_workspace=0
case "$dir" in */alis.build/*|*/alis.build) in_workspace=1 ;; esac
has_cli=0
command -v alis >/dev/null 2>&1 && has_cli=1

case "${ALIS_PRIMER:-}" in
  off) exit 0 ;;
  full) in_workspace=1 ;;
  digest) in_workspace=0; has_cli=1 ;;
esac

if [ "$in_workspace" -eq 0 ] && [ "$has_cli" -eq 0 ]; then
  exit 0
fi

# Outside a workspace the digest is the ceiling.
if [ "$in_workspace" -eq 0 ] && [ -f "$digest" ]; then
  cat "$digest"
  exit 0
fi

[ -f "$primer" ] && cat "$primer"
exit 0
