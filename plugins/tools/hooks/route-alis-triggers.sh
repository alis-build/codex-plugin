#!/usr/bin/env bash
# UserPromptSubmit hook: when the user addresses Alis (a vocative "alis, ..."),
# inject the Define->Build->Deploy primer and the Alis Build routing contract
# into the session context.
#
# Why this exists: the routing rules (build/fix -> SearchSkills first, don't edit
# code; "spec it" -> SpecIt directly) live in the Alis MCP server's
# `instructions` field. Claude Code injects MCP server instructions into the
# model context, so it routes correctly; Codex does not surface them to the
# model, so the rule never reaches it and Codex starts editing code instead of
# routing. This hook restores the contract for Codex, independent of the MCP
# server, and is NOT gated on an ~/alis.build workspace.
#
# Trigger: only a vocative "alis" (e.g. "alis, ...", "ask alis to ..."). Bare
# "build it" / "fix it" / "spec it" deliberately do NOT re-trigger injection —
# the contract injected on the first "alis, ..." already explains how to handle
# them on this and the following turns, so re-injecting would just repeat the
# primer.
#
# Whatever this script prints to stdout is added to Codex's context. The user's
# prompt is read from the `prompt` field of the hook payload (JSON on stdin).
# Codex sets PLUGIN_ROOT for plugin-bundled hooks.
set -euo pipefail

# Without jq we cannot parse the prompt; emit nothing and exit 0 so the prompt
# proceeds unmodified (matches the graceful degradation of the other hooks).
command -v jq >/dev/null 2>&1 || exit 0

payload="$(cat)"
prompt="$(printf '%s' "$payload" | jq -r '.prompt // empty' 2>/dev/null || true)"
[ -n "$prompt" ] || exit 0

# Lowercase for case-insensitive matching.
lc="$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]')"

# Vocative "Alis" (addressing the agent), e.g. "alis,", "alis:", "hey alis",
# "ask alis", "alis please/could/can/help ...". Deliberately does NOT match bare
# platform mentions like "Use Alis Build to list landing zones".
alis_vocative='(^|[^[:alnum:]])alis[[:space:]]*[,:]|(^|[^[:alnum:]])(hey|hi|ask)[[:space:]]+alis([^[:alnum:]]|$)|(^|[^[:alnum:]])alis[[:space:]]+(please|pls|could|can|would|will|help)([^[:alnum:]]|$)'

printf '%s' "$lc" | grep -Eq "$alis_vocative" || exit 0

# DBD framing first (the mental model), then the actionable routing contract.
primer="${PLUGIN_ROOT:-}/context/dbd-primer.md"
[ -f "$primer" ] && cat "$primer"

cat <<'EOF'
<alis-routing>
The user addressed Alis. Keep this routing contract in mind for this and the
following turns:

- "build it" / "fix it", or any request to build or fix something on the Alis
  Build platform without naming a specific workflow → treat as a ROUTER, not a
  direct task. Work out the intended outcome (ask ONE concise question only if
  it is genuinely ambiguous), then call the Alis Build MCP `SearchSkills` tool
  FIRST with that outcome as the query (fall back to `ListSkills` if it returns
  nothing). Present the matching skills (id, what each does, when to choose it),
  ask which to use, and only then call `LoadSkill` and follow that skill's
  workflow — the loaded skill owns execution. Do NOT inspect, write, or edit
  code, run Define / Build / Deploy, or make commits from this router step. If
  no skill fits, say so and offer `RequestSkill`.

- "spec it" / "spec it up", or a request to turn the current session into a build
  specification → call the `SpecIt` tool DIRECTLY. Do NOT route this through
  SearchSkills. It needs no arguments (session context is resolved server-side);
  pass `build_spec` only when the user names an existing one to append to. Report
  the returned BuildSpec back to the user.
</alis-routing>
EOF
