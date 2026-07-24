# Troubleshooting

## The app won't open / Gatekeeper blocks it
There is no signed public release yet (see
`Documentation/PUBLIC_RELEASE_READINESS.md`); local ad-hoc builds can
trigger Gatekeeper. Approve it via System Settings → Privacy & Security.
Do not disable Gatekeeper/SIP as a routine fix.

## A scan finds nothing / fewer results than expected
Likely missing Full Disk Access. Check Settings → the FDA indicator, or see
[FULL_DISK_ACCESS.md](FULL_DISK_ACCESS.md). The app is honest when it can't
read a folder — it skips it rather than guessing.

## Protection says ClamAV is not installed
`clamscan` isn't found at any of the expected Homebrew/MacPorts paths. See
[CLAMAV.md](CLAMAV.md) for install instructions. CoreTend does not
bundle ClamAV.

## I deleted something I need back
See [RESTORE.md](RESTORE.md) (Cleanup/Smart Care — check the Trash) or
[QUARANTINE.md](QUARANTINE.md) (Protection findings).

## The app seems to have wrong/stale totals or a truncated list
Very large result sets are capped for on-screen display (a UI
responsiveness limit, not a data-loss bug) — totals and actions still
apply to everything found. See `Documentation/CHANGELOG.md` (the "totals
fix, scan-scope audit" entry) and `Documentation/KNOWN_LIMITATIONS.md`.

## I want to reset all local data and start over
`Scripts/uninstall-local.sh --dry-run` to preview, then without `--dry-run`
to remove the app's local database, quarantine, and preferences. See
[UNINSTALL.md](UNINSTALL.md) and [DATA_LOCATIONS.md](DATA_LOCATIONS.md).

## Build fails from source
Run `Scripts/doctor.sh` first — it checks prerequisites (macOS version,
Apple Silicon, Swift toolchain). See [DEVELOPMENT.md](../DEVELOPMENT.md).

## Still stuck
Open an issue using the templates in `.github/ISSUE_TEMPLATE/` (include
CoreTend version, macOS version, Apple Silicon model, steps to
reproduce — no private data/logs beyond what's needed). For a suspected
security issue, use [SECURITY.md](../SECURITY.md) instead of a public
issue.
