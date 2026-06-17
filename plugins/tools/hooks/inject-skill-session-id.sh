#!/usr/bin/env bash
# PreToolUse hook: inject the Codex session_id into Alis MCP LoadSkill calls so
# the server can resolve the caller's active Context and prepend an
# <alis-runtime-context> block to the returned skill.
#
# A PreToolUse hook receives the session_id on stdin and may rewrite the
# outgoing tool arguments via hookSpecificOutput.updatedInput. This merges the
# session_id into LoadSkill's arguments (the session_id field on the MCP
# LoadSkillRequest); the model never supplies it. Codex requires
# permissionDecision: "allow" alongside updatedInput.
#
# Reads the hook payload (JSON) on stdin and writes the hook response to stdout.
set -euo pipefail

# jq rewrites the payload. Without it, emit nothing and exit 0 so the tool call
# proceeds unmodified (the skill falls back to its own in-markdown discovery).
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

exec jq -c '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "allow",
    updatedInput: (.tool_input + { session_id: .session_id })
  }
}'
