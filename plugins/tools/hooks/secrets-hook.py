#!/usr/bin/env python3
"""A warning when a tool call carries secret-looking values.

The call is already in the transcript by the time PostToolUse fires, so
nothing here redacts: the person hears which kinds landed and that they need
rotating, and the model is told not to repeat them. The pattern table is the
one in hooks/mod/secrets.ts, in the same order."""
import hashlib
import json
import re
import sys
from pathlib import Path

# Characters scanned per tool call; a Bash result is cut long before this.
MAX_SCAN = 1_000_000

PATTERNS = [
    ("stripe", re.compile(r"\bsk_(?:live|test)_[A-Za-z0-9]{16,}")),
    ("github", re.compile(r"\b(?:gh[oprsu]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{22,})")),
    ("npm", re.compile(r"\bnpm_[A-Za-z0-9]{30,}")),
    ("pypi", re.compile(r"\bpypi-[A-Za-z0-9_-]{50,}")),
    ("linear", re.compile(r"\blin_api_[A-Za-z0-9]{20,}")),
    ("sendgrid", re.compile(r"\bSG\.[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{16,}")),
    ("postgres", re.compile(r"\bpostgres(?:ql)?://[^:/\s@]+:[^@\s]+@")),
    ("aws", re.compile(r"\bAKIA[0-9A-Z]{16}\b")),
    ("google", re.compile(r"\bAIza[0-9A-Za-z_-]{35}\b")),
    ("slack", re.compile(r"\bxox[abpr]-[0-9A-Za-z-]{10,}")),
    ("privateKey", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")),
    # NAME=value lines and "NAME": "value" pairs whose UPPER_SNAKE name says
    # secret. A masked value (••••), a [REDACTED:kind] marker and a names-only
    # listing ({"name": "X_SECRET", "set": true}) have no value after the name;
    # lowercase and camelCase names are code, and *_NAME/_ID/_PATH/_URL/_FILE/
    # _REF name a secret rather than hold one.
    ("assignment", re.compile(r"\b([A-Z0-9_]*(?:SECRET|TOKEN|PASSWORD|PASSWD|API_?KEY)[A-Z0-9_]*)[\"']?\s*[=:]\s*[\"']?[A-Za-z0-9_\-./+=]{16,}")),
]
REFERENCE_NAME = re.compile(r"_(?:NAME|ID|PATH|URL|FILE|REF)$")

# What `alis environment variables|vars|refresh` prints once values are
# revealed: JSON name/value pairs, `NAME   value` table rows, and .env lines.
# Only read for that command: any other output has these shapes innocently.
ENV_COMMAND = re.compile(r"^\s*alis\s+(?:--\S+(?:\s+[^-\s]\S*)?\s+)*(?:environment|environments|envs?)\s+(?:variables|vars|refresh)\b")
REVEALED = [
    re.compile(r"\"name\"\s*:\s*\"[^\"]+\"\s*,\s*\"value\"\s*:\s*\"[^\"]+\""),
    re.compile(r"^[ \t]*[A-Z][A-Z0-9_]*[ \t]{2,}(?!•|\(empty\)|VALUE\b)\S.*$", re.MULTILINE),
    re.compile(r"^[ \t]*(?:export[ \t]+)?[A-Z][A-Z0-9_]*=\S.*$", re.MULTILINE),
]
ORDER = ["revealed"] + [kind for kind, _ in PATTERNS]


def spans_of(text, revealed):
    """(kind, start, end, value) per secret-looking value; an earlier pattern owns any overlap."""
    spans = []

    def add(kind, pattern, keep=lambda m: True):
        for m in pattern.finditer(text):
            start, end = m.span()
            if keep(m) and not any(start < s[2] and end > s[1] for s in spans):
                spans.append((kind, start, end, m.group(0)))

    if revealed:
        for pattern in REVEALED: add("revealed", pattern)
    for kind, pattern in PATTERNS:
        add(kind, pattern, (lambda m: not REFERENCE_NAME.search(m.group(1))) if kind == "assignment" else (lambda m: True))
    return spans


def kinds_of(spans):
    counts = {}
    for kind, _, _, _ in spans: counts[kind] = counts.get(kind, 0) + 1
    return [(kind, counts[kind]) for kind in ORDER if kind in counts]


def secret_kinds_of(text, revealed=False):
    """The kinds of secret-looking values in text, in table order, as (kind, count)."""
    return kinds_of(spans_of(text[:MAX_SCAN], revealed))


def text_of(response):
    """The text a tool result put in the transcript: Bash streams, a Read's content, else the whole JSON."""
    if isinstance(response, str): return response
    if isinstance(response, list): return json.dumps(response)
    if not isinstance(response, dict): return ""
    if isinstance(response.get("stdout"), str) or isinstance(response.get("stderr"), str):
        return f"{response.get('stdout') or ''}\n{response.get('stderr') or ''}"
    content = response["file"].get("content") if isinstance(response.get("file"), dict) else None
    if isinstance(content, str): return content
    return json.dumps(response)


def input_text_of(tool_input):
    """The text a tool call put in the transcript on its way in: every string argument."""
    if not isinstance(tool_input, dict): return ""
    return "\n".join(v for v in tool_input.values() if isinstance(v, str))


def listed(kinds):
    return ", ".join(f"{kind} ×{count}" if count > 1 else kind for kind, count in kinds)


def warning_of(kinds):
    total = sum(count for _, count in kinds)
    return (f"alis: this tool call holds {total} value{'' if total == 1 else 's'} that look like secrets ({listed(kinds)}). "
            "They are now in the session transcript. Do not repeat, quote, summarise or store them; refer to each by its name only. "
            "Tell the person these credentials need to be rotated.")


def toast_of(tool, kinds):
    return f"alis: secret-looking values in the last {tool} call ({listed(kinds)}). They are in the transcript now; rotate them."


def seen_file(payload):
    """Hashes of the values already warned about this session; never the values. None without a session."""
    sid = payload.get("session_id")
    if not isinstance(sid, str) or not re.fullmatch(r"[A-Za-z0-9_-]{1,128}", sid): return None
    return Path.home() / ".alis/claude-secrets-seen" / sid


def answer(payload):
    tool_input = payload.get("tool_input")
    command = tool_input.get("command") if isinstance(tool_input, dict) else None
    revealed = isinstance(command, str) and bool(ENV_COMMAND.match(command))
    text = f"{text_of(payload.get('tool_response'))}\n{input_text_of(tool_input)}"[:MAX_SCAN]
    spans = spans_of(text, revealed)
    if not spans: return {}
    store = seen_file(payload)
    seen = set()
    if store is not None:
        try: seen = set(store.read_text().split())
        except OSError: pass
    hashes = {s[3]: hashlib.sha256(s[3].encode()).hexdigest()[:24] for s in spans}
    fresh = [s for s in spans if hashes[s[3]] not in seen]
    if not fresh: return {}
    if store is not None:
        try:
            store.parent.mkdir(parents=True, exist_ok=True)
            with store.open("a") as f: f.write("".join(hashes[s[3]] + "\n" for s in fresh))
            store.chmod(0o600)
        except OSError: pass
    kinds = kinds_of(fresh)
    tool = payload.get("tool_name") if isinstance(payload.get("tool_name"), str) else "tool"
    return {"systemMessage": toast_of(tool, kinds),
            "hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": warning_of(kinds)}}


def main():
    try:
        payload = json.load(sys.stdin)
        if not isinstance(payload, dict): return
        # Function-hooks handshake: the module serves this job when it says so.
        if "secrets" in str(payload.get("alis_module", "")).split(): return
        response = answer(payload)
        if response: print(json.dumps(response))
    except (ValueError, TypeError, OSError):
        return


if __name__ == "__main__": main()
