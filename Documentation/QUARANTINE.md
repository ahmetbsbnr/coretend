# Quarantine (Protection)

Protection's malware scanner never deletes a detected file automatically.
When you choose to act on a finding, CoreTend moves the file into its
own quarantine folder instead — this is reversible.

## How it works

- Location: `~/Library/Application Support/CoreTend/Quarantine/`
- Each quarantined file is moved (not copied) out of its original location
  and renamed to a random, unique name so it cannot be double-clicked or
  run by accident.
- Its permissions are stripped to read-only for the owner (`0o400`) —
  removing execute access.
- A manifest (`manifest.json` in that folder) records the original path,
  the detection signature, and the date, so the file can be put back
  exactly where it came from.

This is implemented by the `Quarantine` actor in
`Sources/MalwareEngine/MalwareEngine.swift` — see
[SAFETYCORE.md](SAFETYCORE.md) / source for details. The file is never
executed, opened, or modified by CoreTend at any point.

## Restoring a quarantined file

Open Protection → the quarantine list shows every item currently held.
Choose **Restore** on an item to move it back to its original path with
normal permissions restored. If the original folder no longer exists, the
restore will fail — the file stays safely in quarantine.

## Permanently deleting a quarantined item

Choose **Delete Permanently** — this is a separate, explicit action from
quarantining, and is irreversible (it does not use the Trash). Only do this
for items you are confident you don't need.

## What Protection is not

ClamAV-backed scanning (see [PROTECTION.md](PROTECTION.md) and
[CLAMAV.md](CLAMAV.md)) is a local, on-demand signature scan. It is not a
real-time antivirus, not a full endpoint-security product, and not a
guarantee against malware. See
[PROTECTION_LIMITATIONS.md](PROTECTION_LIMITATIONS.md).
