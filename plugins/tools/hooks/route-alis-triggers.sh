#!/usr/bin/env bash
# UserPromptSubmit hook: keep the Alis Build routing contract in front of the
# model once the user has engaged Alis, and load the Define->Build->Deploy primer
# on the engaging turn.
#
# Why this exists: the routing rules (build/fix -> SearchSkills first, don't edit
# code; "spec it" -> SpecIt directly) live in the Alis MCP server's
# `instructions` field. Claude Code injects MCP server instructions into the
# model context as a standing instruction; Codex does not surface them to the
# model at all. A UserPromptSubmit hook is the only channel, but it injects
# per-turn, not as a standing instruction — so a contract injected once on
# "alis, ..." goes stale and later build/fix requests (often phrased without any
# trigger word, e.g. "could you help adding tracing?") are treated as plain
# coding tasks. This hook therefore makes the contract "sticky":
#
#   * vocative "alis" (e.g. "alis, ...", "ask alis to ...") -> inject the DBD
#     primer AND the full routing contract, and mark this session as
#     Alis-engaged.
#   * any later turn in an Alis-engaged session -> inject a terse one-block
#     reminder only (the full contract was already provided on the engaging
#     turn), so the router stays live without repeating the whole block or the
#     primer every turn.
#   * sessions where the user never addressed Alis -> inject nothing.
#
# The routing reminder is self-scoping (it only activates the router for
# build/fix-shaped Alis Build requests), so re-injecting it every turn does not
# hijack unrelated questions. Not gated on an ~/alis.build workspace.
#
# Whatever this script prints to stdout is added to Codex's context. The prompt
# and session_id are read from the hook payload (JSON on stdin). Codex sets
# PLUGIN_ROOT for plugin-bundled hooks.
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

# Pure acknowledgements / pleasantries. A follow-up whose WHOLE text is one of
# these needs no routing context, so the sticky reminder is suppressed for it.
# Anything more than a bare acknowledgement still gets the reminder, so real
# (even obliquely phrased) requests are never missed.
trivial_ack='^((thanks?|thank you|thanks a lot|thx|ty|tysm|ok|okay|k|kk|cool|nice|great|perfect|awesome|excellent|got it|gotcha|makes sense|sure|yep|yeah|yes|y|nope|no|n|sounds good|sg|will do|done|cheers|ta|np)[[:space:]!.,]*)+$'

# Per-session marker so the routing contract stays sticky after the first "alis".
session_id="$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null || true)"
marker=""
if [ -n "$session_id" ]; then
  safe="$(printf '%s' "$session_id" | tr -cd 'A-Za-z0-9._-')"
  [ -n "$safe" ] && marker="${TMPDIR:-/tmp}/alis-routing/${safe}"
fi

emit_primer=false
if printf '%s' "$lc" | grep -Eq "$alis_vocative"; then
  # Engaging turn: full primer + full routing, and remember this session.
  emit_primer=true
  if [ -n "$marker" ]; then
    mkdir -p "$(dirname "$marker")" 2>/dev/null || true
    : > "$marker" 2>/dev/null || true
  fi
elif [ -n "$marker" ] && [ -f "$marker" ]; then
  # Follow-up turn in an Alis-engaged session: terse reminder only.
  emit_primer=false
else
  # Alis never engaged this session: inject nothing.
  exit 0
fi

if $emit_primer; then
  # DBD framing first (the mental model), then the full routing contract.
  primer="${PLUGIN_ROOT:-}/context/dbd-primer.md"
  [ -f "$primer" ] && cat "$primer"
  cat <<'EOF'

<alis-routing>
Alis Build routing contract — the user has engaged Alis this session. Keep this
in mind for this and the following turns:

- "build it" / "fix it", or any request to build, fix, add, or change something
  on the Alis Build platform — including naturally phrased asks like "could you
  help add X to my server?" — → treat as a ROUTER, not a direct task. Work out
  the intended outcome (ask ONE concise question only if it is genuinely
  ambiguous), then call the Alis Build MCP `SearchSkills` tool FIRST with that
  outcome as the query (fall back to `ListSkills` if it returns nothing). Present
  the matching skills (id, what each does, when to choose it), ask which to use,
  and only then call `LoadSkill` and follow that skill's workflow — the loaded
  skill owns execution. Do NOT inspect, write, or edit code, run
  Define / Build / Deploy, or make commits before a skill is loaded. If no skill
  fits, say so and offer `RequestSkill`.

- "spec it" / "spec it up", or a request to turn the current session into a build
  specification → call the `SpecIt` tool DIRECTLY. Do NOT route this through
  SearchSkills. It needs no arguments (session context is resolved server-side);
  pass `build_spec` only when the user names an existing one to append to. Report
  the returned BuildSpec back to the user.
</alis-routing>
EOF
else
  # Follow-up in an engaged session. Skip pure acknowledgements/pleasantries
  # ("thanks", "ok", ...) — they need no routing context. Otherwise emit a terse
  # reminder (the full contract was given on the engaging turn).
  trimmed="$(printf '%s' "$lc" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  printf '%s' "$trimmed" | grep -Eq "$trivial_ack" && exit 0
  cat <<'EOF'
<alis-routing>
Alis Build router active (full contract was provided earlier this session). Any
request to build, fix, add, or change something on the Alis Build platform →
call `SearchSkills` FIRST and do NOT inspect or edit code, run
Define / Build / Deploy, or commit before a skill is loaded. "spec it" → call
`SpecIt` directly.
</alis-routing>
EOF
fi
