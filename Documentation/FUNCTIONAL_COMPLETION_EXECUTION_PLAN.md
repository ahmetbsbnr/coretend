# Functional Completion Execution Plan (0.8.0)

Tracks the 21-step "0.8.0 — Functional Completion" effort. Status is honest:
DONE means real code + passing tests exist; PARTIAL means some real work landed
but the step is not fully satisfied; TODO means not started this phase.
The product version stays **0.7.1** until every automatable criterion in step 19
is genuinely true — it is not yet.

| # | Task | Status | Commit | Notes |
|---|------|--------|--------|-------|
| 0 | Verify state + baseline gates | DONE | 0c1394d | 118→122 tests, 0 warnings, Debug+Release build, all dev gates green, clean tree |
| 1 | Cleanup finalization | PARTIAL | (this) | Added old-installers, old-archives, Xcode-archives rules (Downloads/Developer-scoped, never preselected) + 4 tests. Simulators / Trash-empty / Mail attachments / broken LaunchAgents = DEFERRED (need dedicated safety engines, not blind extension rules) |
| 2 | Smart Care full audit | TODO | | |
| 3 | Protection / FSEvents watch | TODO | | ClamAV-gated; honestly unavailable without it |
| 4 | Privacy Cleaner honesty | TODO | | keep cache-only unless full closed-browser+backup path proven |
| 5 | Applications & updates | TODO | | detect-only, no downloads |
| 6 | My Clutter | TODO | | |
| 7 | Space Lens | TODO | | |
| 8 | Cloud Cleanup | TODO | | |
| 9 | Settings matrix | PARTIAL | (this) | Found + fixed a real orphan: `dryRunDefault` was persisted/toggled in Settings but Cleanup/SmartCare hard-coded `dryRun=true` and never read it. Wired both view models to load it on appear via a shared pure `AppEnvironment.dryRunEnabled(fromSetting:)` helper (3 call sites now route through it) + 3 tests. Full SETTINGS_MATRIX.md / settings-matrix.json generator still TODO |
| 10 | macOS compatibility audit | TODO | | |
| 11 | Stress tests | TODO | | |
| 12 | Accessibility | TODO | | interactive VoiceOver = BLOCKED_ENVIRONMENT |
| 13 | Installer & first-run wizard | TODO | | |
| 14 | Installer/app animation | TODO | | |
| 15 | Visual validation | TODO | | needs display; else BLOCKED_ENVIRONMENT |
| 16 | Local site copy | TODO | | |
| 17 | Documentation | PARTIAL | (this) | CLEANUP_GUIDE updated for new rules |
| 18 | Local CI gates | DONE | 0c1394d | dev gate green; publish gate blocked (expected, pre-release) |
| 19 | Version 0.8.0 decision | BLOCKED | | criteria not met — do NOT bump |
| 20 | Final artifacts | BLOCKED | | only after 19 |
| 21 | Final audit package | BLOCKED | | only after 19 |

## Resume

Read this file + `CONTINUATION.md` + `CURRENT_PROJECT_STATE.json` first, then
pick the next TODO row. Each slice: implement → `bash Scripts/test.sh` →
`swift build -c release` → inspect diff → atomic local commit (never push) →
update this table's Status/Commit → update CONTINUATION.md → continue.
