# TODO — CoreTend

CoreTend 1.0.1 is the current stable release (2026-09-18). It is Developer ID
signed, Apple-notarized, stapled, Minisign-signed (`F8473FB09E1DB730`), and
published as a stable GitHub release. 381 Swift tests pass.

**1.0.0 and 1.2.0-beta.1 do not open.** Both trap at launch (SIGTRAP) on every
Mac except the one that built them: SwiftPM's generated `Bundle.module`
accessor resolved only from the `.app` root and the build machine's own scratch
directory, while the resource bundle ships in `Contents/Resources`. The build
machine had that directory, so the app ran for whoever built it and for nobody
else. Both releases carry an explicit warning in their titles and notes; 1.0.1
fixes it. This is why "core functionality is complete" was true of the source
and false of the artifact — the two are not the same claim.

## Release follow-up

Completed 2026-09-04 by maintainer verification: interactive VoiceOver,
keyboard traversal, focus visibility, Dynamic Type, second-Mac/different-macOS
compatibility, and 44-frame native FR/EN × light/dark × every-module visual
matrix. See `Documentation/HUMAN_QA_REPORT.md`.

Release-workflow provenance plumbing is complete for the next release:
`.github/workflows/release.yml` now uses the dedicated signing Mac and applies
Developer ID signing, notarization, stapling, SHA-256, SLSA attestation and
Minisign to the same final bytes. A retrospective SLSA attestation for 1.0.0
would still be false and will not be created.

## Deliberately deferred product scope

- Additional locales beyond English and French.
- Browser history/cookie deletion; cache-only cleaning avoids live-profile DB
  corruption.
- Dedicated safe engines for iOS Simulators, emptying Trash, Mail attachments,
  and broken LaunchAgents. Never implement these as blind file rules.
- Possible privileged helper and Mac App Store edition. Neither is required by
  current features or promised to users.

## Future product ideas — not shipped, not promised

These are recorded proposals only. They require a separate product and safety
review before any implementation:

- Developer cleanup: Xcode DerivedData and iOS Simulator caches, with explicit
  scope and confirmation for every location.
- Universal-binary size analysis: report removable Intel slices first; never
  alter an app without signature-aware validation and a reversible path.
- Complete app uninstall: discover related support files with a reviewed,
  app-specific allowlist rather than broad `~/Library` deletion.
- Expanded native security signals beyond Integrity's current read-only scope.
- Background-item manager: list LaunchAgents, LaunchDaemons and login items;
  any disable action would need explicit review and rollback.
- Sensitive-metadata cleaner: EXIF/device/date inspection and opt-in removal.
- Notification Center widget showing free space and linking to the main app.
- Optional CLI destructive workflows remain deferred; `coretend-cli` now ships
  read-only rule/path inspection with no filesystem mutation.
- Shortcuts actions for inspect/report workflows, with confirmation before any
  destructive action.

Historical TODOs live under `Documentation/Archive/` and
`Documentation/Audits/`. `Documentation/PROJECT_STATE.json` is current machine-
readable state; `Documentation/RELEASE_STATE.md` carries release evidence.
