# Requirements Compliance Summary

> **0.8.1 Final Canonical Audit Resync note (2026-07-25).** The 69 requirements
> below were **not** re-audited in this phase, and the status counts are
> therefore carried forward unchanged from session 4. Saying otherwise would be
> the exact kind of false freshness this resync exists to remove.
>
> What *is* re-verified as of `92cbd08`:
>
> | Claim | Value |
> |---|---|
> | `REQUIREMENTS_AUDIT_COMMIT` (last commit touching the requirements doc set) | `03839803274c620d204dcc8ab28f7bbbdb6cc5b4` |
> | Tests | 274 in 57 suites, PASS, 0 failures |
> | Debug / Release build | PASS / PASS, 0 warnings |
> | Feature inventory | 46 features (was 42; the four rebrand features were missing) |
> | Publication gate | RED, for the human reasons in `HUMAN_BLOCKERS.md` |
>
> Two corrections to statements made in the body below:
>
> 1. "no display this session" is **stale**. A real display is available; what
>    remains blocked is module-targeted capture and the full capture campaign.
>    See `KNOWN_LIMITATIONS.md`.
> 2. `AUDITED_SOURCE_COMMIT: b33c06b…` below is the commit of the *original*
>    requirements audit and is correct as history. It is not the current HEAD and
>    must not be read as one.
>
> The requirements set also does not yet contain entries for the four features
> the rebrand delivered (data migration and its surfaces). Adding and auditing
> them is a requirements-phase task, not a documentation resync, and is recorded
> as open in `NON_COMPLIANCE_REGISTER.md`.

AUDITED_SOURCE_COMMIT: `b33c06b8d68b9b03316821c3f6cfb17252f35011`. Rollup of
`Documentation/REQUIREMENTS_TRACEABILITY_MATRIX.md` (**69 requirements**: the 28 from session 2 plus
**41 new this session** under PROD/FUNC/VIS/MOTION/A11Y/I18N/PERF/WEB/DOC/OPS — prefixes the original
audit brief required and that session 2's baseline had completely skipped). Session 3 of the
requirements-reconciliation phase.

**Why this table looks less clean than session 2's**: session 2 covered only the "easy" domains
(safety/security/distribution/platform/legal — all mechanically checkable by grep and script). This
session covers the domains session 2 explicitly deferred (functional re-verification, visual/motion
charter compliance, accessibility, localization, performance, website, docs, governance) — several of
which are genuinely BLOCKED_ENVIRONMENT (no display this session) or UNKNOWN (not yet read). That is
the intended, honest result of extending into harder territory, not a regression in rigor.

## Overall status counts (updated session 4 — see correction note below)

| Status | Count |
|---|---|
| COMPLIANT_VERIFIED | 44 |
| COMPLIANT_PARTIAL | 10 |
| IMPLEMENTED_UNVERIFIED | 10 |
| NON_COMPLIANT | 1 |
| BLOCKED_HUMAN | 0 |
| BLOCKED_ENVIRONMENT | 1 |
| DEFERRED_APPROVED | 0 |
| SUPERSEDED | 0 |
| NOT_APPLICABLE | 0 |
| UNKNOWN | 3 |
| **Total** | **69** |

**Session-4 correction**: A11Y-003 was re-verified and downgraded from NON_COMPLIANT to
COMPLIANT_PARTIAL — the session-3 grep hit (`MCCard` in `DesignSystem.swift` handling
`accessibilityReduceTransparency`) was misread as "zero matches" when it was in fact a real match;
Reduce Transparency is genuinely handled, only Increase Contrast remains unhandled. See
`Documentation/NON_COMPLIANCE_REGISTER.md` and `Documentation/REQUIREMENTS_TRACEABILITY_MATRIX.md`
for the corrected entry. VIS-003 (design-token drift — 3 hardcoded colors, 25 raw font-size sites)
was re-confirmed genuinely NON_COMPLIANT this session, unchanged. See
`Documentation/FINAL_COMPLIANCE_SCORECARD.md` for the full session-4 scoring and verdict.

## Breakdown by priority (explicit, as required)

| Priority | COMPLIANT_VERIFIED | COMPLIANT_PARTIAL | IMPLEMENTED_UNVERIFIED | NON_COMPLIANT | BLOCKED_ENVIRONMENT | UNKNOWN | Total |
|---|---|---|---|---|---|---|---|
| MUST | 39 | 6 | 9 | 0 | 0 | 0 | 54 |
| SHOULD | 4 | 4 | 1 | 1 | 1 | 3 | 14 |
| n/a (disclosed limitation, MAC-003) | 1 | 0 | 0 | 0 | 0 | 0 | 1 |
| **Total** | **44** | **10** | **10** | **1** | **1** | **3** | **69** |

**A MUST that is COMPLIANT_PARTIAL, IMPLEMENTED_UNVERIFIED, NON_COMPLIANT, or BLOCKED_* caps the
overall verdict below FULLY_CONFORMING_VERIFIED** (per the original brief's §23 scoring rule) — of 54
MUST requirements, 15 are not COMPLIANT_VERIFIED (6 COMPLIANT_PARTIAL including the corrected
A11Y-003, 9 IMPLEMENTED_UNVERIFIED, 0 NON_COMPLIANT MUST — the sole remaining NON_COMPLIANT, VIS-003,
is SHOULD priority). The verdict is short of FULLY_CONFORMING_VERIFIED but with zero NON_COMPLIANT or
BLOCKED_* MUSTs and a weighted MUST score of 44.25/54 (81.9%). See
`Documentation/FINAL_COMPLIANCE_SCORECARD.md` for the computed verdict: **MOSTLY_CONFORMING**.

## Breakdown by domain

| Domain | Requirements | COMPLIANT_VERIFIED | COMPLIANT_PARTIAL | IMPLEMENTED_UNVERIFIED | NON_COMPLIANT | BLOCKED_ENVIRONMENT | UNKNOWN |
|---|---|---|---|---|---|---|---|
| SAFE | 6 | 6 | 0 | 0 | 0 | 0 | 0 |
| PROTECTION | 1 | 1 | 0 | 0 | 0 | 0 | 0 |
| SEC | 3 | 3 | 0 | 0 | 0 | 0 | 0 |
| DIST | 3 | 2 | 1 | 0 | 0 | 0 | 0 |
| MAC | 3 | 3 | 0 | 0 | 0 | 0 | 0 |
| LEGAL | 4 | 4 | 0 | 0 | 0 | 0 | 0 |
| OSS | 2 | 2 | 0 | 0 | 0 | 0 | 0 |
| TEST | 1 | 1 | 0 | 0 | 0 | 0 | 0 |
| ARCH | 2 | 2 | 0 | 0 | 0 | 0 | 0 |
| PRIV | 3 | 3 | 0 | 0 | 0 | 0 | 0 |
| **PROD** (new) | 4 | 3 | 1 | 0 | 0 | 0 | 0 |
| **FUNC** (new) | 10 | 6 | 3 | 2 (FUNC-006/007) | 0 | 0 | 0 |
| **VIS** (new) | 3 | 0 | 1 | 1 | 1 | 0 | 0 |
| **MOTION** (new) | 2 | 0 | 0 | 2 | 0 | 0 | 0 |
| **A11Y** (new) | 4 | 0 | 2 | 0 | 0 | 1 | 1 |
| **I18N** (new) | 3 | 1 | 1 | 0 | 0 | 0 | 1 |
| **PERF** (new) | 4 | 0 | 0 | 3 | 0 | 0 | 1 |
| **WEB** (new) | 5 | 4 | 1 | 0 | 0 | 0 | 0 |
| **DOC** (new) | 2 | 2 | 0 | 0 | 0 | 0 | 0 |
| **OPS** (new) | 4 | 3 | 0 | 1 | 0 | 0 | 0 |
| **Total** | **69** | **44** | **10** | **10** | **1** | **1** | **3** |

(A11Y row updated session 4: A11Y-003 moved from NON_COMPLIANT to COMPLIANT_PARTIAL; A11Y-002 remains
BLOCKED_ENVIRONMENT — column above reflects COMPLIANT_PARTIAL=2 i.e. A11Y-001 + A11Y-003.)

## What changed this session vs. the session-1 baseline

- Several requirements the baseline explicitly marked "not independently re-verified" (SAFE-002,
  SEC-001, SEC-002, PRIV-001) were re-verified this session with fresh commands/code reads and
  held up.
- **SEC-003 / DIST-001 regression found and fixed**: `Scripts/test-release-manifest.sh` was
  actually FAILING at the start of this session — session 1's own new
  `Documentation/REQUIREMENTS_DECISION_HISTORY.md` mentioned the dangerous command
  `sudo spctl --master-disable` with its "Do not..." warning on the line *after* the mention,
  which the script's look-behind-only heuristic didn't credit as a warning. Fixed by reordering
  the sentence (see `git log` for the `fix(audit)` commit this session). Re-ran
  `Scripts/build-release.sh` + `Scripts/test-release-manifest.sh` end to end afterward: **ALL
  CHECKS PASSED**.
- The SafetyCore audit log was checked again with real rigor per the session brief: it is
  **in-memory only** (`public private(set) var auditLog: [String] = []`, no SQLite/file backing).
  This matches what `SAFETY_MODEL.md` itself already discloses ("will persist to SQLite once
  Persistence lands") — no baseline requirement claims persistence today, so this is not a
  compliance failure, but it is called out explicitly per the session brief's instruction not to
  rubber-stamp it.
- Cleanup rules were enumerated directly from `ruleID:` literals in `Sources/`, not from
  `ROADMAP.md`: `apps.leftovers`, `apps.uninstall`, `apps.uninstall.associated`,
  `clutter.duplicates`, `privacy.browsercache` — five rules exist in code today.
- "Check for Updates" (`Sources/CoreTendApp/AppUpdatesView.swift:40`) confirmed to call
  `NSWorkspace.shared.open(URL(string: "macappstore://showUpdatesPage")!)` — it opens the Mac App
  Store's Updates page, it is not a real in-app update check. (No baseline requirement ID covers
  this claim directly; flagged here for session 3's functional pass to turn into a FUNC-*
  requirement if warranted.)
- Protection/ClamAV: `ClamAVScanner.isAvailable` gates the real-scan UI in `ProtectionView.swift`;
  `clamscan` is not installed in this environment (`Scripts/doctor.sh` confirms), so the
  honest-unavailable code path is the one structurally verified — not visually screenshotted
  (headless environment).

## Known gaps carried forward

- Full module-by-module functional re-verification (per-view API line-by-line, 15
  `IMPLEMENTED_UNVERIFIED` `CoreTendApp` views per `PROJECT_COMPLETE_AUDIT.md` §9) is still not
  complete — FUNC-006/FUNC-007 inherit this gap directly.
- No live display was available this session (same as every prior session) — VIS-001, VIS-002,
  MOTION-001/002, A11Y-002/004, PERF-001 remain BLOCKED_ENVIRONMENT or IMPLEMENTED_UNVERIFIED for
  their interaction/visual-confirmation components. `Scripts/capture.sh` was not re-attempted this
  session; session 4/5 should try it once before declaring this a permanent limitation.
- 3 UNKNOWN entries (A11Y-004, I18N-003, PERF-003) are genuinely unread this session — logged
  honestly rather than guessed at.
- `PROJECT_COMPLETE_AUDIT.md` and the machine-readable JSON/CSV twins of the *audit report itself*
  now synchronized to the 69-requirement matrix as of session 4 (see
  `Documentation/FINAL_COMPLIANCE_SCORECARD.md` and `Documentation/CONTINUATION.md`).

## Session 4 additions (this session)

- Spot-checked the 2 session-3 NON_COMPLIANT findings + 1 BLOCKED_ENVIRONMENT finding before doing
  anything else, per this session's brief. VIS-003 (design-token drift) re-confirmed genuinely
  NON_COMPLIANT — unchanged, left as a documented gap rather than rushed (fixing 25 raw font-size
  call sites plus adding new category-color tokens is real design-system work out of this session's
  scope). A11Y-003 was re-verified and found to be **inaccurate as recorded**: the code already
  handles Reduce Transparency (`MCCard` in `DesignSystem.swift`, predating session 3's audit) —
  downgraded NON_COMPLIANT → COMPLIANT_PARTIAL. This is a docs-accuracy correction, not a code
  change (no `fix(...)` commit needed; the underlying code was already compliant).
- Computed the final compliance scorecard and verdict per the original brief's §23 formula:
  `Documentation/FINAL_COMPLIANCE_SCORECARD.md`. Verdict: **MOSTLY_CONFORMING** (zero NON_COMPLIANT
  or BLOCKED_* MUSTs, weighted MUST score 44.25/54 = 81.9%, but 15/54 MUST requirements below
  COMPLIANT_VERIFIED — disqualifies FULLY_CONFORMING_VERIFIED per the brief's own rule).
- Synchronized `PROJECT_COMPLETE_AUDIT.md`, `project-state-audit.json`, `public-readiness.json`
  (created), `DOCUMENT_INDEX.md`, and did a final repo-wide grep pass for stale numbers
  (28-requirement/27-of-28 era) and stale session/commit references.

## Session 3 additions

- Extended `MASTER_REQUIREMENTS_BASELINE.md` with 41 new requirements across PROD (4), FUNC (10),
  VIS (3), MOTION (2), A11Y (4), I18N (3), PERF (4), WEB (5), DOC (2), OPS (4) — sourced from
  README.md, FEATURE_INVENTORY.md, VISUAL_DIRECTION.md, MOTION_SYSTEM.md, DESIGN_TOKENS.md,
  WEBSITE_AUDIT.md, GOVERNANCE.md/SUPPORT.md/CONTRIBUTING.md/SECURITY.md, and direct code reads —
  not invented.
- Real re-verification work performed, not copied forward: fresh FR/EN key-diff (372/372, 0 drift —
  I18N-001), fresh grep sweeps for hardcoded colors/fonts bypassing the design-token system
  (VIS-003 — found real drift: 3 hardcoded colors, 25 raw font-size sites), fresh grep for
  Increase Contrast/Reduce Transparency handling (A11Y-003 — found none, a real gap), a full code
  read of `AppUpdatesView.swift`/`AppUpdateSource.detect` that **corrected** an initial wrong
  assumption about App Updates being a bare deep-link (FUNC-005 — it's real per-app mechanism
  detection, just not availability-checking).
