# Alis Build Codex Plugin

<p align="center">
  <img src="plugins/alis-build/assets/logo.svg" alt="Alis Build logo" width="128" height="128">
</p>

<p align="center">
  <strong>Connect Codex to Alis Build through MCP.</strong>
</p>

Connect Codex to Alis Build so Codex can inspect landing zones, products, neurons, builds, deploys, and related workspace context through the Alis Build MCP server.

This first release is MCP-only. It does not bundle skills, hooks, commands, or UI.

## What You Get

- A preconfigured Codex MCP server for `https://mcp.alis.build/mcp`
- OAuth/OIDC authentication through `https://identity.alisx.com`
- Alis Build tools exposed inside Codex after login
- Read and write access controlled by Alis Build OAuth scopes and Codex tool approvals

## Before You Start

You need:

- Codex CLI or the Codex IDE extension
- Network access to `https://mcp.alis.build`
- Network access to `https://identity.alisx.com`
- An Alis Build account with access to the landing zones and products you want to use
- OAuth access for the scopes below:

```text
build:read
build:write
ideas:read
ideas:write
```

## Install

Add this repository as a Codex plugin marketplace:

```sh
codex plugin marketplace add https://github.com/alis-build/codex-plugin.git --sparse .agents/plugins --sparse plugins/alis-build
```

Install the plugin:

```sh
codex plugin add alis-build@alis
```

## Sign In

Authenticate the Alis Build MCP server:

```sh
codex mcp login alis-build
```

In the Codex TUI, run:

```text
/mcp
```

Expected result:

- `alis-build` is listed as an MCP server.
- Login opens a browser for `https://identity.alisx.com`.
- OAuth consent includes `build:read`, `build:write`, `ideas:read`, and `ideas:write`.

## OAuth Callback Setup

Codex uses a local callback URL during MCP login. If Alis Identity is configured to allow Codex's native loopback redirects, no extra setup is needed.

For the smoothest install, the Alis Identity OAuth client should allow Codex's native redirect shape:

```text
http://127.0.0.1:<ephemeral-port>/callback/<generated-id>
```

If wildcard redirect URIs are supported, allow both loopback hostnames:

```text
http://127.0.0.1:*/callback/*
http://localhost:*/callback/*
```

If Alis Identity requires an exact redirect URI, register:

```text
http://localhost:7777/oauth/callback
```

Then add these top-level settings to your Codex `config.toml`, usually at `~/.codex/config.toml`:

```toml
mcp_oauth_callback_port = 7777
mcp_oauth_callback_url = "http://localhost:7777/oauth/callback"
```

You can also pass the callback settings for a single login:

```sh
codex mcp login alis-build \
  -c mcp_oauth_callback_port=7777 \
  -c 'mcp_oauth_callback_url="http://localhost:7777/oauth/callback"' \
  --scopes build:read,build:write,ideas:read,ideas:write
```

See [docs/oauth.md](docs/oauth.md) for more detail.

## Use It

After login, ask Codex to use Alis Build. For example:

```text
List the landing zones I can access.
```

```text
Show recent builds for product os in landing zone alis.
```

```text
Review the latest deploy logs for this neuron and suggest the next action.
```

Codex will ask before running tools that require approval. This plugin sets Alis Build tools to `prompt` approval mode by default.

## Local Development

Validate JSON files:

```sh
python3 -m json.tool plugins/alis-build/.codex-plugin/plugin.json
python3 -m json.tool plugins/alis-build/.mcp.json
python3 -m json.tool .agents/plugins/marketplace.json
```

Install from a local checkout:

```sh
codex plugin marketplace add /path/to/codex-plugin
codex plugin add alis-build@alis
```

## Repository Layout

```text
.
├── .agents
│   └── plugins
│       └── marketplace.json
├── LICENSE
├── README.md
├── docs
│   ├── oauth.md
│   └── publishing.md
└── plugins
    └── alis-build
        ├── .codex-plugin
        │   └── plugin.json
        ├── .mcp.json
        └── assets
            └── logo.svg
```

## Publishing

See [docs/publishing.md](docs/publishing.md) for release steps.

## Security Notes

The plugin includes a public OAuth client ID because Alis Build does not support dynamic client registration. Do not commit OAuth client secrets, user tokens, or local Codex credentials to this repository.

The plugin does not filter or exclude MCP tools. Access is controlled by OAuth scopes, Alis Build permissions, and Codex tool approval prompts.
