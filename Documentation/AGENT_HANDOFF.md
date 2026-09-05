# CoreTend Agent Handoff

## ACTIVE — v1.1 Storage / Smart Scan / Space Lens app polish

- Branch: `feat/v1.1-smart-scan-polish`, from `feat/finder-extension`
  (`1ed2efb`). Not pushed, not merged, `main` untouched.
- Website branch `feat/community-contact-site-v1.1` (`3e08b23`) is a separate
  frozen deliverable — **do not touch it** in the app pass.
- Commits so far: `7f5be65` storage semantics · `4c47554` Dashboard/sidebar/
  focus bug fixes · `193ccc4` Smart Scan orchestrator domain · `8b822bb`
  StorageScanProgress · `944f33a` pause audit test · `4dc707a` Smart Scan
  real providers · `bfb444e` app-scope `SmartScanModel` + late-progress
  state fix.
- Gate status at `bfb444e`: `Scripts/build.sh` clean (0 warnings — the
  only test-target diagnostics are the pre-existing `Suite`/`Test`
  swift-testing deprecation notices), `Scripts/test.sh` **768 passed /
  0 failed**, `Scripts/repository-doctor.sh` passed. `Scripts/build-xcode.sh`
  **NOT re-run since `7ba9428`** — last known good there (both appex + 7
  intents / 6 shortcuts embedded); every change since is SwiftPM-source +
  `.strings` only. Re-run it at the next checkpoint to confirm.

### Done this pass

1. **Storage semantics (§1).** `Sources/CoreTendApp/StorageScanSummary.swift`
   — six deliberately distinct measures (`itemsInspected`,
   `detectedBytes`/`Count`, `reclaimableBytes`, `reviewRequiredBytes`,
   `selectedBytes`, `recoveredBytes?`) with invariants (`detected ==
   reclaimable + reviewRequired`, `selected <= detected`, `recovered <=
   selected`). `CleanupModel.summary` exposes it; `CleanupView.reviewView`
   now shows a *labelled* "X potentially recoverable" + "n items inspected",
   a "Y needs individual review" line, and the CTA reads
   "Move <selected> to Trash" with a "<selected> selected · ready…" caption.
   Strings `cleanup.reclaimable_metric` / `items_inspected` / `needs_review`
   / `selected_ready` / `move_selected` (EN+FR parity); scan progress
   "found"/"trouvés" → "detected"/"détectés".
   `StorageScanSummaryTests` (7) prove `inspected != detected != reclaimable
   != selected != recovered` and the partial-selection CTA math.
2. **Bug fixes (§8–10).** `CoreTendApp.swift`: `NavigationSplitView` now
   owns `columnVisibility` pinned to `.all` + `.navigationSplitViewStyle
   (.balanced)` + an `onChange` guard → a detail view (Duplicates' heavy
   List) can no longer collapse the sidebar into an empty column.
   `.listRowBackground(Color.clear)` on sidebar rows → the only selection
   indicator is `sidebarRow`'s own teal marker (driven by `selection ==
   module`, not list focus), so moving focus to a Space Lens bubble no
   longer greys out the active module. `DashboardView.swift`: the primary
   CTA label wraps to 2 lines with `layoutPriority(1)` on its column → the
   FR "Analyser le stockage" stops clipping to "Anal…". Translation
   unchanged.
3. **Smart Scan coordination domain (§13–17, no UI).**
   `Sources/CoreTendApp/SmartScanService.swift` — `SmartScanModuleID`
   (disk-heavy vs cheap), `SmartScanTotals` (four buckets that never
   collapse: recoverable bytes / review bytes / attention COUNT /
   informational COUNT — no score), `SmartScanModuleState`,
   `SmartScanReport` with overlap-aware global aggregation
   (`isGlobalRecoverableExact=false` when an overlapping module also had
   recoverable bytes → UI shows category totals separately),
   `SmartScanProvider` protocol seam, and `actor SmartScanCoordinator`:
   cheap providers concurrent, disk-heavy through a bounded TaskGroup (cap
   2, `peakDiskConcurrency` seam), cancellation → `wasCancelled` partial
   report with no `.completed`/no Timeline write, per-module failure
   isolation, `start()`-while-running returns the in-flight task.
   `SmartScanServiceTests` (11) cover all of that + a no-destructive-
   dependency source grep.
4. **Live Storage scan progress (§2).** `StorageScanProgress.swift` — a
   value + pure reducer folding `ScanEvent` into phase / itemsInspected /
   findingsDetected / reclaimable & review bytes-so-far (risk split) /
   currentPath / elapsed / isPausable. **No percentage field** (engine has
   no total). `CleanupModel` owns it and drives pause/resume/cancel;
   `scanningView` shows real counters + running-recoverable + current path.
   `StorageScanProgressTests` (8).

5. **Smart Scan real providers (§1–7) — DONE.** `4dc707a`.
   `Sources/CoreTendApp/SmartScanProviders.swift`: `SmartScanRecoveryCandidates`
   actor memoises one `RecoveryPlanService.prepareCandidates()` pass;
   `SmartScanStorageFamilyProvider` maps its payload slice into
   `SmartScanTotals` (`.recommended`/`.optional` → recoverable,
   `.reviewRequired` → review, `.notIncluded` → informational pointer only,
   never re-summed — reuses `RecoveryPlanEligibility` anti-double-counting so
   `overlapsStorage = false` and the global recoverable stays exact).
   `SmartScanApplicationsProvider` = app count + managed-update-path count
   (counts, not "update available"). `SmartScanIntegrityProvider` = global
   launch daemons → attention, quarantined downloads + user agents →
   informational (no malware claim). `SmartScanProviders.live(home:environment:
   store:)` factory. `SmartScanProvidersTests` (8).
   Strings `smartscan.headline.{recoverable,nothing,apps,signals}` EN+FR.

6. **App-scope `SmartScanModel` (§8–9) — DONE.** `bfb444e`.
   `Sources/CoreTendApp/SmartScanModel.swift` — `@MainActor @Observable`,
   owns a `SmartScanCoordinator`, phases idle/running/completed/cancelled,
   polled live snapshot + elapsed, `start()`/`cancel()`/`reset()`,
   `hasCompletedReport` false for a cancelled run. Injectable coordinator/
   clock/poll-interval. **Not yet held by `MainWindow` / not yet shown in
   any view** — that is the next step. Also fixed a real coordinator bug:
   a provider's final-line progress ping used to clobber `.completed` →
   `.scanning` (now `setScanningDetail` only refines a live scanning
   state); regression test added.

### Remaining

- **Wire `SmartScanModel` into the UI (§8, §10–17)** — start here:
  - `MainWindow` (`CoreTendApp.swift` ~line 405): add
    `@State private var smartScan = SmartScanModel()` next to
    `developerModel`; pass `DashboardView(smartScan: smartScan)`. This is
    what makes the app-scope lifetime real (survives `selection` changes).
  - `DashboardView`: accept `let smartScan: SmartScanModel`. Replace / lead
    the hero with a Smart Scan panel: idle → "Start Smart Scan" /
    "Lancer l'analyse intelligente" (`smartScan.start()`) + a coverage
    list (Storage/Privacy/Developer/Applications/Integrity, no health
    score); running → per-module rows from `smartScan.modules` (Queued/
    Scanning/Completed/Unavailable/Failed/Cancelled — NO %), elapsed,
    Cancel; completed → 4 category totals (recoverable / needs review /
    attention / informational), one global number **iff**
    `report.isGlobalRecoverableExact` else per-category with a one-line
    why; cancelled → labelled partial + Dismiss (`reset()`).
  - Result primary CTA "Review Recovery Plan" / "Examiner le plan de
    récupération" → `navigate(.recoveryPlan)` (`RecoveryPlanView` already
    runs `prepareCandidates()` on load — NO new executor, §18).
  - Category rows drill in via `navigate(.cleanup/.duplicates/.privacyLab/
    .developer/.protection)` (§16).
  - New strings (EN+FR): `smartscan.start`, `smartscan.cancel`,
    `smartscan.coverage.*`, `smartscan.state.{queued,scanning,completed,
    unavailable,failed,cancelled}`, `smartscan.category.{recoverable,
    review,attention,informational}`, `smartscan.global.exact`,
    `smartscan.global.inexact_note`, `smartscan.partial_note`,
    `smartscan.review_recovery_plan`, `smartscan.elapsed`.
- **Failure-isolation / permission-limited / cancellation UI (§20–22)** —
  render `.failed` / `.unavailable` / `.cancelled` module states as
  first-class rows in the running + result views; a cancelled run shows a
  labelled partial, never a success state (`hasCompletedReport` already
  gates this in the model).
- **Advisor reuse in the result detail (§17)** — when a category row is
  expanded, show the `AdvisorFinding` domain fields (why / confidence /
  risk / reversibility / next-action) already on each
  `RecoveryPlanCandidateData.candidate.finding`; do not parse display text.
- **Finish Storage progress P1 (§41)** — `CleanupView.scanningView` still
  needs elapsed-time display + phase-aware copy (the domain type
  `StorageScanProgress` already carries `elapsed` / `phase`).
- **Live Storage scan progress (§2)**: extract a structured progress type
  (`itemsInspected`/`bytesInspected`/`findingsDetected`/`reclaimableSoFar`/
  `currentCategory`/`elapsed`/`phase`) out of `CleanupModel`/the views into
  the domain; drive it from real `ScanEngine` events, not fabricated %.
- **Space Lens 2.0 (§3–6)**: replace `SpaceLensView` with an aggregated
  (largest-N + Other), throttled (~5–10 updates/s), stable-identity
  interactive explorer — big canvas + synced list + breadcrumb, single-
  click select (map↔list), double-click / Return drill, Back, search;
  Reduce-Motion parity; accessible bubble labels ("Library, 32.4 GB, 38
  percent of this folder"). Bounded rendering for 500k+ scanned entries.
- **Pause audit (§7)**: `ScanPauseController` exists and is wired into
  `ScanEngine.run(rules:pauseController:)` — verify it actually suspends
  work (not a UI-only toggle); if it doesn't, implement real suspension or
  remove the Pause button. Cancel already produces no completed
  Timeline snapshot (`CleanupModel` writes the snapshot only on
  `.finished`) — keep that invariant for Smart Scan.
- **Localization sweep (§11)** of any remaining EN-in-FR in Storage / Space
  Lens / Dashboard / Duplicates / Smart Scan surfaces.
- **VoiceOver / manual** verification of Space Lens + Smart Scan — **HUMAN
  VERIFICATION REQUIRED** (no manual pass done).

### Next exact action

1. Add `@MainActor @Observable SmartScanModel` at app scope (init in
   `CoreTendApp` / `AppEnvironment`, NOT in `DashboardView`) owning a
   `SmartScanCoordinator(providers: SmartScanProviders.live())`. Expose:
   per-module `SmartScanModuleState`, the live `SmartScanReport`, elapsed,
   `start()` (no-op if running), `cancel()`, last completed report.
2. Wire `DashboardView` hero → "Start Smart Scan" / "Lancer l'analyse
   intelligente"; idle = coverage list; running = per-module state rows (no
   %); result = 4 categories (recoverable / needs review / attention /
   informational), one global number iff `isGlobalRecoverableExact`.
3. Result primary CTA "Review Recovery Plan" / "Examiner le plan de
   récupération" → `router` navigate to `.recoveryPlan` (RecoveryPlanView
   already calls `prepareCandidates()` on load — NO new executor).
4. Then Space Lens 2.0 (domain model + bounded aggregation first).
Run `build.sh` + `test.sh` + `repository-doctor.sh` + `build-xcode.sh` at
each checkpoint.

---

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
