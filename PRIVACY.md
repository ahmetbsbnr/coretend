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
  privacy cleaner cache scan, my activity).

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
