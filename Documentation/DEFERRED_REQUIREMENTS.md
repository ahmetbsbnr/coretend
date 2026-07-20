# Deferred Requirements

AUDITED_SOURCE_COMMIT: `b33c06b8d68b9b03316821c3f6cfb17252f35011`.

None of the 28 requirements in `Documentation/MASTER_REQUIREMENTS_BASELINE.md` carry a
DEFERRED_APPROVED or SUPERSEDED status in `Documentation/REQUIREMENTS_TRACEABILITY_MATRIX.md` this
session — every requirement resolved to COMPLIANT_VERIFIED or COMPLIANT_PARTIAL (see
`REQUIREMENTS_COMPLIANCE_SUMMARY.md`). `Documentation/REQUIREMENTS_DECISION_HISTORY.md` (session 1)
was re-read for explicitly superseded decisions and contains none — every decision it records
("holds," "confirmed") rather than "superseded by."

This file exists as the place those entries will go once any exist, per the session brief's
document set. It stays empty and honest rather than being padded with a fabricated deferral.

## Related, but not a requirement deferral

`Documentation/NON_COMPLIANCE_REGISTER.md` → DIST-003 (COMPLIANT_PARTIAL, not deferred — the
requirement is judged as currently met by a manual step; the *automation* of that step is the open
item, tracked there with a P3/XS fix, not deferred as a requirement).

`Documentation/MASTER_REQUIREMENTS_BASELINE.md`'s own "Known open gaps" section lists two explicit
scope deferrals that are NOT requirement statuses (they're baseline-construction scope notes, not
DEFERRED_APPROVED requirements):
- Full per-view public-API line-by-line audit (§9 `PROJECT_COMPLETE_AUDIT.md`) — 15 `MacCareApp`
  views remain `IMPLEMENTED_UNVERIFIED` in the prior feature audit's own vocabulary; carried to
  session 3 (module-by-module functional re-verification pass, per `CONTINUATION.md`).
- VIS-/MOTION-/A11Y-/I18N-/PERF- requirement mining from `VISUAL_DIRECTION.md`, `BRAND_SYSTEM.md`,
  `DESIGN_TOKENS.md`, `MOTION_SYSTEM.md` was never done — those requirement IDs don't exist in the
  baseline yet, so they can't appear in this matrix or be deferred from it. Also carried to
  session 3.
