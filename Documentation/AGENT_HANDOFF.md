# CoreTend Agent Handoff

## ACTIVE — v1.1 Smart Scan + Space Lens 2.0 app pass

### Targeted UI fix pass (2026-09-06) — HEAD after `b200cbd`

Two user-facing items from the visual-QA pass, nothing else touched.

- **Command palette — outside-click dismissal is now real (`CoreTendApp.swift`).**
  Replaced `.sheet(isPresented: $showCommandPalette)` (document-modal — outside
  click is a structural no-op) with `CommandPaletteOverlay` in an `.overlay` on
  `MainWindow`: an opaque full-window `Color.black.opacity(0.18)` backdrop that
  **consumes** the dismissal click (no click-through to the control beneath) and
  closes, with the panel floating above behind its own `.contentShape`. Escape
  has exactly **one** owner now — `.onExitCommand { close() }` on the overlay;
  removed the field `.onKeyPress(.escape)`, the ✕ `.keyboardShortcut(
  .cancelAction)`, and the container `.onExitCommand` from the previous pass.
  On close the whole overlay leaves the tree (no orphaned focus).
- **⌘ trigger moved out of the window corner (`CoreTendApp.swift`).** Removed the
  global `.toolbar` item; `MainWindow` now injects `.safeAreaInset(edge: .top)
  { paletteHeader }` on the detail `Group` — a 26 pt circular ⌘ button,
  trailing-aligned to the page gutter (`MCSpacing.page` / `.sm` / `.xs`, tokens
  only). One placement, every module.
- **New strings:** `palette.open.a11y` / `palette.close.a11y` (EN + FR, parity
  checked).
- **Tests:** +5 in `CommandPaletteTests.swift` (overlay-not-sheet, backdrop
  consumes+closes, single Escape owner, trigger in header band, a11y string
  parity). Suite **812 → 817**, all green.
- **Sidebar fix (`55d184c`) preserved** — scroll hosts untouched;
  `SidebarStructureTests` still passes.
- **HUMAN VERIFICATION REQUIRED (physical gesture / visual only):** the
  AppleScript+`screencapture` route is non-functional this session (CoreTend
  launches but System Events sees 0 windows — same blocker as prior passes), so
  a human must confirm on device: outside-click closes with no click-through to
  "Préparer le plan"; Escape / ✕ / result-click all close; ⌘ trigger placement
  and compact-width title readability across all 14 modules at 900×632 and
  1320×820; the Dashboard→Recovery Plan→other→Recovery Plan sidebar walk.
- **Gates (this checkpoint):** build.sh clean, build.sh release BUILD SUCCEEDED
  (32 s), test.sh **817 passed / 0 failed**, repository-doctor passed,
  build-xcode.sh OK. Working tree: only the 4 files of this change +
  `BETA_QA.md` / `AGENT_HANDOFF.md`. **Not pushed, not merged, not tagged.**

### Visual QA pass (2026-09-06) — HEAD `921db98`

- **P0 FIXED & retested with the running app:** the sidebar scrolled
  off-screen on Recovery Plan (`-1252 pt`, blank / only "Système" visible —
  the reported screenshot). Root cause: a `.borderedProminent` default
  button in a non-scrolling `NavigationSplitView` detail makes AppKit scroll
  the *sidebar's* list to "reveal" it. Fix (`55d184c`): scroll-host the
  centred detail states — `MCSuccessState` + `MCEmptyState` (DesignSystem)
  and `RecoveryPlanView.startState` / `transientState`. Pre-existing bug,
  not from the recent polish. Regression test
  `SidebarStructureTests.centredDetailStatesWithADefaultButtonAreScrollHosted`.
- `b57b86f`: `55d184c` had accidentally re-committed a stale
  `CoreTendApp.swift` (stray `git checkout` from the bisect left it staged),
  reverting the `MCFormatting.locale` wiring + palette tweaks from
  `6247549`. Restored. Also `.onExitCommand` + field-level
  `.onKeyPress(.escape)` on the command palette.
- **Verified live:** French byte formatting ("6,54 Go", "245,11 Go") on
  Dashboard / APFS; sidebar intact across modules at 900x632 and 1320x820.
- **HUMAN VERIFICATION REQUIRED:** command-palette Escape (harness can't
  deliver a testable Escape into the sheet); the full light/dark × EN/FR ×
  window-size matrix; Space Lens / Smart Scan / Storage / other module deep
  walks; VoiceOver; Reduce Motion; Finder / Widget / Shortcuts /
  Notifications live. Screenshots (gitignored, contain disk free-space):
  `Documentation/VisualAudit/_capture_2026-09-05_sidebar/`.
- **Gates at `921db98`:** build.sh clean (0 warnings), build.sh release
  BUILD SUCCEEDED, test.sh **812 passed / 0 failed**, repository-doctor
  passed, build-xcode.sh BUILD SUCCEEDED (widget + Finder embedded, 7/6
  intents/shortcuts, no absolute paths).



- Branch: `feat/v1.1-smart-scan-polish`, from `feat/finder-extension`
  (`1ed2efb`). **Not pushed, not merged, `main` untouched.**
- Website branch `feat/community-contact-site-v1.1` is a separate frozen
  deliverable — not touched in this pass.
- HEAD: `957751f`. Key commits this program:
  `7f5be65` storage semantics · `4c47554` sidebar/CTA/focus bug fixes ·
  `193ccc4` Smart Scan orchestrator domain · `8b822bb` StorageScanProgress ·
  `944f33a` pause audit proof · `4dc707a` Smart Scan real providers ·
  `bfb444e` app-scope SmartScanModel + coordinator regression fix ·
  `402c238` Smart Scan wired into app + Dashboard hero + Recovery Plan
  handoff · `008bfb2` Space Lens 2.0 · `d874308` Storage phase-aware
  progress + localization · `957751f` sidebar-structure regression tests.

### Gates (all green at `957751f`)

| Gate | Result |
|---|---|
| `Scripts/build.sh` | clean, **0 compiler warnings** |
| `Scripts/build.sh release` | **BUILD SUCCEEDED** |
| `Scripts/test.sh` | **796 passed / 0 failed** |
| `Scripts/repository-doctor.sh` | passed (EN/FR parity, Xcode drift, no absolute paths) |
| `Scripts/build-xcode.sh` | **BUILD SUCCEEDED** — `CoreTendWidget.appex` + `CoreTendFinder.appex` embedded, **7 App Intents / 6 App Shortcuts**, FR localizations, no absolute developer path |

Test-target `Suite`/`Test` swift-testing deprecation notices are pre-existing
tooling diagnostics, not compiler warnings. The codesign `Specifying ':' in
the path is deprecated` line in build-xcode is a codesign tooling notice.

### Smart Scan — DONE

- **Domain** (`SmartScanService.swift`, `SmartScanProviders.swift`): six real
  providers wrapping existing engines. Storage/Developer/Duplicates/Privacy
  reuse ONE memoised `RecoveryPlanService.prepareCandidates()` via
  `SmartScanRecoveryCandidates`; `.recommended`/`.optional` → recoverable
  bytes, `.reviewRequired` → review bytes, `.notIncluded` → informational
  count only (never re-summed → anti-double-counting preserved,
  `isGlobalRecoverableExact` stays true). Applications/Integrity = counts
  only, no malware claim. `SmartScanCoordinator` actor: bounded disk
  concurrency, cheap-provider concurrency, cancellation, failure isolation,
  no duplicate start, late-progress-ping can't clobber `.completed`.
- **App-scope model** (`SmartScanModel.swift`): `@MainActor @Observable`,
  held by `MainWindow` `@State` (survives module navigation), passed to
  `DashboardView(smartScan:)`. Phases idle/running/completed/cancelled,
  whole-second elapsed, snapshot only re-assigned on change, `start()`
  (no-op while running) / `cancel()` / `reset()`, `hasCompletedReport`
  false for a cancelled run.
- **Dashboard UI** (`SmartScanDashboardSection.swift`): idle hero ("Smart
  Scan" / "Analyse intelligente" + coverage list, no score); running
  (`SmartScanModuleRow` × 6 with icon + name + state label + detail +
  status glyph, never colour alone; elapsed; Cancel); completed (four
  separate dimensions; exact global recoverable OR per-category + overlap
  note; per-module drill-in via `.mcNavigate`; "Review Recovery Plan" /
  "Examiner le plan de récupération" primary CTA → `.recoveryPlan`; "New
  Smart Scan"); cancelled ("Scan cancelled", partial states, "Start Again",
  no CTA); partial (a `.failed` module → banner + successful modules shown).
  Old storage hero demoted to `storageGlance` card. FR-CTA-clip fix carried
  over (`lineLimit(2)` + `layoutPriority`).
- **Recovery Plan handoff** (`SmartScanHandoff.swift`): the completed run's
  exact `SmartScanRecoveryCandidates` is published to `SmartScanHandoff
  .shared`; `RecoveryPlanViewModel.preparePlan()` reads
  `freshCandidates()` first (10-min freshness) — same candidates, same
  `RecoveryPlanEligibility` categories, same identity, **no second scan, no
  re-sum, no reclassification** — and only falls back to a fresh
  `prepareCandidates()` when opened directly. `RecoveryPlanView`
  auto-prepares on a fresh handoff and shows a "prepared from your last
  Smart Scan" note. Cleared on `start()`/`reset()`. **No new destructive
  executor** — flow stays Smart Scan → Review Recovery Plan → confirm →
  SafetyCenter → PathValidator → Trash.
- **Tests**: `SmartScanServiceTests` (12), `SmartScanProvidersTests` (8),
  `SmartScanModelTests` (5), `SmartScanHandoffTests` (8) — provider
  mapping, coordinator concurrency/cancel/failure/no-duplicate-start,
  model lifetime, handoff publishes exact candidates only on completion,
  cancelled publishes nothing, new start clears handoff, stale ignored,
  drill-target mapping, elapsed formatting, no-destructive-dependency grep.

### Space Lens 2.0 — DONE

- **Domain** (`SpaceLensPresentation.swift`): `SpaceLensNode` (stable path
  id, %-of-scope, childCount, parentID, depth, category, sourcePath,
  isOther/isDrillable) + `SpaceLensScope` + `SpaceLensAggregator`. Bounded:
  ≤40 bubbles, ≤120 list rows per scope; deterministic order (bytes desc,
  path asc); long tail + engine "Other (small items)" fold into exactly one
  synthetic Other (aggregate bytes + folded count), never drillable/
  deletable. SwiftUI never sees the raw hierarchy.
- **Engine**: `SpaceLensEvent.partial(root:)` added — a growing lower-bound
  root emitted after each top-level folder resolves (depth 0 only).
  Existing `.finished`/`.progress`/`.cancelled`/minChildSize/symlink/
  depth-cap contract unchanged.
- **View model** (`SpaceLensViewModel`): `selectionID` (one shared value
  for canvas + list; sidebar selection untouched), `scope(filter:)`,
  `drill(nodeID:)` (files & Other never drill), throttled `applyPartial`
  (injectable clock, ~8/s, stops after navigation), `scanStartedAt` +
  privacy-safe `friendlyLocation`.
- **View** (`SpaceLensView`): top = breadcrumb + Back + folded-Other note +
  debounced search (clears off-screen selection) + category filter; center
  = larger bubble canvas (`RadialPack` on `SpaceLensNode`, deterministic
  slot per id → no reshuffle on partial/filter); bottom = precise List
  (Name / % of scope / Size, VoiceOver-primary). **Single click selects**
  (both), **double-click / Return / → drills**, Esc = Back. Selection =
  stroke + halo only, **no scale** (Reduce-Motion identical layout); hover
  scale gated on `!reduceMotion`. Every bubble individually accessible:
  "Library, 32.4 GB, 38 percent of this folder, directory" + isButton +
  isSelected + drill hint. Scanning view shows items + real elapsed
  (`TimelineView`) + friendly location + live "largest so far" list.
  Delete/reveal/Quick Look/exclude preserved. Pause is the proven-real
  `ScanPauseController` (engine calls `waitWhilePaused()` in both loops;
  covered by `pausedSpaceLensScanResumesAndFinishes`). Cancel → `.cancelled`,
  no completed snapshot.
- **Tests**: `SpaceLensAggregatorTests` (11 incl. **500k-entry stress**
  proving bounded render + exact aggregation + <5 s single pass),
  `SpaceLensExplorerTests` (10 — bounded scope, drill by id, shared
  selection, clock-driven throttle, partials stop after nav, friendly
  location privacy), ScanCore `emitsGrowingPartialRoots`. Existing
  `SpaceLensNavigationTests` + engine tests unchanged & green.

### Polish — DONE

- **Storage progress P1** (`CleanupView.scanningView`): phase-aware header
  (Scanning/Paused/Finalizing/Cancelled/Failed) + elapsed + friendly
  location. No fabricated bytesInspected.
- **Localization**: all new Smart Scan / Space Lens / Storage strings EN+FR;
  `LocalizationParityTests` + existing whole-catalogue parity test green.
- **Regressions**: FR Dashboard CTA wrap preserved in the new hero; sidebar
  focus fix intact (`SmartScanDashboardSection` uses no `List(selection:)`);
  `SidebarStructureTests` locks DuplicatesView free of nested nav
  containers + MainWindow column-visibility guard.

### HUMAN VERIFICATION REQUIRED (code complete, not visually checked)

- Duplicates empty-sidebar visual confirmation on device
- Smart Scan hero / running / result visual polish; FR Dashboard layout at
  narrow + wide window widths
- Space Lens interaction feel: double-click drill in a real window,
  keyboard nav, bubble layout at various sizes, drill/selection animation
- VoiceOver pass over Smart Scan module rows + Space Lens bubbles/list
- Reduce Motion appearance

### Not done / deferred to P2

- Smart Scan result screen does not yet show an inline expandable Advisor
  panel (why/confidence/risk) per module — the drill-in modules and the
  Recovery Plan screen already render full Advisor detail, and the result
  headlines are built from structured `SmartScanTotals`, never parsed text.
- Space Lens drill uses `withAnimation` + `matchedGeometryEffect` (already
  present); no new `matchedGeometryEffect` choreography was added.

### Beta QA / release-hardening pass — done at `92dd1a1`

- Full log: **`Documentation/BETA_QA.md`** (environment, gates, per-section
  PASS / HUMAN VERIFICATION REQUIRED / EXTERNAL CONFIGURATION REQUIRED).
- **Bug fixed (P0):** `SmartScanModel` reused one coordinator + candidate
  cache for every run, so "New Smart Scan" replayed the first scan's
  memoised disk snapshot. `start()` now builds a fresh coordinator + cache
  each run. Regression: `eachRunBuildsAFreshCoordinatorSoNewSmartScanReallyRescans`.
- **Bugs fixed (P2):** Space Lens canvas render bound 40 → 14 (radial pack
  runs out of clear slots past ~14; overflow → on-canvas "Other"); list-row
  double-click → `.simultaneousGesture(TapGesture(count: 2))` (won't steal
  the List's single-click selection); `applyCategory` drops "Other" while a
  category filter is active.
- **Static audits PASS:** no-network-dependency (only `UpdateChecker`),
  Restore Center untouched, entitlements (host App-Group-only / Finder
  sandbox-only / widget sandbox+App-Group), nested signing order inside-out,
  static bundle audit (no `/Users` paths, no secrets/fixtures), 7 App
  Intents / 6 App Shortcuts, launch smoke (beta build starts, no crash).
- **Version bump NOT performed** — `1.1.0-beta.1` locations documented in
  BETA_QA §36 (atomic release-branch change gated by
  `check-version-consistency.sh`): `PublicIdentity.example.json` +
  `Resources/Info.plist` + `project.yml` (+ regen `CoreTend.xcodeproj`) +
  `PROJECT_STATE.json`. `published-release.json` untouched (records live
  v1.0.0).
- **EXTERNAL CONFIGURATION REQUIRED:** App Group
  `group.com.ahmetbsbnr.coretend` portal registration; Developer ID
  identity + notary profile for `sign-and-notarize.sh`.
- **Gates at `92dd1a1`:** build.sh + release clean (0 warnings), test.sh
  **797 passed / 0 failed**, repository-doctor passed, build-xcode.sh
  BUILD SUCCEEDED (both `.appex`, 7/6 intents/shortcuts, no absolute paths).
- **Next exact action:** run the interactive HUMAN VERIFICATION list in
  `Documentation/BETA_QA.md` on device (Duplicates sidebar is the P0
  human check), then perform the atomic version bump on a release branch
  and run `sign-and-notarize.sh` once the App Group is registered. Do not
  push / merge / publish without authorization.


## Exact recovered and validated checkpoint

- Branch: `feat/finder-extension`.
- Starting HEAD: `71d1c06fe927ab62823e625f9c61e2f120c9cadb`.
- Validated implementation HEAD: `4cb9a0df4d5d3258874f197566098b1c3545ce43`.
- This handoff is delivered by the following documentation-only commit; use
  `git log -2 --oneline` for its final hash. No runtime source changes follow
  the implementation commit above.
- At documentation preparation: implementation committed; documentation changes
  unstaged, then staged/committed as one handoff receipt. Final intended state:
  clean working tree. No push, merge, main modification, or history rewrite.
- Prior shipping commits: `fddf0de`, `71d1c06`. No Finder commit existed at takeover.
  All staged Finder scaffolding and unstaged docs were preserved and finished.
- Unrelated local agent setup/backups remain intact, locally excluded through
  `.git/info/exclude`; they are not product changes.

## Completed — Finder Extension FAIT (local engineering gates)

Real embedded `CoreTendFinder.appex`, `com.apple.FinderSync`, bundle id
`com.ahmetbsbnr.coretend.finder`; FinderShared-only package dependency;
entitlements exactly App Sandbox. Widget remains embedded. Both executable
plist declarations fixed. XcodeGen remains authoritative for project generation.

Single existing folder/image/app selection offers corresponding read-only action.
Empty/multiple/unsupported/missing/symlink selection offers none. Menu uses bounded
single-item attributes; no contents, recursion, hashing, metadata decoding,
SQLite, network, or destructive engine in the extension.

Handoff: one `coretend://finder/<action>?path=<encoded-absolute-path>` URL via
NSWorkspace explicitly targeting the containing host. Host uses existing AppRouter,
strict syntax parsing, live validation at receipt and consumption, replacement of
stale payloads, shared consume-once gate, and receiver close/reopen lifecycle.
Invalid selections show EN/FR guidance. No persisted URL payload.

Host integrations remain existing Space Lens (Finder scan skips path history),
Privacy Lab/ImageMetadataInspector (in-memory), and Integrity/CodeSignInspector
(off-main). No automatic cleanup, Trash, Restore, or Recovery Plan.
Registration uses actual account home via getpwuid, /Applications, /Volumes.
Settings explains enablement/read-only semantics without fabricated status.

## Exact validation

- `Scripts/build.sh`: PASS; no compiler warnings.
- `Scripts/test.sh`: **727 passed, 0 failing**.
- `Scripts/repository-doctor.sh`: PASS including localization/project drift.
- `Scripts/build-xcode.sh`: **BUILD SUCCEEDED**, both embedded extensions,
  correct identifiers/executables, FR resources, **7 intents / 6 shortcuts**.
- Compiled Finder copy ad-hoc signed and exact sandbox-only entitlements verified.
- Test compilation has existing swift-testing Test/Suite deprecation diagnostics.
  Finder-only metadata extraction skip and codesign display-syntax deprecation
  are tooling notices. No app compiler errors or warnings.
- No Developer ID signed/notarized artifact produced.

Full recovery, architecture, artifact/log hashes, and human checklist:
`FINDER_EXTENSION_VALIDATION.md`, `MACOS_INTEGRATIONS.md` §6.

## Remaining concrete work / next action

No implementation gate remains. **HUMAN VERIFICATION REQUIRED**: System Settings
visibility/enablement; real Finder menus and all actions; cold/warm/background/
menu-bar-only/closed-window delivery; Desktop/Documents/Downloads/external volume;
EN/FR; VoiceOver/keyboard; signed/notarized build with both extensions; second Mac
and supported macOS. Do not claim these were tested.

Next action: enable the local extension in System Settings and perform that manual
matrix. A separately authorized release run may follow; do not push/merge/publish
implicitly. Launch Items Manager is analysis only, recorded in
`LAUNCH_ITEMS_MANAGER_READINESS.md`; do not implement it without a new assignment.
