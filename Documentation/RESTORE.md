# Restore / Undo a Cleanup

MacCare Local's cleanup and Smart Care actions delete files by moving them
to the macOS **Trash** by default — not by permanent deletion — precisely so
mistakes are recoverable.

## Restoring files removed by Cleanup / Smart Care

1. Open **Finder → Trash**.
2. Find the item(s) — macOS preserves the original name; if you need to
   confirm origin, check MacCare Local's Activity/History view for the scan
   summary (path, size, and date) recorded at cleanup time.
3. Right-click → **Put Back**, or drag the item back to its original
   location.

As long as you have not emptied the Trash, the removal is fully reversible.
Emptying the Trash (from Finder, or via "Empty Trash" automation) is a
macOS-level action outside MacCare Local's control and is final.

## Restoring items flagged by Protection

Malware-scan findings use a separate mechanism — the app-owned Quarantine
folder, not the Trash. See [QUARANTINE.md](QUARANTINE.md) for how to
restore those.

## Dry-run mode

Every scan/clean flow (Cleanup, Smart Care, Protection) supports a
**dry-run** mode: the scan runs and shows exactly what would be removed and
how much space it would free, but nothing is deleted. Review the dry-run
results before running for real. Activity history records whether an entry
was a dry run (`dryRun` field in `~/Library/Application
Support/MacCareLocal/store.sqlite`).

## If something looks wrong after a cleanup

1. Check the Trash first — most removed files are still there.
2. Check Protection → Quarantine if the item relates to a malware finding.
3. See [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
4. If you believe MacCare Local removed something it should not have,
   report it per [SECURITY.md](../SECURITY.md) or open a bug report (see
   `.github/ISSUE_TEMPLATE/`).
