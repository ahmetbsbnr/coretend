# ROADMAP

Status values: COMPLETE, PARTIAL, IMPLEMENTED_UNVERIFIED, BLOCKED_ENVIRONMENT,
BLOCKED_HUMAN, DEFERRED, NOT_STARTED.

This file historically tracked v0.1-era planning order and had drifted years
out of date (it still read "Persistence ← NEXT" and "Applications: not
started" after both had long since shipped). Rewritten this pass against the
actual v0.7.1 state confirmed via `Sources/`, `Documentation/feature-inventory.json`,
and a real `Scripts/test.sh` run (114/114 passing). See `Documentation/FEATURE_MATRIX.md`
for per-module detail and `Documentation/CHANGELOG.md` for the version history.

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
12. PARTIAL — Protection (ClamAV wrapper + quarantine tested; no ClamAV binary on this machine, so the live-scan path is unverified here, not unbuilt)
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
- DEFERRED — FSEvents live downloads watch: nice-to-have, not required for any v0.7.1 commitment.
- BLOCKED_ENVIRONMENT — Real-machine screenshot capture for `Documentation/VisualAudit/After` (no attached display / window capture in any automated session to date, including this one).
- BLOCKED_HUMAN — Public identity fields (`Configuration/PublicIdentity.local.json`: legal name, address, domain, security contact) and code signing/notarization — both require the maintainer's real-world decisions/credentials, not more engineering.

## Next (not started this pass, no date commitment)

- Fill BLOCKED_HUMAN items, then re-run `Scripts/check-publish-readiness.sh` before any public push.
- Capture real After screenshots on a machine with an attached display; finish `Documentation/VISUAL_QA.md` checkboxes.
- Additional locales beyond en/fr, if there's demonstrated demand.
