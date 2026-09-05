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
they always are on a real install. This has never actually failed on a real
install — the only way to reach the gap is a test fixture that deliberately
deletes specific markers to simulate an old database — but two migrations
since have needed a defensive fix because of it, so treat the pattern as a
real, recurring cost of the `MAX(version)` design rather than a one-off:

- `CREATE TABLE`/`CREATE INDEX` (v5): use `IF NOT EXISTS`. Cheap, and SQLite
  supports it directly — a plain `CREATE TABLE` re-run against a schema that
  already has it otherwise throws `migrationFailed` instead of degrading
  gracefully.
- `ALTER TABLE ADD COLUMN` (v6): **SQLite has no `IF NOT EXISTS` form for
  this.** A re-run throws `"duplicate column name"`. The `LegacyDataMigrationTests`
  fixture that simulates an old install works around this by also dropping
  the column (and any index on it) it added — see that file's `seedRealStore`
  comment. Any *future* `ALTER TABLE ADD COLUMN` migration needs the same
  fixture-side treatment or that test will fail exactly like this again.
  Prefer a new table (with `IF NOT EXISTS`) over `ALTER TABLE ADD COLUMN`
  when the schema change allows it, specifically to avoid this gap.
- `DELETE`/`UPDATE`-only migrations (v4) are naturally idempotent under a
  re-run and need no special handling.

This is deliberately not "fixed" at the runner level (e.g. replacing
`MAX(version)` with a per-version presence check, or making the runner
tolerant of specific SQL errors): no real, supported upgrade path has ever
exercised the gap, only a test's simulation technique, so a runner change
would be extra complexity paid for a scenario that can't occur outside tests.
Revisit this if that ever stops being true.

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

Version 6, as of this writing:
- v1 — `activity`, `exclusions`, `settings`
- v2 — `safety_log` (append-only SafetyCore audit trail)
- v3 — `locations` (favorites & recently-scanned folders)
- v4 — removes the retired `dryRunDefault` setting (data-only, no new table)
- v5 — `timeline_snapshots`, `timeline_categories` (Storage Timeline)
- v6 — `timeline_snapshots.scope` (which scan methodology produced a
  snapshot — see [PERSISTENCE.md](PERSISTENCE.md) "Timeline" for why
  comparisons must never cross scopes)

See [PERSISTENCE.md](PERSISTENCE.md) for what each table holds.
