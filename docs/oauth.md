# OAuth Setup

The Alis Build MCP server uses OAuth/OIDC through:

```text
https://identity.alisx.com
```

## Required Scopes

- `build:read`
- `build:write`
- `ideas:read`
- `ideas:write`

## Redirect URI

Register this exact redirect URI for the OAuth client:

```text
http://localhost:7777/oauth/callback
```

Configure Codex with:

```toml
mcp_oauth_callback_port = 7777
mcp_oauth_callback_url = "http://localhost:7777/oauth/callback"
```

These callback settings are top-level Codex settings, not plugin-level MCP settings. A plugin can provide the MCP server and OAuth metadata, but it cannot force the callback URL used by `codex mcp login` for every installing user.

To make install-and-login work without per-user Codex config, the Alis Identity OAuth client should accept Codex's default native loopback redirect shape:

```text
http://127.0.0.1:<ephemeral-port>/callback/<generated-id>
```

If wildcard redirect URIs are supported, register both loopback hostnames:

```text
http://127.0.0.1:*/callback/*
http://localhost:*/callback/*
```

If the identity provider cannot allow loopback redirects with dynamic ports and paths, use the fixed `localhost:7777` callback and document the required Codex config.

## Login

Run:

```sh
codex mcp login alis-build
```

If scopes are not advertised by the MCP server metadata, run:

```sh
codex mcp login alis-build --scopes build:read,build:write,ideas:read,ideas:write
```

If Codex still opens an authorize URL with a redirect like `http://127.0.0.1:<port>/callback/<id>`, the fixed callback config has not been loaded. For a one-shot login, run:

```sh
codex mcp login alis-build \
  -c mcp_oauth_callback_port=7777 \
  -c 'mcp_oauth_callback_url="http://localhost:7777/oauth/callback"' \
  --scopes build:read,build:write,ideas:read,ideas:write
```

The plugin MCP config includes:

```json
{
  "mcpServers": {
    "alis-build": {
      "oauth_resource": "https://mcp.alis.build/mcp",
      "oauth": {
        "client_id": "cac878c2-ae88-47d4-89dc-3815ff556821",
        "scopes": [
          "build:read",
          "build:write",
          "ideas:read",
          "ideas:write"
        ]
      }
    }
  }
}
```

Codex stores MCP configuration in `config.toml`. The default location is:

```text
~/.codex/config.toml
```

Codex stores OAuth tokens separately from this plugin. Do not commit OAuth tokens or client secrets.
