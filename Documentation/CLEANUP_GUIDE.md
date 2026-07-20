# Cleanup Guide

Cleanup finds files that are very likely safe to remove — caches, logs,
leftovers, duplicates, similar/near-duplicate images, large unused files —
and lets you review before anything happens.

## Flow (`Sources/MacCareApp/CleanupView.swift`)

1. **Idle** — press "Start Scan."
2. **Scanning** — progress (files scanned, bytes found so far) streams live.
3. **Review** — findings are grouped by category. Each item is individually
   selectable/deselectable; totals update as you toggle. If the list is
   very large the UI truncates the on-screen count but still totals and
   acts on everything found — see `Documentation/KNOWN_LIMITATIONS.md` and
   the 5000-row display-cap fix noted in `CHANGELOG.md`.
4. **Run** — the button reads "Simulate" in dry-run mode or "Move to
   Trash" otherwise. Nothing is permanently deleted by Cleanup: items go to
   the macOS Trash, recoverable per [RESTORE.md](RESTORE.md).
5. **Done** — shows bytes freed (or, in dry-run, bytes that would be
   freed).

## Dry-run

Toggle dry-run in Settings or in the Cleanup view before running. Dry-run
performs the full scan and shows exactly what would be removed, but skips
the actual move-to-Trash step. Recommended for your first run.

## What gets scanned

Cleanup's engines live in `ScanCore` (`Sources/ScanCore/`): duplicate files
(`DuplicateEngine`), near-duplicate/similar images
(`SimilarImagesEngine`), and general space usage (`SpaceLensEngine`), each
gated by `SafetyCore`'s `PathValidator` (see [SAFETYCORE.md](SAFETYCORE.md))
so protected system paths and your Documents/Desktop/Pictures/Music/Movies
roots are never auto-selected.

## Safety

Every candidate path is risk-rated (`RiskLevel`: low/medium/high) before
being offered. See [SAFETY_MODEL.md](SAFETY_MODEL.md). Exclusions you've
added (see [EXCLUSIONS.md](EXCLUSIONS.md)) are respected on every scan.
