# Migrations

`Store` (`Sources/Persistence/Store.swift`) keeps an ordered, append-only
array of SQL migration strings (`private static let migrations: [String]`).
Each element is one version; index `0` is schema version `1`, and so on.

## How it applies migrations

A `schema_migrations` table (`version INTEGER PRIMARY KEY, applied REAL NOT
NULL`) tracks the highest version already applied. On `Store.init`, it
reads the current **max** version and runs every migration with a higher
index than that, each inside its own transaction (`db.transaction { ... }`) —
either the whole migration's SQL plus its `schema_migrations` row commits,
or neither does. A failure throws `DatabaseError.migrationFailed(version:message:)`
rather than leaving the database in an unknown state.

Because this check is a bare `MAX(version)` rather than "is version N present
in the table", it assumes markers are applied contiguously from 1 upward, as
they always are on a real install. Any schema-creating migration (`CREATE
TABLE`/`CREATE INDEX`) should still use `IF NOT EXISTS` — cheap insurance if
that assumption is ever violated (as one `PersistenceTests` fixture that
partially rolls back markers to simulate an old install discovered), since a
plain `CREATE TABLE` re-run against a schema that already has it throws
`migrationFailed` instead of degrading gracefully. `DELETE`/`UPDATE`-only
migrations (v4) are naturally idempotent and don't need this.

## The rule for adding a migration

**Never edit a shipped migration string.** Append a new entry to the
`migrations` array instead — this is called out explicitly in the source
comment. Editing a shipped entry would change what already-applied
databases think they've run, silently corrupting anyone who upgrades from
an older build.

To add schema:

```swift
private static let migrations: [String] = [
    // v1
    """
    CREATE TABLE activity (...);
    CREATE TABLE exclusions (...);
    CREATE TABLE settings (...);
    """,
    // v2  <- append here, never touch v1's string above
    """
    ALTER TABLE ...;
    """,
]
```

Add a `PersistenceTests` case that opens a fresh `Store`, confirms
`schemaVersion()` reports the new version, and exercises the new
table/column. See [TESTING.md](TESTING.md).

## Current schema

Version 5, as of this writing:
- v1 — `activity`, `exclusions`, `settings`
- v2 — `safety_log` (append-only SafetyCore audit trail)
- v3 — `locations` (favorites & recently-scanned folders)
- v4 — removes the retired `dryRunDefault` setting (data-only, no new table)
- v5 — `timeline_snapshots`, `timeline_categories` (Storage Timeline)

See [PERSISTENCE.md](PERSISTENCE.md) for what each table holds.
