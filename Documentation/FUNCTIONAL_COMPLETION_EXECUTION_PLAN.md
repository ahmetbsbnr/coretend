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
| 2 | Smart Care full audit | DONE | 846617c | Audited orchestrator against safety matrix (SMART_CARE_AUDIT.md). Extracted pure `autoExecutableFindings` (only low-risk+preselected auto-executes) + SmartCareSafetyTests + catalog invariant (no preselected medium/high rule). Module *implementations* for Protection/Performance/Applications remain Steps 3/5 (honestly shown unavailable) |
| 3 | Protection / FSEvents watch | DONE | 28540dc | `ProtectionWatcher` actor behind injectable `MalwareScanning`/`FileProbe`: debounce/coalesce, file-stability wait, size+mtime fingerprint dedup with disk persistence, rate limit, honest ClamAV-unavailable, clean stop/restart. NEVER auto-quarantines (notify→review→voluntary). Real `FSEventsProducer` bridges FSEventStream→AsyncStream (not unit-tested; needs live runloop). Wired into Protection UI as off-by-default in-session watch over Downloads/Applications. +14 tests (139→153): single/burst/repeat/temp/modified/deleted/unmounted/unavailable/disabled/cancel/restart/persist |
| 4 | Privacy Cleaner honesty | DONE | (this) | Extracted testable `BrowserCatalog.detect(home:)` — real non-fuzzy detection of Chromium family (Chrome/Edge/Brave/Vivaldi/Chromium, "Default"/"Profile N" layout) + Firefox + Safari. Default stays cache-only to Trash; per-profile running-browser block + close-and-rescan already present. History/cookies/session deletion kept DEFERRED honestly (sizes shown, never deleted) — no closed-browser+backup+restore path yet. +5 fixture-tree tests (153→158) |
| 5 | Applications & updates | DONE | (this) | Centralized update-mechanism detection into tested `AppDiscovery.updateMechanism` engine (`UpdateMechanism` enum): App Store receipt, safe-https Sparkle feed (rejects http/file/javascript/no-host as dangerous), download-origin `kMDItemWhereFroms`, honest `.unknown`; non-overpromising `actionLabel` ("Show Update Options", never "Available"). UI `AppUpdateSource.detect` now delegates (single source of truth). +9 tests. Homebrew Cask origin NOW IMPLEMENTED (was deferred): found a concrete non-fuzzy signal — Caskroom `<token>/.metadata/<ver>/<ts>/Casks/<token>.json` carries an exact `{"app":["Name.app"]}` artifact stanza (incl. rename `target`). New `HomebrewCaskIndex.build()` maps exact bundle name→token; `classify` gains `.homebrewCask(token:)` outranking Sparkle/manual (App Store still wins). UI adds `.homebrew` update source (reveal-in-Finder action; never shells out to brew). +8 tests |
| 6 | My Clutter | TODO | | |
| 7 | Space Lens | TODO | | |
| 8 | Cloud Cleanup | TODO | | |
| 9 | Settings matrix | DONE | 995a49b | dryRunDefault orphan fix (e0021fa) + `Scripts/generate-settings-matrix.py`: derives SETTINGS_MATRIX.md from settings-matrix.json (5 settings), discovers real keys from Sources/ and fails on any orphaned/undocumented setting — no-orphan gate wired into repository-doctor. Also fixed a flaky 5s ClamAV process-timeout test (→30s) |
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
