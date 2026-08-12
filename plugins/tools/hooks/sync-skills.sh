#!/usr/bin/env bash
# SessionStart hook: refresh catalog metadata used by ambient suggestions.
# --cache-only is explicit for compatibility with older alis CLIs, whose
# default sync installed and pruned native harness skills. Detached, silent,
# and fail-open: discovery must never delay or break session startup.
cat >/dev/null 2>&1 || true
command -v alis >/dev/null 2>&1 || exit 0
(alis skills sync --cache-only >/dev/null 2>&1 &)
exit 0
