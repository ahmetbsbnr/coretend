# ROADMAP

Status values: COMPLETE, PARTIAL, IMPLEMENTED_UNVERIFIED, BLOCKED_ENVIRONMENT,
BLOCKED_HUMAN, DEFERRED, NOT_STARTED.

This file historically tracked v0.1-era planning order and had drifted years
out of date (it still read "Persistence ← NEXT" and "Applications: not
started" after both had long since shipped). Rewritten against the actual
v0.7.1 state (114/114 passing) and updated again during the 0.8.0 —
Functional Completion phase (`feat/functional-completion`, see
`Documentation/FUNCTIONAL_COMPLETION_EXECUTION_PLAN.md` for the authoritative
21-step tracker; 215/215 passing at this update). See
`Documentation/FEATURE_MATRIX.md` for per-module detail and
`Documentation/CHANGELOG.md` for the version history.

## Shipped (v0.1 → v0.7.1)

1. COMPLETE — App shell + design system (Orbital Ecology tokens: MCColor/MCSpacing/MCMotion/MCFont)
2. COMPLETE — ScanCore (streaming, cancellation, exclusions, min-size/age filters)
3. COMPLETE — SafetyCore (validator, center, dry-run default, re-validation, SQLite-persisted audit log)
4. COMPLETE — Persistence (SQLite actor, migrations apply-once/idempotent)
5. COMPLETE — Smart Care dry-run orchestrator
6. COMPLETE — Cleanup user rules (7 rules, grouped review)
7. COMPLETE — My Clutter (large/old, duplicates, similar images)
8. COMPLETE — Space Lens treemap
9. COMPLETE — Applications + Leftovers
10. COMPLETE — Performance
11. COMPLETE — Menu Bar agent
12. PARTIAL — Protection (ClamAV wrapper + quarantine tested; optional `ProtectionWatcher` FSEvents actor now built and wired into the UI as off-by-default in-session watch — debounce/coalesce/dedup/rate-limit/clean-restart tested; no ClamAV binary on this machine, so the live-scan path stays unverified here, not unbuilt)
13. COMPLETE — Privacy Cleaner
14. COMPLETE — Cloud Cleanup
15. COMPLETE — Accessibility pass (5 previously-unannotated views + 3 system settings, per commit b8fb716)
16. COMPLETE — Hardening / compliance pass (v0.7.1: SafetyCore audit persistence, ClamAV wrapper timeout/cancellation, Privacy Cleaner running-browser guard, CI split into normal vs publish gate)
17. COMPLETE — Local packaging (`Scripts/package-local.sh`, `Scripts/package-zip.sh`, `Scripts/package-dmg.sh`)
18. COMPLETE — Open-source foundation (LICENSE/NOTICE/COPYRIGHT/TRADEMARKS/THIRD_PARTY_NOTICES, community docs, CI)
19. COMPLETE — Bilingual static website skeleton (`Website/generate.py`, en/fr, no tracking)

## Not shipped

- NOT_STARTED — Privileged helper: no Developer ID signing identity available; every current feature works unprivileged, so this was deferred by choice rather than blocked mid-build.
- DEFERRED — Browser history/cookie removal in Privacy Cleaner: deliberately deferred, DB-corruption risk on live browser profiles judged not worth it for marginal space gain.
- DEFERRED — Extended cleanup rules needing dedicated safety engines rather than plain extension/age rules: iOS Simulators (distinguish caches/unavailable-devices/runtimes/active devices; use official `simctl` mechanisms, never blind delete), Trash-emptying (separate strong-confirmation action, never automatic), Mail attachments (never touch Mail DBs; report-only), broken LaunchAgents (detect invalid plist/missing target; reveal/exclude, Trash plist only after review). Not shipped as blind rules.
- BLOCKED_ENVIRONMENT — Real-machine screenshot capture for `Documentation/VisualAudit/After` (no attached display / window capture in any automated session to date, including this one).
- BLOCKED_HUMAN — Public identity fields (`Configuration/PublicIdentity.local.json`: legal name, address, domain, security contact) and code signing/notarization — both require the maintainer's real-world decisions/credentials, not more engineering.

## Next (not started this pass, no date commitment)

- Fill BLOCKED_HUMAN items, then re-run `Scripts/check-publish-readiness.sh` before any public push.
- Capture real After screenshots on a machine with an attached display; finish `Documentation/VISUAL_QA.md` checkboxes.
- Additional locales beyond en/fr, if there's demonstrated demand.
