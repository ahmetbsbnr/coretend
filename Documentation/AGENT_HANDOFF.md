# CoreTend Agent Handoff

## ACTIVE — v1.1 Storage / Smart Scan / Space Lens app polish

- Branch: `feat/v1.1-smart-scan-polish`, from `feat/finder-extension`
  (`1ed2efb`). Not pushed, not merged, `main` untouched.
- Website branch `feat/community-contact-site-v1.1` (`3e08b23`) is a separate
  frozen deliverable — **do not touch it** in the app pass.
- Commits so far: `7f5be65` storage semantics · `4c47554` Dashboard/sidebar/
  focus bug fixes · `193ccc4` Smart Scan orchestrator domain.
- **All four gates green** at the latest commit: `Scripts/build.sh`
  (+release), `Scripts/test.sh` **745 passed / 0 failed** (727 baseline +18),
  `Scripts/repository-doctor.sh`, `Scripts/build-xcode.sh` (**BUILD
  SUCCEEDED**; `CoreTendWidget.appex` + `CoreTendFinder.appex` +
  `Metadata.appintents` with 7 intents / 6 shortcuts all still embedded).

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

### Remaining (not started — needs a running app to build & verify safely)

- **Smart Scan real providers** wrapping the actual engines (Cleanup rules,
  Leftovers, DuplicateEngine, DeveloperCenterService, BrowserCatalog,
  ApplicationInspection, IntegrityCore) as `SmartScanProvider`s; set each
  provider's `overlapsStorage` from the *proven* Recovery Plan overlap
  rules (`RecoveryPlanEligibility` / the `user.caches` exclusion).
- **Smart Scan model + UI**: an `@MainActor @Observable` owner holding the
  `SmartScanCoordinator` at app/domain scope (not in `DashboardView`), the
  live module-state list (§18), the structured result screen (§19) reusing
  `AdvisorService`, and the action flow ending at **Review Recovery Plan**
  (§20 — no new delete executor).
- **Dashboard integration (§21)**: make "Start Smart Scan / Analyse
  intelligente" the primary CTA; if a scan is already running show its
  progress instead of starting a duplicate.
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

Build the Smart Scan real providers (`SmartScanProviders.swift`) + the
`@Observable SmartScanModel`, then wire the Dashboard CTA. Then Space Lens
2.0. Run all four gates at each checkpoint.

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
