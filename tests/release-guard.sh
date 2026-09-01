#!/bin/bash
# Release guard: invariants that must hold before a version of the plugin is
# published. Run it before tagging; tag builds run with RELEASE_GUARD_STRICT=1
# so a release can never ship what a branch merely warns about.
set -eu

repo="$(cd "$(dirname "$0")/.." && pwd)"
fail=0

# 1. No unsubstituted release placeholders may ship (the Claude plugin's
#    v0.19.0 was published with literal __…__ markers in a command, breaking
#    it for every user).
if grep -rn '__[A-Z_]*__' "$repo/plugins" >/dev/null 2>&1; then
  if [ -n "${RELEASE_GUARD_STRICT:-}" ]; then
    echo "FAIL: unsubstituted placeholder present in shipped plugin content:" >&2
    grep -rn '__[A-Z_]*__' "$repo/plugins" >&2
    fail=1
  else
    echo "WARN: placeholder present in plugins/ — a tagged release will fail this guard" >&2
  fi
fi

# 2. plugin.json and marketplace.json versions must agree — the marketplace
#    entry is what installers resolve.
pv="$(jq -r .version "$repo/plugins/tools/.codex-plugin/plugin.json")"
mv_="$(jq -r '.plugins[0].version' "$repo/.agents/plugins/marketplace.json")"
if [ "$pv" != "$mv_" ]; then
  echo "FAIL: version skew plugin.json=$pv marketplace.json=$mv_" >&2
  fail=1
fi

# 3. Hook scripts must parse and hooks.json must be valid JSON.
for f in "$repo"/plugins/tools/hooks/*.sh; do
  bash -n "$f" || { echo "FAIL: $f does not parse" >&2; fail=1; }
done
jq -e . "$repo/plugins/tools/hooks/hooks.json" >/dev/null || {
  echo "FAIL: hooks.json is not valid JSON" >&2
  fail=1
}

# 4. Every hook regression must pass. Syntax-only checks do not catch manifest
#    scoping, lifecycle, approval, or fail-open behavior regressions.
for f in "$repo"/plugins/tools/hooks/*.test.sh; do
  [ -f "$f" ] || continue
  if ! bash "$f"; then
    echo "FAIL: hook regression failed: $f" >&2
    fail=1
  fi
done

if [ "$fail" -eq 0 ]; then
  echo "release guard: OK (version $pv)"
fi
exit "$fail"
