#!/usr/bin/env bash
# Regression test for workspace context mapping, including sessions opened
# below a define service's version root.
set -euo pipefail

hook_dir="$(cd "$(dirname "$0")" && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

workspace="$test_dir/alis.build/acme"
define_root="$workspace/define/acme/payments/ledger/v1"
build_root="$workspace/build/payments/ledger/v1"
define_nested="$define_root/docs/guides"
build_nested="$build_root/internal/server"
mkdir -p "$define_nested" "$build_nested"
touch "$define_root/ledger.proto" "$define_root/reporting.proto"

run_hook() {
  CODEX_PROJECT_DIR="$1" bash "$hook_dir/inject-service-context.sh" <<<'{"source":"startup"}'
}

expect_contains() { # $1=name $2=output $3=needle
  local name="$1" out="$2" needle="$3"
  case "$out" in
    *"$needle"*) ;;
    *) echo "FAIL $name: missing '$needle'" >&2; exit 1 ;;
  esac
}

build_out="$(run_hook "$build_nested")"
expect_contains "nested build package" "$build_out" "Package id:  acme.payments.ledger.v1"
expect_contains "nested build counterpart" "$build_out" "$define_root"
expect_contains "nested build protos" "$build_out" "Proto files: ledger.proto, reporting.proto"

define_out="$(run_hook "$define_nested")"
expect_contains "nested define package" "$define_out" "Package id:  acme.payments.ledger.v1"
expect_contains "nested define counterpart" "$define_out" "$build_root"
expect_contains "nested define root protos" "$define_out" "Proto files: ledger.proto, reporting.proto"

plain_out="$(run_hook "$test_dir/plain")"
[ -z "$plain_out" ] || {
  echo "FAIL unrelated directory: wanted no output" >&2
  exit 1
}

# Both context-producing hooks must be re-run whenever Codex rebuilds the
# model's session context.
jq -e '
  any(.hooks.SessionStart[];
    .matcher == "^(startup|resume|clear|compact)$" and
    ([.hooks[].command] | sort) == ([
      "${PLUGIN_ROOT}/hooks/inject-service-context.sh",
      "${PLUGIN_ROOT}/hooks/load-primer.sh"
    ] | sort)
  )
' "$hook_dir/hooks.json" >/dev/null || {
  echo "primer and service context must cover every SessionStart source" >&2
  exit 1
}

echo "inject-service-context hook: nested workspace mapping and lifecycle config verified"
