# Restore / Undo a Cleanup

CoreTend's cleanup actions remove files by moving them to the macOS **Trash**
by default — not by permanent deletion — precisely so mistakes are
recoverable. Two independent paths exist:

1. **Restore Center** (in-app) — for items CoreTend itself moved to the Trash,
   while a private local restore record still exists and the Trash item is
   still there.
2. **Finder → Trash → Put Back** — always available for anything in the Trash,
   independent of CoreTend.

## Restore Center

Sidebar → **Restore Center** (System group). It lists the CoreTend operations
(cleanup, app uninstall, Recovery Plan runs, …) whose Trashed items can still
be moved back, grouped by operation.

Flow:

```
CoreTend cleanup → Trash → restore manifest captured
   → Restore Center shows availability
   → you review / select
   → confirm
   → destination re-validated
   → item moved back
   → per-item result shown, coarse restore recorded in Activity
   → manifest state updated
```

### What "restorable" means (and does not)

Restore Center checks, per item, on every load and refresh:

- the recorded **Trash URL still exists** (captured from
  `FileManager.trashItem(at:resultingItemURL:)` at delete time — never
  reconstructed from a filename, because macOS renames collisions in the
  Trash);
- it is still the **same item** — POSIX inode + volume UUID + directory-ness,
  with the stored size/date as supporting evidence;
- the **original location is clear** — its parent folder exists and is
  writable, and nothing already occupies the original path.

Item states shown: **Available**, **Restored**, **Conflict — location
occupied**, **Original location unavailable**, **Changed in Trash**, **Not in
Trash**, **Volume not connected**.

### Restore is per-item, never atomic

A multi-item restore validates and moves each item independently. A failure
or skip on one never rolls back another. The result is real, e.g.
"Restored 15 · 1 skipped (occupied) · 2 no longer available".

### Conflicts are refused, never resolved

If something already exists at an item's original location, CoreTend
**refuses** that item ("Conflict — location occupied") and moves on. It never
overwrites, renames, or deletes whatever is already there. Correct refusal is
preferred over unsafe recovery.

### Empty Trash = gone

Once the Trash is emptied, the item is `missingFromTrash` and Restore Center
reports it as no longer restorable. CoreTend cannot recover a file after the
Trash has been emptied — and neither can Finder. This is not an Undo
illusion.

### External volumes

Restore captures the source volume UUID so it does not assume every item
lives in `~/.Trash`. When the recorded volume is not mounted, the item shows
"Volume not connected" and is not offered until the disk is reconnected.
Real external-volume restore (`/Volumes/…/.Trashes/<uid>`) is **HUMAN
VERIFICATION REQUIRED** — the model is exercised with synthetic volume
identity in tests, not a real removable disk.

## The restore manifest (private local record)

To offer in-app restore, CoreTend keeps a small **local** table
(`restore_manifest`, DB schema v7). Unlike every other CoreTend table, it
stores **real, unredacted** paths — the original location and the Trash
location — because those are the minimum needed to put a file back.

Stored per item: a stable item id, the originating operation id (the same id
the redacted `safety_log` uses, so the two correlate without the audit log
holding a path), original path, Trash path, source volume UUID, inode, file
vs. directory, size at execution, modification date, rule id, risk,
timestamp, and lifecycle state.

A directory moved to the Trash is **one** manifest row for its root — its
descendants are never enumerated. Restoring the root moves the whole subtree
back with its metadata via a normal filesystem move.

### Privacy boundary

The restore manifest is deliberately walled off:

- **local only** — never synced, never transmitted, no network path exists;
- **excluded from `DiagnosticReport`** — the diagnostic report is built only
  from a fixed `Inputs` struct that has no field able to carry a path;
  restore activity appears there only as a count;
- **excluded from Timeline** — Timeline measures scans, not actions;
- **excluded from Advisor persistence** — Advisor is pure and stateless;
- **not in the ordinary audit log** — `safety_log` stays redacted; a restore
  writes a redacted `.executed` event there (`rule_id` `restore.<original
  rule>`), never the real path;
- **user-clearable** — "Forget Restore History" deletes every manifest row in
  one action.

### Forget Restore History ≠ Empty Trash

"Forget Restore History" removes CoreTend's restore **records** only. It does
**not** empty the Trash and never removes anything from it — Finder "Put
Back" may still work afterwards. CoreTend never empties the Trash from any
control.

### Retention

Manifest rows are pruned on a bounded schedule (mirroring Timeline's 90-day
window):

- any row older than **90 days** is removed;
- a row in a non-`available` state (restored, missing, invalid identity) is
  removed after **30 days**.

So a private-path record does not linger once it is no longer actionable,
while a Trashed item still gets three months of in-app restore.

## When `AdvisorReversibility.restorableByCoreTend` is true

Only when a restore manifest exists **and** that item's Trash copy is
currently present, identity-checked, and its destination is clear. A
scan-result Advisor finding (produced before anything is Trashed) is never
`restorableByCoreTend`. An emptied-Trash item is honestly `irreversible`; an
item whose automatic restore is blocked but whose Trash copy still exists
stays `trash` (Finder Put Back may still work).

## Restoring via Finder (always available)

1. Open **Finder → Trash**.
2. Find the item — macOS preserves the original name; CoreTend's
   Activity/History view records the operation summary (counts, size, date).
3. Right-click → **Put Back**, or drag it back.

As long as the Trash has not been emptied, this is fully reversible.
Emptying the Trash is a macOS-level action outside CoreTend's control and is
final.

## If something looks wrong after a cleanup

1. Check Restore Center, then the Trash.
2. See [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
3. If you believe CoreTend removed something it should not have, report it
   per [SECURITY.md](../SECURITY.md) or open a bug report (see
   `.github/ISSUE_TEMPLATE/`).
