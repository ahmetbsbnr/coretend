# DECISIONS

## D1 — SwiftPM instead of Xcode project (2026-07-19)
Machine has only CommandLineTools; `xcodebuild` unavailable. Project is a SwiftPM package;
the .app bundle is assembled by `Scripts/package-local.sh` (release binary + Info.plist +
ad-hoc codesign). If Xcode is installed later, an .xcodeproj can be generated without
restructuring.

## D2 — Swift Testing instead of XCTest (2026-07-19)
XCTest is not shipped with CommandLineTools. Swift Testing framework is (under
Library/Developer/Frameworks) but needs explicit -F/-rpath flags → `Scripts/test.sh`.

## D3 — Dry-run ON by default (2026-07-19)
SafetyCenter defaults to dryRun=true; the user must explicitly flip the toggle to move
anything to the Trash. Safest default per SAFETY_MODEL.

## D4 — Symlinks skipped during scans (2026-07-19)
ScanEngine skips symlinks entirely (no descend, no finding). Prevents loops and
allowlist escapes. Following-with-loop-guard can be added later if a real need appears.

## D5 — macOS deployment target 14 (2026-07-19)
Target machine runs macOS 26; .v14 keeps Observation/NavigationSplitView available with
headroom. No reason to require .v26 APIs yet.
