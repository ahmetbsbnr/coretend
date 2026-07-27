# Rebrand Migration Test Plan — Pre-Implementation (HISTORICAL)

> **HISTORICAL DOCUMENT — SUPERSEDED, NOT CORRECTED.**
>
> These are the acceptance criteria written *ahead of* the implementation. The
> claim "No migration code exists yet" was true when written and is **no longer
> true**. Preserved verbatim; deliberately not rewritten to match what shipped.
>
> For which of these scenarios became real tests, which were satisfied by an
> equivalent test rather than a literal one, and which were dropped with a
> stated reason, read
> [`../CORETEND_DATA_MIGRATION_REPORT.md`](../CORETEND_DATA_MIGRATION_REPORT.md).
>
> The design this plan accompanies is archived beside it as
> [`PRE_IMPLEMENTATION_MIGRATION_DESIGN.md`](PRE_IMPLEMENTATION_MIGRATION_DESIGN.md).
>
> Archived here during the 0.8.1 Final Canonical Audit Resync, at
> `92cbd08bc3cd1d8ad0513391cbd7552b520f09fe`. Previous path:
> `Documentation/REBRAND_MIGRATION_TEST_PLAN.md`.

---

Test matrix the future user-data migration (`USER_DATA_RENAME_MIGRATION.md`)
must pass before it ships. No migration code exists yet — this is the
acceptance criteria written ahead of the implementation, matching this
project's established practice of writing the safety bar before the
feature (see `SMART_CARE_AUDIT.md` for the precedent).

## Unit-testable scenarios (pure logic, injectable paths — no real
`~/Library` access needed, same pattern as `ProtectionWatcherTests`'
`FakeProbe`)

1. **Fresh install, no old data**: old directory doesn't exist → migration
   is a no-op, new directory created normally by the app's existing
   first-run logic, no error.
2. **Old data present, new directory absent**: all four items copy
   successfully; source directory afterward is byte-for-byte unchanged
   (checksum before/after).
3. **Migration re-run after already succeeding (idempotency)**: second run
   detects existing new-directory data and skips the copy — does not
   duplicate, does not error, does not re-copy.
4. **New directory already has real data (existing new-identity install)**:
   migration must **not** overwrite it — old-identity data stays
   unmigrated, a clear signal is surfaced (not silently dropped).
5. **Interrupted mid-copy (simulate a crash after item 1 of 4 copies,
   before item 2 starts)**: re-running the migration completes items 2-4
   without re-copying or corrupting item 1.
6. **Interrupted mid-single-file-copy (crash while `store.sqlite` itself
   is partially written to its temp destination)**: the temp file is
   either absent or clearly incomplete on restart; the migration detects
   this (temp file exists but no matching completed rename) and restarts
   that one item's copy from scratch — never treats a partial temp file
   as done.
7. **Permission-denied on the destination directory**: migration surfaces
   a real, actionable error — does not silently continue as if it
   succeeded, does not crash uncaught.
8. **Disk full mid-copy**: same as above — real error surfaced, no partial
   "looks migrated but isn't" state left behind (covered by scenario 6's
   temp-then-rename pattern).
9. **Corrupt source `store.sqlite`** (e.g. truncated file): the copy
   itself succeeds (it's a byte copy, not an SQLite-aware operation) but
   the app's normal SQLite-open-and-validate path (already exists,
   exercised by `PersistenceTests`) surfaces the corruption the same way
   it would for a non-migrated corrupt database — no special-casing
   needed, but a test should confirm the migration doesn't mask this by
   e.g. swallowing the open error.
10. **`UserDefaults` migration when the old bundle ID has no prefs file at
    all** (e.g. app was installed but never launched under the old
    identity): no-op, no crash, new identity gets its own normal defaults.
11. **`UserDefaults` migration when old values exist but new domain
    already has different values**: same non-overwrite rule as scenario 4
    — old values are not force-written over real new-identity settings.

## Integration-level scenarios (need a real temp `Application Support`-
shaped directory tree, via `mktemp -d`, same pattern
`Scripts/preflight-workspace-migration.sh`'s own tests use — not real
`~/Library`)

12. **End-to-end**: build a fixture old directory with a real (small)
    SQLite file (via `Persistence.Store`'s own init, so the fixture is
    guaranteed schema-valid, not hand-crafted), a fake quarantined file,
    and a fingerprint JSON; run the migration; open the new-location
    `Store` and confirm the settings/exclusions/activity rows read back
    identically.
13. **Post-migration app launch**: after migration, a fresh `AppEnvironment`
    initialized against the new bundle identity finds and correctly reads
    the migrated `store.sqlite` — proving the migration's output is not
    just byte-copied but actually *usable* by the real code path, not
    only inspectable by a test-only reader.

## Manual/BLOCKED_ENVIRONMENT scenarios (need a real bundle-ID change +
real launch, cannot be simulated in a unit test)

14. **Real macOS launch under the new bundle identifier**, confirming
    `NSUserDefaults`'s own OS-level domain separation behaves as expected
    (this is OS behavior, not this project's code, but should be
    confirmed once for real before relying on it in production).
15. **Gatekeeper/first-launch behavior unaffected** by the bundle-ID
    change (unsigned-app warning still appears/behaves identically).

## Gate

Once implemented, this migration's unit + integration tests (1-13) must
be part of the normal `Scripts/test.sh` suite, not a separate opt-in
suite — matching how every other safety-sensitive path in this project
(SafetyCenter, Quarantine, ProtectionWatcher) is tested inline, not
bolted on separately.
