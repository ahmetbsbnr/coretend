# Workspace cleanup record

Date: 2026-08-01

The canonical CoreTend source remains this repository. Generated and historical
materials were classified rather than silently deleted.

## Archived

- `docs/apple-support/` → `Documentation/Archive/WorkspaceLegacy/apple-support/`
  (historical proposal bundle and screenshots).
- `graphify-out/` → `Documentation/Archive/WorkspaceLegacy/graphify-out/`
  (generated graph report and graph data).
- `Documentation/RESCUE_STATUS.md` →
  `Documentation/Archive/WorkspaceLegacy/RESCUE_STATUS.md` (historical rescue
  log containing paths that must not be used as product documentation).

## Backup and recovery

Before the moves, a byte-preserving backup was written to
`/Users/ahmetbasbunar/Developer/Website/_backups/coretend-workspace-20260801/`.
The backup contains the original directories, the rescue report, generated
cache material, and `SHA256SUMS`. Recovery is a copy-back operation; the active
repository does not depend on these files.

## Retained generated material

Build output, `.build`, DerivedData, DMG/ZIP artifacts and preview caches are
not source inputs and remain outside the tracked tree. No personal files were
deleted and no iCloud checkout was made canonical.
