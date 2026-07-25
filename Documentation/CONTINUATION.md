# CONTINUATION

## Where we are (product version 0.8.1, phase: 0.8.1 Final Canonical Audit Resync, CLOSED)

Branch `feat/coretend-rebrand-workspace`. **Nothing pushed, deployed, published,
signed, notarized. No DNS touched. No product behaviour changed.**

This phase changed only documents, evidence and archives, to make them agree with
the real final state. What it actually found and did:

- **Re-measured everything.** 274 tests in 57 suites, PASS. Debug and Release both
  build with zero warnings. Cross-checked for coherence: 274 `@Test`
  declarations equal 274 executed tests, 57 `@Suite` declarations equal 57
  executed suites, and the one parameterized test (4 arguments) accounts for the
  278 executed *cases*. The 0.8.0 figures of 250/55 were not carried forward.
- **Froze the 0.8.0 state** at `Documentation/AuditHistory/0.8.0/` — verbatim, not
  rewritten — and rewrote `CURRENT_PROJECT_STATE.json` and
  `CURRENT_AUDIT_STATE.json` for 0.8.1.
- **Separated the three commit identities.** `PRODUCT_SOURCE_COMMIT` is
  `92cbd08…` (what the artifacts were built from). `FINAL_REPOSITORY_HEAD` and
  `AUDIT_PACKAGE_COMMIT` are recorded post-hoc in the audit package manifest,
  because a commit cannot contain its own SHA.
- **Corrected the migration evidence.** The two pre-implementation documents both
  opened by saying no migration code existed. They are archived verbatim under
  `Documentation/RebrandHistory/PRE_IMPLEMENTATION_MIGRATION_*` and superseded by
  `Documentation/CORETEND_DATA_MIGRATION_REPORT.md`, which records the shipped
  code, the 20 tests, the one real run on this one machine, and what is *not*
  covered.
- **Fixed seven real defects**, listed in `CURRENT_PROJECT_STATE.json` under
  `defectsFoundAndFixedThisPhase`. The two that matter most:
  `Scripts/check-legacy-brand-references.sh` was **red at `92cbd08`** (the claim
  below that it passed was wrong), and it scanned case-sensitively, so a dead
  `MACCARELOCAL_STORE_DIR` export sat in the tree with the gate reporting green.
- **Rebuilt the release artifacts** — not by choice.
  `Scripts/test-release-manifest.sh` is a required gate and calls
  `Scripts/build-release.sh` inside its own resync regression check. That rebuild
  is also what corrected `latest.json`'s stale `sourceCommit`.

### Correction to the section below

The 0.8.1 rebrand section that follows states "Gates all green: legacy
references, …". That was not true at `92cbd08`: the legacy-references gate
failed on `Documentation/AUDIT_COMMANDS.log` and on this very file. It is green
now, after this phase's fix. The section is otherwise accurate and is left as
written.

## Previous phase (0.8.1 — CoreTend Rebrand & Workspace Migration, EXECUTED)

Branch `feat/coretend-rebrand-workspace`, off `feat/functional-completion`.
**Nothing pushed, nothing deployed, nothing published.** Repository path is now
`WEBSITE/products/coretend/app`.

The rename is done and the workspace is reorganised. What actually landed:

- **Name.** MacCare Local → **CoreTend**, everywhere: sources, SwiftPM package
  and targets, executable, bundle, resources, both localisations, scripts, CI,
  docs, site, legal metadata. Bundle identifier `com.ahmetbsbnr.coretend`.
  `Scripts/check-legacy-brand-references.sh` passes, and every allowlisted
  survivor states why it must keep the old name.
- **User data.** `Sources/Persistence/LegacyDataMigration.swift` migrates the
  Application Support directory and the old `UserDefaults` domain on first
  launch: copy-only, per-item, resumable, never overwriting existing
  new-identity data, failures surfaced in Settings. 20 tests. Verified for real
  on this machine — store + WAL + SHM + Quarantine copied, three preference
  keys carried, legacy directory untouched.
- **Identity.** Living System palette named at its definition in
  `MCColor.LivingSystem` with contrast tests in both directions, and a complete
  generated asset set (icon 16–1024 + icns, menu-bar templates, favicons,
  lockups light/dark/mono, onboarding hero, Open Graph, DMG background, SVG +
  PDF vector sources).
- **Site.** Rebuilt bilingual on the new identity, zero external requests, zero
  JavaScript, gated by `Scripts/check-website.sh` (freshness, locale parity,
  link integrity, accessibility floor, editorial honesty read per sentence).
- **Workspace.** Both repositories moved into `WEBSITE/` as independent git
  repos; `Scripts/check-workspace-layout.sh` proves they stay independent.
- **Release.** 0.8.1 ZIP + DMG built, SHA256SUMS verifies, ZIP passes
  `unzip -t`, app launches from a temp directory outside the repository.

Gates all green: legacy references, brand assets, website, workspace layout,
version consistency, private data, licenses, repository doctor. 274/274 tests
pass; Debug and Release build with zero warnings.

## What is still blocked, and why

**Publication.** `Scripts/check-brand-clearance.sh --publication` fails on
purpose. `--engineering` passes, and that is what authorised this work locally.
To unblock publication, all of these must become true:

1. A real trademark search for "CoreTend" (Nice 9 / 42, across EUIPO, INPI,
   USPTO, UKIPO, WIPO) plus a prior-software-usage search. **None has been
   run**, and `Documentation/BRAND_SEARCH_EVIDENCE.md` says exactly that rather
   than leaving an empty conflict table to be misread as a clean result.
2. `legalReviewStatus` → `accepted` and `publicReleaseAllowed` → `true` in
   `Configuration/BrandRenameApproval.local.json` (gitignored).
3. A legal identity and a security contact. The legal and security pages render
   bracketed placeholders where those belong — visible gaps, not invented
   values.
4. A signing/notarization decision. Builds are unsigned.

**Environment.** The DMG's saved icon positions need the Finder, which refused
automation here. Reported as `BLOCKED_ENVIRONMENT` by `package-dmg.sh`; the DMG
is functional, with its background and volume icon embedded. Interactive
VoiceOver and the full visual-QA capture campaign remain blocked the same way.

## Rollback

`Documentation/PRODUCT_RENAME_ROLLBACK.md` has three independent paths: reset to
the local tag `pre-coretend-rebrand-0.8.0`, clone from the git bundles in
`~/Documents/CoreTend-Migration-Backups/`, or `mv` the two repositories back to
their old paths. Nothing was deleted at any point.

## Files in flight
None — tree is clean, every slice is committed.

## Resume command

```sh
cd ~/Documents/MAC_ORGANISE/00_DOCUMENTS_EXISTANTS/01_PROJETS/01_PROJETS_ACTIFS/WEBSITE/products/coretend/app
git status --short && git log --oneline -12 && bash Scripts/test.sh
```

Then verify claims against real source before trusting this file — earlier
sessions ended in infrastructure interruptions and this document lagged the
commits until reconciled by hand. Commit small and often.

---

## Previous phase (0.8.1A — Brand Clearance & Workspace Migration Preflight, CLOSED)
Branch `feat/functional-completion` (unchanged, no push). Product version
stays **0.8.0** — this phase was preflight/planning only, no rename
applied. Key outcome: **MacClear = `CONFLICT_HIGH`**, blocked — three
independent real "MacClear"/"macclear" GitHub repos found in the exact
same category, one a near-exact technical/functional twin
(`BRAND_NAME_CLEARANCE.md`). A 32-name screened shortlist exists
(`BRAND_NAME_SHORTLIST.md`) with no selection made — that choice is
`BLOCKED_HUMAN`. Portfolio repo identified and inventoried, read-only
(`PORTFOLIO_REPOSITORY_INVENTORY.md`). Workspace target structure,
product-rename inventory/plan/rollback, user-data migration design +
test plan, cross-site design audit, and logo/asset planning are all
documented, nothing executed. Two new gates
(`Scripts/check-brand-clearance.sh`, `Scripts/check-workspace-migration-readiness.sh`)
and a non-destructive preflight/backup script
(`Scripts/preflight-workspace-migration.sh`) exist and are tested (18
shell tests total across the three). No folder moved, no repo renamed, no
bundle identifier changed, no domain changed, no MacClear asset produced.
Next command after the user approves a name: fill in
`Configuration/BrandRenameApproval.local.json`, then re-run
`Scripts/check-brand-clearance.sh <approved-name>`.

## Previous phase (0.8.0 — Functional Completion, CLOSED)
Branch `feat/functional-completion`. The 0.8.0 effort completed all 21 steps
this session: steps 1-18 (every automatable item) are DONE/DONE_VERIFIED/
CODE_DONE/READY_FOR_MANUAL_QA, step 19's version decision was made (bumped
0.7.1 → 0.8.0, locally — no push/deploy/publish), step 20 built and verified
the ZIP/DMG artifacts, step 21 built the external audit package. See
`Documentation/FUNCTIONAL_COMPLETION_EXECUTION_PLAN.md` for the full 21-step
table (the authoritative tracker) and `Documentation/FUNCTIONAL_COMPLETION_REPORT.md`
for the narrative summary. Remaining gaps are exclusively BLOCKED_ENVIRONMENT
(interactive VoiceOver, full visual-QA capture campaign) or BLOCKED_HUMAN
(legal identity, signing) — both documented, neither hidden. Next phase is
NOT started: no MacClear rename, no project relocation, no 0.9.0 work.

## HEAD this phase
Latest: (final commit of this session, packaging + audit zip) — closed the
plan. Resumed from `317e32c` (previous session's HEAD after a documentation
recovery pass). This session: fixed the last Sendable warning (0 project
warnings in Debug/Release, `95cac30`); closed Step 3's FSEvents test matrix
(rate-limit + rename-independence tests, `b140527`, DONE_VERIFIED); shipped
My Clutter search/volume-awareness/UI-exposed-exclusions across Large & Old,
Duplicates, and Similar Images (`6b688dd`, `ef04a11`, `35588ff`, `04bf457`,
215→250 tests, Step 6 DONE_VERIFIED); documented Step 1's Cleanup scope
decision (`c6a01c2`, DONE_VERIFIED_WITH_DEFERRED_SCOPE); re-confirmed real
display availability and closed Step 15 as READY_FOR_MANUAL_QA (one real
verification capture succeeded); bumped version 0.7.1→0.8.0 centrally
(`5ff689f`); built and verified 0.8.0 release artifacts (`7e60e06`); built
the external audit package. Full detail in `FUNCTIONAL_COMPLETION_REPORT.md`.

## Earlier this phase
Latest before this session: `7da3dde` — Step 17 (documentation sync), recovered after an API
disconnect mid-session. Previous agent's uncommitted doc work (7 new module
docs + regenerated test-inventory/AUDIT_COMMANDS.log) was inspected, verified
against source, and committed (`932a961`), then Steps 7/8 in the plan table
(Space Lens/Cloud Cleanup — stuck at TODO despite real tested work at
`a7ac701`) and ROADMAP/FEATURE_MATRIX (still called the Step 3 FSEvents
watcher DEFERRED) were corrected, and the missing
`FUNCTIONAL_COMPLETION_REPORT.md` was added (`7da3dde`). 215/215 tests,
Debug+Release build, all dev gates (doctor/repository-doctor/private-data/
licenses/placeholders/feature-inventory/settings-matrix/markdown-links) green
throughout. Publish gate stays red as expected (BLOCKED_HUMAN identity/
signing). **Version stays 0.7.1** — Step 15 (visual validation) is still
BLOCKED_ENVIRONMENT, Steps 1/6 still carry deliberately-deferred safety items
plus Step 6's non-safety enhancements (Large&Old name search, per-volume
awareness, UI-exposed exclusions), and Steps 19-21 are correctly BLOCKED
until those close — do not bump version, do not build final artifacts yet.

Earlier: `2070566` — Step 16 (local site copy). See "Task just finished" below
for Steps 14 + 16. Earlier milestone summarized
here: `f336475` — Step 10 (macOS compatibility audit). Re-ran the full
API grep across `Sources/`; every API (MenuBarExtra=13, Vision
feature-print/QLThumbnailGenerator=10.15, FSEvents/ubiquitous/SQLite3
ancient, `@Observable`=14 exactly at floor) sits at or below the declared
macOS 14 target, so **no `@available` guards were needed** — confirms the
existing `API_AVAILABILITY_AUDIT.md`. Added
`.github/workflows/compat-matrix.yml` (macos-14 + macos-15 build+test),
status IMPLEMENTED_UNVERIFIED (never pushed/run — no Xcode/2nd Mac). Static
grep + single-machine `swift build`/`Scripts/test.sh` only; NOT compiled
against the 14.0 SDK. 191 tests / 41 suites green. Prior HEADs this phase
`cee99e1`→`c3900dc` = Step 6 (My Clutter) partial.

Earlier: `a7ac701` — Step 7 (Space Lens) + Step 8 (Cloud Cleanup) testability
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

## Task just finished (Step 14 + Step 16 — animation verify + site copy)
**Step 14 (Installer/app animation) — VERIFIED, no fixes needed.** All Core
Bloom / Orbital Ecology motion is real-state-driven: `MCHeroCoreView` derives
`MCHeroState` from `SmartCareViewModel.phase`; `OrbitalProgressView` animates
only when `animating && !reduceMotion`; `OnboardingView` uses the static
`CoreBloomMark` only. No `.repeatForever` / `scheduledTimer` / `Timer.publish`
anywhere in Sources — the single continuous animation is a
`TimelineView(.animation)` indeterminate arc that SwiftUI auto-pauses off-screen
and is gated behind `animating && !reduceMotion`. Reduce Motion honored at every
call site via the `MCMotion.animation(_:reduce:)` choke point +
`@Environment(\.accessibilityReduceMotion)` inside each DesignSystem view. All
colors are `MCColor.*` tokens (the only hex hits outside DesignSystem are Mach-O
magic numbers in AppDiscovery, not colors). No Swift change made.

**Step 16 (Local site copy) — DONE (`2070566`).** Site is generated by
`Website/generate.py` (single source). One real overstatement fixed in the EN+FR
features cards: Privacy Cleaner said it clears "caches, logs and other
reclaimable local files" → corrected to browser cache-only (Chrome-family/
Firefox/Safari), only while the browser is closed, history/cookies shown but
never deleted (matches PrivacyCleanerView + Step 4). Protection card tightened:
ClamAV installed separately, flags for review, no auto-quarantine. Everything
else already honest (download page discloses unsigned/not-notarized + no live
link, pre-1.0 banners, no multi-OS testing claim). Regenerated
`en/features.html` + `fr/features.html`. Site stays static/bilingual, no
trackers/accounts/download links added. 215/215 tests + build still green.

## Task before that (Step 13 — First-run wizard)
Extended `OnboardingView.swift` (was 4 basic steps) into the full 8-step plan
wizard, split into a tested pure-logic file + a view. Three atomic commits:
1. `OnboardingLogic.swift` + `OnboardingLogicTests.swift` (+15 tests, 200→215):
   SecurityProfile→SecurityConfig (safe-default invariant), LaunchLocation.detect,
   SystemCheck.items/overall (worst-wins), ClamAVVersionInfo.parse.
2. The 8-step wizard view (Welcome→Summary) driven by that logic. Move-to-
   Applications is a user-space FileManager copy (fallback ~/Applications, then
   reveal-for-drag) — no sudo/privilege escalation. Notification toggle requests
   real macOS auth, never claims grant; FDA step only opens Settings + rechecks.
3. Re-launchable from Settings ("Run setup assistant again" → .mcShowOnboarding
   observed by MainWindow); new persisted `securityProfile` setting documented
   in settings-matrix.json (regenerated SETTINGS_MATRIX.md, no-orphan gate green).
EN+FR strings added (UTF-16 files). **Tested vs view-only**: the three logic
pieces are unit-tested; the SwiftUI layout of every step is view-only (SwiftUI
view bodies aren't unit-testable). **Deferred**: actual installer/DMG packaging
(this slice is the first-run wizard only — no 0.8.0 zip per scope). **Blocked**:
interactive on-display verification = BLOCKED_ENVIRONMENT. 215/215 tests green,
Debug+Release build green, repository-doctor all checks passed.

## Task before that (Step 12 — Accessibility, code-level)
Code-level accessibility audit of every SwiftUI view (CoreTendApp + shared
DesignSystem views). Codebase was already strong; found and fixed a small set
of real gaps in 4 atomic commits (all modifier-only, no new tests — SwiftUI
modifier presence isn't unit-testable):
- Reveal-in-Finder icon buttons in Cleanup/Protection/Duplicates/Leftovers/
  Performance now have `accessibilityLabel` (MyClutter/CloudCleanup/
  SimilarImages already did).
- Privacy per-profile selection toggle labeled.
- Space Lens treemap: `accessibilityElement(children:.ignore)` + item-count/
  size summary label (fragments no longer leak to VoiceOver; child list is the
  keyboard-navigable equivalent, unchanged).
- Menu-bar metric rows: non-color warning glyph + combined "needs attention"
  VoiceOver label (CPU/free-space warns were color-only).
- MCEmptyState/MCErrorState decorative icons `accessibilityHidden`.
New EN/FR strings: `spacelens.treemap.a11y_summary`, `menubar.warning_a11y`.
No functional/safety behavior changed. 200/200 tests green throughout.
**Interactive VoiceOver + real-display verification = BLOCKED_ENVIRONMENT**
(headless CommandLineTools, no display/VoiceOver session). What needed no
change: DesignSystem already wires Reduce Motion/Transparency/Differentiate-
Without-Color + MCAccessibilityState.increaseContrast; decorative animation
views (Fragment/Mesh/Overlap/CoreBloom/HeroCore) already hidden + expose
accessibilityDescription; status badges are symbol+text; Duplicates keeper is
a text badge; Protection threats are icon+color; Settings toggles/exclusion
buttons and Applications rows already labeled; AppUpdates/MyActivity/
Onboarding/SafetyLog had no unlabeled controls.

## Task before that
- Step 10 (`f336475`): macOS compatibility audit. Grep-verified all APIs
  ≤ macOS 14 floor ⇒ zero `@available` fixes. `compat-matrix.yml` drafted
  (IMPLEMENTED_UNVERIFIED). Docs: Step 10 row + `API_AVAILABILITY_AUDIT.md`
  re-verification section.
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
- **Step 11**: stress tests — DONE. 9 stress fixtures added (191→200 tests),
  all synthetic/no-personal-data, kept in the normal suite with count assertions
  + generous wall-clock ceilings (durations printed, not asserted). Covered:
  cleanup 12k findings (uncapped streaming), duplicates 10k same-size candidates
  incl. hard links + sparse (correct + sub-quadratic), similar images 157 incl.
  4×5000² (metadata-only pixel-count, memory-bounded), Space Lens wide 5k
  siblings + deep 60 levels, SQLite history 8k×2 rows (bounded indexed reads
  measured ~0.01s), FSEvents burst 20k events/50 paths (coalesces to 50 scans),
  rapid cancellation of Space Lens + ScanEngine (fast teardown). No bugs found.
  Suite wall clock ~7s → ~12s real. Details + measured-vs-qualitative breakdown
  in `Documentation/STRESS_TEST_REPORT.md`.
- **Step 12** (accessibility), **Step 13** (first-run wizard), **Step 14**
  (installer/app animation — VERIFIED, no fixes), **Step 16** (local site copy —
  DONE `2070566`): complete (see above / plan rows). **Step 17** (documentation):
  PARTIAL — remaining doc-set sync not started.
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
