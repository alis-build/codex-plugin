#!/usr/bin/env bash
# UserPromptSubmit hook: per-prompt skill discovery. Delegates all decisions
# (wake-phrase detection, gating, confidence, dedupe, latency budget) to the
# alis CLI, which reads the UserPromptSubmit JSON payload from stdin and
# prints plain context to stdout, or nothing. Raw stdout becomes session
# context. Every failure path is silent — discovery must never break a prompt.
command -v alis >/dev/null 2>&1 || exit 0
payload="$(cat 2>/dev/null)" || exit 0
case "${CODEX_PROJECT_DIR:-$PWD}" in
  */alis.build/*) ;;
  *)
    # Outside an alis.build workspace, only explicit addresses matter
    # ("alis, …", "capture this as a skill"). This cheap prefilter skips the
    # CLI call for prompts that cannot contain one; the CLI's strict regexes
    # make the actual decision. ALIS_SUGGEST_ALWAYS=1 disables the prefilter.
    if [ "${ALIS_SUGGEST_ALWAYS:-0}" != "1" ]; then
      printf '%s' "$payload" | grep -qiE 'alis|skill' || exit 0
    fi
    ;;
esac
# No `exec` here: exec would make the `|| exit 0` fallback dead code, so a CLI
# error (e.g. an older alis without `--hook`) would propagate a non-zero exit.
printf '%s' "$payload" | alis skills suggest --hook --harness codex 2>/dev/null || exit 0
