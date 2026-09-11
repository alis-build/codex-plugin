#!/usr/bin/env bash
# Local diagnostic breadcrumb only. No approval state or credentials.
set -u
command -v jq >/dev/null 2>&1 || exit 0
[ -n "${PLUGIN_ROOT:-}" ] && [ -n "${HOME:-}" ] || exit 0
version="$(jq -r '.version // empty' "$PLUGIN_ROOT/.codex-plugin/plugin.json" 2>/dev/null)" || exit 0
target="$HOME/.alis"
mkdir -p "$target" 2>/dev/null || exit 0
temp="$(mktemp "$target/.codex-plugin-health.XXXXXX")" || exit 0
trap 'rm -f "$temp"' EXIT
chmod 600 "$temp"
jq -nc --arg root "$PLUGIN_ROOT" --arg version "$version" --arg observedAt "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" '{root:$root,version:$version,observedAt:$observedAt}' > "$temp" || exit 0
mv "$temp" "$target/codex-plugin-health.json" 2>/dev/null || true
