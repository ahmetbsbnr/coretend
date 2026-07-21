# CONTINUATION

## Where we are (product version 0.7.1, phase: 0.8.0 — Functional Completion)
Branch `feat/functional-completion`. The 0.8.0 effort is IN PROGRESS and NOT
complete — the product version stays **0.7.1** until every automatable criterion
in step 19 of the plan is genuinely met. See
`Documentation/FUNCTIONAL_COMPLETION_EXECUTION_PLAN.md` for the 21-step status
table (the authoritative tracker), plus `CURRENT_PROJECT_STATE.json`.

## HEAD this phase
Latest: `a7ac701` — Step 7 (Space Lens) + Step 8 (Cloud Cleanup) testability
pass. `CloudCleanupViewModel.detectProviders(home:)` / `.measure(root:)` made
static+nonisolated for fixture-based testing (Google Drive `CloudStorage`
layout, Dropbox root, symlink skip, byte-descending sort). `SpaceLensEngine`
gets symlink-skip / nested-rollup / depth-cap / empty-zero-size coverage.
New `SpaceLensNavigationTests` covers the view model's descend/pop stack
logic directly. 174→184 tests (39 suites).

Prior in this phase, oldest→newest: `323d3b5` (Step 1 cleanup rules),
`e0021fa` (dryRunDefault orphan fix), `0ed32cd` (checkpoint), `995a49b`
(Step 9 settings matrix + orphan gate + flaky-test fix), `846617c` (Step 2
Smart Care audit), `44ae5b2` (checkpoint), `d483e61` (Step 5 partial —
update-mechanism engine), `af27a48`+`28540dc` (Step 3 — FSEvents watcher
core + Protection UI wiring), `663e170` (Step 4 — Chromium-family browser
detection), `ea9334f` (Step 5 finish — Homebrew Cask origin via Caskroom
metadata), `e8dac04` (Step 6/8 partial — cloud-file hydration safety),
`07bd8bc` (SyncState classification tests, recovered after an ECONNRESET
mid-session), `a7ac701` (this slice, recovered after hitting the session
API limit mid-session).

**Two prior slices ended in infra interruptions, not broken work**: both
times the interrupted agent had already committed cleanly and left at most
one slice of good, complete, tested — but uncommitted — work behind. Both
times it was inspected, verified via `Scripts/test.sh`, and committed rather
than discarded. Lesson applied going forward: commit smaller and more often.

## Baseline verified this phase (re-verified at HEAD a7ac701)
- 184 tests / 39 suites green (`bash Scripts/test.sh`), 0 warnings.
- Debug + Release `swift build` succeed (both re-verified just now).
- Tree clean, no stray worktrees (`git worktree list` shows only the main
  checkout), no untracked files.
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
- Step 7/8 (`a7ac701`): Space Lens navigation logic tests + Cloud Cleanup
  provider-detection/measure made testable (see above). Space Lens engine
  edge cases (symlinks, nested rollup, depth cap, empty dirs) covered.
- Step 6/8 partial (`e8dac04`, `07bd8bc`): cloud files never hydrated to
  size them; `SyncState.classify` invariant tests.
- Step 5 (`d483e61`, `ea9334f`): tested `AppDiscovery.updateMechanism`
  engine (App Store/Sparkle-with-dangerous-URL-rejection/download-origin/
  unknown), UI delegates to it; Homebrew Cask origin via real Caskroom
  receipt metadata (not fuzzy name matching).
- Step 4 (`663e170`): testable Chromium-family (Chrome/Chromium/Brave-style)
  browser profile + running-state detection.
- Step 3 (`af27a48`, `28540dc`): injectable/testable FSEvents watch engine
  core, wired into Protection UI as an optional, off-by-default surface.
- Step 2 (`846617c`): Smart Care audit — pure nonisolated
  `SmartCareViewModel.autoExecutableFindings` (only reversible low-risk
  preselected findings auto-execute) + safety tests + catalog invariant test.
  `Documentation/SMART_CARE_AUDIT.md` maps every safety property to code+test.
- Step 9 (`995a49b`): script-derived `SETTINGS_MATRIX.md`/`settings-matrix.json`
  + no-orphan gate wired into `repository-doctor.sh --check`.
- Step 1 (`323d3b5`): 3 new built-in cleanup rules (old installers, old
  archives, Xcode Archives), all medium-risk / `preselect:false`.

## Next task — verify each of these against real source before assuming done
Given two prior sessions' docs lagged behind actual commits, the next agent
MUST verify per-step completeness against source, not just this file:
- **Step 3 (FSEvents)**: core watcher + UI wiring landed — verify the full
  simulated-stream test matrix from the plan (burst, dedup, temp-file,
  deleted-before-scan, unmounted volume, ClamAV-absent, cancel, restart) is
  actually present; add what's missing.
- **Step 4 (Privacy Cleaner)**: VERIFIED COMPLETE (audit pass). Detection is
  real for Chromium family (Chrome/Edge/Brave/Vivaldi/Chromium), Firefox, and
  Safari — `BrowserCatalog.detect(home:)` walks known on-disk layouts, no
  fuzzy matching. Browser-running state genuinely gates the UI: `isRunning`
  disables the per-profile selection toggle, shows `privacy.profile_running_reason`,
  and offers `Close Browser & Rescan` (`closeBrowserAndRescan`); `cleanCaches`
  also re-filters `!isRunning` before acting, so a mid-scan relaunch can't slip
  through. Default is genuinely cache-only: `cleanCaches` only touches
  `profile.cacheURLs` (always under `Library/Caches`) through a SafetyCenter
  whose PathValidator is scoped to `Library/Caches`; History/Cookies bytes are
  reported for transparency, never deleted. UI copy (footer + strings, EN/FR)
  is honest — no "full privacy cleanup" claim. History/cookies/session deletion
  stays DEFERRED (no closed-browser+backup+tested-restore path yet). Added test
  `cacheOnlyValidatorAcceptsCachesRejectsHistoryAndCookies` proving the
  enforcement gate rejects History/Cookies paths (185 tests total).
- **Step 6 (My Clutter)**: audited against the plan checklist (`30337dc`,
  `cee99e1`). 191 tests (was 185).
  - **Large & Old** (`LargeOldFilesView`/`MyClutterViewModel` + `ScanEngine`):
    VERIFIED read-only — no deletion path, findings only revealed in Finder /
    Quick Look, so nothing can be auto-deleted. Size + age filters, size/age
    sort, Quick Look, Finder-reveal, 2000-item cap, and graceful `.error`
    handling (permission-denied/unreadable ignored, no crash) all confirmed.
    Added `MyClutterSortTests` for the `sortedFindings` UI seam. DEFERRED
    (enhancement, not safety): name search field, per-volume awareness, and
    UI-exposed exclusions — engine supports `excludedPaths` (tested) but the
    Large & Old screen wires the default config.
  - **Duplicates** (`DuplicateEngine` + `DuplicatesView`): VERIFIED pipeline
    (size→64KB partial→full SHA-256, hard-link collapse, symlink skip,
    remote-only iCloud skip, shallowest-path keeper, `wastedBytes` counts
    copies-minus-keeper so the keeper is never double-counted, keeper never
    fully removable, Trash-based via SafetyCenter). FIXED: added mid-scan-edit
    guard — `hasChangedOnDisk` (fresh-URL read to defeat URL resource-value
    caching) deselects any copy whose mtime changed since the scan before
    trashing. History/restore ride the shared SafetyCenter store.
  - **Similar Images** (`SimilarImagesEngine` + `SimilarImagesView`): VERIFIED
    Vision feature-print pipeline, jpg/png/heic/gif/tiff/webp/bmp, EXIF
    orientation (via `VNImageRequestHandler(url:)`), metadata-only pixel-count
    (no full decode → memory-bounded), corrupt image skipped via `try?`,
    Photos-library + remote-only iCloud skipped, async QL thumbnails off the
    main actor, configurable threshold, greedy clustering, best-resolution
    suggestion. VERIFIED no deletion path exists at all — reveal-only, so
    deletion can never be automatic. Added end-to-end `SimilarImagesEngineTests`.
    The view's `.unavailable` branch is currently unreachable (engine never
    emits it) — harmless dead branch, left for a future Vision-unavailable path.
- **Step 10**: macOS compatibility audit — not started.
- **Step 11**: stress tests — partially pre-covered (`engineStreamsAllFindingsUncappedAt5001`,
  12-consumer totals, hard-link collapsing) but large SQLite history / bursty
  FSEvents / deep-wide-tree fixtures not yet built.
- **Steps 12-14, 16-17**: accessibility audit, first-run wizard, installer
  animation, site copy sync, doc set — not started.
Steps needing environment/human stay BLOCKED (12's interactive VoiceOver
portion, 15 screenshots, 19-21 version bump/artifacts — do NOT bump to
0.8.0; criteria far from met).

## Files in flight
None — tree is clean, this slice is committed.

## Blockers
- Interactive VoiceOver, real-display screenshots: BLOCKED_ENVIRONMENT.
- Public identity + signing: BLOCKED_HUMAN (see ROADMAP / HUMAN_BLOCKERS).

## Resume command
Read `Documentation/CONTINUATION.md`,
`Documentation/FUNCTIONAL_COMPLETION_EXECUTION_PLAN.md`, and
`CURRENT_PROJECT_STATE.json`, then continue the next TODO row — but verify
each "done" step above against real source first, don't trust doc claims
alone (two prior sessions ended in infra interruptions and this file lagged
real commits until manually reconciled). Verify state with
`git status --short && git log --oneline -15 && bash Scripts/test.sh` before
editing. Commit small and often — one function + its tests + a commit,
not a multi-module batch — so an API/session interruption never loses more
than a few minutes of work.

---
(Older per-session history through v0.4.x lived here; superseded by the plan
tracker and CHANGELOG. Trimmed to keep this file resume-usable from scratch.)
