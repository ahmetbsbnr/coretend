# User Data Rename Migration — Pre-Implementation Design (HISTORICAL)

> **HISTORICAL DOCUMENT — SUPERSEDED, NOT CORRECTED.**
>
> This is the *pre-implementation* design, written before any migration code
> existed. Its opening sentence ("No migration code exists yet, no data has
> moved") was true at the commit that authored it and is **no longer true**.
> It is preserved verbatim below as the design record of what was planned; it
> has deliberately **not** been rewritten to match what shipped.
>
> For the state of the migration as actually delivered in 0.8.1 — the code,
> the tests, what was really migrated, and on which machine — read
> [`../CORETEND_DATA_MIGRATION_REPORT.md`](../CORETEND_DATA_MIGRATION_REPORT.md).
>
> The acceptance criteria written alongside this design are archived next to it
> as [`PRE_IMPLEMENTATION_MIGRATION_TEST_PLAN.md`](PRE_IMPLEMENTATION_MIGRATION_TEST_PLAN.md).
>
> Archived here during the 0.8.1 Final Canonical Audit Resync, at
> `92cbd08bc3cd1d8ad0513391cbd7552b520f09fe`. Previous path:
> `Documentation/USER_DATA_RENAME_MIGRATION.md`.

---

Planning document. No migration code exists yet, no data has moved.
Inventories exactly what local data exists today and how a future bundle-
identifier change must handle it.

## Inventory of local data today

| Data | Location | Keyed by | Contains |
|---|---|---|---|
| SQLite store | `~/Library/Application Support/MacCareLocal/store.sqlite` | Directory name (currently hardcoded `"MacCareLocal"` in `Store.swift`, not derived from `CFBundleIdentifier`) | `settings` table (`dryRunDefault`, `securityProfile`), `exclusions` table, `activity` table (scan/cleanup history) |
| Quarantine | `~/Library/Application Support/MacCareLocal/Quarantine/` | Same directory convention | Quarantined files moved there by the malware-scan flow, plus their metadata |
| FSEvents fingerprint cache | `~/Library/Application Support/MacCareLocal/watch-fingerprints.json` (sibling to `Quarantine/`, per `ProtectionView.swift`) | Same directory convention | Per-path size+mtime fingerprints, used only to dedupe re-scans — safe to lose (regenerates), but should still migrate for continuity |
| `UserDefaults` (`menuBarEnabled`, `onboardingDone`, `onboardingStep`) | Standard `~/Library/Preferences/<CFBundleIdentifier>.plist` | **`CFBundleIdentifier`** (`local.maccare.app`) — this is the one truly bundle-ID-coupled piece of data | Menu-bar toggle state, onboarding completion/step |

**Key finding**: the SQLite/Quarantine/fingerprint data uses a *hardcoded
directory name* (`"MacCareLocal"`), not the bundle identifier — so
renaming the product does **not** automatically orphan it the way
`UserDefaults` does. This is actually good news for migration risk: only
one data class (`UserDefaults`) is silently bundle-ID-coupled by the OS
itself; the rest is under this project's own control and only needs a
directory-name change, which the app can migrate itself on first launch
under a new identity.

## Migration strategy

1. **Detect**: on first launch under a new bundle identifier, check
   whether `~/Library/Application Support/<newName>/` exists. If it does,
   the migration already ran (or this is a fresh new-name install with no
   old data) — do nothing further.
2. **Locate the old data**: check for
   `~/Library/Application Support/MacCareLocal/` (the known old directory
   name — hardcoded as a one-time migration constant, not a guess).
3. **Copy, never move**: copy `store.sqlite`, `Quarantine/`, and
   `watch-fingerprints.json` into the new directory. The old directory is
   left completely untouched — this is the single design decision that
   makes rollback trivial (see `PRODUCT_RENAME_ROLLBACK.md`) and makes
   the migration safe to re-run (idempotent: if the new directory already
   has a `store.sqlite`, the copy step is skipped, never overwritten).
4. **`UserDefaults`**: read the old bundle identifier's preference domain
   directly (`CFPreferencesCopyValue` with the old identifier passed
   explicitly, since `UserDefaults.standard` only sees the *current*
   bundle's domain) for `menuBarEnabled`/`onboardingDone`/`onboardingStep`,
   and write them into the new domain via `UserDefaults.standard`. Old
   domain's plist file is untouched.
5. **Report, don't hide**: if the copy step encounters a real error
   (permission denied, disk full, corrupt SQLite file) it must **not**
   silently continue as if migration succeeded — surface it to the user
   (a Settings-visible message, or an onboarding-step warning), same
   honesty standard as every other SafetyCore-adjacent operation in this
   project.

## Non-negotiable properties (per the phase brief)

- **Idempotent**: running the migration twice produces the same end state
  as running it once (guarded by "does the new directory already have
  data" check in step 1/3).
- **Non-destructive**: old directory and old `UserDefaults` domain are
  never deleted or overwritten by this migration.
- **Cannot overwrite an existing installation**: if the new bundle
  identifier's directory already has a non-empty `store.sqlite`, the
  migration must not clobber it — that would mean two different rename
  attempts (or a reinstall) stepping on real, already-in-use data under
  the new identity.
- **Resumable after interruption**: because each of the three data items
  (SQLite file, Quarantine directory, fingerprint JSON) is copied
  independently and the "already migrated" check is per-item (not one big
  transaction), a crash mid-migration leaves at most one item
  incompletely copied — re-running picks up whatever wasn't finished.
  SQLite's own file copy is not atomic mid-write, so the migration must
  copy to a temp filename in the destination directory and rename into
  place only after the copy completes (matching the same
  copy-to-temp-then-rename pattern `Quarantine`'s own restore logic
  already uses elsewhere in this codebase).
- **Backed up implicitly**: because the source is never touched, the
  "backup" *is* the untouched old directory — no separate backup step is
  needed for this specific migration (distinct from the workspace-level
  Git-bundle backups in `preflight-workspace-migration.sh`, which cover a
  different concern).
- **Silent only for safe operations**: the copy itself can run silently
  on first launch (copying files is safe and reversible) — but must never
  silently proceed past a real I/O error (see step 5), and must never
  silently delete or overwrite anything.
- **Compatible with old data format**: since this migration only copies
  files (never transforms their contents), the SQLite schema and
  Quarantine metadata format are unchanged — no format-migration risk is
  introduced by the rename itself.

## What this migration explicitly does NOT do

- Does not touch `Configuration/PublicIdentity.local.json` (a build-time
  config file, not runtime user data).
- Does not attempt to migrate data for a user who manually renamed or
  moved their `Application Support` folder outside this app's normal
  behavior — only the documented, known old directory name is checked.
- Does not run automatically for a *fresh* install with no prior
  MacCare-Local install on the machine (step 1's check short-circuits:
  no old directory found, nothing to do).

See `REBRAND_MIGRATION_TEST_PLAN.md` for the test matrix this migration
needs before it's implemented, and
`Documentation/user-data-rename-migration.json` for the machine-readable
version of the inventory above.
