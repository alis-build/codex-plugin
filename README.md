# Alis Build Codex Plugin

<p align="center">
  <img src="plugins/tools/assets/connectivity.svg" alt="Codex connected to Alis Build" width="760">
</p>

<p align="center">
  <strong>Connect Codex to Alis Build.</strong>
</p>

Use this plugin to let Codex inspect Alis Build landing zones, products, neurons, builds, deploys, and related workspace context.

## What You Get

- A preconfigured Codex MCP server for `https://mcp.alis.build`
- A preconfigured Alis Build OAuth client and scopes for MCP sign-in
- OAuth/OIDC sign-in through `https://identity.alisx.com`
- Alis Build tools available inside Codex after sign-in
- Codex approval prompts before tools perform sensitive actions

## Before You Start

You need:

- Codex CLI or the Codex IDE extension
- An Alis Build account with access to the landing zones and products you want to use
- Network access to `https://mcp.alis.build` and `https://identity.alisx.com`

## Install

Add the Alis plugin marketplace:

```sh
codex plugin marketplace add https://github.com/alis-build/codex-plugin.git --sparse .agents/plugins --sparse plugins/tools
```

Install the Alis Build plugin:

```sh
codex plugin add tools@alis-build
```

## Sign In

Authenticate with Alis Build:

```sh
codex mcp login alis-build
```

In Codex, run:

```text
/mcp
```

You should see `alis-build` listed as an MCP server. The sign-in flow opens `https://identity.alisx.com` in your browser.

## Use It

After sign-in, ask Codex to use Alis Build:

```text
Use Alis Build to list the landing zones I can access.
```

```text
Show recent builds for product os in landing zone alis.
```

```text
Review the latest deploy logs for this neuron and suggest the next action.
```

Codex will ask before running tools that require approval.

## Troubleshooting

If `alis-build` does not appear in `/mcp`, confirm that the plugin install completed successfully:

```sh
codex plugin add tools@alis-build
```

If sign-in fails, confirm that you can reach both `https://mcp.alis.build` and `https://identity.alisx.com`, then run the login command again:

```sh
codex mcp login alis-build
```

If you see `Dynamic client registration not supported`, remove any manually added MCP server with the same name and use the plugin-provided configuration:

```sh
codex mcp remove alis-build
codex mcp login alis-build
```

That error usually means `alis-build` was previously added with `codex mcp add alis-build --url https://mcp.alis.build`, which does not include the Alis Build OAuth client ID.
