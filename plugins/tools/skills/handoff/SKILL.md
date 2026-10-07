---
name: handoff
description: Continue the current codex CLI session on an enrolled Alis workstation in herdr. Use when the user wants to hand off work or close their laptop while it continues remotely.
---

Use the Alis coordinator; never copy agent homes, kill processes, invent session IDs,
or launch a second continuation yourself. This skill applies to the native CLI;
IDE and desktop app sessions need a verified CLI registration.

1. Use the current session ID from hook context (or the agent's session environment).
   Before asking the user anything, run
   `alis workstation handoff check --agent codex --mode summary --session <id> --to <alias> --json`
   (leave out `--to` to see `workstation.eligible`; if several qualify, ask which of
   their existing workstations to use). It starts nothing. Read `ready`, `continuity`,
   `workstation`, `issues`, `error` and `fallback`.
2. If `ready` is false, do not run the handoff. Explain `error.message` in plain words
   and follow `error.agent`. `HANDOFF_SESSION_NOT_REGISTERED` is usual in the Codex
   desktop app when the Alis plugin's hooks have not run in this thread: keep the
   workstation the user chose and offer two ways forward: (a) `fallback` (`--detached`),
   a new conversation on that workstation from this folder while this thread stays open
   and is not copied; or (b) connect this app to handoff first: run `codex` in a terminal
   in this folder, open `/hooks`, trust the Alis Build hooks (the approval is shared with
   the desktop app), start a new thread and ask again. Never show state file names, never
   invent a session id, never create or switch workstations on the user's behalf.
3. Native cross-machine resume for codex is not enabled in this release. Tell the user,
   in both halves, that the handoff starts a **new conversation** with continuation
   context on their **existing workstation `<alias>`** (no new workstation), and obtain
   their choice before proceeding. Never silently downgrade to a summary.
4. After that choice, write a short continuation note with the task, constraints,
   completed external actions, exact active Alis operation IDs, and the next step.
   Run `alis workstation handoff --agent codex --mode summary --session <id>
   --to <alias> --instruction '<note>' --json` (or the `fallback` command with the
   note) as one standalone invocation with literal shell quoting. Do not wait for
   remote operations to finish; stop only their local watchers once the operation IDs
   and any pending results are saved.
5. End this turn after the coordinator returns. It waits for a recoverable
   boundary and opens an independent progress window. Polling from this source
   turn prevents the boundary. Keep the laptop open until `safe_to_close: true`.
   After a detached start, tell the user to stop working in this thread once
   `safe_to_close` is true, because it is not copied.

Use `alis workstation handoff status <id> --watch --json` from another terminal.
Use `alis workstation handoff open <id>` to open the continuation in herdr.
Spaces use `alis.os`, tabs `cli.v1`, with one pane per continuation. Paired build
and Define worktrees isolate simultaneous handoffs; local files stay intact.
Normal destination trust and permission prompts still apply. Unknown background
work blocks handoff rather than being abandoned. `cancel <id>` releases the source
claim only once any launched remote continuation has acknowledged cancellation.
Uncertain remote status never permits starting a second copy locally.
