#!/usr/bin/env bash
# Warns when a tool call carries secret-looking values; never redacts.
# Runs on every tool result, so Python only starts when the payload holds a
# trigger of some pattern in secrets-hook.py (or an alis environment command,
# whose revealed rows have no trigger of their own).
set -eu
command -v python3 >/dev/null 2>&1 || exit 0
payload=$(cat 2>/dev/null) || exit 0
printf '%s' "$payload" | grep -qiE 'sk_(live|test)_|gh[oprsu]_|github_pat_|npm_|pypi-|lin_api_|SG\.|://|AKIA|AIza|xox[abpr]-|PRIVATE KEY|SECRET|TOKEN|PASSW|API_?KEY|alis (--\S+ )*(environment|environments|envs?) ' || exit 0
printf '%s' "$payload" | exec python3 -B "$(dirname "$0")/secrets-hook.py"
