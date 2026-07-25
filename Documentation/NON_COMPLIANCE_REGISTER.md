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

> **Updated by the 0.8.1 Final Canonical Audit Resync (2026-07-25). The predicted
> defect actually happened.**
>
> The automation gap described below is **closed**: `Scripts/build-release.sh:26`
> now sets `SOURCE_COMMIT=$(git rev-parse HEAD)` and stamps it into
> `latest.json`, and `Scripts/test-release-manifest.sh` asserts the field equals
> the real HEAD.
>
> The drift still recurred anyway, exactly as this entry warned it would, by a
> route the automation does not cover: the 0.8.1 artifacts were built while the
> release changes were still **uncommitted** in the working tree, so
> `git rev-parse HEAD` correctly returned the *previous* commit
> (`3b5dc73`). Those changes — including `Resources/Info.plist`'s 0.8.0 → 0.8.1
> version strings, which are inside the bundle — were committed 8 minutes later
> as `dec47a1`. The manifest was never resynced, so it advertised a
> `sourceCommit` whose tree could not have produced the artifacts it described.
> The artifacts were right; the record was wrong.
>
> Detected by comparing the ZIP's embedded `Info.plist` (`0.8.1`) against the
> tree at the claimed `sourceCommit` (`0.8.0`). Resolved when the mandatory
> `test-release-manifest` gate rebuilt the artifacts and resynced the manifest.
>
> - **Residual status**: COMPLIANT_PARTIAL (unchanged rating, different reason).
>   Stamping is automated; *building from a clean tree* is not enforced.
> - **Residual gap**: `build-release.sh` does not refuse to run on a dirty tree,
>   so `sourceCommit` can still name a commit whose tree differs from what was
>   packaged.
> - **Fix**: have `build-release.sh` fail when `git status --short` is non-empty,
>   or record the dirty state in the manifest.
> - **Priority**: P3. A one-line guard, but it is a product-tooling change and
>   therefore outside a documentation resync's scope.
> - **See also**: `KNOWN_LIMITATIONS.md` on why this gate cannot be green at the
>   commit that records its own output.



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
- **Evidence**: `grep -rn "Color(red:" Sources/CoreTendApp` → `SpaceLensView.swift:72-75` (3 category
  colors hardcoded as `Color(red:green:blue:)` instead of `MCColor.chartSeries[n]`); `grep -rn
  "\.font(\.system(size:" Sources/CoreTendApp` → 25 matches bypassing `MCFont`.
- **Priority**: P3 (design-system discipline, not a functional or safety defect).
- **User impact**: none functional; inconsistent dark-mode/contrast adaptation risk for the 3
  hardcoded colors specifically (they don't get the `NSColor` dynamic-provider light/dark handling
  that `MCColor` gives for free).
- **Fix**: migrate `SpaceLensView`'s category colors to `MCColor.chartSeries`; migrate `.font(.system(size:` call sites to `MCFont` tokens.
- **Recommended version**: 0.7.x or 0.8.0 (small, mechanical cleanup).

### A11Y-003 — Increase Contrast unhandled (Reduce Transparency IS handled) — DOWNGRADED session 4
- **Status**: COMPLIANT_PARTIAL (MUST priority) — corrected session 4, was wrongly NON_COMPLIANT
- **Session-4 re-verification**: re-ran `grep -rn "ncreaseContrast\|educeTransparency" Sources/` and
  this time actually read the hit: `Sources/DesignSystem/DesignSystem.swift:10-27` (`MCCard`) DOES
  handle `@Environment(\.accessibilityReduceTransparency)`, falling back to an opaque
  `MCColor.elevatedBackground` fill instead of `.regularMaterial` when the setting is on. This code
  predates session 3 (part of the original Orbital Ecology design-system commit `c2dff93`) — the
  session-3 finding of "zero matches" was a mistaken read of the grep output, not a code regression.
  Increase Contrast remains genuinely unhandled — zero matches for that half.
- **Priority**: P3 (half of the original MUST gap is closed; the remaining half — Increase Contrast
  — is real but narrower in scope).
- **User impact**: none for Reduce Transparency users (handled); potentially real for Increase
  Contrast users (unhandled, unverifiable without a live session).
- **Fix**: add explicit `@Environment(\.accessibilityDifferentiateWithoutColor)` /
  `NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast` handling for Increase Contrast only
  — Reduce Transparency needs no further work.
- **Tests needed**: none automatable without a live accessibility-settings toggle; add to
  `MANUAL_ACCEPTANCE_TEST_PLAN.md`.
- **Recommended version**: 0.8.0 (accessibility hardening pass, narrower scope than originally logged).

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

### A11Y-001 — 6 of 20 CoreTendApp view files have zero accessibility-annotation calls
- **Status**: COMPLIANT_PARTIAL (SHOULD priority)
- **Evidence**: `grep -rl "accessibilityLabel\|accessibilityValue\|accessibilityHint" Sources/CoreTendApp
  Sources/DesignSystem` → 14 files matched, out of 20 `CoreTendApp` view files (+ DesignSystem
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

### VIS-CAMPAIGN — After-screenshot visual QA campaign
- **Status**: BLOCKED_ENVIRONMENT
- **Evidence**: this session (2026-07-21, v0.7.1 closeout) runs with no display/window-capture access
  — `Scripts/capture.sh` requires an attached display and System Events automation, neither available
  in this non-interactive execution context. No screenshots or sidecar JSON were fabricated to fill
  this gap.
- **Priority**: P2 (blocks finishing `Documentation/VISUAL_QA.md` checkboxes, does not block function).
- **Fix**: re-run `Scripts/capture.sh` on a machine with an attached display and computer-use/GUI access.
- **Recommended version**: whenever that environment is available; not tied to a version number.

### HUMAN-IDENTITY — Public release identity fields undecided
- **Status**: BLOCKED_HUMAN
- **Evidence**: `Configuration/PublicIdentity.local.json` does not exist (`Scripts/check-publish-readiness.sh`
  fails on this check by design pre-release). Legal name, legal address, domain, and security-contact
  values are all placeholder tokens in `Website/generate.py` and its generated `Website/*/legal.html`,
  `privacy.html`, `security.html`, `documentation.html` output (133 placeholder occurrences per
  `Scripts/check-placeholders.sh`, expected pre-release).
- **Priority**: P1 for public launch, P4 for this compliance-hardening pass (no code fix possible here).
- **Fix**: maintainer decides legal entity name/address, registers/confirms a domain, sets a reachable
  security contact, copies `Configuration/PublicIdentity.example.json` to `PublicIdentity.local.json`
  and fills it in, then regenerates the website.
- **Recommended version**: before any real public push/deploy; explicitly not part of 0.7.1 or 0.8.0
  scope by themselves.

### HUMAN-SIGNING — No code signing / notarization
- **Status**: BLOCKED_HUMAN
- **Evidence**: no Apple Developer ID configured anywhere in this repo or environment; the privileged
  helper and any future signed/notarized distribution both depend on it.
- **Priority**: P1 for public launch, out of scope for a local/unsigned build.
- **Fix**: maintainer enrolls in the Apple Developer Program and configures signing.
- **Recommended version**: before any notarized public release.

---

## Opened by the 0.8.1 Final Canonical Audit Resync (2026-07-25)

### RESYNC-001 — Requirements baseline does not cover the rebrand's features
- **Status**: UNKNOWN (not yet audited)
- **Evidence**: `Documentation/requirements-traceability.json` holds 69
  requirements, none of which addresses the legacy-data migration, its launch
  wiring, its Settings surface, or the uninstaller's opt-in legacy handling.
  Those four features exist, are tested (20 tests), and are now listed in
  `Documentation/feature-inventory.json` — but no requirement traces to them.
- **Priority**: P3. The features are verified at the code and test level; what is
  missing is requirement-level traceability.
- **Fix**: add MIGRATION-* requirements and audit them in a requirements phase.
- **Recommended version**: next requirements-reconciliation pass, not 0.8.1.

### RESYNC-002 — Distribution smoke test is not isolated from real user data
- **Status**: COMPLIANT_PARTIAL
- **Evidence**: `Store.defaultPath()`
  (`Sources/Persistence/Store.swift:77-84`) always resolves to
  `~/Library/Application Support/CoreTend` and reads no environment variable, so
  `Scripts/test-distribution.sh`'s launch check runs the real app against the
  real per-user store. A dead `MACCARELOCAL_STORE_DIR` export implied isolation
  that never existed; it was removed rather than renamed, and the script's false
  "never touches the real location" comment was corrected.
- **User impact**: none in practice — the test launches and quits, performing no
  scan, no cleanup and no deletion.
- **Priority**: P3.
- **Fix**: make the store path injectable in `Sources/` so the test can point at
  a temp directory. A product-tooling change, out of scope for a documentation
  resync.

### RESYNC-003 — build-release.sh does not refuse a dirty tree
- **Status**: COMPLIANT_PARTIAL
- **Evidence**: see the DIST-003 update above. `sourceCommit` is stamped from
  `git rev-parse HEAD` but nothing enforces that HEAD's tree is what was actually
  packaged, which is how the 0.8.1 manifest came to name `3b5dc73`.
- **Priority**: P3.
- **Fix**: fail the build when `git status --short` is non-empty, or record the
  dirty state in the manifest.

### RESYNC-004 — check-legacy-brand-references.sh scanned case-sensitively
- **Status**: RESOLVED this phase
- **Evidence**: the gate was **red at `92cbd08`** on two unexplained files
  (`Documentation/AUDIT_COMMANDS.log`, `Documentation/CONTINUATION.md`), and its
  case-sensitive scan additionally missed `MACCARELOCAL_STORE_DIR`. It now scans
  with `rg -li`, both legitimate files are allowlisted with stated reasons, and
  its 5 self-tests pass.
- **Priority**: was P2 (a green gate that was not actually green).

---

## Closed by the 0.9.0 Final Public Launch phase (2026-07-25)

### DIST-003 / RESYNC-003 — CLOSED
The circular provenance requirement is gone. `Release/latest.json` and
`Release/SHA256SUMS` are no longer tracked; they are generated into `dist/` from
the tracked `Release/latest.template.json`, so `sourceCommit` names the commit
actually packaged and nothing needs committing afterwards. `build-release.sh`
refuses a dirty tree, which was the specific route by which the 0.8.1 drift
occurred. The template declares `_doNotAddHere` and the build fails if it carries
a computed field, so a hand-edited checksum cannot beat a measured one.
`test-release-manifest.sh` no longer rebuilds artifacts as a side effect.
Evidence: `Scripts/test-release-provenance.sh` (15 tests),
`Documentation/RELEASE_PROVENANCE.md`. The publication gate was demonstrated
green on an exact tag with nothing committed after it.

### RESYNC-002 — CLOSED
The distribution smoke test no longer runs against the real user store.
`TestStoreOverride` gates on two agreeing environment variables and a validated
temporary path, and the marker suppresses the legacy-data migration so the test
cannot read real pre-rename data. Isolation is measured, not asserted:
`test-distribution.sh` fingerprints the real store before and after and fails on
any change, and confirms the isolated store holds zero activity rows.
`check-test-isolation.sh` statically enforces the shape (9 self-tests); 22 unit
tests cover validation. Verified: real store untouched across a full run.

### RESYNC-004 — remains CLOSED
No regression. `check-legacy-brand-references.sh` still scans case-insensitively
and every allowlisted path still states a reason.

### RESYNC-001 — still OPEN
No requirement yet traces to the migration features or to the new store-isolation
mechanism. Feature-level and test-level verification exist; requirement-level
traceability does not. Unchanged priority: P3, for a requirements phase.
