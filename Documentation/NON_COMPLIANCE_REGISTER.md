# Non-Compliance Register

AUDITED_SOURCE_COMMIT: `b33c06b8d68b9b03316821c3f6cfb17252f35011`. Every NON_COMPLIANT,
COMPLIANT_PARTIAL, IMPLEMENTED_UNVERIFIED, or BLOCKED_* finding from
`Documentation/REQUIREMENTS_TRACEABILITY_MATRIX.md`. Priority scale: P0 (data loss/critical
security) — P4 (future improvement).

Session 2 found one entry meeting this bar in the original 28-requirement baseline (DIST-003).
**Session 3 extended the baseline into PROD/FUNC/VIS/MOTION/A11Y/I18N/PERF/WEB/DOC/OPS domains and
found 24 additional non-clean entries** (2 NON_COMPLIANT, 9 COMPLIANT_PARTIAL, 10
IMPLEMENTED_UNVERIFIED, 1 BLOCKED_ENVIRONMENT, plus the 3 UNKNOWN entries listed for completeness
even though they're not technically "non-compliance," they're "not yet checked"). This is the
expected, honest result of covering the harder domains session 2 skipped — see
`REQUIREMENTS_COMPLIANCE_SUMMARY.md` for the full rollup.

---

## DIST-003 — sourceCommit in the release manifest should reflect the actual audited/built HEAD

- **Requirement**: `Release/latest.json`'s `sourceCommit` field should match the commit
  `Scripts/build-release.sh` was actually run against (SHOULD priority).
- **Status**: COMPLIANT_PARTIAL
- **Evidence**: `Scripts/build-release.sh` has no automated step that stamps `sourceCommit` from
  `git rev-parse HEAD` — it's static JSON a human/agent edits by hand. Session 1 already found and
  fixed one instance of drift (stale `sourceCommit`, commit `96deb37`); this session confirmed the
  underlying gap (no automation) is still present — the field is correct right now because it was
  hand-verified, not because the tooling prevents drift.
- **Priority**: P3 (process/quality gap — not user-facing today, but a real recurring-defect risk
  at every future release cut; not P2 because nothing currently ships wrong).
- **User impact**: none currently. If a future release is cut without the manual sync step, the
  manifest would misreport its own provenance — a distribution-honesty concern (this repo's
  stated value, see DIST-002/SEC-003) rather than a functional bug.
- **Data risk**: none.
- **Effort**: XS — `build-release.sh` already computes/writes other manifest fields
  programmatically (see the DIST-001 resync logic); adding `git rev-parse HEAD` output is a
  one-line addition to the same code path.
- **Fix**: add automated `sourceCommit` stamping to `Scripts/build-release.sh`, matching the
  pattern already used for checksums/sizes.
- **Tests needed**: extend `Scripts/test-release-manifest.sh` with a check that `sourceCommit`
  equals `git rev-parse HEAD` at the moment the script runs (mirroring its existing
  checksum/size-resync checks).
- **Recommended version**: 0.8.0 or later (small `feat(release)` change; explicitly out of scope
  for this docs-and-audit session per session instructions — no version bumps this session).

---

## Session 3 findings (new domains)

### VIS-003 — Hardcoded colors and font sizes bypass the design-token system
- **Status**: NON_COMPLIANT (SHOULD priority)
- **Evidence**: `grep -rn "Color(red:" Sources/MacCareApp` → `SpaceLensView.swift:72-75` (3 category
  colors hardcoded as `Color(red:green:blue:)` instead of `MCColor.chartSeries[n]`); `grep -rn
  "\.font(\.system(size:" Sources/MacCareApp` → 25 matches bypassing `MCFont`.
- **Priority**: P3 (design-system discipline, not a functional or safety defect).
- **User impact**: none functional; inconsistent dark-mode/contrast adaptation risk for the 3
  hardcoded colors specifically (they don't get the `NSColor` dynamic-provider light/dark handling
  that `MCColor` gives for free).
- **Fix**: migrate `SpaceLensView`'s category colors to `MCColor.chartSeries`; migrate `.font(.system(size:` call sites to `MCFont` tokens.
- **Recommended version**: 0.7.x or 0.8.0 (small, mechanical cleanup).

### A11Y-003 — No explicit Increase Contrast / Reduce Transparency handling found
- **Status**: NON_COMPLIANT (MUST priority)
- **Evidence**: `grep -rn "ncreaseContrast\|educeTransparency" Sources/` → zero matches anywhere in
  `Sources/`. The app relies entirely on system materials providing this behavior automatically,
  which is a reasonable but explicitly *unverified* assumption (no code-level opt-in/adaptation
  logic exists to confirm or override it).
- **Priority**: P2 (accessibility MUST with no code-level evidence of compliance — real risk for
  users who rely on these settings, even if native materials likely cover most of it).
- **User impact**: potentially real for users with Increase Contrast or Reduce Transparency enabled;
  unverifiable without a live interactive session.
- **Fix**: add explicit `@Environment(\.accessibilityReduceTransparency)` /
  `NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast` handling, or verify (with a live
  session) that system materials genuinely suffice and document that decision explicitly rather than
  leaving it implicit.
- **Tests needed**: none automatable without a live accessibility-settings toggle; add to
  `MANUAL_ACCEPTANCE_TEST_PLAN.md`.
- **Recommended version**: 0.8.0 (accessibility hardening pass).

### FUNC-003 — Protection live-scan path is BLOCKED_ENVIRONMENT
- **Status**: COMPLIANT_PARTIAL (MUST priority)
- **Evidence**: no `clamscan` installed on this audit machine; only `parse()` output-parsing and the
  quarantine data path are tested, never the real `Process()` invocation.
- **Priority**: P2 — this is the core promise of the Protection module; an untested live-invocation
  path is a real, if environment-forced, coverage gap.
- **User impact**: unknown whether the real scan invocation works end-to-end on a machine with
  ClamAV installed; not exercised in this or any prior session.
- **Fix**: install ClamAV in a future session (or CI) and run a real scan against an EICAR test
  file to close this gap.
- **Recommended version**: n/a (test-infrastructure gap, not a code defect).

### A11Y-001 — 6 of 20 MacCareApp view files have zero accessibility-annotation calls
- **Status**: COMPLIANT_PARTIAL (SHOULD priority)
- **Evidence**: `grep -rl "accessibilityLabel\|accessibilityValue\|accessibilityHint" Sources/MacCareApp
  Sources/DesignSystem` → 14 files matched, out of 20 `MacCareApp` view files (+ DesignSystem
  components). The specific 6 files were not individually enumerated this session (grep gave file
  count, not the diff-list) — flagged as a to-do for session 4.
- **Priority**: P3.
- **Fix**: enumerate the 6 files, add labels where interactive/informational content warrants them.
- **Recommended version**: 0.8.0.

### FUNC-006 / FUNC-007 — My Clutter / Space Lens view-internal logic unread
- **Status**: IMPLEMENTED_UNVERIFIED (MUST priority, both)
- **Evidence**: engine wiring confirmed real; view-internal filter/sort/rendering logic in
  `DuplicatesView.swift`, `SimilarImagesView.swift`, `MyClutterView.swift`, `SpaceLensView.swift` not
  read line-by-line this or prior sessions.
- **Priority**: P3 (no evidence of a defect, just unverified — carried from `FEATURE_INVENTORY.md`).
- **Fix**: full line-by-line reads in a future session, per the still-open §9
  `PROJECT_COMPLETE_AUDIT.md` 15-view gap.
- **Recommended version**: n/a (verification work, not a code change).
