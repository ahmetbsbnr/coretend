# Privacy

MacCare Local runs entirely locally. This document states plainly what
that means.

## No telemetry, no accounts

- No user accounts, no sign-in, no subscription.
- No telemetry, no usage analytics, no crash reporting sent to any
  server.
- No advertising, no ad SDKs.
- No network calls as part of any core feature (cleanup, duplicates,
  space analysis, similar images, applications/leftovers, performance,
  privacy cleaner cache scan, my activity).

## The one optional network dependency

The Protection module's malware scanning is powered by a
separately-installed, optional ClamAV. If you choose to update ClamAV's
virus definitions, that update process contacts ClamAV's own definition
mirrors — not a MacCare Local server, and only when you trigger it. See
[Documentation/CLAMAV.md](Documentation/CLAMAV.md) and
[Documentation/PROTECTION_LIMITATIONS.md](Documentation/PROTECTION_LIMITATIONS.md).
The app itself ships no analytics alongside this.

## Data storage

All app data (scan history, quarantine records, "My Activity" history,
preferences) is stored locally in this Mac's standard per-app storage
locations. Nothing is synced to any MacCare Local–operated server,
because none exists. See
[Documentation/DATA_LOCATIONS.md](Documentation/DATA_LOCATIONS.md) and
[Documentation/PERSISTENCE.md](Documentation/PERSISTENCE.md) for exact
paths and schema.

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

Security-relevant privacy concerns: see [SECURITY.md](SECURITY.md)
(`[SECURITY_CONTACT_TO_DEFINE]` until a monitored channel is set up — see
[Documentation/HUMAN_BLOCKERS.md](Documentation/HUMAN_BLOCKERS.md)).
