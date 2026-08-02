# ROADMAP

Status values: COMPLETE, PARTIAL, IMPLEMENTED_UNVERIFIED, BLOCKED_ENVIRONMENT,
BLOCKED_HUMAN, DEFERRED, NOT_STARTED.

This file historically tracked v0.1-era planning order and had drifted years
out of date (it still read "Persistence ← NEXT" and "Applications: not
started" after both had long since shipped). Rewritten against the actual
v0.7.1 state (114/114 passing), then again through the 0.8.0 — Functional
Completion phase (`feat/functional-completion`, see
`Documentation/FUNCTIONAL_COMPLETION_EXECUTION_PLAN.md` for the authoritative
21-step tracker; 250/250 passing at this update, version now 0.8.0 — local
version bump only, no push/deploy/publish). See
`Documentation/FEATURE_MATRIX.md` for per-module detail and
`Documentation/CHANGELOG.md` for the version history.

## Shipped (v0.1 → v0.8.0)

1. COMPLETE — App shell + design system (Orbital Ecology tokens: MCColor/MCSpacing/MCMotion/MCFont)
2. COMPLETE — ScanCore (streaming, cancellation, exclusions, min-size/age filters)
3. COMPLETE — SafetyCore (validator, typed approval, execution re-validation, Trash action, SQLite-persisted audit log)
4. COMPLETE — Persistence (SQLite actor, migrations apply-once/idempotent)
5. COMPLETE — Smart Care review-and-confirm orchestrator
6. COMPLETE — Cleanup user rules (7 rules, grouped review)
7. COMPLETE — My Clutter (large/old, duplicates, similar images)
8. COMPLETE — Space Lens treemap
9. COMPLETE — Applications + Leftovers
10. COMPLETE — Performance
11. COMPLETE — Menu Bar agent
12. COMPLETE — IntegrityCore (native download provenance, code-signature tiers and login-item inventory; read-only, with no malware-detection or quarantine claim)
13. COMPLETE — Privacy Cleaner
14. COMPLETE — Cloud Cleanup
15. COMPLETE — Accessibility pass (5 previously-unannotated views + 3 system settings, per commit b8fb716)
16. COMPLETE — Hardening / compliance pass (SafetyCore audit persistence, Privacy Cleaner running-browser guard, CI split into normal vs publish gate; the former external-scanner experiment was subsequently retired)
17. COMPLETE — Local packaging (`Scripts/package-local.sh`, `Scripts/package-zip.sh`, `Scripts/package-dmg.sh`)
18. COMPLETE — Open-source foundation (LICENSE/NOTICE/COPYRIGHT/TRADEMARKS/THIRD_PARTY_NOTICES, community docs, CI)
19. COMPLETE — Bilingual static website skeleton (`Website/generate.py`, en/fr, no tracking)
20. COMPLETE — Functional Completion phase (v0.8.0): Cleanup finalized at 10 rules with deferred-scope decisions documented; Protection FSEvents watch full test matrix; My Clutter search/volume/exclusions; Space Lens + Cloud Cleanup testability; macOS-14 compatibility audit; stress tests; code-level accessibility audit; first-run wizard; animation verification; documentation sync

## Not shipped

- NOT_STARTED — Privileged helper: no Developer ID signing identity available; every current feature works unprivileged, so this was deferred by choice rather than blocked mid-build.
- DEFERRED — Browser history/cookie removal in Privacy Cleaner: deliberately deferred, DB-corruption risk on live browser profiles judged not worth it for marginal space gain.
- DEFERRED — Extended cleanup rules needing dedicated safety engines rather than plain extension/age rules: iOS Simulators (distinguish caches/unavailable-devices/runtimes/active devices; use official `simctl` mechanisms, never blind delete), Trash-emptying (separate strong-confirmation action, never automatic), Mail attachments (never touch Mail DBs; report-only), broken LaunchAgents (detect invalid plist/missing target; reveal/exclude, Trash plist only after review). Not shipped as blind rules — full rationale per candidate in `REQUIREMENTS_DECISION_HISTORY.md`.
- BLOCKED_ENVIRONMENT — Interactive VoiceOver verification, and a full FR/EN × light/dark × every-module screenshot capture campaign for `Documentation/VisualAudit/After`. A real display IS available in this sandbox (re-confirmed 2026-07-24) and one verification capture succeeded; the sidebar-navigation capture path needs a follow-up fix. Not a code defect, not a version blocker per this phase's scope decision — see `KNOWN_LIMITATIONS.md`.
- BLOCKED_HUMAN — Public identity fields (`Configuration/PublicIdentity.local.json`: legal name, address, domain, security contact) and code signing/notarization — both require the maintainer's real-world decisions/credentials, not more engineering. Blocks public push/deploy, not this local version bump.

## Next (not started this pass, no date commitment)

- Fill BLOCKED_HUMAN items, then re-run `Scripts/check-publish-readiness.sh` before any public push.
- Root-cause the sidebar-navigation `capture.sh` window-index flake, then run the full FR/EN × light/dark × every-module capture campaign; finish `Documentation/VISUAL_QA.md` checkboxes.
- Additional locales beyond en/fr, if there's demonstrated demand.
- Revisit the four deferred Cleanup candidates (Simulators/Trash-empty/Mail-attachments/LaunchAgents) if a dedicated safety engine for one of them becomes worth building.
