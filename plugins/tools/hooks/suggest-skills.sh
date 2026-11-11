#!/usr/bin/env bash
# UserPromptSubmit hook: wake-phrase routing and, in plan mode, skill discovery.
# The alis CLI reads the UserPromptSubmit JSON payload from stdin and prints
# plain context to stdout, or nothing; what this hook prints becomes session
# context. Three kinds of answer come back:
#   - a wake-phrase instruction ("alis, …", "capture this as a skill"): shown;
#   - "Skill store match for this request …": in plan mode the CLI asks the
#     Skill store to rank the request, and words that answer this way: shown;
#   - "Possibly relevant Alis skill …": a guess from the CLI's local
#     word-overlap matcher. Dropped: matching whole prompts suggested unrelated
#     skills too often (the Claude plugin dropped it for the same reason).
# Every failure path is silent — discovery must never break a prompt.
command -v alis >/dev/null 2>&1 || exit 0
payload="$(cat 2>/dev/null)" || exit 0
# Outside plan mode only explicit addresses matter, so this cheap prefilter
# skips the CLI call for prompts that cannot contain one; the CLI's strict
# regexes make the actual decision. A plan-mode prompt always reaches the CLI,
# which is where it asks the Skill store. ALIS_SUGGEST_ALWAYS=1 disables the
# prefilter.
plan_re='"permission_mode"[[:space:]]*:[[:space:]]*"plan"'
if [ "${ALIS_SUGGEST_ALWAYS:-0}" != "1" ] && ! [[ $payload =~ $plan_re ]]; then
  printf '%s' "$payload" | grep -qiE 'alis|skill' || exit 0
fi
# Swallow every CLI failure (an older alis that rejects --hook exits 1).
out="$(printf '%s' "$payload" | alis skills suggest --hook --harness codex 2>/dev/null)" || exit 0
case "$out" in
  "Possibly relevant Alis skill"*) exit 0 ;;
esac
[ -n "$out" ] && printf '%s\n' "$out"
exit 0
