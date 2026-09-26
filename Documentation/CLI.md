# CoreTend CLI

The CLI is local and read-only. `scan` always requires an explicit `--root` and a declared rule ID. It reports observed paths and byte measurements; unknown values remain `null` in JSON. It never schedules work or changes files.

```sh
coretend scan --root /path/selected/by/user --rule scan.explore --format json
coretend record list --store /path/explicitly/chosen/CoreTend.sqlite
coretend help
coretend version
```

`record list` opens the supplied SQLite file read-only. It does not infer, locate, create, migrate, or modify a user store. Mutation commands are not defined. Paths printed by the CLI are local output and may reveal private names; review output before sharing it.

`scan` returns exit code `0` only when traversal completed without scan issues. Missing, unreadable, excluded, or otherwise failed roots/items produce exit code `2`. In JSON mode, output is an object with `files`, `issues` (`path` and stable `reason`), and boolean `complete`; in text mode, each issue is printed after the file count. Exit `1` means command/store failure and `130` means cancellation. A partial result must not be treated as a complete scan.
