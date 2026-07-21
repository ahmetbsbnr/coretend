# CONTINUATION

## Where we are (product version 0.7.1, phase: 0.8.0 — Functional Completion)
Branch `feat/functional-completion`. The 0.8.0 effort is IN PROGRESS and NOT
complete — the product version stays **0.7.1** until every automatable criterion
in step 19 of the plan is genuinely met. See
`Documentation/FUNCTIONAL_COMPLETION_EXECUTION_PLAN.md` for the 21-step status
table (the authoritative tracker), plus `CURRENT_PROJECT_STATE.json`.

## HEAD this phase
`846617c`. Commits added this latest session (started from `0ed32cd`):
`995a49b` (settings matrix + orphan gate + flaky-test fix, Step 9 DONE),
`846617c` (Smart Care audit + safety tests, Step 2 DONE). Earlier session:
`323d3b5` (cleanup rules), `e0021fa` (dryRunDefault orphan fix).

## Baseline verified this phase
- 130 tests / 34 suites green (`bash Scripts/test.sh`), 0 warnings.
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
- Step 9 DONE (`995a49b`): `Scripts/generate-settings-matrix.py` derives
  `Documentation/SETTINGS_MATRIX.md` from `settings-matrix.json` (5 real
  settings). It discovers actual keys from `Sources/` (@AppStorage / setSetting
  / setting / .exclusions()) and fails on any orphaned or undocumented setting —
  the no-orphan gate, wired into `repository-doctor.sh` (`--check`). Also fixed a
  flaky 5s ClamAV process-timeout test (three result tests → 30s; the dedicated
  0.3s timeout test is unaffected). This flakiness is why the earlier "125 green"
  claim intermittently showed 1 failure.
- Step 2 DONE (`846617c`): Smart Care audit. Extracted pure nonisolated
  `SmartCareViewModel.autoExecutableFindings` (only reversible low-risk
  preselected findings auto-execute) + `SmartCareSafetyTests` +
  `CleanupRuleCatalogTests` (no preselected medium/high rule can exist).
  `Documentation/SMART_CARE_AUDIT.md` maps every safety property to code + test.
  Protection/Performance/Applications module *implementations* remain Steps 3/5
  (honestly shown unavailable, not simulated).

## Older completed work
Step 1 (partial): added 3 built-in cleanup rules in
`Sources/FileRules/UserCleanupRules.swift` — `user.oldinstallers`
(`.dmg/.pkg/.mpkg`, Downloads-only, 30d+), `user.oldarchives`
(archive extensions, Downloads-only, ≥1 MB, 30d+, no archive parsing),
`dev.xcode.archives` (Xcode Archives, 30d+). All medium-risk, `preselect:false`.
Added the Xcode Archives root to `allowedRoots`. 4 new tests in
`Tests/FileRulesTests/UserCleanupRulesTests.swift`. Docs: CLEANUP_GUIDE.md rule
table, ROADMAP.md deferred list, new FUNCTIONAL_COMPLETION_EXECUTION_PLAN.md.

## Next task
Steps 9 and 2 are now DONE. Remaining ordered work is mostly real feature
implementation (larger than the doc/audit slices just finished):
- Step 11 (stress tests): partially pre-covered — `engineStreamsAllFindingsUncappedAt5001`
  and the 12-consumer totals test already exist; DuplicateEngine already collapses
  hard links, honors min-size, picks keeper. Remaining stress fixtures (large SQLite
  history, deep/wide trees) depend on Steps 3/7 engines not yet built.
- Steps 3-8, 13-14: FSEvents watch, Privacy browser detection, app-update detection,
  My Clutter (duplicates/similar images), Space Lens, Cloud Cleanup, onboarding
  wizard, installer animation — each a real implementation slice + tests.
- Step 10: macOS compatibility audit (@available + fallbacks).
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
