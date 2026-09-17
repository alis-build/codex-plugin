---
name: frontend-preview
description: >-
  Show an Alis service's web frontend in a real browser beside the
  conversation (terminal-browser) and drive it: open the page, click through
  it, read its console and errors, screenshot it, check a UI change. Use when
  the user asks to see, open, preview, check or test the app, a page, a form
  or a UI change of a service with a web frontend, or sends an element from
  the browser. NOT for build or deploy logs, operation status, the Alis
  console, or anything the alis CLI answers directly.
---

# Frontend preview: see and drive a service's page

terminal-browser draws a real Chromium in a terminal pane. You open it beside
the conversation, the user watches it, and you drive it.

Run `terminal-browser` commands with escalated permissions, as `alis` already
runs: the sandbox blocks the calls terminal-browser makes to find the terminal
pane this Codex session runs in.

## 1. Open it

1. The dev server must answer. `alis run` stays in the foreground, so if it
   is not running, ask the user to start it in another pane of the service
   folder (inside herdr, a split beside this one) and wait until it listens.
2. Run `alis preview --json` in the service folder, or
   `alis --cwd <service folder> preview --json` from elsewhere. It opens the
   service's `.claude/launch.json` port, else the Makefile's `APP_URL`, else a
   Vite app's configured port, else `localhost:8080`. Pass `--port <n>` or `--url <address>` when you know better
   (a Vite server on 5173, a route such as `/checkout`).
3. Dev server on a workstation, agent on this laptop: run
   `alis preview --ssh alis-<org>-<id> --port <n> --json`. The browser stays
   here and its traffic goes through the workstation, so `localhost` is the
   workstation's. `alis workstation list --json` gives the id.

Read the result:

- `opened: true`: the page is beside the conversation. Go to step 2.
- `workstation_url`: this machine is a workstation, whose browser terminal
  cannot draw the browser. Give the user that address and the `hint`. Do not retry.
- `guessed: true`: no frontend or port was found, so the page may not answer.
  Tell the user which address you tried.
- `TERMINAL_BROWSER_NOT_FOUND`: ask the user before installing (the envelope's
  `agent` field has the command). Meanwhile give them the address.
- `PREVIEW_FAILED`: usually a terminal that cannot draw kitty graphics or
  cannot split (iTerm2, a workstation's browser terminal). Suggest Ghostty,
  kitty, WezTerm, tmux or herdr, and give the user the address.

## 2. Drive it

Use `terminal-browser action -- <command>`. The `terminal-browser` skill has
the full command reference.

- `terminal-browser action -- snapshot -i` lists the interactive elements as
  `@e1`, `@e2` refs. Snapshot again after every navigation; refs belong to one page.
- `click @e3`, `fill @e5 "text"`, `press Enter`, `open <url>`, `reload`.
- `console`, `errors` and `network requests` show what went wrong.
- `screenshot --annotate <path>` when layout matters; then read the image.
- Always finish with `terminal-browser action done`, which clears the
  "agent is driving" glow the user sees.

## 3. The user points at something

The user can select an element in the browser and send it to you (ctrl+g, or
right-click and "send to agent"). It arrives as a message starting with `> `
that describes the element, with its source file for React dev builds. Treat
it as the thing to change: find it in the code, change it, then reload the
page and check the result.

Inside herdr the user can also press `prefix+f` to open the same preview
beside any pane.

## Not for

Build or deploy logs, operation status, the Alis console, or anything the
`alis` CLI answers (`alis logs`, `alis operations`, `alis context view`).
