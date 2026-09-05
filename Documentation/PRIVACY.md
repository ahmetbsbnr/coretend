# PRIVACY
CoreTend is fully offline. No telemetry, no accounts, no network calls, no
analytics. All scan results and audit logs stay on this Mac. Deletion uses the
system Trash by default and is reversible from there.

Privacy Lab inspects the metadata embedded in an image the user explicitly
selects. The analysis is local and read-only: the image is never modified,
metadata (including GPS coordinates) is held only in memory for that
inspection and is not persisted, logged, or sent anywhere, and no Photos
Library is scanned. See `Documentation/PRIVACY_LAB.md`.

Restore Center keeps a local, private manifest (DB schema v7) of the real
original and Trash locations of items CoreTend moved to the Trash, so it can
move them back. The ordinary audit log stays redacted; this manifest is
never synced or transmitted, is excluded from the diagnostic report, is
bounded to 90 days (30 for terminal states), and is cleared by "Forget
Restore History" — which never empties the Trash. See
`Documentation/RESTORE.md`.
