#!/usr/bin/env bash
set -euo pipefail

hook_dir="$(cd "$(dirname "$0")" && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/bin"
cat > "$test_dir/bin/alis" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$ALIS_TEST_LOG"
EOF
chmod +x "$test_dir/bin/alis"

PATH="$test_dir/bin:$PATH" ALIS_TEST_LOG="$test_dir/calls" \
  "$hook_dir/sync-skills.sh" <<<'{"source":"startup"}'

attempts=0
while [ ! -s "$test_dir/calls" ]; do
  attempts=$((attempts + 1))
  [ "$attempts" -lt 100 ] || { echo "timed out waiting for alis call" >&2; exit 1; }
  sleep 0.01
done

actual="$(sed -n '1p' "$test_dir/calls")"
expected="skills sync --cache-only"
[ "$actual" = "$expected" ] || {
  echo "catalog sync = '$actual'; want '$expected'" >&2
  exit 1
}

echo "sync-skills hook: catalog-only call verified"
