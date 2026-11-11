#!/usr/bin/env bash
set -euo pipefail

hook_dir="$(cd "$(dirname "$0")" && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/bin"
# The fake CLI logs its arguments and answers with $ALIS_TEST_ANSWER.
cat > "$test_dir/bin/alis" <<'FAKE'
#!/bin/sh
printf '%s\n' "$*" >> "$ALIS_TEST_LOG"
cat > /dev/null
[ -n "${ALIS_TEST_ANSWER:-}" ] && printf '%s\n' "$ALIS_TEST_ANSWER"
exit 0
FAKE
chmod +x "$test_dir/bin/alis"

run_hook() { # $1 = prompt, $2 = permission_mode, $3 = the CLI's answer, $4 = ALIS_SUGGEST_ALWAYS
  PATH="$test_dir/bin:$PATH" ALIS_TEST_LOG="$test_dir/calls" ALIS_TEST_ANSWER="${3:-}" \
    ALIS_SUGGEST_ALWAYS="${4:-0}" \
    "$hook_dir/suggest-skills.sh" <<<"{\"session_id\":\"t\",\"cwd\":\"/tmp/site\",\"permission_mode\":\"${2:-default}\",\"prompt\":\"$1\"}"
}
calls() { if [ -f "$test_dir/calls" ]; then wc -l < "$test_dir/calls" | tr -d ' '; else echo 0; fi; }

wake='The user addressed alis by name. Before doing anything else: …'
ranked='Skill store match for this request — Alis skill: block-forgejocodereviewer — Adds an AI reviewer.'
guessed='Possibly relevant Alis skill: build-your-first-ios-app — Guide builders.'

# 1. Switched off (ALIS_SUGGEST_ALWAYS=0), a prompt without a wake word never
#    reaches the CLI outside plan mode.
out="$(run_hook "put an AI reviewer on our pull requests" default "$ranked")"
[ "$(calls)" = "0" ] || { echo "generic prompt reached the CLI outside plan mode" >&2; exit 1; }
[ -z "$out" ] || { echo "generic prompt produced output: $out" >&2; exit 1; }

# 2. A wake-phrase-shaped prompt reaches the CLI and its instruction is shown.
out="$(run_hook "alis, find me a tracing skill" default "$wake")"
[ "$(calls)" = "1" ] || { echo "wake phrase did not reach the CLI" >&2; exit 1; }
grep -q "skills suggest --hook --harness codex" "$test_dir/calls" || {
  echo "unexpected CLI call: $(cat "$test_dir/calls")" >&2; exit 1; }
[ "$out" = "$wake" ] || { echo "wake instruction was not passed through: $out" >&2; exit 1; }
run_hook "capture this as a skill" default "" >/dev/null
[ "$(calls)" = "2" ] || { echo "capture phrase did not reach the CLI" >&2; exit 1; }

# 3. In plan mode every prompt reaches the CLI and a Skill store match is shown.
out="$(run_hook "put an AI reviewer on our pull requests" plan "$ranked")"
[ "$(calls)" = "3" ] || { echo "plan-mode prompt did not reach the CLI" >&2; exit 1; }
named="$ranked
If you answer without loading it, name the skill in your answer so the user knows it exists."
[ "$out" = "$named" ] || { echo "Skill store match was not passed through: $out" >&2; exit 1; }

# 4. A local guess is dropped, in plan mode and outside it.
out="$(run_hook "put an AI reviewer on our pull requests" plan "$guessed")"
[ -z "$out" ] || { echo "local guess was shown in plan mode: $out" >&2; exit 1; }
out="$(run_hook "which alis skill covers sendgrid templates" default "$guessed")"
[ -z "$out" ] || { echo "local guess was shown: $out" >&2; exit 1; }

# 5. Left at its default, every prompt reaches the CLI outside plan mode too,
#    and a Skill store match is shown there.
before="$(calls)"
out="$(PATH="$test_dir/bin:$PATH" ALIS_TEST_LOG="$test_dir/calls" ALIS_TEST_ANSWER="$ranked" \
  "$hook_dir/suggest-skills.sh" <<<'{"session_id":"t","permission_mode":"default","prompt":"put an AI reviewer on our pull requests"}')"
[ "$(calls)" = "$((before + 1))" ] || { echo "a default-mode prompt did not reach the CLI" >&2; exit 1; }
[ "$out" = "$named" ] || { echo "Skill store match was not shown outside plan mode: $out" >&2; exit 1; }
out="$(run_hook "update the makefile" default "" 1)"
[ "$(calls)" = "$((before + 2))" ] || { echo "ALIS_SUGGEST_ALWAYS=1 did not reach the CLI" >&2; exit 1; }
[ -z "$out" ] || { echo "an empty answer produced output: $out" >&2; exit 1; }

# 6. A missing alis CLI exits 0 silently.
out="$(PATH="/usr/bin:/bin" "$hook_dir/suggest-skills.sh" <<<'{"prompt":"alis, hello"}')" || {
  echo "missing alis CLI produced a non-zero exit" >&2; exit 1; }
[ -z "$out" ] || { echo "missing alis CLI produced output: $out" >&2; exit 1; }

echo "suggest-skills hook: wake phrases, Skill store matches, the off switch, dropped local guesses, and fail-open verified"
