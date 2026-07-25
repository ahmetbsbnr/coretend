# CoreTend Data Migration — Delivered State Report

**Status of this document**: current. It describes the migration **as
shipped and as actually executed**, not as planned.

| Field | Value |
|---|---|
| Product | CoreTend |
| Version | 0.8.1 |
| Branch | `feat/coretend-rebrand-workspace` |
| Final repository HEAD | `92cbd08bc3cd1d8ad0513391cbd7552b520f09fe` |
| Commit that delivered the migration code | `ca62b4a` — `feat(migration): migrate user data and preferences from the MacCare Local identity` |
| Commit that delivered the uninstall/legacy-gate half | `e557e96` — `feat(uninstall,gate): handle pre-rename data on removal, gate leftover old references` |
| Product source commit of the audited artifacts | `3b5dc73fbe522f92c88ea0b035ba8b8907b220e1` (last commit touching `Sources/`/`Tests/`) |
| Test result at final HEAD | 274 tests / 57 suites, PASS, 0 failures |
| Migration tests | 20, suite `"Legacy data migration"` |

This document supersedes the two pre-implementation documents, which are
preserved unmodified as history:

- [`RebrandHistory/PRE_IMPLEMENTATION_MIGRATION_DESIGN.md`](RebrandHistory/PRE_IMPLEMENTATION_MIGRATION_DESIGN.md)
  (was `Documentation/USER_DATA_RENAME_MIGRATION.md`)
- [`RebrandHistory/PRE_IMPLEMENTATION_MIGRATION_TEST_PLAN.md`](RebrandHistory/PRE_IMPLEMENTATION_MIGRATION_TEST_PLAN.md)
  (was `Documentation/REBRAND_MIGRATION_TEST_PLAN.md`)

Both of those open by stating that no migration code exists. That was true
when they were written and is false now. They were archived rather than
edited so the planning record stays intact.

---

## 1. Code actually delivered

| Artefact | Path | Size |
|---|---|---:|
| Migration engine | `Sources/Persistence/LegacyDataMigration.swift` | 317 lines |
| Tests | `Tests/PersistenceTests/LegacyDataMigrationTests.swift` | 501 lines, 20 `@Test` |
| Launch wiring | `Sources/CoreTendApp/AppEnvironment.swift:14-31` | — |
| User-visible result surface | `Sources/CoreTendApp/SettingsView.swift:185-186, 229-265` (`MigrationNoticeRow`) | — |
| Uninstall handling of legacy data | `Scripts/uninstall.sh` (`--include-legacy`, opt-in) | — |
| Localized strings | `Sources/CoreTendApp/Resources/{Base,fr}.lproj/Localizable.strings` (`settings.migration_*`) | — |

### What it migrates

Data items, in copy order (`LegacyDataMigration.itemNames`):

1. `store.sqlite`
2. `store.sqlite-wal`
3. `store.sqlite-shm`
4. `Quarantine/`
5. `watch-fingerprints.json`

The SQLite sidecars follow the main database deliberately — copying a `-wal`
without its database is worse than copying neither.

Preference keys (`LegacyDataMigration.preferenceKeys`), read out of the old
domain with `CFPreferencesCopyAppValue` because `UserDefaults.standard` can
only ever see the running bundle's own domain:

- `menuBarEnabled`
- `onboardingDone`
- `onboardingStep`

Only these three. A blanket domain copy would drag along OS-managed
bookkeeping keyed to the old identity.

### Source identities it looks for

Hardcoded constants, never pattern-matched:

- directories: `MacCareLocal`, `MacCare Local`
- bundle identifier: `local.maccare.app`
- destination directory: `CoreTend` (asserted equal to `Store.defaultPath()`
  by a test, so the two can never drift into copying data somewhere the app
  does not read)

## 2. Behaviour, and the code that guarantees it

### Idempotent

Runs unconditionally on every launch (`AppEnvironment.init`), with no
"have we done this yet" flag — such a flag can drift out of sync with the
filesystem, which is the actual source of truth. Idempotency comes from the
per-item destination check (`LegacyDataMigration.swift:206-210`): if the
destination item exists, it is recorded as `skipped` and never touched. A
second run therefore reports `completedWithSkips` and changes nothing.

Covered by `secondRunChangesNothing`, `migrationCanBeRerunAfterARollback`.

### Non-destructive copy

`copyItem` then `moveItem` — never `moveItem` from the source. The legacy
directory is never modified, renamed, or deleted by this code at any point.
The consequence stated plainly: **the untouched source is itself the backup
of this migration.**

Covered by `normalMigrationCopiesEveryItemAndLeavesTheSourceUntouched`
(checksums the source before and after).

### Never clobbers an existing install

If data already exists under the CoreTend identity, it wins — old data stays
unmigrated and is reported as skipped rather than silently dropped. Same rule
for preferences: a key already set under the new identity is not overwritten
(`migratePreferences`, `LegacyDataMigration.swift:267`).

Covered by `existingNewDataIsNeverOverwritten`,
`preferencesAlreadySetUnderTheNewIdentityWin`.

### Crash-safe per item

Each item is copied to `.migrating-<uuid>-<name>` inside the destination and
then renamed into place. A crash mid-copy leaves a stray temp file and an
*absent* destination, which the next run treats as "not yet migrated" and
redoes — rather than a truncated file that looks complete.

Covered by `interruptedRunResumesAndLeavesNoHalfCopiedItem`.

### Errors reported, never swallowed

A failed item is rolled back individually (its temp file removed, source
untouched), recorded in `report.failures`, and the run's status becomes
`completedWithErrors`. `MigrationNoticeRow` renders a failure with a warning
icon and the per-item reason — a migration that failed must never look like
one that worked.

Covered by `unwritableDestinationIsReportedNotSwallowed`,
`unreadableLegacyItemFailsThatItemOnly`.

### Rollback

`rollback(_:)` removes only what the given report lists as `migrated`. It
never removes `skipped` items (they pre-existed) and never touches anything
in the legacy source.

Covered by `rollbackRemovesOnlyWhatThisRunCreated`,
`migrationCanBeRerunAfterARollback`.

### Journalled

Every run appends its full report to `migration-log.json` beside the migrated
data. A migration that leaves no trace of having run is a migration nobody
can debug.

Covered by `everyRunIsJournalledBesideTheData`.

### Old data retained

The legacy directory and the legacy preference domain survive the migration
untouched. They are removed only if the user explicitly passes
`--include-legacy` to `Scripts/uninstall.sh`; that flag is off by default,
and legacy paths are ordered last in the removal list so an interrupted
uninstall can never leave the current install half-removed while the backup
is already gone.

## 3. Tests — planned vs. delivered

All 20 migration tests run inside the normal `Scripts/test.sh` suite, not a
separate opt-in target, satisfying the pre-implementation plan's gate.

| Planned scenario | Delivered test | Status |
|---|---|---|
| 1 Fresh install, no old data | `noLegacyDataLeavesEverythingAlone` | Covered |
| 2 Old data present, new dir absent; source unchanged | `normalMigrationCopiesEveryItemAndLeavesTheSourceUntouched` | Covered |
| 3 Idempotency on re-run | `secondRunChangesNothing` | Covered |
| 4 New dir already has real data → no overwrite | `existingNewDataIsNeverOverwritten` | Covered |
| 5 Interrupted between items | `interruptedRunResumesAndLeavesNoHalfCopiedItem` | Covered |
| 6 Interrupted mid-single-file copy | `interruptedRunResumesAndLeavesNoHalfCopiedItem` (same temp-then-rename invariant) | Covered by equivalent |
| 7 Permission denied on destination | `unwritableDestinationIsReportedNotSwallowed` | Covered |
| 8 Disk full mid-copy | — | **Not covered.** No test simulates ENOSPC. The temp-then-rename path is the same one scenario 7 exercises, so the invariant is tested, but the specific errno is not. |
| 9 Corrupt source `store.sqlite` not masked | `corruptDatabaseFileIsCopiedVerbatimAndNotSilentlyDropped` | Covered |
| 10 Old bundle ID has no prefs at all | `preferencesMigrateEvenWithNoLegacyFilesOnDisk`, `noLegacyDataLeavesEverythingAlone` | Covered |
| 11 Old prefs exist but new domain differs | `preferencesAlreadySetUnderTheNewIdentityWin` | Covered |
| 12 End-to-end with a real schema-valid store | `migratedStoreKeepsItsActivityExclusionsAndSettings` (fixture built via `Persistence.Store`'s own init) | Covered |
| 13 Post-migration launch via real `AppEnvironment` | `migrationTargetsTheDirectoryTheStoreActuallyUses` asserts the destination equals `Store.defaultPath()` | **Covered by equivalent, weaker.** No test constructs a real `AppEnvironment` against a migrated directory; `AppEnvironment.shared` is a process-wide singleton reading the real `~/Library`, which no test is allowed to touch. The path contract is asserted instead. |
| 14 Real macOS launch under the new bundle ID | not automatable | **Satisfied manually — see §4** |
| 15 Gatekeeper/first-launch unaffected | not automatable | BLOCKED_ENVIRONMENT — unsigned, un-notarized build; first-launch Gatekeeper behaviour has not been re-verified after the bundle-ID change |

Tests delivered beyond the plan:

- `quarantineContentsSurviveTheMove` — directory copy, not just files
- `alternateLegacyDirectoryNameIsAlsoFound` — the `MacCare Local` spelling
- `sqliteSidecarsMigrateWithTheirDatabase` — `-wal`/`-shm` ordering
- `unreadableLegacyItemFailsThatItemOnly` — failure isolation
- `unrelatedLegacyPreferenceKeysAreNotCopied` — allowlist enforcement
- `everyRunIsJournalledBesideTheData` — journal
- `rollbackRemovesOnlyWhatThisRunCreated`, `migrationCanBeRerunAfterARollback` — rollback

Every test drives the fully-injectable initialiser against `mktemp -d`
directories and scratch `UserDefaults` suites. **No test reads or writes the
real `~/Library`.**

## 4. Data actually migrated — real execution

A real migration ran **once**, on **one machine**: the single Apple-silicon
development Mac this project is built and tested on. Evidence is the
journal the migration itself wrote.

| Field | Value |
|---|---|
| Journal | `~/Library/Application Support/CoreTend/migration-log.json` |
| Runs recorded | 1 |
| Date (UTC) | `2026-07-25T09:08:32Z` |
| Status | `completed` |
| Legacy source | `~/Library/Application Support/MacCareLocal` |
| Destination | `~/Library/Application Support/CoreTend` |
| Items migrated | `store.sqlite`, `store.sqlite-wal`, `store.sqlite-shm`, `Quarantine` |
| Items skipped | none |
| Failures | none |
| Preference keys migrated | `menuBarEnabled`, `onboardingDone`, `onboardingStep` |

`watch-fingerprints.json` does not appear in the migrated list because it did
not exist in the legacy directory on this machine — the per-item
`fileExists` guard skipped it silently, which is the designed behaviour, not
a failure.

Verified independently of the journal, after the fact:

- The legacy directory still exists and still contains `store.sqlite`,
  `store.sqlite-wal`, `store.sqlite-shm`, `Quarantine/`, with modification
  times predating the migration — confirming the copy was non-destructive.
- `store.sqlite` is byte-identical across the two locations:
  `a209ba85773882b79b8147779c406fbb67a12dcb723ba7c4ea7ca3168e651cc8`
- The legacy preference domain `local.maccare.app.plist` still exists
  alongside the new `com.ahmetbsbnr.coretend.plist`.

This satisfies planned scenario 14: the app really did launch under the new
bundle identifier and the OS-level preference-domain separation behaved as
the design assumed.

## 5. Limits — what this report does not claim

- **One machine, one run.** The migration has been executed for real exactly
  once, on one arm64 Mac running the developer's own account. No claim is
  made about any other machine, macOS version, hardware, user account,
  filesystem, or locale. Multi-machine and multi-OS verification has not
  been performed.
- **The executed run took the happy path.** Status was `completed` with zero
  skips and zero failures. The skip, failure, rollback, and
  interrupted-resume paths have been exercised **only by unit tests against
  temporary directories**, never by a real failing migration on real user
  data.
- **No disk-full test.** Planned scenario 8 has no corresponding test.
- **No real-`AppEnvironment`-over-migrated-data test.** Planned scenario 13
  is covered by a path-contract assertion instead (see §3).
- **Gatekeeper after the bundle-ID change is unverified.** The build is
  unsigned and not notarized, so first-launch behaviour under the new
  identity has not been re-confirmed. Planned scenario 15 stays
  BLOCKED_ENVIRONMENT.
- **Migration from versions older than the audited legacy layout is not
  handled.** Only the two known directory names and the one known legacy
  bundle identifier are recognised.
- **No network, no telemetry, no remote reporting** is involved in any part
  of this migration.

## 6. Evidence index

| Claim | Where to verify it |
|---|---|
| Code exists and behaves as described | `Sources/Persistence/LegacyDataMigration.swift` |
| 20 tests exist and pass | `Tests/PersistenceTests/LegacyDataMigrationTests.swift`; `Documentation/test-inventory.json` (274/57 PASS at `92cbd08`) |
| Raw test run output | `Documentation/AUDIT_COMMANDS.log` |
| Runs on launch | `Sources/CoreTendApp/AppEnvironment.swift:14-31` |
| Result shown to the user | `Sources/CoreTendApp/SettingsView.swift:229-265` |
| Legacy data survives uninstall by default | `Scripts/uninstall.sh`; `Scripts/test-uninstall.sh` |
| Real execution on this machine | `~/Library/Application Support/CoreTend/migration-log.json` (not included in the audit package — it is personal data; see `AUDIT_PACKAGE_EXCLUSIONS.md`) |
| Original design intent | `Documentation/RebrandHistory/PRE_IMPLEMENTATION_MIGRATION_DESIGN.md` |
| Original acceptance criteria | `Documentation/RebrandHistory/PRE_IMPLEMENTATION_MIGRATION_TEST_PLAN.md` |
| Rollback of the rename as a whole | `Documentation/PRODUCT_RENAME_ROLLBACK.md` |
| Feature inventory entries | `Documentation/feature-inventory.json` — `migration.legacydata`, `migration.launchwiring`, `settings.migrationnotice`, `uninstall.legacydata` |
