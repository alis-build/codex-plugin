#!/usr/bin/env bash
# UserPromptSubmit hook: per-prompt skill discovery. Delegates all logic
# (wake-phrase detection, gating, dedupe, latency budget) to the alis CLI,
# which reads the UserPromptSubmit JSON payload from stdin and prints plain
# context to stdout, or nothing. Raw stdout becomes session context.
# Every failure path is silent — discovery must never break a prompt.
command -v alis >/dev/null 2>&1 || exit 0
case "${CODEX_PROJECT_DIR:-$PWD}" in
  */alis.build/*) ;;
  *) [ "${ALIS_SUGGEST_ALWAYS:-0}" = "1" ] || exit 0 ;;
esac
# No `exec` here: exec would make the `|| exit 0` fallback dead code, so a CLI
# error (e.g. an older alis without `--hook`) would propagate a non-zero exit.
alis skills suggest --hook --harness codex 2>/dev/null || exit 0
