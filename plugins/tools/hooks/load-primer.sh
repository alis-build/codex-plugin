#!/usr/bin/env bash
# SessionStart hook: always inject the Alis Build DBD primer into the session.
#
# The primer (context/dbd-primer.md) is the standing how-to guide — the DBD
# mental model, the routing contract (when to discover a skill vs run a command),
# and the execution contract (prefer the `alis` CLI). Installing the plugin
# installs this guide into every session; no trigger word is required, which
# replaces the old vocative-gated UserPromptSubmit injection.
#
# Whatever this script prints to stdout is added to the session context at
# startup. Codex sets PLUGIN_ROOT for plugin-bundled hooks. If the primer is
# missing we emit nothing and exit 0 so the session proceeds unmodified
# (graceful degradation, like the sibling hooks).
set -euo pipefail

primer="${PLUGIN_ROOT:-}/context/dbd-primer.md"
[ -f "$primer" ] && cat "$primer"
exit 0
