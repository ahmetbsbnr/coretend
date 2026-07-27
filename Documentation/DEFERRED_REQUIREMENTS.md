# Deferred Requirements

AUDITED_SOURCE_COMMIT: `b33c06b8d68b9b03316821c3f6cfb17252f35011`.

None of the 69 requirements in `Documentation/MASTER_REQUIREMENTS_BASELINE.md` (28 from session 2 +
41 new session-3 entries) carry a DEFERRED_APPROVED or SUPERSEDED status in
`Documentation/REQUIREMENTS_TRACEABILITY_MATRIX.md` — every requirement resolved to one of
COMPLIANT_VERIFIED, COMPLIANT_PARTIAL, IMPLEMENTED_UNVERIFIED, NON_COMPLIANT, BLOCKED_ENVIRONMENT, or
UNKNOWN (see `REQUIREMENTS_COMPLIANCE_SUMMARY.md`). None of the new statuses is a deferral — they are
honestly-reported gaps in *verification*, not requirements the project has decided to postpone or
supersede.

This file exists as the place those entries will go once any exist, per the session brief's
document set. It stays empty and honest rather than being padded with a fabricated deferral.

## Genuinely UNKNOWN this session (not deferred, just not yet checked)

- **A11Y-004** (text alternatives to charts/treemap) — `SpaceLensView.swift`/`PerformanceView.swift`
  not read for this specifically.
- **I18N-003** (pluralization/sizes/dates correctness) — `L10n.swift` formatting helpers not read.
- **PERF-003** (on-demand vs eager thumbnail generation) — thumbnail code path not read.

These are candidates for session 4's remaining scope, not deferrals — the difference matters: a
deferral means "we decided not to do this now," UNKNOWN means "we haven't looked yet."

## Related, but not a requirement deferral

`Documentation/NON_COMPLIANCE_REGISTER.md` → DIST-003 (COMPLIANT_PARTIAL, not deferred — the
requirement is judged as currently met by a manual step; the *automation* of that step is the open
item, tracked there with a P3/XS fix, not deferred as a requirement).

`Documentation/MASTER_REQUIREMENTS_BASELINE.md`'s own "Known open gaps" section lists two explicit
scope deferrals that are NOT requirement statuses (they're baseline-construction scope notes, not
DEFERRED_APPROVED requirements):
- Full per-view public-API line-by-line audit (§9 `PROJECT_COMPLETE_AUDIT.md`) — 15 `CoreTendApp`
  views remain `IMPLEMENTED_UNVERIFIED` in the prior feature audit's own vocabulary; carried to
  session 3 (module-by-module functional re-verification pass, per `CONTINUATION.md`).
- VIS-/MOTION-/A11Y-/I18N-/PERF- requirement mining from `VISUAL_DIRECTION.md`, `BRAND_SYSTEM.md`,
  `DESIGN_TOKENS.md`, `MOTION_SYSTEM.md` was never done — those requirement IDs don't exist in the
  baseline yet, so they can't appear in this matrix or be deferred from it. Also carried to
  session 3.
