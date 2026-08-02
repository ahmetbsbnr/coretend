# Persistence

`Sources/Persistence/` — depends on SafetyCore and is used by `CoreTendApp`.

## `Database` (internal, `final class`)

Thin SQLite3 wrapper (`import SQLite3` directly, no ORM/third-party
dependency) owned exclusively by the `Store` actor — not thread-safe on its
own, the actor is what makes it safe. Opens with
`SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE`, sets `PRAGMA
journal_mode=WAL` and `PRAGMA foreign_keys=ON` on open. Typed errors
(`DatabaseError`) instead of silent failure.

## `Store` (public `actor`)

The only persistence entry point the app uses. Default path:
`~/Library/Application Support/CoreTend/store.sqlite` (see
`Store.defaultPath()`, and [DATA_LOCATIONS.md](DATA_LOCATIONS.md)).

Three concerns, each a small table:
- **Activity** (`recordActivity`, `activity(limit:kind:)`, `clearActivity`)
  — history of scan/cleanup/restore/error events. Cleanup bytes represent
  completed moves only; retired preview rows remain in old databases solely
  for downgrade compatibility and are hidden from current APIs.
- **Exclusions** (`addExclusion`, `removeExclusion`, `exclusions`) — see
  [EXCLUSIONS.md](EXCLUSIONS.md).
- **Settings** (`setSetting`, `setting`) — simple key/value store,
  upserted with `ON CONFLICT ... DO UPDATE`.

All access is actor-isolated — call these from anywhere, awaits handle the
serialization; there is no separate locking to reason about.

## Retired preview records

The v4 migration removes the former preview-default setting. Legacy columns
remain for downgrade compatibility, while current activity and safety-log
queries hide old preview-only rows. No current product API writes or exposes
that mode. Integrity is read-only and has no quarantine store.
