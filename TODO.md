# TODO — CoreTend

CoreTend 1.0.0 shipped on 2026-09-03. It is Developer ID signed,
Apple-notarized, stapled, Minisign-signed, and published as a stable GitHub
release. Core functionality is complete; 383 Swift tests pass (post-1.0.0
work — Storage Timeline then Advisor — added 41 since the 342 that shipped
in 1.0.0).

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

## Done — Storage Timeline minimal vertical (1.1 "Insight" scope)

"What changed since my last scan?" is now answerable end to end: `Persistence`
schema v6 (`timeline_snapshots` incl. `scope`, `timeline_categories`), a
`TimelineService` layer, a real `StorageTimelineView` (sidebar, under
Storage), and a Dashboard "Since last scan" card. Comparisons never mix scan
kinds — every one is scoped (Cleanup/Duplicates/Leftovers/Privacy today) and
the cross-scope Dashboard card only ever compares a scan against the previous
snapshot of that same scope. Category aggregates only, never file paths.
See `Documentation/FEATURE_MATRIX.md` → "Storage Timeline" and
`Documentation/PERSISTENCE.md` → "Timeline" for the full detail, including
which engines are deliberately not wired yet and why (My Clutter/Large & Old,
Space Lens, Similar Images, Cloud Cleanup).

Follow-up, not blocking the vertical above: wiring more engines as their
scan semantics allow it; richer physical/APFS-aware sizing (planned as its
own "APFS Intelligence" roadmap item); a WidgetKit surface reusing
`TimelineService`.

## Done — CoreTend Advisor minimal vertical

A deterministic, local, read-only explanation layer between scan engines and
UI: `AdvisorFinding`/`AdvisorService`/`AdvisorDetailsView`
(`Sources/CoreTendApp/`). Reuses `SafetyCore.RiskLevel` and `TimelineScope`
rather than inventing parallel taxonomies; adds `AdvisorConfidence`
(exact/high/probable/uncertain) and `AdvisorReversibility`, since neither
existed. Wired and visible in the UI: Cleanup, Duplicates, Leftovers,
Privacy. See `Documentation/FEATURE_MATRIX.md` → "CoreTend Advisor" and
`Documentation/SAFETY_MODEL.md` → "Advisor" for the full mapping and why
Applications/Integrity aren't connected yet.

Recovery Plan readiness: `AdvisorFinding` already exposes everything Recovery
Plan needs structurally (`reclaimableBytes`, `risk`, `confidence`, `category`,
`reversibility`) — Recovery Plan should consume these fields directly, never
parse Advisor's UI text. Not yet decided: an explicit `isEligibleForRecoveryPlanning`
rule (deferred to when Recovery Plan's actual eligibility criteria are
defined, rather than guessed at now).

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
