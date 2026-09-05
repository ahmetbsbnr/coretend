# Privacy

CoreTend runs entirely locally. This document states plainly what
that means.

## No telemetry, no accounts

- No user accounts, no sign-in, no subscription.
- No telemetry, no usage analytics, no crash reporting sent to any
  server.
- No advertising, no ad SDKs.
- No network calls as part of any core feature (cleanup, duplicates,
  space analysis, similar images, applications/leftovers, performance,
  privacy cleaner cache scan, Privacy Lab image-metadata inspection,
  my activity, App Intents / Shortcuts, local notifications, scheduled
  scans, the desktop widget).
- App Intents / Shortcuts are entirely local and read-only. No Shortcut
  can clean up, delete, empty the Trash, restore, or disable a login item.
  The image-metadata Shortcut does not store the file path.
- Local notifications are `UNUserNotificationCenter` only — no push, no
  server. They contain **totals only** (e.g. "8.4 GB potentially
  recoverable"), never a file path, name, location, GPS value, or browser
  profile name. Permission is requested only from an explicit Settings /
  onboarding action, and every category can be turned off in Settings.
- Scheduled scans are opt-in and read-only: they update Storage Timeline
  and may send a notification, and never clean up, delete, or move anything.
- The **desktop widget** (WidgetKit) is read-only and shows **aggregates
  only** — free disk space of total, a worded storage trend, and optionally
  a recoverable total / last-scan date / last-activity kind. It never shows
  a file path, filename, GPS value, restore-item name, image metadata value,
  browser profile name, or security finding. The app hands the widget these
  numbers through a small versioned JSON snapshot in a shared **App Group**
  container (`group.com.ahmetbsbnr.coretend`) on this Mac; the widget never
  opens the app's database and nothing leaves the machine. If no snapshot
  exists yet the widget says so rather than showing a fake `0`.

## The one product network request

The Integrity tab reads only local, already-existing macOS metadata (download
quarantine attributes, code-signature status, login items); none of it is sent
anywhere. A user-initiated update check may request the public
`https://coretend.ahmetbsbnr.com/latest.json` manifest. It does not upload scan
findings, paths or an index of files. The app ships no analytics alongside it.

## Data storage

All app data (scan history, quarantine records, "My Activity" history,
preferences) is stored locally in this Mac's standard per-app storage
locations. Nothing is synced to any CoreTend–operated server,
because none exists. See
[Documentation/DATA_LOCATIONS.md](Documentation/DATA_LOCATIONS.md) and
[Documentation/PERSISTENCE.md](Documentation/PERSISTENCE.md) for exact
paths and schema.

The ordinary safety/audit log stores **redacted** paths only. The one
exception is the **Restore Center manifest** (DB schema v7): to move a
CoreTend-Trashed file back to where it came from, CoreTend records that
item's real original and Trash locations locally. This record never leaves
this Mac, is never synced or transmitted, is excluded from the diagnostic
report, and can be cleared at any time with **Forget Restore History**
(which removes records only — it never empties the Trash). Entries are
pruned automatically after 90 days (30 for items no longer restorable). See
[Documentation/RESTORE.md](Documentation/RESTORE.md).

## Deletions

Deletions default to the Trash, not permanent removal, so mistakes stay
recoverable. See [Documentation/RESTORE.md](Documentation/RESTORE.md).

## Full Disk Access

Some scans require macOS's Full Disk Access permission to see into
protected locations. This permission is requested transparently through
macOS's own consent UI and used only to read/report/act on files you
choose to act on — never uploaded anywhere. See
[Documentation/FULL_DISK_ACCESS.md](Documentation/FULL_DISK_ACCESS.md).

## Source availability

Because the project is open source, every claim above is independently
verifiable by reading the source rather than trusting this document. See
[Documentation/SAFETY_MODEL.md](Documentation/SAFETY_MODEL.md) and
[Documentation/THREAT_MODEL.md](Documentation/THREAT_MODEL.md) for the
detailed model.

## Contact

Security-relevant privacy concerns: see [SECURITY.md](SECURITY.md), which
routes them to [GitHub private vulnerability
reporting](https://github.com/ahmetbsbnr/coretend/security/advisories/new).
