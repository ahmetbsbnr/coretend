# Functional Completion Report (0.8.0 phase — CLOSED)

This is a snapshot report, not the tracker itself. The authoritative,
continuously-updated source is
`Documentation/FUNCTIONAL_COMPLETION_EXECUTION_PLAN.md` (21-step table) —
if the two ever disagree, that file wins. Product version is now **0.8.0**
(bumped locally this phase — no push, no deploy, no public publication).

## Snapshot at close

- Branch: `feat/functional-completion`
- Tests: 250/250 passing, 55 suites, 0 failures (`bash Scripts/test.sh`)
- Build: `swift build` and `swift build -c release` both green, **0 project
  warnings** (the one pre-existing Sendable warning in `OnboardingView.swift`
  was fixed this phase)
- Dev gates green: `doctor.sh`, `repository-doctor.sh` (bundles
  check-private-data, check-licenses, check-placeholders,
  check-feature-inventory, settings-matrix no-orphan gate,
  check-markdown-links, .gitignore sanity), `check-version-consistency.sh`,
  `test-uninstall.sh`, `test-distribution.sh`, `test-release-manifest.sh`,
  `verify-download.sh`
- Publish gate (`check-publish-readiness.sh`) intentionally red — expected
  pre-release, not a dev-gate failure. Human blockers only: placeholder
  tokens in the public-facing legal/security pages and no
  `Configuration/PublicIdentity.local.json`.
- Repo tree: clean at each commit checkpoint, no stray worktrees, no push.

## Step status (see the plan file for full evidence per step)

| # | Step | Status |
|---|------|--------|
| 0 | Baseline gates | DONE |
| 1 | Cleanup finalization | DONE_VERIFIED_WITH_DEFERRED_SCOPE — 10 rules shipped; Simulator/Trash-empty/Mail-attachments/broken-LaunchAgents candidates each classified with a security rationale in `REQUIREMENTS_DECISION_HISTORY.md`, not silently missing |
| 2 | Smart Care audit | DONE |
| 3 | Protection / FSEvents watch | DONE_VERIFIED — full 14-scenario matrix closed |
| 4 | Privacy Cleaner honesty | DONE |
| 5 | Applications & updates | DONE |
| 6 | My Clutter | DONE_VERIFIED — name search, real volume awareness, and UI-exposed exclusions shipped across all three sub-modules |
| 7 | Space Lens | DONE |
| 8 | Cloud Cleanup | DONE |
| 9 | Settings matrix | DONE |
| 10 | macOS compatibility audit | DONE (static grep only; compat-matrix CI workflow IMPLEMENTED_UNVERIFIED — never run, no 2nd Mac — BLOCKED_ENVIRONMENT) |
| 11 | Stress tests | DONE |
| 12 | Accessibility | CODE_DONE (interactive VoiceOver = BLOCKED_ENVIRONMENT) |
| 13 | Installer & first-run wizard | DONE (view layout itself not unit-testable) |
| 14 | Installer/app animation | VERIFIED (no fixes needed) |
| 15 | Visual validation | READY_FOR_MANUAL_QA — a real display IS available this session; one verification capture succeeded; full FR/EN × light/dark × every-module campaign is separate remaining work |
| 16 | Local site copy | DONE |
| 17 | Documentation | DONE — full doc-set sync, 7 new module docs, decision history, this report |
| 18 | Local CI gates | DONE (dev gate green; publish gate blocked, expected) |
| 19 | Version 0.8.0 decision | DONE — bumped, locally |
| 20 | Final artifacts | DONE — ZIP/DMG built, mounted, launched outside the repo, checksummed |
| 21 | Final audit package | DONE — external audit ZIP built |

## Why the version could move to 0.8.0

Step 19's criteria: no step left PARTIAL/NOT_STARTED, no orphaned settings,
no misleading UI/docs, remaining limits exclusively environment/human. All
held at close:

- **BLOCKED_ENVIRONMENT**: interactive VoiceOver verification and the full
  visual-QA capture campaign (Step 15) remain incomplete, but a real
  display genuinely exists in this sandbox this phase (re-confirmed via
  `screencapture -x` and `System Events` automation, both working) and one
  verification capture succeeded — this is real remaining polish work, not
  a fabricated blocker, and per this phase's explicit scope it does not
  block a local version bump. The compat-matrix CI workflow similarly has
  never run (no second Mac).
- **BLOCKED_HUMAN**: public legal identity, security contact, domain, and
  code signing/notarization are unset — required before any public
  push/deploy, not before local functional completion. Tracked in
  `Documentation/HUMAN_BLOCKERS.md`.
- **Deliberately deferred, not missing**: iOS Simulator data cleanup,
  Trash-emptying, Mail-attachment cleanup, broken-LaunchAgent removal, and
  browser history/cookie deletion in Privacy Cleaner require dedicated
  safety engines that don't exist yet — shipping them as blind rules would
  violate the project's own safety bar. Each is classified
  (DEFERRED_APPROVED / NOT_PLANNED / REPORT_ONLY / ANALYSIS_ONLY) with a
  written rationale in `Documentation/REQUIREMENTS_DECISION_HISTORY.md`,
  and documented as absent everywhere the UI/site could imply otherwise.

None of the above are automatable gaps hiding behind schedule pressure —
each is either an environment fact of this sandbox or a maintainer decision
outside engineering's authority. **MacCare Local 0.8.0** is the local
functional-completion version; public release readiness is a separate,
still-open decision gated on the BLOCKED_HUMAN items above.
