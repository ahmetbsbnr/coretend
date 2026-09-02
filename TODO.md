# TODO — CoreTend

Short, current list. History and the pre-IntegrityCore version of this file
(which still framed several items around ClamAV) live in
`Documentation/Archive/TODO_2026-08-08_pre-integritycore-cleanup.md` and
`Documentation/Audits/`. This file is not a project history — see
`Documentation/PROJECT_HISTORY.md` / `Documentation/PROJECT_STATE.md` for that.

**ClamAV is not part of the current product.** It was fully retired in
`eac408c` and replaced by IntegrityCore — a native, read-only inspector of
code-signature, download-provenance and login-item facts. IntegrityCore is
**not an antivirus** and makes no malware-detection claim. Any older
checklist item that assumed ClamAV presence/absence, ClamAV installation
guidance, or an antivirus database is obsolete and has been dropped, not
carried forward.

**Signing is done.** `v0.9.1-rc.6` (2026-08-31) is the first Developer ID
signed + Apple-notarized release, published and verified. The remaining
gates for **v1.0.0** — automatable (attestation, 3 crash-test items,
`SmartCareView` decision) and human-only (clean-Mac QA, DMG Finder QA, full
client journey, VoiceOver, **trademark attorney review**) — plus the exact
ship sequence, are in `Documentation/RELEASE_STATE.md` → "Path to v1.0.0".
Items 1–5 and 7 below are the human-only gates, unchanged.

## Open — needs a second Mac or a display session (cannot run here)

1. **Clean-Mac launch repro.** The report that CoreTend didn't launch on
   another Mac was never root-caused. Reproduce with the exact public
   artifact from the download page, on a clean user account, and collect
   Console/crash logs, `codesign -dvvv`, `spctl --assess --verbose=4`,
   `otool -L`, `xattr -lr` before concluding cause (Gatekeeper vs. crash vs.
   missing resource vs. architecture — don't assume).
2. **DMG visual validation.** Narrowed by `Documentation/Audits/
   DMG_PACKAGING_AUDIT.md` (2026-08-09): the packaging pipeline, geometry
   and on-brand background artwork are all proven correct headlessly. What
   remains is purely how it renders/feels in a real Finder window — icon
   alignment, drag-and-drop feel — not a rebuild.
3. **Full client journey.** Download → quarantine → mount → copy → first
   launch → Gatekeeper prompt → onboarding → scan → uninstall/reinstall, in
   both languages, with real screenshots — not simulated.
4. **Crash-test matrix — mostly done.** Classified and executed in
   `Documentation/Audits/CRASH_MATRIX_CLASSIFICATION.md` (2026-08-09):
   31/40 items executed for real (`Scripts/test-robustness.sh` 31/31 PASS +
   existing `swift test` coverage), 6 N/A (ClamAV), 3 honest gaps (disk-
   nearly-full, CPU-under-load, timeout — feasible, not yet run), 2 need
   real memory pressure/sleep-wake control, 2 need a display session.
5. **GitHub attestation — dry run proven, real publish path still
   unverified.** `release-draft.yml` now attests a real build (see
   `SESSION_2026-08-09_AUDIT.md` §14) without publishing. What's still
   open: running `gh attestation verify` against an actual tagged, published
   release once one ships next.
6. ~~Portfolio-sync workflow, run for real.~~ **Done 2026-08-09.** Already
   supported `workflow_dispatch`; dispatched it for real, confirmed
   already-in-sync (no-op, the correct outcome) — see
   `SESSION_2026-08-09_AUDIT.md` §14.
7. **Interactive accessibility QA.** VoiceOver, keyboard traversal, focus
   visibility, Dynamic Type — code-level accessibility is real (tests
   assert labels/contrast/Reduce Motion), but none of it has been observed
   interactively; this environment has no display session.
8. ~~Smart Care: needs an explicit decision.~~ **Done — retired.**
   `.smartCare` renders `DashboardView` and always did; the standalone
   `SmartCareView` + view model were deleted, the auto-execute safety
   filter moved to `UserCleanupRules.autoExecutable(_:)` (guarded by
   `CleanupAutoExecuteTests`), `SMART_CARE.md` / `FEATURE_MATRIX.md` /
   `feature-inventory.json` / `check-retired-preview-mode.sh` updated, and
   the portfolio case study was corrected in PR #25. The menu-bar "last
   Smart Care" line is now "last activity" (newest record of any kind).

## Open — automatable, no second Mac needed

9. **Publish a new RC if artifacts changed.** If app/bundle/DMG content
   changes, cut the next RC (don't silently replace a published one's
   assets); update SHA-256/Minisign/SBOM/attestation/release notes, and
   make sure site, portfolio and the in-app updater all point at it.

## Signing / notarization — now available, not yet shipped

**Done 2026-08-31:** an Apple Developer Program account (Team `NSCUV5G738`)
is enrolled, a **Developer ID Application** certificate was issued from the
existing CSR and installed, and `Scripts/sign-and-notarize.sh` produced a
real signed + notarized (both `Accepted`) + stapled `0.9.1-rc.5` **locally**
(`spctl --assess` → `accepted / Notarized Developer ID`). The script's
first-run ordering bug was fixed.

**Open:** ship it. This is a **new RC** (artifact content + name change), see
`Documentation/SIGNING_NOTARIZATION.md` → "Publishing a signed release":
bump version, notes, sign+notarize, regenerate `latest.json` / `SHA256SUMS`
/ **Minisign** (needs the human-held private key) / SBOM, drop the
`-unsigned` token across scripts + site + CI, tag + push, then re-point the
download page and in-app updater at the published tag.

The site's one-page redesign is validated — don't restructure it, only fix
real defects.

## Done when

- Clean-Mac launch cause is identified and any fixable cause is fixed.
- DMG is rebuilt, on-brand, drag-and-drop works, and it's been tested like a
  real customer would.
- The crash-test matrix has actually run, with results recorded.
- The full client journey has been walked end-to-end with evidence.
- A new RC ships only if something changed, and site/portfolio/updater all
  agree on its version.
- The GitHub attestation has been verified with saved output, not assumed.
- The portfolio-sync workflow has run for real at least once.
- CI is green and production (site, portfolio, release) has been checked
  live, not just locally.
