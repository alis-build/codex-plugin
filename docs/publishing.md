# Publishing

Repository:

```text
https://github.com/alis-build/codex-plugin
```

## Preflight

Validate JSON:

```sh
python3 -m json.tool plugins/alis-build/.codex-plugin/plugin.json
python3 -m json.tool plugins/alis-build/.mcp.json
python3 -m json.tool .agents/plugins/marketplace.json
```

Confirm the OAuth redirect URI is registered for the Alis Build OAuth client:

```text
http://localhost:7777/oauth/callback
```

Confirm MCP login from a clean Codex profile:

```sh
codex mcp login alis-build
```

If scopes are not advertised by the MCP server metadata:

```sh
codex mcp login alis-build --scopes build:read,build:write,ideas:read,ideas:write
```

## Marketplace

This repository includes a marketplace file:

```text
.agents/plugins/marketplace.json
```

The marketplace entry references the plugin package inside this marketplace repo:

```json
{
  "source": {
    "source": "local",
    "path": "./plugins/alis-build"
  }
}
```

Users can add the marketplace with:

```sh
codex plugin marketplace add https://github.com/alis-build/codex-plugin.git --sparse .agents/plugins --sparse plugins/alis-build
```

Then install the Alis Build plugin:

```sh
codex plugin add alis-build@alis
```

## Release

1. Validate JSON.
2. Verify OAuth login.
3. Tag the release:

   ```sh
   git tag v0.1.0
   ```

4. Push `main` and the tag.
5. Re-run marketplace install from a clean Codex profile.
