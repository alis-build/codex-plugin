#!/usr/bin/env bash
# UserPromptSubmit hook: when the user addresses Alis or says "build it" / "fix
# it", inject the Define->Build->Deploy primer and the trigger-routing contract
# into the session context.
#
# Why this exists: the routing rules ("alis" / "build it" / "fix it" ->
# SearchSkills first, don't edit code) live in the Alis MCP server's
# `instructions` field. Claude Code injects MCP server instructions into the
# model context, so it routes correctly; Codex does not surface them to the
# model, so the rule never reaches it and Codex starts editing code instead of
# routing. This hook restores the contract for Codex, independent of the MCP
# server, and is NOT gated on an ~/alis.build workspace.
#
# The DBD primer used to be injected on every SessionStart inside a workspace;
# it is now gated on the same trigger words so context is only added when the
# user actually invokes Alis.
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
# "build it" / "fix it" routers.
build_fix='(^|[^[:alnum:]])(build|fix) it([^[:alnum:]]|$)'

if printf '%s' "$lc" | grep -Eq "$alis_vocative" || printf '%s' "$lc" | grep -Eq "$build_fix"; then
  # DBD framing first (the mental model), then the actionable routing contract.
  primer="${PLUGIN_ROOT:-}/context/dbd-primer.md"
  [ -f "$primer" ] && cat "$primer"

  cat <<'EOF'
<alis-routing>
The user addressed Alis or said "build it" / "fix it". Treat this as a ROUTER
trigger, not a direct task. Before inspecting, writing, or editing any code:

1. Determine what they want to build or fix from the prompt, open files, visible
   errors, and existing landing zone / product / neuron context. If the intent
   is genuinely ambiguous, ask ONE concise question: "What exactly should Alis
   build or fix?"
2. Call the Alis Build MCP `SearchSkills` tool FIRST, using the intended outcome
   as the query (not the literal words "build it"). If it returns nothing, fall
   back to `ListSkills`.
3. Present the matching skills (id, what each does, when to choose it) and ask
   the user which to use.
4. Only after the user picks a skill, call `LoadSkill` and follow that skill's
   workflow — the loaded skill owns execution.

This router step must NOT itself inspect, write, or edit code, run
Define / Build / Deploy, or make commits. If no skill fits, say so and offer
`RequestSkill`.
</alis-routing>
EOF
fi
