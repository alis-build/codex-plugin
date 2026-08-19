#!/usr/bin/env bash
set -euo pipefail

hook_dir="$(cd "$(dirname "$0")" && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/bin" "$test_dir/workspace/alis.build/org/build/prod" "$test_dir/elsewhere"
cat > "$test_dir/bin/alis" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$ALIS_TEST_LOG"
cat > /dev/null
EOF
chmod +x "$test_dir/bin/alis"

run_hook() { # $1 = CODEX_PROJECT_DIR, $2 = prompt
  PATH="$test_dir/bin:$PATH" ALIS_TEST_LOG="$test_dir/calls" \
    CODEX_PROJECT_DIR="$1" ALIS_SUGGEST_ALWAYS=0 \
    "$hook_dir/suggest-skills.sh" <<<"{\"session_id\":\"t\",\"prompt\":\"$2\"}"
}
calls() { wc -l < "$test_dir/calls" 2>/dev/null | tr -d ' ' || echo 0; }

# 1. Inside an alis.build workspace, every prompt reaches the CLI.
run_hook "$test_dir/workspace/alis.build/org/build/prod" "update the makefile"
[ "$(calls)" = "1" ] || { echo "workspace prompt did not reach the CLI" >&2; exit 1; }
grep -q "skills suggest --hook --harness codex" "$test_dir/calls" || {
  echo "unexpected CLI call: $(cat "$test_dir/calls")" >&2; exit 1; }

# 2. Outside a workspace, a generic prompt never reaches the CLI.
run_hook "$test_dir/elsewhere" "update the makefile"
[ "$(calls)" = "1" ] || { echo "generic prompt outside workspace reached the CLI" >&2; exit 1; }

# 3. Outside a workspace, wake-phrase-shaped prompts do reach the CLI.
run_hook "$test_dir/elsewhere" "alis, find me a tracing skill"
[ "$(calls)" = "2" ] || { echo "wake phrase outside workspace did not reach the CLI" >&2; exit 1; }
run_hook "$test_dir/elsewhere" "capture this as a skill"
[ "$(calls)" = "3" ] || { echo "capture phrase outside workspace did not reach the CLI" >&2; exit 1; }

# 4. ALIS_SUGGEST_ALWAYS=1 bypasses the outside-workspace prefilter.
PATH="$test_dir/bin:$PATH" ALIS_TEST_LOG="$test_dir/calls" \
  CODEX_PROJECT_DIR="$test_dir/elsewhere" ALIS_SUGGEST_ALWAYS=1 \
  "$hook_dir/suggest-skills.sh" <<<'{"session_id":"t","prompt":"update the makefile"}'
[ "$(calls)" = "4" ] || { echo "ALIS_SUGGEST_ALWAYS=1 did not bypass the prefilter" >&2; exit 1; }

# 5. A missing alis CLI exits 0 silently.
out="$(PATH="/usr/bin:/bin" CODEX_PROJECT_DIR="$test_dir/elsewhere" \
  "$hook_dir/suggest-skills.sh" <<<'{"prompt":"alis, hello"}')" || {
  echo "missing alis CLI produced a non-zero exit" >&2; exit 1; }
[ -z "$out" ] || { echo "missing alis CLI produced output: $out" >&2; exit 1; }

echo "suggest-skills hook: workspace gate, wake-phrase prefilter, and fail-open verified"
