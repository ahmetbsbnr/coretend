# User Guide

MacCare Local est un utilitaire macOS open source conçu pour analyser,
nettoyer, organiser et optimiser les Mac Apple Silicon. Il fonctionne
entièrement en local, sans compte, sans abonnement et sans télémétrie.
Chaque élément détecté est expliqué avant toute action, et les suppressions
utilisent par défaut la Corbeille afin de rester réversibles.

This guide indexes the rest of `Documentation/` for end users. Start here,
then follow the links for the area you need.

## Getting started
- [INSTALLATION.md](INSTALLATION.md) — build/install from source.
- [FIRST_LAUNCH.md](FIRST_LAUNCH.md) — onboarding, first scan.
- [FULL_DISK_ACCESS.md](FULL_DISK_ACCESS.md) — the one permission the app
  asks for, and what happens if you skip it.

## Features
- [SMART_CARE.md](SMART_CARE.md) — one-click combined scan/clean.
- [CLEANUP_GUIDE.md](CLEANUP_GUIDE.md) — caches, duplicates, similar
  images, large files.
- [PROTECTION.md](PROTECTION.md) — local malware scan (ClamAV) and
  quarantine.
- [EXCLUSIONS.md](EXCLUSIONS.md) — tell scans to leave a path alone.

## Safety
- Dry-run is the default everywhere destructive: see each feature doc
  above for its dry-run behavior.
- [RESTORE.md](RESTORE.md) — undo a cleanup (Trash).
- [QUARANTINE.md](QUARANTINE.md) — undo a Protection action.
- [SAFETY_MODEL.md](SAFETY_MODEL.md) — the engineering rules behind "never
  touch system paths."
- [KNOWN_LIMITATIONS.md](KNOWN_LIMITATIONS.md) and
  [PROTECTION_LIMITATIONS.md](PROTECTION_LIMITATIONS.md) — what MacCare
  Local does not claim to do.

## Your data
- [DATA_LOCATIONS.md](DATA_LOCATIONS.md) — where local data lives and how
  to delete it.
- [UNINSTALL.md](UNINSTALL.md) — full removal.

## When something goes wrong
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- [FAQ.md](FAQ.md)
- [SECURITY.md](../SECURITY.md) — reporting a vulnerability.
- Bug reports: `.github/ISSUE_TEMPLATE/`.

## What MacCare Local is not

Not affiliated with CleanMyMac, MacPaw, or Apple. Not a full antivirus or a
security guarantee. Not a "miracle" speed booster. Not AI-generated or a
school/portfolio project — it's a maintained open source utility.
