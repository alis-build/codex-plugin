#!/usr/bin/env bash
# SessionStart hook: refresh catalog metadata used by ambient suggestions.
# --cache-only is explicit for compatibility with older alis CLIs, whose
# default sync installed and pruned native harness skills. hooks.json asks
# Codex to run this command asynchronously; the script itself stays attached
# so Codex can enforce its timeout and cancel unfinished work with the session.
# Silent and fail-open: discovery must never delay or break session startup.
cat >/dev/null 2>&1 || true
command -v alis >/dev/null 2>&1 || exit 0
alis skills sync --cache-only >/dev/null 2>&1 || true
exit 0
