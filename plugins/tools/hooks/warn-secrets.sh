#!/usr/bin/env bash
# The CLI owns payload parsing, policy and native replies. Older CLIs leave
# optional decisions to the host; check-cli.sh reports the required upgrade.
set -eu
hook_dir=$(cd "$(dirname "$0")" && pwd)
alis hooks run --protocol 1 --harness codex --handler secrets --plugin-root "$hook_dir/.." 2>/dev/null || true
