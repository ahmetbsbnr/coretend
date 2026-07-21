# CONTINUATION

## Where we are (product version 0.7.1, phase: 0.8.0 — Functional Completion)
Branch `feat/functional-completion`. The 0.8.0 effort is IN PROGRESS and NOT
complete — the product version stays **0.7.1** until every automatable criterion
in step 19 of the plan is genuinely met. See
`Documentation/FUNCTIONAL_COMPLETION_EXECUTION_PLAN.md` for the 21-step status
table (the authoritative tracker), plus `CURRENT_PROJECT_STATE.json`.

## HEAD this phase
`e0021fa`. Commits added this session: `323d3b5` (cleanup rules),
`e0021fa` (dryRunDefault orphan fix). Started from `0c1394d`.

## Baseline verified this phase
- 125 tests / 32 suites green (`bash Scripts/test.sh`), 0 warnings.
- Debug + Release `swift build` succeed.
- Dev gates green: doctor, repository-doctor, check-private-data, check-licenses,
  check-feature-inventory, check-version-consistency, check-markdown-links.
- Publish gate (`check-publish-readiness.sh`) intentionally fails pre-release
  (BLOCKED_HUMAN identity/signing) — expected, not a dev-gate failure.

## Toolchain (unchanged, read first)
- No Xcode — CommandLineTools only. Build `swift build`, tests **only** via
  `Scripts/test.sh`, bundle via `Scripts/package-local.sh`.
- After changing a public struct's stored layout, `rm -rf .build` once
  (incremental cross-module reads have corrupted twice historically).

## Task just finished
Step 9 (partial): fixed a real orphaned setting — `dryRunDefault` was persisted
in Settings but never read by Cleanup/Smart Care. Wired via shared pure helper
`AppEnvironment.dryRunEnabled(fromSetting:)` + 3 tests. The full @AppStorage/
store settings surface (menuBarEnabled, onboardingDone/Step, dryRunDefault,
exclusions) is small and now all consumers verified — no remaining orphans. A
script-generated SETTINGS_MATRIX.md / settings-matrix.json is still TODO.

Earlier this session — Step 1 (partial): added 3 built-in cleanup rules in
`Sources/FileRules/UserCleanupRules.swift` — `user.oldinstallers`
(`.dmg/.pkg/.mpkg`, Downloads-only, 30d+), `user.oldarchives`
(archive extensions, Downloads-only, ≥1 MB, 30d+, no archive parsing),
`dev.xcode.archives` (Xcode Archives, 30d+). All medium-risk, `preselect:false`.
Added the Xcode Archives root to `allowedRoots`. 4 new tests in
`Tests/FileRulesTests/UserCleanupRulesTests.swift`. Docs: CLEANUP_GUIDE.md rule
table, ROADMAP.md deferred list, new FUNCTIONAL_COMPLETION_EXECUTION_PLAN.md.

## Next task
Good next automatable slices (existing code, no display/human needed):
- Step 9 remainder: write `Scripts/generate-settings-matrix.py` deriving
  `Documentation/settings-matrix.json` + SETTINGS_MATRIX.md from source
  (@AppStorage keys + store settings + their consumers).
- Step 2: Smart Care audit matrix doc + integration tests over the existing
  orchestrator (category × engine × risk × preselect × reversibility).
- Step 11: deterministic stress-test fixtures (10k findings, duplicate/hardlink
  groups) — pure, CI-safe assertions.
Steps needing environment/human stay BLOCKED (12 VoiceOver, 15 screenshots,
19-21 version bump/artifacts — do NOT bump to 0.8.0; criteria far from met).

## Files in flight
None — tree is clean, this slice is committed.

## Blockers
- Interactive VoiceOver, real-display screenshots: BLOCKED_ENVIRONMENT.
- Public identity + signing: BLOCKED_HUMAN (see ROADMAP / HUMAN_BLOCKERS).

## Resume command
Read `Documentation/CONTINUATION.md`,
`Documentation/FUNCTIONAL_COMPLETION_EXECUTION_PLAN.md`, and
`CURRENT_PROJECT_STATE.json`, then continue the next TODO row. Verify state with
`git status --short && bash Scripts/test.sh` before editing.

---
(Older per-session history through v0.4.x lived here; superseded by the plan
tracker and CHANGELOG. Trimmed to keep this file resume-usable from scratch.)
