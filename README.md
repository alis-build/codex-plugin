# Alis Build Codex Plugin

<p align="center">
  <img src="plugins/tools/assets/connectivity.svg" alt="Codex connected to Alis Build" width="760">
</p>

<p align="center">
  <strong>Connect Codex to Alis Build.</strong>
</p>

Use this plugin to let Codex work with Alis Build organisations, products, neurons, builds, and deploys through the `alis` CLI, with workspace-aware context injected into every session.

## What You Get

- A workspace-gated Define → Build → Deploy primer: the full primer inside an `alis.build` workspace, a compressed digest elsewhere when the `alis` CLI is installed, and zero tokens on unrelated projects
- Quiet, local-first skill discovery: a `discover` skill that fires on platform-shaped work (never on generic coding just because you are inside a workspace), probes the local catalog in ~40ms, and loads the right registry skill; plus a `capture` skill that saves just-completed work as a reusable team skill
- Confidence-gated per-prompt skill suggestions (a `UserPromptSubmit` hook backed by `alis skills suggest`) — a suggestion appears only when the match is distinctive; wake phrases (`alis, …`, `capture this as a skill`) route from any directory
- Catalog metadata refreshed quietly when a new session starts; the plugin never installs or prunes native user skills
- Workspace-aware context injection through Codex hooks
- The `alis` CLI runnable without per-command approval prompts (with destructive commands double-keyed)

## Before You Start

You need:

- Codex CLI or the Codex IDE extension
- The `alis` CLI installed, on your `PATH`, and signed in (`alis login`)
- An Alis Build account with access to the organisations and products you want to use

## Install

Install the Alis Build plugin:

```sh
codex plugin marketplace add https://github.com/alis-build/codex-plugin && codex plugin add tools@alis-build && codex
```

## Use It

Ask Codex to use Alis Build:

```text
find a skill for adding tracing to my service
```

```text
capture this as a skill
```

```text
Use Alis Build to list the organisations I can access.
```

```text
Show recent builds for product os in organisation alis.
```

```text
Review the latest deploy logs for this neuron and suggest the next action.
```

Codex runs these through the `alis` CLI without asking for approval on every command.

## Workflow Skills

This plugin includes Alis Build workflow skills:

- **`discover`** — finds and loads the right Alis Build skill for platform-shaped work. It fires on your own words (Codex routes on the skill's description) when the task touches the platform — proto contracts, neurons, Define/Build/Deploy, Spanner, Pub/Sub, ADK agents — but not on generic coding (Makefiles, ordinary bugs, tests, git) just because you are inside a workspace. It probes the local catalog first (`alis skills suggest --json`, ~40ms, no network), loads a skill only on a distinctive match, and hands execution to it; the registry search (`alis skills search`) is reserved for explicit "find me a skill" asks. No match means silence — it never narrates discovery that found nothing.
- **`capture`** — turns work just completed in the session into a reusable team skill ("capture this as a skill"): dedupe against the registry, register a draft with `alis skills capture`, distill generalized steps, and publish on your approval.
- **`getting-started`** — a guided Alis Build setup and optional quickstart:

```text
Use the Alis Build - Getting Started skill to help me get started on Alis Build.
```

## Workspace Context

This plugin ships Codex hooks that keep sessions grounded in the Alis Build workflow:

- **DBD primer (workspace-gated).** A `SessionStart` hook loads the Define → Build → Deploy
  primer (so Codex frames help around the platform lifecycle), together with the skills
  contract: discovery is native — the `discover` skill fires on your own words when the task
  touches the platform; direct DBD commands (`define it` / `build it` / `deploy it` on a known
  target) run the `alis` CLI with no skill. The full primer loads only when the session's
  working directory is inside an `alis.build` workspace; outside a workspace, a machine with
  the `alis` CLI on `PATH` gets a compressed digest instead, and a machine with neither gets
  nothing — unrelated projects pay zero tokens. Set `ALIS_PRIMER=full|digest|off` to override
  the gate. Codex runs it for `startup`, `resume`, `clear`, and `compact`, so context is restored
  whenever a session is opened or its model context is rebuilt.
- **Per-prompt skill suggestions.** A `UserPromptSubmit` hook pipes each prompt's payload to
  `alis skills suggest --hook --harness codex`, a purely local ~40ms call that prints plain-text
  context or nothing. Wake phrases ("alis, …", "capture this as a skill") yield deterministic
  routing instructions and work from any directory; other prompts get at most one ambient
  one-liner, and only when the match is distinctive (the CLI's confidence gate keys on id/name
  token evidence, so generic Makefile/rename/debug prompts stay silent). Inside an `alis.build`
  workspace the hook runs on every prompt; elsewhere a cheap prefilter skips prompts that
  cannot contain a wake phrase (set `ALIS_SUGGEST_ALWAYS=1` to disable the prefilter). Silent
  on every failure path — a missing or failing `alis` CLI never breaks a prompt.
- **Skills catalog refresh.** On `startup`, a `SessionStart` hook runs
  `alis skills sync --cache-only` through Codex's managed background-hook support. The CLI uses
  its 24-hour cache, and this explicit compatibility flag ensures older CLIs also refresh metadata
  only—native user skills are never installed or pruned. Resume, clear, and compact events do not
  start duplicate refresh jobs.
- **Service context (workspace-aware).** A `SessionStart` hook detects when the session is opened
  inside an Alis Build service folder (`~/alis.build/<org>/build|define/…`) and injects the package id
  plus a pointer to the matching definitions ⇄ implementation counterpart. It runs for `startup`,
  `resume`, `clear`, and `compact`, and is silent outside a workspace.
- **`alis` CLI access.** On `startup`, a `SessionStart` hook ensures Codex can run the `alis` CLI
  without per-command approval prompts. `alis` subcommands need network access and your local session, which Codex's
  sandbox blocks; the only lever that runs a command unrestricted is an execpolicy allow rule, and a
  plugin manifest cannot declare one. So the hook writes a dedicated, version-stamped
  `~/.codex/rules/alis-build.rules` (v4) containing a broad `prefix_rule(pattern=["alis"],
  decision="allow")` (skipped if your own rules already grant it), plus prompt rules for the whole
  `alis blocks|block …` namespace and for invocations whose first argument is `--approve`, `--json`,
  `--help`, `-h`, `--version`, or `-v`. Execpolicy's most-restrictive-wins therefore prompts both
  blocks-first and root-flag-first spellings, including explicit `--yes`/`--approve` uninstall
  attempts. Canonical non-block commands such as `alis build … --json` retain the broad allow.
  The rules take effect from the next session if Codex loads them
  before the hook runs. To remove it, delete that file (and the `["alis"]` entry from
  `~/.codex/rules/default.rules` if you also approved it interactively). The approval-record hook
  independently excludes every `blocks|block uninstall` flag permutation from automatic standing
  grants. Production stays safe
  regardless — the CLI itself refuses to deploy to a production environment
  (exit code 3) until re-run with `--confirm-production`, which the agent is instructed to add only
  after your explicit approval (`alis docs safety`). Codex also evaluates each segment of a chained
  command separately, so `alis define && rm -rf /` cannot ride on the allow.
- **Approval record for the alis CLI.** A `PreToolUse` hook on the shell tool records each clean,
  single `alis …` invocation at `~/.alis/agent-approval.json` (harness `codex`, the session's
  permission mode, session id, and exact command). It is an observer only — execpolicy owns shell
  approval — and lets the alis CLI treat a fresh record from the same `CODEX_THREAD_ID` in
  `acceptEdits`, `dontAsk`, or `bypassPermissions` mode as a standing grant for non-production
  approvals. Destructive block uninstalls never receive that automatic grant, regardless of flag
  order. `default` and `plan` do not grant approval. Production deploys always require
  `--confirm-production` from a human.
- **Production guard.** A second `PreToolUse` hook on the shell tool denies any `alis …`
  command that carries `--confirm-production`, wherever the flag sits, and returns a reason that
  hands the exact command to you to run in your own terminal. The DBD primer already tells the
  agent never to add that flag itself, but the primer arrives through a hook that can silently
  fail (see Troubleshooting), execpolicy prefix rules cannot see a flag that follows a variable
  package id, and with `approvals_reviewer = "auto_review"` an escalation is judged by a model,
  not by you. Codex hooks honour only `allow` and `deny` today (`ask` is parsed but not
  supported), so the guard is a deny: the agent cannot confirm a production rollout on your
  behalf, and the CLI's exit-code-3 gate stays exactly where it was. Ordinary commands pay
  nothing — the hook exits silently unless both `alis` and the flag are present.

Hooks are enabled by default in Codex. If you have disabled them globally, re-enable them by removing
`[features].hooks = false` from `~/.codex/config.toml`.

## Primer sync

`plugins/tools/context/dbd-primer.md` and `plugins/tools/context/dbd-digest.md` are synced
from the canonical primer and digest in the Alis Build Claude Code plugin
(`claude-plugin/plugins/alis-build/context/`). The local differences are harness adaptations
only: the Skills sections name this plugin's `discover` / `capture` skills instead of
Claude's `alis-build:*` skills, and the primer gate reads Codex's hook environment
(`PLUGIN_ROOT`, `CODEX_PROJECT_DIR`). Lifecycle routing lives in `hooks.json`: primer and
service context run for `startup`, `resume`, `clear`, and `compact`, while rule installation
and catalog refresh run only on `startup`. Sync the bodies on each claude-plugin primer release.

## Troubleshooting

If the primer or hooks do not take effect, confirm that the plugin install completed successfully:

```sh
codex plugin add tools@alis-build
```

After updating or reinstalling the plugin, start a new Codex thread. Active threads retain the
versioned plugin paths they originally loaded, while reinstalling may prune that cached version;
continuing an old thread can therefore leave its hooks or skills pointing at missing files.

**Restart the Codex desktop app (and any long-running `codex app-server`) after an upgrade too.**
The app-server resolves plugin paths once, at launch, and new threads inherit them. If the
plugin cache is upgraded while the app is running (for example by a `codex` CLI session that
refreshes the marketplace), the old version directory is pruned and every hook of the running
app — primer, service context, skill suggestions, approval record, production guard — silently
stops working for each new thread, while the skill list still advertises the old paths. The
symptom is a session that starts with no "Alis Build — Define, Build, Deploy" primer block and a
`No such file or directory` error when the agent opens a `discover`/`capture` skill. Hooks exit 0
on every failure by design, so nothing else warns you. Until the app is restarted, treat such a
session as having no Alis Build context at all, and in particular do not rely on it to respect
the production gate.

If `alis` commands fail with an auth error, run `alis login` (or `alis authorise <org>.<product>` for git/package credentials) and retry.
