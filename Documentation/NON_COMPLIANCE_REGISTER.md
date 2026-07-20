# Non-Compliance Register

AUDITED_SOURCE_COMMIT: `b33c06b8d68b9b03316821c3f6cfb17252f35011`. Every NON_COMPLIANT,
COMPLIANT_PARTIAL, or BLOCKED_* finding from `Documentation/REQUIREMENTS_TRACEABILITY_MATRIX.md`.
Priority scale: P0 (data loss/critical security) — P4 (future improvement).

Out of 28 requirements this session found **one** entry meeting this bar: DIST-003. Everything
else in the baseline came back COMPLIANT_VERIFIED with real evidence (see
`REQUIREMENTS_VERIFICATION_EVIDENCE.md`) — this register is short because the verification work
was thorough, not because it was skipped; see `REQUIREMENTS_COMPLIANCE_SUMMARY.md` for what was
specifically re-checked this session (SAFE-002, SEC-001/002, PRIV-001, and the SEC-003 regression
that was found and fixed mid-session, which is why it does NOT appear here — it was closed out
before this register was written, not swept under it).

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
