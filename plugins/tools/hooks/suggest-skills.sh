#!/usr/bin/env bash
# UserPromptSubmit hook: wake-phrase routing and skill discovery.
# The alis CLI reads the UserPromptSubmit JSON payload from stdin and prints
# plain context to stdout, or nothing; what this hook prints becomes session
# context. Three kinds of answer come back:
#   - a wake-phrase instruction ("alis, …", "capture this as a skill"): shown;
#   - "Skill store match for this request …": the CLI asks the Skill store to
#     rank a prompt that passes its gates (alis 1.187.18 or later; before
#     that, in plan mode only), and words that answer this way: shown;
#   - "Possibly relevant Alis skill …": a guess from the CLI's local
#     word-overlap matcher. Dropped: matching whole prompts suggested unrelated
#     skills too often (the Claude plugin dropped it for the same reason).
# Every failure path is silent — discovery must never break a prompt.
command -v alis >/dev/null 2>&1 || exit 0
payload="$(cat 2>/dev/null)" || exit 0
# ALIS_SUGGEST_ALWAYS=0 goes back to asking only where it used to: for prompts
# that could hold an explicit address, and in plan mode.
plan_re='"permission_mode"[[:space:]]*:[[:space:]]*"plan"'
if [ "${ALIS_SUGGEST_ALWAYS:-1}" = "0" ] && ! [[ $payload =~ $plan_re ]]; then
  printf '%s' "$payload" | grep -qiE 'alis|skill' || exit 0
fi
# Swallow every CLI failure (an older alis that rejects --hook exits 1).
out="$(printf '%s' "$payload" | alis skills suggest --hook --harness codex 2>/dev/null)" || exit 0
case "$out" in
  ""|"Possibly relevant Alis skill"*) exit 0 ;;
  "Skill store match"*)
    # A "can you help with …" prompt is often answered without loading
    # anything; the user should still learn the skill exists.
    out="$out
If you answer without loading it, name the skill in your answer so the user knows it exists." ;;
esac
printf '%s\n' "$out"
exit 0
