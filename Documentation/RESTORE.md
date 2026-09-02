# Restore / Undo a Cleanup

CoreTend's cleanup and Smart Care actions delete files by moving them
to the macOS **Trash** by default — not by permanent deletion — precisely so
mistakes are recoverable.

## Restoring files removed by Cleanup / Smart Care

1. Open **Finder → Trash**.
2. Find the item(s) — macOS preserves the original name; if you need to
   confirm origin, check CoreTend's Activity/History view for the scan
   summary (path, size, and date) recorded at cleanup time.
3. Right-click → **Put Back**, or drag the item back to its original
   location.

As long as you have not emptied the Trash, the removal is fully reversible.
Emptying the Trash (from Finder, or via "Empty Trash" automation) is a
macOS-level action outside CoreTend's control and is final.

## Cleanup restore — no separate manifest

Cleanup-capable modules have **no app-level
restore manifest of their own** — the only record kept is the Activity
history summary (counts, size and timestamp), not a per-file path list.
Recoverability depends entirely on the macOS Trash (see above), not on any
CoreTend restore code. CoreTend cannot programmatically restore an individual
cleaned file by name; use Finder's Trash “Put Back”. Integrity is read-only and
therefore has no restore or quarantine path.

## If something looks wrong after a cleanup

1. Check the Trash first — most removed files are still there.
2. See [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
3. If you believe CoreTend removed something it should not have,
   report it per [SECURITY.md](../SECURITY.md) or open a bug report (see
   `.github/ISSUE_TEMPLATE/`).
