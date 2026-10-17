# CoreTend CLI

The CLI is local. `scan` always requires an explicit `--root` and a declared rule ID. It reports observed paths and byte measurements; unknown values remain `null` in JSON. It never schedules work.

`clean` reads every cleanup rule's folder under `HOME` and lists what the Clean space would offer. Without `--confirm` nothing moves. With `--confirm`, the items marked safe — or every item of the rule given with `--rule` — go to the macOS Trash, each one revalidated just before; nothing is erased.

`mcp` runs a Model Context Protocol server on standard input and output with four read-only tools: `disk_usage`, `cleanup_candidates`, `largest_items`, `app_leftovers`. Add it to an assistant with the command `coretend mcp` (or `npx -y coretend mcp`).

```sh
coretend --lang en help
coretend --lang fr scan --root /path/selected/by/user --rule scan.explore
coretend scan --root /path/selected/by/user --rule scan.explore --format json
coretend record list --store /path/explicitly/chosen/CoreTend.sqlite
coretend clean                     # dry run
coretend clean --confirm           # safe items to the Trash
coretend clean --rule cleanup.npmcache --confirm
coretend mcp
coretend help
coretend version
```

`record list` opens the supplied SQLite file read-only. It does not infer, locate, create, migrate, or modify a user store. Paths printed by the CLI are local output and may reveal private names; review output before sharing it.

Use the optional global `--lang en|fr` before the command to choose help and text/error messages. English is the default. Invalid language values are usage errors. JSON scan keys, stable issue reason codes, and exit codes do not change with language.

Flag values beginning with `-` are rejected as malformed options. To pass a relative path whose name begins with a hyphen, prefix it with `./`.

`scan` returns exit code `0` only when traversal completed without scan issues. Missing, unreadable, excluded, or otherwise failed roots/items produce exit code `2`. In JSON mode, output is an object with `files`, `issues` (`path` and stable `reason`), and boolean `complete`; in text mode, each issue is printed after the file count. Invalid/unsupported commands and a missing required `--store` return `2`; an explicitly requested but unreadable store or scan failure returns `1`. Pressing Control-C during a scan cancels it and returns exit code `130`. A partial result must not be treated as a complete scan.
