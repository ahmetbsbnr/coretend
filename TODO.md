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

## Open — needs a second Mac or a display session (cannot run here)

1. **Clean-Mac launch repro.** The report that CoreTend didn't launch on
   another Mac was never root-caused. Reproduce with the exact public
   artifact from the download page, on a clean user account, and collect
   Console/crash logs, `codesign -dvvv`, `spctl --assess --verbose=4`,
   `otool -L`, `xattr -lr` before concluding cause (Gatekeeper vs. crash vs.
   missing resource vs. architecture — don't assume).
2. **DMG visual redesign + capture.** Current DMG background/layout is
   rejected. Rebuild with the CoreTend paper/ink/cobalt direction, verify
   icon/window geometry at Retina and non-Retina, capture real screenshots.
3. **Full client journey.** Download → quarantine → mount → copy → first
   launch → Gatekeeper prompt → onboarding → scan → uninstall/reinstall, in
   both languages, with real screenshots — not simulated.
4. **Crash-test matrix.** The ~40-scenario matrix (cold launches, killed
   mid-scan, corrupted prefs/cache, permission denials, huge/Unicode/
   symlinked/cyclic paths, unmounted volumes during scan, network-down
   update checks, sleep/wake mid-operation, rapid relaunch) — none of it
   deletes or touches real user data; use isolated temp dirs and a scratch
   `HOME`.
5. **GitHub attestation verification.** Download the public artifact, run
   the official `gh attestation verify` command against the expected repo,
   confirm it matches the tagged workflow/commit, keep the output.
6. **Portfolio-sync workflow, run for real.** Trigger via
   `workflow_dispatch` at least once; verify manifest fetch, no-op-when-
   synced, controlled version bump, typecheck, build, conditional commit
   (no commit loop), Vercel deploy, correct production version. A
   workflow that has only ever been scheduled, never run, is not validated.
7. **Interactive accessibility QA.** VoiceOver, keyboard traversal, focus
   visibility, Dynamic Type — code-level accessibility is real (tests
   assert labels/contrast/Reduce Motion), but none of it has been observed
   interactively; this environment has no display session.

## Open — automatable, no second Mac needed

8. **Publish a new RC if artifacts changed.** If app/bundle/DMG content
   changes, cut the next RC (don't silently replace a published one's
   assets); update SHA-256/Minisign/SBOM/attestation/release notes, and
   make sure site, portfolio and the in-app updater all point at it.

## Explicitly out of scope until 1.0

Developer ID signing, notarization, stapling, and replacing any currently
public artifact with a signed one. **Developer ID Application is not
actually installed on this Mac** (verified directly against the keychain,
2026-08-09 — see `Documentation/Audits/SESSION_2026-08-09_AUDIT.md`); a
Developer ID certificate being ready is not a reason to start this early.
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
