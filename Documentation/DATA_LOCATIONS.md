# Data Locations

MacCare Local stores all of its own data locally, on the Mac it runs on. No
account, no cloud sync, no telemetry.

| Data | Path |
|---|---|
| Activity history, exclusions, settings (SQLite) | `~/Library/Application Support/MacCareLocal/store.sqlite` |
| Quarantined files (Protection) | `~/Library/Application Support/MacCareLocal/Quarantine/` |
| Quarantine manifest (JSON) | `~/Library/Application Support/MacCareLocal/Quarantine/manifest.json` |
| App preferences | `~/Library/Preferences/local.maccare.app.plist` |

Files removed via Cleanup/Smart Care go to the macOS Trash (`~/.Trash`) by
default, not to any MacCare Local–owned folder — see
[RESTORE.md](RESTORE.md). Only Protection's malware quarantine uses the
app-owned `Quarantine/` folder above, because a detected file must not
remain executable in place.

## Deleting all local data

Run `Scripts/uninstall-local.sh --dry-run` to preview what would be removed,
or `Scripts/uninstall-local.sh` to remove the app bundle (if installed in
`/Applications`), the Application Support folder, and the preferences file.
See [UNINSTALL.md](UNINSTALL.md). If you have quarantined items you still
want to restore, do that first — see [QUARANTINE.md](QUARANTINE.md).

## What is never written

MacCare Local does not send data anywhere. There is no server component, no
analytics SDK, no crash reporter that phones home. Everything above stays on
disk until you delete it yourself.
