#!/usr/bin/env bash
set -euo pipefail
dir="$(cd "$(dirname "$0")" && pwd)"
temp="$(mktemp -d)"
trap 'rm -rf "$temp"' EXIT
HOME="$temp" PLUGIN_ROOT="$dir/.." bash "$dir/record-plugin-health.sh"
version="$(jq -r .version "$dir/../.codex-plugin/plugin.json")"
jq -e --arg version "$version" '.version == $version and (.root | endswith("hooks/..")) and (.observedAt | length > 0) and (has("permission_mode") | not)' "$temp/.alis/codex-plugin-health.json" >/dev/null
echo 'record-plugin-health: OK'
