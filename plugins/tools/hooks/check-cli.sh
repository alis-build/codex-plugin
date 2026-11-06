#!/usr/bin/env bash
# Startup-only capability check; plugin upgrades may precede CLI upgrades.
set -eu
if alis hooks capabilities 2>/dev/null | grep -qE '"protocol"[[:space:]]*:[[:space:]]*1([,}[:space:]])'; then
  exit 0
fi
printf '%s\n' '{"systemMessage":"alis: this plugin requires a newer Alis CLI. Run `alis upgrade`, then restart this coding agent to enable all Alis hooks.","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"alis: this plugin requires a newer Alis CLI. Run `alis upgrade`, then restart this coding agent to enable all Alis hooks."}}'
