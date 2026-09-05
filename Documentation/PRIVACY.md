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

The macOS integration layer (App Intents / Shortcuts, local notifications,
scheduled scans, the desktop widget) is local and read-only. Shortcuts
cannot delete, clean up, empty the Trash, restore, or disable a login item;
the image-metadata Shortcut does not store the file path. Local
notifications (`UNUserNotificationCenter`, no push/server) carry totals only
— never a path, name, location, GPS value, or browser profile — and every
category is toggleable in Settings with permission requested only from an
explicit action. Scheduled scans (`NSBackgroundActivityScheduler`, opt-in
Off/Daily/Weekly) update Storage Timeline and may notify, and never mutate
the filesystem. The **WidgetKit widget** is read-only and shows aggregates
only (free-of-total disk space, a worded storage trend, optionally a
recoverable total / last-scan date / activity kind); it never shows a path,
filename, GPS value, restore-item name, image metadata value, browser
profile, or security finding. The app publishes those numbers to the widget
as a small versioned JSON snapshot in a shared App Group container
(`group.com.ahmetbsbnr.coretend`) — the widget never opens the app's
database, and nothing leaves this Mac; a missing snapshot shows "unavailable"
rather than a fabricated `0`. See `Documentation/MACOS_INTEGRATIONS.md`.
