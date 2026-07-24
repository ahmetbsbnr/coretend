# Functional Completion Report (0.8.0 phase)

This is a snapshot report, not the tracker itself. The authoritative,
continuously-updated source is
`Documentation/FUNCTIONAL_COMPLETION_EXECUTION_PLAN.md` (21-step table) —
if the two ever disagree, that file wins. Product version stays **0.7.1**
until every automatable criterion in Step 19 of the plan is genuinely true.

## Snapshot at this update

- Branch: `feat/functional-completion`
- Tests: 215/215 passing, 49 suites, 0 failures (`bash Scripts/test.sh`)
- Build: `swift build` and `swift build -c release` both green (1 pre-existing
  Sendable warning in `OnboardingView.swift`, not a failure)
- Dev gates green: `doctor.sh`, `repository-doctor.sh` (bundles
  check-private-data, check-licenses, check-placeholders,
  check-feature-inventory, settings-matrix no-orphan gate,
  check-markdown-links, .gitignore sanity)
- Publish gate (`check-publish-readiness.sh`) intentionally red — expected
  pre-release, not a dev-gate failure. Three human blockers: placeholder
  tokens in the public-facing legal/security pages, no
  `Configuration/PublicIdentity.local.json`, and a stale `Release/latest.json`
  `sourceCommit` (only meaningful once a real release build is cut).
- Repo tree: clean at each commit checkpoint, no stray worktrees, no push.

## Step status (see the plan file for full evidence per step)

| # | Step | Status |
|---|------|--------|
| 0 | Baseline gates | DONE |
| 1 | Cleanup finalization | PARTIAL (Simulator/Trash-empty/Mail-attachments/broken-LaunchAgents rules deliberately DEFERRED — need dedicated safety engines, not blind extension rules; not presented as shipped in docs/UI) |
| 2 | Smart Care audit | DONE |
| 3 | Protection / FSEvents watch | DONE |
| 4 | Privacy Cleaner honesty | DONE |
| 5 | Applications & updates | DONE |
| 6 | My Clutter | PARTIAL (Large&Old name search / per-volume awareness / UI-exposed exclusions are enhancement-only DEFERRED, not safety gaps) |
| 7 | Space Lens | DONE |
| 8 | Cloud Cleanup | DONE |
| 9 | Settings matrix | DONE |
| 10 | macOS compatibility audit | DONE (static grep only; compat-matrix CI workflow IMPLEMENTED_UNVERIFIED — never run, no 2nd Mac) |
| 11 | Stress tests | DONE |
| 12 | Accessibility | CODE_DONE (interactive VoiceOver = BLOCKED_ENVIRONMENT) |
| 13 | Installer & first-run wizard | DONE (view layout itself not unit-testable; DMG/installer packaging is a separate later step) |
| 14 | Installer/app animation | VERIFIED (no fixes needed) |
| 15 | Visual validation | TODO — BLOCKED_ENVIRONMENT (no attached display in this session) |
| 16 | Local site copy | DONE |
| 17 | Documentation | PARTIAL → mostly closed this pass (module docs added: Applications, Cloud Cleanup, My Clutter, Settings, Space Lens, first-run state machine, installer experience; ROADMAP/FEATURE_MATRIX corrected for FSEvents; this report created) |
| 18 | Local CI gates | DONE (dev gate green; publish gate blocked, expected) |
| 19 | Version 0.8.0 decision | BLOCKED — criteria not met, do not bump |
| 20 | Final artifacts | BLOCKED — only after 19 |
| 21 | Final audit package | BLOCKED — only after 19 |

## Why the version has not moved to 0.8.0

Step 19's criteria require, among others, no orphaned settings, no
misleading UI/docs, and every automatable task closed. Real, honest
blockers remain:

- **BLOCKED_ENVIRONMENT**: interactive VoiceOver verification, real-display
  screenshots (Step 15), and the compat-matrix CI workflow have never
  actually run (no display, no second Mac in this environment).
- **BLOCKED_HUMAN**: public legal identity, security contact, domain, and
  code signing/notarization are unset — required before any public
  push/deploy, not before internal functional completion, but still listed
  honestly as open in `Documentation/ROADMAP.md` and
  `Documentation/HUMAN_BLOCKERS.md`.
- **Deliberately deferred, not missing**: several Cleanup rules (Simulators,
  Trash-emptying, Mail attachments, broken LaunchAgents) and browser
  history/cookie deletion in Privacy Cleaner require dedicated safety
  engines that have not been proven safe yet — shipping them as blind
  rules would violate the project's own safety bar, so they stay out and
  are documented as absent, not implied present.

None of the above are automatable gaps hiding behind schedule pressure —
each is either an environment fact of this sandbox or a maintainer decision
outside engineering's authority. When Step 19's remaining automatable items
(finishing Step 17's doc sync, and re-confirming there is no orphaned
setting or misleading claim) are closed, the version decision can be
revisited — but the archive and version name stay **MacCare Local 0.7.1**
until then.
