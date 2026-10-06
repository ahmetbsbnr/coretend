# coretend

CoreTend for the terminal and for AI assistants, on macOS (Apple silicon).

```sh
npx coretend clean            # what can be cleaned; nothing moves
npx coretend clean --confirm  # safe items go to the Trash — never erased
npx coretend mcp              # read-only MCP server
```

Add CoreTend to an MCP client (Claude Desktop, Claude Code, Cursor…):

```json
{ "mcpServers": { "coretend": { "command": "npx", "args": ["-y", "coretend", "mcp"] } } }
```

Tools: `disk_usage`, `cleanup_candidates`, `largest_items`, `app_leftovers` — all read-only.

On first run the package downloads the signed and notarized `coretend` binary from the GitHub
release, checks its SHA-256 and caches it in `~/Library/Caches/coretend`. No telemetry.

The app: https://coretend.ahmetbsbnr.com · Source: https://github.com/ahmetbsbnr/coretend · Apache-2.0
