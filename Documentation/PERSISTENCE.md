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

Concerns, each a small table (or pair of tables):
- **Activity** (`recordActivity`, `activity(limit:kind:)`, `clearActivity`)
  — history of scan/cleanup/restore/error events. Cleanup bytes represent
  completed moves only; retired preview rows remain in old databases solely
  for downgrade compatibility and are hidden from current APIs.
- **Exclusions** (`addExclusion`, `removeExclusion`, `exclusions`) — see
  [EXCLUSIONS.md](EXCLUSIONS.md).
- **Settings** (`setSetting`, `setting`) — simple key/value store,
  upserted with `ON CONFLICT ... DO UPDATE`.
- **Locations** (`addFavorite`, `removeFavorite`, `recordLocationVisit`,
  `removeRecent`, `favorites`, `recents`) — one table backing both favorite
  folders and recently-scanned ones; a row with neither signal is pruned.
- **Safety log** (`recordSafetyEvent` via `SafetyAuditSink`, `safetyLog`,
  `purgeSafetyLog`) — append-only SafetyCore audit trail. Paths are redacted
  (`Store.redactPath`) before they ever reach disk; `purgeSafetyLog()` is the
  only deletion path and is an explicit, all-or-nothing user action.
- **Restore manifest** (`recordRestoreManifest` via `RestoreManifestSink`,
  `restoreManifestItems`, `restoreManifestItem(id:)`,
  `setRestoreManifestState`, `restoreManifestCount`, `pruneRestoreManifests`,
  `clearRestoreManifests`) — DB schema **v7**. The **one** table that stores
  real, unredacted `original_path` and `trash_path` values: they are the
  minimum needed for Restore Center to move a CoreTend-Trashed item back.
  One row per Trashed operation item (a directory root is one row; its
  descendants are never enumerated). Written only by `SafetyCenter` on a
  successful `trashItem` move, via a sink that also conforms to
  `RestoreManifestSink` (`Store` does) — the permanent `removeItem` fallback
  writes nothing. States: `available` / `restored` / `missingFromTrash` /
  `invalidIdentity`; destination-side problems (conflict, missing/unwritable
  parent, unmounted volume) are recomputed live and never stored.
  `pruneRestoreManifests` runs after every write and drops any row older than
  90 days, plus non-`available` rows older than 30. `clearRestoreManifests`
  ("Forget Restore History") is the explicit, all-or-nothing user action,
  mirroring `purgeSafetyLog()`; it removes records only and never touches the
  Trash. This table is excluded from `DiagnosticReport`, Timeline, and audit
  exports — see `Documentation/RESTORE.md` / `Documentation/PRIVACY.md`.
- **Timeline** (`recordTimelineSnapshot`, `timelineSnapshots`,
  `timelineCategories`, `timelineComparison(scope:since:)`,
  `timelineComparisonSincePreviousSnapshot(scope:)`,
  `latestTimelineComparisonAcrossScopes`, `clearTimelineHistory`) — one
  snapshot row per completed scan (a total, a trigger, and a **scope**), plus
  one row per category observed in that scan (a rule ID or engine-defined
  bucket name, logical/physical bytes, file count, risk). No file paths are
  ever stored here — aggregates only, so Timeline history can't become a
  sensitive per-file trail.

  **Scope is the comparison boundary.** A snapshot's `scope` identifies the
  scan methodology that produced it ("cleanup", "duplicates", "leftovers",
  "privacy"). A Cleanup scan covers a fixed set of system-cache rules; a
  Duplicates scan covers wasted space from copies in a different fixed root
  set; neither is "total storage", and they measure disjoint things. Every
  comparison method therefore takes an explicit `scope` (or derives one from
  whatever snapshot is most recent) — there is no API that diffs "the two
  most recent snapshots" regardless of what produced them, because that would
  silently misrepresent disk usage the moment a second engine is wired in.
  `latestTimelineComparisonAcrossScopes()` is the one exception worth
  understanding: it picks the single most recent snapshot *of any scope*,
  then compares it against the previous snapshot *of that same scope* — this
  is what a Dashboard-level "since last scan" card should call, never a
  routine that blends totals across scopes.

  `pruneTimelineSnapshots` (private, runs per-scope after every write to that
  scope) keeps each scope's snapshots from the last 90 days but always keeps
  at least that scope's 5 most recent regardless of age — so a rarely-scanned
  engine (e.g. Duplicates) can't be pruned away just because another scope is
  scanned often. `clearTimelineHistory()` is the explicit, all-or-nothing,
  every-scope user action, mirroring `purgeSafetyLog()`; there is
  deliberately no per-scope clear, since this is a privacy action ("forget my
  local scan history"), not a per-feature reset.

  Wired scopes, as of this writing: Cleanup (`CleanupViewModel`, one category
  per rule group), Duplicates (`DuplicatesViewModel`, one "wastedSpace"
  category), Leftovers (`LeftoversViewModel`, one "applicationData"
  category), Privacy (`PrivacyCleanerViewModel`, one category per detected
  browser, cache bytes only — history/cookies are shown but never deleted, so
  they aren't a "reclaimable" figure). **Not wired**, deliberately: My
  Clutter/Large & Old (its size/age thresholds are user-adjustable per scan,
  so two scans aren't a comparable scope), Space Lens (reports the size of an
  arbitrary folder tree — a different unit than "reclaimable junk", not
  something to fold into the same kind of total), Similar Images (the
  engine's public API exposes a group's total bytes, not the reclaimable
  portion excluding the kept image — recording the raw total would overstate
  what's actually reclaimable), Cloud Cleanup (reports local-vs-cloud sync
  state per provider, not a reclaimable figure). See `CoreTendApp`'s
  `TimelineScope` and `TimelineService` for the UI-facing layer built on top
  of this.

All access is actor-isolated — call these from anywhere, awaits handle the
serialization; there is no separate locking to reason about.

## Retired preview records

The v4 migration removes the former preview-default setting. Legacy columns
remain for downgrade compatibility, while current activity and safety-log
queries hide old preview-only rows. No current product API writes or exposes
that mode. Integrity is read-only and has no quarantine store.

## Migrations

Ordered, append-only (`Store.migrations`); never edit a shipped entry.
v1 base tables · v2 `safety_log` · v3 `locations` · v4 drop preview setting ·
v5 Timeline tables · v6 Timeline `scope` column · **v7 `restore_manifest`**
(Restore Center; the only table with unredacted paths).
