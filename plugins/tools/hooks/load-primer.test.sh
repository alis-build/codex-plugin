#!/usr/bin/env bash
# Regression test for the load-primer gate: full primer only inside an
# alis.build workspace, digest for CLI-only machines outside a workspace,
# nothing when neither workspace nor CLI is present, ALIS_PRIMER=full|digest|off
# overrides, and $PWD fallback when CODEX_PROJECT_DIR is unset.
set -euo pipefail

hook_dir="$(cd "$(dirname "$0")" && pwd)"
plugin_root="$(cd "$hook_dir/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

workspace="$test_dir/alis.build/acme/build/x/v1"
plain="$test_dir/plain"
mkdir -p "$workspace" "$plain" "$test_dir/bin"
printf '#!/bin/sh\nexit 0\n' > "$test_dir/bin/alis"
chmod +x "$test_dir/bin/alis"

primer_header="# Alis Build — Define, Build, Deploy (DBD)"
digest_header="# Alis Build — DBD refresher"

run_hook() { # $1=cwd $2=PATH prefix $3=extra env assignments (or "")
  env -i HOME="$test_dir" PATH="$2:/usr/bin:/bin" \
    PLUGIN_ROOT="$plugin_root" CODEX_PROJECT_DIR="$1" ${3:-} \
    bash "$hook_dir/load-primer.sh" <<<'{"source":"startup"}'
}

expect() { # $1=name $2=want(full|digest|none) $3=output
  name="$1" want="$2" out="$3"
  case "$want" in
    full) grep -qF "$primer_header" <<< "$out" || { echo "FAIL $name: wanted full primer" >&2; exit 1; } ;;
    digest) grep -qF "$digest_header" <<< "$out" || { echo "FAIL $name: wanted digest" >&2; exit 1; } ;;
    none) [ -z "$out" ] || { echo "FAIL $name: wanted no output, got: $(echo "$out" | head -1)" >&2; exit 1; } ;;
  esac
}

expect "workspace startup" full \
  "$(run_hook "$workspace" "$test_dir/emptybin")"
expect "outside workspace with CLI" digest \
  "$(run_hook "$plain" "$test_dir/bin")"
expect "outside workspace without CLI" none \
  "$(run_hook "$plain" "$test_dir/emptybin")"
expect "ALIS_PRIMER=off in workspace" none \
  "$(run_hook "$workspace" "$test_dir/emptybin" "ALIS_PRIMER=off")"
expect "ALIS_PRIMER=full outside" full \
  "$(run_hook "$plain" "$test_dir/emptybin" "ALIS_PRIMER=full")"
expect "ALIS_PRIMER=digest in workspace" digest \
  "$(run_hook "$workspace" "$test_dir/emptybin" "ALIS_PRIMER=digest")"
expect "PWD fallback in workspace" full \
  "$(cd "$workspace" && env -i HOME="$test_dir" PATH="$test_dir/emptybin:/usr/bin:/bin" \
      PLUGIN_ROOT="$plugin_root" bash "$hook_dir/load-primer.sh" <<<'{"source":"startup"}')"

# The sandbox-recovery bullet must reach both the full primer and the digest:
# without it the agent debugs the network instead of asking for escalation
# when a platform call fails inside the sandbox (ticket 4fd5150f).
sandbox_marker="can't reach alis.build"
grep -qF "$sandbox_marker" <<< "$(run_hook "$workspace" "$test_dir/emptybin")" \
  || { echo "FAIL full primer: missing sandbox recovery bullet" >&2; exit 1; }
grep -qF "$sandbox_marker" <<< "$(run_hook "$plain" "$test_dir/bin")" \
  || { echo "FAIL digest: missing sandbox recovery bullet" >&2; exit 1; }

echo "load-primer hook: gating matrix verified"
