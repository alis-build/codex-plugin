#!/usr/bin/env bash
set -euo pipefail

hook_dir="$(cd "$(dirname "$0")" && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/bin"
cat > "$test_dir/bin/alis" <<'EOF'
#!/bin/sh
sleep 0.1
printf '%s\n' "$*" >> "$ALIS_TEST_LOG"
exit "${ALIS_TEST_EXIT:-0}"
EOF
chmod +x "$test_dir/bin/alis"

PATH="$test_dir/bin:$PATH" ALIS_TEST_LOG="$test_dir/calls" \
  "$hook_dir/sync-skills.sh" <<<'{"source":"startup"}'

[ -s "$test_dir/calls" ] || {
  echo "sync-skills returned before alis completed; shell self-detach detected" >&2
  exit 1
}

actual="$(sed -n '1p' "$test_dir/calls")"
expected="skills sync --cache-only"
[ "$actual" = "$expected" ] || {
  echo "catalog sync = '$actual'; want '$expected'" >&2
  exit 1
}

# A failed refresh must remain fail-open.
PATH="$test_dir/bin:$PATH" ALIS_TEST_LOG="$test_dir/calls" ALIS_TEST_EXIT=42 \
  "$hook_dir/sync-skills.sh" <<<'{"source":"startup"}'

# Codex, rather than this shell script, owns background execution. Keep both
# persistent maintenance hooks to real startups so resume/clear/compact cannot
# stack sync jobs or rewrite machine-level rules.
jq -e '
  [
    .hooks.SessionStart[] as $group
    | $group.hooks[]
    | select(
        .command == "${PLUGIN_ROOT}/hooks/ensure-alis-rule.sh" or
        .command == "${PLUGIN_ROOT}/hooks/sync-skills.sh"
      )
    | {
        command,
        matcher: $group.matcher,
        async: (.async // false)
      }
  ] | sort_by(.command) == ([
    {
      command: "${PLUGIN_ROOT}/hooks/ensure-alis-rule.sh",
      matcher: "^startup$",
      async: false
    },
    {
      command: "${PLUGIN_ROOT}/hooks/sync-skills.sh",
      matcher: "^startup$",
      async: true
    }
  ] | sort_by(.command))
' "$hook_dir/hooks.json" >/dev/null || {
  echo "maintenance hooks must be startup-only and sync-skills must use Codex-managed async" >&2
  exit 1
}

echo "sync-skills hook: attached catalog-only call and managed async config verified"
