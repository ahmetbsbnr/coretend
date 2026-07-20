# Persistence

`Sources/Persistence/` — no dependencies, used by `MacCareApp`.

## `Database` (internal, `final class`)

Thin SQLite3 wrapper (`import SQLite3` directly, no ORM/third-party
dependency) owned exclusively by the `Store` actor — not thread-safe on its
own, the actor is what makes it safe. Opens with
`SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE`, sets `PRAGMA
journal_mode=WAL` and `PRAGMA foreign_keys=ON` on open. Typed errors
(`DatabaseError`) instead of silent failure.

## `Store` (public `actor`)

The only persistence entry point the app uses. Default path:
`~/Library/Application Support/MacCareLocal/store.sqlite` (see
`Store.defaultPath()`, and [DATA_LOCATIONS.md](DATA_LOCATIONS.md)).

Three concerns, each a small table:
- **Activity** (`recordActivity`, `activity(limit:kind:)`, `clearActivity`)
  — history of scan/cleanup/restore/error events, with `dryRun` recorded
  per entry.
- **Exclusions** (`addExclusion`, `removeExclusion`, `exclusions`) — see
  [EXCLUSIONS.md](EXCLUSIONS.md).
- **Settings** (`setSetting`, `setting`) — simple key/value store,
  upserted with `ON CONFLICT ... DO UPDATE`.

All access is actor-isolated — call these from anywhere, awaits handle the
serialization; there is no separate locking to reason about.

## What's not here

Quarantine (Protection's malware findings) is a separate JSON-manifest
store owned by `MalwareEngine.Quarantine`, not this SQLite database — see
[QUARANTINE.md](QUARANTINE.md). Keeping it separate means a
Persistence-layer bug can't corrupt quarantine state and vice versa.
