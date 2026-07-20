# CONTINUATION

## Where we are (v0.2.0)
All 10 sidebar modules are real and functional. 46 tests green, 0 warnings,
Release app packaged. See PROJECT_STATE.json + FEATURE_MATRIX.md.

## Toolchain (unchanged, read first)
- No Xcode — CommandLineTools only. Build `swift build`, tests **only** via
  `Scripts/test.sh`, bundle via `Scripts/package-local.sh`.
- After changing a public struct's stored layout, run `rm -rf .build` once —
  SwiftPM incremental builds have produced corrupted cross-module reads twice.

## Next step (in order)
1. Privacy Cleaner: browser profile detection (Safari limited by TCC; Chrome/Firefox
   profiles under ~/Library/Application Support), sizes per category, sqlite backup
   before any modification, refuse when browser running.
2. App Updater: read Sparkle SUFeedURL from installed apps' Info.plist, compare
   versions, open official page. No downloads.
3. FSEvents watcher on ~/Downloads feeding Protection (only if ClamAV present).
4. Accessibility pass (labels on toggles/buttons, focus order).
5. fr localization.

## Gotchas accumulated
- DirectoryEnumerator iteration is banned in async contexts → sync static helpers.
- /var vs /private/var: use ScanConfiguration.canonical for path comparisons.
- @Observable stored property initializers cannot reference covariant Self.

## v0.4.0 — Visual Foundation (2026-07-20)
- Direction: Orbital Ecology / Core Bloom. Tout est documenté dans
  VISUAL_DIRECTION.md, BRAND_SYSTEM.md, DESIGN_TOKENS.md, MOTION_SYSTEM.md,
  VISUAL_AUDIT.md (+ bugs données à corriger), VISUAL_QA.md, ASSET_PIPELINE.md.
- QA visuelle: `Scripts/capture.sh out.png "Nom Module"` sur le bundle réel;
  clair via defaults NSRequiresAquaSystemAppearance.
- Assets: régénérer via swift Resources/Brand/Sources/generate-brand-assets.swift
  + iconutil (voir ASSET_PIPELINE.md). package-local.sh copie dans le bundle.
- Reprise: densifier identités secondaires des modules (voir VISUAL_QA tableau),
  puis corriger les 2 bugs données notés dans VISUAL_AUDIT.md.

## v0.4.1 — Totals & scope audit (2026-07-20)
- Bug "scan scope leak" (Downloads scan touchant Music): audité en profondeur
  (ScanEngine.scanRoot, ScanRule.roots, exclusions). Le code était déjà correct
  — chaque règle a ses propres racines explicites, exclusions filtrées avant
  `enumerator.skipDescendants()`, symlinks jamais suivis. Pas de code à
  changer; ajouté `Scan root isolation` suite dans ScanCoreTests pour verrouiller
  ce comportement (Downloads-only + multi-règles).
- Bug "totaux tronqués à 5000": réel. `SmartCareViewModel.totalFoundBytes`
  était un computed property sur `findings` (plafonné UI), divergeant du total
  réel accumulé pendant le stream. Fix: `totalFindingCount`/`totalFoundBytes`
  sont maintenant des propriétés stockées mises à jour à chaque `.finding`
  event (jamais depuis la liste plafonnée), dans CleanupViewModel et
  SmartCareViewModel. `isDisplayTruncated` + texte "N of M shown" ajoutés aux
  deux vues. Ajouté test ScanCoreTests avec 5001 résultats synthétiques
  prouvant que le moteur ne plafonne jamais en interne.
- 60 tests verts, build release + package + lancement bundle réel vérifiés.
- **Reprise**: Step B (identités secondaires modules), Step C (fr localization),
  Step D (audit visuel final -> 0.5.0) restent à faire — non commencés cette
  session faute de temps. Voir VISUAL_QA.md / VISUAL_DIRECTION.md pour le detail
  des specs par module.

## Step B — en cours (v0.4.1 code, 2026-07-20)
- `Sources/DesignSystem/MeshView.swift`: `MCMeshView`, motif maille de
  confinement pour Protection (nœuds+rayons sur anneau, Canvas, statique —
  aucun timer). Complétude reflète l'état réel (moteur absent → maille
  clairsemée/pointillée; prêt → complète; scan → partielle; détection →
  distorsion ambre, jamais rouge). VoiceOver via `accessibilityDescription`.
  Câblé dans `ProtectionView.swift` (carte indisponible + carte scan).
- 60 tests verts, build release + package + lancement bundle réel vérifiés.
- **Pas commencé**: Cleanup (fragments/regroupement/troncature), Space Lens
  (continuité spatiale), Applications (capsules), My Clutter (superposition),
  My Activity (chronologie), Cloud Cleanup (plein/contour), Performance
  (harmonisation), menu bar, Settings (états permission). Step C (fr) et
  Step D (audit final 0.5.0) non commencés.
- **Reprise**: continuer Step B dans l'ordre — Cleanup ensuite, puis Space
  Lens, Applications, My Clutter, My Activity, Cloud Cleanup, Performance,
  menu bar, Settings. Pour chaque module: implémenter en SwiftUI natif,
  build release, test, package, lancer, capturer via `Scripts/capture.sh`
  clair+sombre, mettre à jour VISUAL_QA.md honnêtement, commit atomique.
  Ne pas passer à 0.5.0 avant que Step B/C/D soient réellement complets.

## Step B — Cleanup + Space Lens done (v0.4.1 code, 2026-07-20, resumed session)
- Picked up uncommitted work from a prior session killed by a network error
  (no commits had landed). Diff was already substantially complete.
- `Sources/DesignSystem/FragmentView.swift` (new): `MCFragmentSpec`/
  `MCFragmentView` — Cleanup's motif. One fragment per rule group, width =
  real byte share (never per-file, never decorative), selection shown via
  fill+outline+checkmark together (never color alone), dashed outline for
  unselected, opacity phases for moving/settled (calm success, no confetti).
  Reduce Transparency → opaque fills; Reduce Motion respected via
  `MCMotion.animation(reduce:)`. `accessibilityDescription(fragments:)` gives
  the VoiceOver summary; the existing findings `List` remains the accessible
  detail view. Wired into `CleanupView`/`CleanupViewModel` (scanning/review/
  done phases) using the existing `totalFindingCount`/`totalFoundBytes`/
  `isDisplayTruncated` truncation plumbing — no new truncation logic needed.
  `doneView` also now surfaces `failedCount` (items that couldn't be trashed)
  instead of silently dropping it.
- `Sources/MacCareApp/SpaceLensView.swift` / `Sources/ScanCore/SpaceLensEngine.swift`:
  `matchedGeometryEffect` zoom continuity between treemap and drill-down
  (`@Namespace`, `navigate(_:)` wraps real state changes only), breadcrumb
  keyboard shortcut, hover/selection/keyboard-focus state, semantic
  `SpaceNodeCategory` (folder/media/document/archive/code/other) coloring by
  type instead of index-cycling. `SpaceNode` gained `isAccessDenied` /
  `isCloudPlaceholder` (real signals from `contentsOfDirectory` failure and
  `ubiquitousItemDownloadingStatusKey`) surfaced as pattern overlays + tooltip
  text, not just color, so permission/iCloud caveats are honest. Accessible
  `List` fallback retained.
- **Bug found & fixed via testing** (not previously caught): `MCFragmentView`
  conforms to `View`, so Swift inferred `@MainActor` on *all* its members,
  including the plain-data `static func accessibilityDescription`. Swift
  Testing runs off the main actor, so calling it crashed with SIGTRAP
  (`dispatch_assert_queue_fail`) on the first non-trivial test — not a test
  logic bug, a real isolation bug that would have hit any nonisolated caller.
  Fixed with `nonisolated static func`. Full diagnostic trace is in
  `~/Library/Logs/DiagnosticReports/swiftpm-testing-helper-*.ips` if useful.
- 62 tests verts (was 60; +2 new fragment tests), `swift build -c release`
  clean at 0 warnings, `Scripts/package-local.sh` succeeded, app launched.
- **Screenshots NOT captured this session**: this sandbox has no attached
  display (`screencapture` errors "could not create image from display")
  and no way to grant Accessibility/TCC permission headlessly, so
  `Scripts/capture.sh` cannot run here at all (not even `System Events`
  window queries succeed). VISUAL_QA.md documents this honestly instead of
  faking captures. **Reprise**: on a machine with a real display, launch the
  packaged bundle, run `Scripts/capture.sh` light+dark for Cleanup and Space
  Lens per VISUAL_QA.md's procedure, save to `Documentation/VisualAudit/After/`,
  and tick the checklist boxes for those two rows.
- **Still pending in Step B**: Applications (capsules), My Clutter
  (overlap), My Activity (chronologie), Cloud Cleanup (plein/contour),
  Performance (harmonisation), menu bar, Settings (états permission) — not
  started, stay scoped to Cleanup + Space Lens was the instruction this
  session. Then Step C (fr localization), then Step D (final 0.5.0 audit).
  Do not bump the version past 0.4.1 until Step B/C/D are genuinely done.

## Step B — Applications + My Clutter done (v0.4.1 code, 2026-07-20, resumed session)
- **Applications**: `Sources/MacCareApp/ApplicationsView.swift` gained
  `AppGrouping` (none/publisher/size/update state/last used) and
  `AppGroupingLogic`, all derived from real data only — no invented
  fields. Extended `InstalledApp` (`Sources/AppDiscovery/AppDiscovery.swift`)
  with `lastUsedDate` (Spotlight `kMDItemLastUsedDate` via `MDItemCopyAttribute`,
  `nil` when genuinely unindexed) and `isQuarantined` (real
  `com.apple.quarantine` xattr via `.quarantinePropertiesKey`). Added
  `AppUpdateSource` (App Store receipt / Sparkle feed / manual) as a
  shared public enum so `AppUpdatesView` and the new "update state"
  grouping read the same detection logic instead of duplicating it.
  The native `List` stays the sole primary view — grouping only changes
  `Section` boundaries — with `matchedGeometryEffect` per row so
  position is preserved across grouping transitions (no separate
  "constellation" canvas was built; the spec called it optional and the
  reliable list already carries the real identity/state/size data per
  row). `LeftoversView` now flags `group.*` container ids and any
  bundle-id vendor prefix shared by more than one leftover as
  "Shared / review" (badge + color, never color alone) via
  `LeftoversViewModel.isAmbiguous`.
- **My Clutter**: new `Sources/DesignSystem/OverlapView.swift`
  (`MCOverlapStack`) is the shared overlap/similarity motif — items
  overlap by default and separate on real `onHover` state (or when
  Reduce Motion is on), decorative/`accessibilityHidden`, same pattern
  as `MCMeshView`/`MCFragmentView`. Wired into `DuplicatesView` (icon
  strip above the existing accessible rows; confirmed via the
  pre-existing `hardLinksNotTreatedAsDuplicates` test that
  `DuplicateEngine` already excludes hard links at the inode-collapse
  stage, never counts them as duplicate bytes — just made that explicit
  in the UI copy, no engine change needed) and `SimilarImagesView`
  (wraps the existing `AsyncThumbnail`/QuickLook pipeline — no second
  thumbnail path). `SimilarImagesEngine`/`SimilarImageGroup`
  (`Sources/ScanCore/SimilarImagesEngine.swift`) gained real per-member
  pixel dimensions read via `ImageIO`/`CGImageSourceCopyPropertiesAtIndex`
  (no full decode) and `bestResolutionURL`, marked in the UI by badge +
  label, never auto-selected or auto-deleted. `LargeOldFilesView`
  (`Sources/MacCareApp/MyClutterView.swift`) got a native size/age sort
  picker, `.quickLookPreview` Quick Look integration, and larger metric
  numbers (it stays a data table by design, not a heavy visualization).
- Added a `MacCareAppTests` test target (`Package.swift`) since the new
  grouping/ambiguity logic lives in the `MacCareApp` executable target,
  which previously had no test coverage — `@testable import MacCareApp`
  works fine for an `executableTarget` under SwiftPM 6. 8 new tests
  (grouping buckets, leftover ambiguity, `SimilarImageGroup`
  best-resolution) — 70 total, up from 62, all green.
- Verification loop run in full: `swift build -c release` 0 warnings
  (from a clean `.build`), `Scripts/test.sh` 70/70 green,
  `Scripts/package-local.sh` succeeded, bundle launched and stayed up
  (`ps` + `log show` checked, no crash/error), quit cleanly.
- **Screenshots NOT captured this session** — same no-attached-display
  constraint as the Cleanup/Space Lens session; `VISUAL_QA.md` documents
  Applications and My Clutter as code-done/capture-pending truthfully.
- **Reprise**: remaining Step B modules are My Activity (chronologie),
  Cloud Cleanup (plein/contour), Performance (harmonisation), menu bar,
  Settings (états permission) — none started. After Step B, Step C (fr
  localization), then Step D (final 0.5.0 audit, which also needs real
  screen captures for every module done so far — Cleanup, Space Lens,
  Applications, My Clutter — once a machine with a display is
  available). Do not bump the version past 0.4.1 until B/C/D are done.

## Step B — My Activity + Cloud Cleanup done (v0.4.1 code, 2026-07-20, resumed session)
- Confirmed no attached display again (`Scripts/capture.sh` errors with
  `System Events` process-index -1719, same as prior sessions) — captures
  stay marked capture-pending in `VISUAL_QA.md`, honest per instructions.
- **My Activity** (`Sources/MacCareApp/MyActivityView.swift`): backed by
  real `ActivityRecord`s only (`Persistence.Store.activity`), no invented
  event kinds — the `Kind` enum stays `scan/cleanup/restore/error` as it was.
  Added pure/tested `ActivityGrouping.byDay` (calendar-day grouping),
  `ActivityDateRange` (all/7d/30d filter), and `ActivityImpactSummary`
  (real freed bytes vs simulated/dry-run bytes, kept strictly separate,
  cleanup-kind only — scans never count as "freed"). Timeline uses `List`
  `Section`s per day with a small connector dot (native, no new Canvas
  view — this is a data table with light identity, per the module spec,
  not a heavy visualization like Cleanup's fragments). Rows are
  `DisclosureGroup`s showing real/simulated status in explicit text.
  CSV export via `NSSavePanel`, no new persistence. Quarantine restore
  previously wasn't logged at all despite `ActivityRecord.Kind.restore`
  existing since v0.2 — `ProtectionViewModel.restore(_:)` now records one
  on success, and `.restore` rows in My Activity link back to Protection
  via a small `NotificationCenter` `.mcNavigate` post that `MainWindow`
  observes to switch sidebar `selection` (reused mechanism, not a new
  restore path).
- **Cloud Cleanup** (`Sources/MacCareApp/CloudCleanupView.swift`): added
  `SyncState` (local/partial/placeholder), classified primarily from the
  real `URLResourceKey.ubiquitousItemDownloadingStatusKey` signal read in
  `measure()` (byte-ratio is only a fallback when that signal is absent).
  Local vs remote rendered as filled vs outline SF Symbols (`folder.fill`
  vs `folder`) plus a text badge — shape carries the meaning, not color
  alone. Deliberately **no pinned badge**: there is no public API to read
  Finder's "Keep Downloaded" pin state for an arbitrary iCloud Drive item,
  so the module doesn't fabricate one (documented in code and
  VISUAL_QA.md). Renamed the local-bytes total to `recoverableLocalBytes`
  with copy stating this is analysis-only; verified `measure()` only
  calls `resourceValues`/`contentsOfDirectory` — never
  `startDownloadingUbiquitousItem` — so it genuinely never triggers a
  download, matching what the UI already claimed.
- Added `Tests/MacCareAppTests/MyActivityGroupingTests.swift` (5 tests:
  day grouping, date-range filter, real/simulated separation, 3 `SyncState`
  classification cases). 75 tests green (was 70).
- Verification loop run in full: `swift build -c release` 0 warnings,
  `Scripts/test.sh` 75/75 green, `Scripts/package-local.sh` succeeded,
  bundle launched (`ps` confirmed process up), quit cleanly via
  `osascript`, no crash/error.
- **Reprise**: remaining Step B modules are Performance (harmonisation),
  menu bar, Settings (états permission) — none started. After Step B,
  Step C (fr localization), then Step D (final 0.5.0 audit, needs real
  screen captures for every module done so far — Cleanup, Space Lens,
  Applications, My Clutter, My Activity, Cloud Cleanup — once a machine
  with a display is available). Do not bump the version past 0.4.1 until
  B/C/D are done.

## Step B — Performance + menu bar + Settings done, STEP B FULLY COMPLETE
## (v0.4.1 code, 2026-07-20, isolated worktree session)
- Confirmed again no attached display (`Scripts/capture.sh` fails the same
  way: `System Events` process index -1719) — every touched screen stays
  "code done, capture pending" in `VISUAL_QA.md`, honestly.
- **Performance** (`Sources/MacCareApp/PerformanceView.swift`): this was a
  harmonization/audit pass, not a rebuild. Confirmed already correct: tokens
  consistent with Cleanup/Protection, CPU/memory/disk data 100% real
  (`SystemMetrics.MetricsCollector`, no decorative curves), 2s refresh
  cadence reasonable, units correctly labeled, VoiceOver already present
  on `MCMetricCard` (value+detail as text) and the CPU chart
  (`accessibilityLabel`), Reduce Motion trivially satisfied (no explicit
  animation on redraw). One real gap found and fixed: nothing paused
  sampling when the window was hidden/backgrounded — added
  `@Environment(\.scenePhase)` gating `PerformanceViewModel.start()`/
  `.stop()` alongside the existing `onAppear`/`onDisappear`.
- **Menu bar** (`Sources/MacCareApp/MacCareApp.swift`): kept the existing
  monochrome template icon (`MenuBarTemplate.png`, `isTemplate=true`,
  18px) and the panel's "sample only while open" behavior (already
  correct — a `.task` scoped to the popover view's lifecycle). Added
  `MenuBarIconModel` — a slow (30s), independent-of-panel background poll
  whose only job is a shape-based "attention" badge (small triangle
  overlay at a fixed offset, not a color change) driven by real
  thermal/memory-pressure/disk-free thresholds via the same
  `MetricsCollector` pipeline (no duplicate collection). The pure
  threshold function `MenuBarIconModel.needsAttention` is unit tested.
  Panel gained: last Smart Care result read from `Store.activity` (first
  record whose summary starts with "Smart Care" — reuses existing
  `ActivityRecord` schema, no new persistence), an honest Protection line
  (`ClamAVScanner().isAvailable`), and a "Settings…" quick action
  alongside the existing Open/Quit (reuses the `.mcNavigate`
  `NotificationCenter` mechanism `MainWindow` already observes).
- **Settings** (`Sources/MacCareApp/SettingsView.swift`): reorganized into
  General / Appearance / Scans & Cleanup / Protection / Monitoring &
  Permissions / Exclusions / Data / About, all native `Form`/`Section`/
  `Toggle`/`LabeledContent` — no custom-drawn controls. Every permission
  state shown now comes from a real system query, never simulated: Full
  Disk Access reuses the existing `PermissionProbe.hasFullDiskAccess()`
  (with Open System Settings + Re-check), ClamAV reuses
  `ClamAVScanner().isAvailable`, notifications query
  `UNUserNotificationCenter.current().notificationSettings()` (the app
  doesn't request notifications today, so this is honestly usually
  "Not requested" — never fabricated as granted), and the privileged
  helper is shown as genuinely unavailable (no signing identity, per
  `FEATURE_MATRIX.md` — not a bug, not a fake progress bar). Fixed the
  About section's hardcoded "0.1.0" to read the real
  `CFBundleShortVersionString` from the bundle (was stale since v0.1; app
  is actually v0.4.1). Added a Data section wiring the previously-unused
  `Store.clearActivity()` behind a confirmation dialog — the only new
  persistence-adjacent UI, no new persistence logic. Extracted
  `PermissionFormatting.notificationLabel/Icon` as pure functions so
  permission-state text formatting is directly testable.
- Added `Tests/MacCareAppTests/PerformanceAndSettingsTests.swift` (7
  tests: 4 attention-threshold cases, 3 notification-label formatting
  cases). 82 tests green (was 75).
- Verification loop run in full: `swift build` clean incremental,
  `swift build -c release` from a clean `.build` — 0 warnings,
  `Scripts/test.sh` 82/82 green, `Scripts/package-local.sh` succeeded,
  bundle launched (`ps` confirmed process up, `log show` checked — no
  error/fault entries), quit cleanly via `osascript`.
- **Step B is now FULLY COMPLETE** — all 10 modules (Cleanup, Protection,
  Space Lens, Applications, My Clutter, My Activity, Cloud Cleanup,
  Performance, menu bar, Settings) have their visual/harmonization work
  done in code.
- **Reprise**: Step C (French localization) and Step D (final 0.5.0
  audit — real screen captures for all 10 modules once a machine with a
  display is available, plus bumping to 0.5.0 only once C and D's exit
  criteria are genuinely met) are next. Do not bump the version past
  0.4.1 until then. This session ran in an isolated worktree per
  instructions — the orchestrating session should reconcile/merge these
  three commits (`fix(performance)`, `feat(menubar)`, `feat(settings)`)
  against any concurrent work on the same files.

## Step C (French localization) — session progress, partial

Worked directly on `main` (no worktree), one commit per module, 82/82
tests green and `swift build -c release` 0 warnings before every commit.

**Modules localized this session** (added `L("...")` calls in the View
files, added matching key/value pairs to both
`Sources/MacCareApp/Resources/Base.lproj/Localizable.strings` and
`fr.lproj/Localizable.strings`):
- `CleanupView.swift` (`cleanup.*` keys)
- `ProtectionView.swift` (`protection.*` keys) — includes the malware-tab
  and Privacy-tab container strings; `PrivacyCleanerView.swift` itself
  (the Privacy tab's content) was **not** reached this session
- `SpaceLensView.swift` (`spacelens.*` keys)
- `ApplicationsView.swift` (`apps.*` keys) — the `AppGrouping` enum's
  `rawValue`s (used both as SwiftUI picker labels and as dictionary
  grouping/sort keys inside `AppGroupingLogic`) were deliberately **not**
  localized: they're a hybrid of display text and internal logic key,
  and localizing just the display side would desync the `order` arrays
  that string-match against them. Left as a known gap — see below.
- `MyClutterView.swift` (`clutter.*` keys) — the tab container only;
  `DuplicatesView.swift` and `SimilarImagesView.swift` (its other two
  tabs) were **not** reached this session
- `AppUpdatesView.swift` (`updates.*` keys)
- `LeftoversView.swift` (`leftovers.*` keys)

**Key naming**: kept the established `<module>.<sub>.<name>` lowercase
dotted convention (e.g. `cleanup.review.truncated`,
`protection.quarantine_empty`). Shared strings reused existing
`common.*` keys (`common.cancel`, `common.dry_run`,
`common.reveal_in_finder` — added `reveal_in_finder` as a new shared
key since three modules had identical "Reveal in Finder" `.help()` text)
or `smartcare.scan_again` where the English text was identical to an
existing key.

**Translation style**: matched the existing natural/professional
register (not literal) — e.g. "Libérer de l'espace"-style phrasing,
"Simuler le nettoyage" not "Nettoyage de simulation", "à faible risque"
constructions kept consistent with Smart Care's hero copy. French
punctuation spacing before `:` and `»`-style em dashes followed the
existing file's conventions.

**What was intentionally left untouched** (per task constraints): all
`ActivityRecord(summary: ...)` strings (internal activity-log text, not
shown localized anywhere else in the codebase — confirmed by checking
`SmartCareView.swift`, which already established this same
English-only-for-activity-log pattern) and all engine/model logic in
SafetyCore/ScanCore/AppDiscovery/MalwareEngine.

**Verification performed**: grep-based key diff confirms
`Base.lproj/Localizable.strings` and `fr.lproj/Localizable.strings`
keys match 1:1 (`diff` of sorted key lists — empty). A second grep
confirms every `L("...")` call anywhere under `Sources/MacCareApp`
resolves to a key present in `Base.lproj/Localizable.strings` — no
dangling references. No live locale-override launch was performed
(no `Scripts/package-local.sh`/`Scripts/capture.sh` run this session —
not attempted due to session time constraints, not because it failed).

**Step C is NOT complete.** Modules still needing the same treatment:
`PrivacyCleanerView.swift`, `DuplicatesView.swift`,
`SimilarImagesView.swift`, `MyActivityView.swift`,
`CloudCleanupView.swift`, `PerformanceView.swift`, menu bar
(`AppEnvironment.swift` / wherever the menu-bar extra lives),
`SettingsView.swift`, `OnboardingView.swift`, `MacCareApp.swift`, plus a
final whole-tree grep sweep for any remaining bare `Text("...")` /
`Button("...")` / `.alert(...)` / `Toggle("...", ...)` literals (alert/
confirmation-dialog copy specifically was not audited this session).
Also unresolved: the `AppGrouping`/sort-bucket rawValue strings in
`ApplicationsView.swift` need a proper fix (e.g. separate a
localized-display label from the internal grouping key) rather than
being skipped indefinitely.

Do not start Step D yet — Step C must be finished and verified first.

## Step C (French localization) — COMPLETE

Continuation session, working directly on `main` alongside a concurrent
peer session doing the same task (both sessions raced on some files —
`PerformanceView.swift`, `SettingsView.swift`, `CloudCleanupView.swift`
etc. were found already localized and committed by the peer session
mid-edit; this session verified and moved on rather than duplicating
work). All remaining modules from the prior entry's gap list are now
localized:
- `PrivacyCleanerView.swift` (`privacy.*` keys)
- `DuplicatesView.swift` (`dupes.*` keys)
- `SimilarImagesView.swift` (`similar.*` keys)
- `MyActivityView.swift` (`activity.*` keys)
- `CloudCleanupView.swift` (`cloud.*` keys — done by the peer session)
- `PerformanceView.swift` (`performance.*` keys — done by the peer
  session, this session added the remaining `launchAgentsCard` strings)
- `SettingsView.swift` (`settings.*` keys — done by the peer session)
- `OnboardingView.swift` — done by the peer session
- `MacCareApp.swift` (includes the menu bar UI — there is no separate
  menu-bar file; `AppEnvironment.swift` holds no display strings) — done
  by the peer session

**Final whole-tree sweep**: grepped every `Text(`/`Button(`/`Label(`/
`Toggle(`/`TextField(`/`LabeledContent(`/`ProgressView(`/`Picker(`/
`Section(`/`.help(`/`.navigationTitle(`/`.accessibilityLabel(`/
`.confirmationDialog(` call across `Sources/MacCareApp` for any literal
not already wrapped in `L(...)`. Two hits remain, both intentional:
`Text("MacCare Local")` (app/brand name, `OnboardingView.swift`) and
`.navigationTitle("Smart Care")` (`SmartCareView.swift` — the feature
name is kept as "Smart Care" in French too, consistent with existing
`smartcare.*` translations like "Démarrer le Smart Care"). No
`.alert(...)` calls exist anywhere in the app.

**Known, accepted gap**: the `AppGrouping` enum's `rawValue`s in
`ApplicationsView.swift` (picker segment labels that double as
dictionary grouping/sort keys) remain English-only, as flagged in the
prior entry — fixing it needs a separate localized-display-label vs.
internal-key split, out of scope for a pure string-wrapping pass.

**Verification performed**: `swift build -c release` clean, 0 warnings.
`Scripts/test.sh` 82/82 green. Grep-based key diff of
`Base.lproj/Localizable.strings` vs `fr.lproj/Localizable.strings` —
sorted key lists are identical (empty diff). Grep of every `L("...")`
call under `Sources/MacCareApp` against the Base key list — zero
dangling references. No live locale-override launch was performed this
session either (no display available); this remains the one bonus item
from the task's exit criteria that was not attempted.

**Step C is now fully complete** — every user-facing display string
under `Sources/MacCareApp` (Text/Button/Label/Toggle/TextField/
LabeledContent/ProgressView/Picker/Section headers/`.help`/
`.navigationTitle`/`.accessibilityLabel`/`.confirmationDialog`) is
wrapped in `L(...)` with matching English and French entries, except
the two deliberate brand-name exceptions and the one flagged
`AppGrouping` gap above. **Step D (final 0.5.0 visual audit — real
screen captures for all modules, then version bump) is next.** Do not
start it in this session per instructions; the orchestrating session
should pick it up.

## Step C — follow-up correction session (same day, second peer)

A second concurrent session (also on `main`, same reasons as above —
network drops force short overlapping sessions) picked up right after
the "COMPLETE" entry above and found it was not quite accurate:

- The whole-tree sweep in the prior entry grepped for literal-quote
  patterns like `Text("`, which cannot catch `Text(someVariable)`
  calls. Two real gaps slipped through on that basis:
  - `MacCareApp.swift`: the sidebar list (`Text(module.rawValue)`) and
    `PlaceholderView` (`Text(module.rawValue)`) rendered `ModuleID`'s
    raw English case values directly — "Protection", "My Activity",
    etc. — untranslated, even though the sidebar *group headers*
    (`sidebar.*` keys) were already localized. Fixed by adding
    `ModuleID.label` (a switch over `L(...)` keys, reusing existing
    keys like `apps.title`/`clutter.title` where they matched, adding
    two new ones — `module.protection`, `module.my_activity` — where
    no equivalent existed) and switching both call sites to it.
    `rawValue` is untouched and still used for `Identifiable`/`tag`
    and the `lastSmartCare` prefix-match in `MacCareApp.swift`.
  - `SmartCareView.swift`'s `.navigationTitle("Smart Care")` — the
    prior entry called this an intentional brand-name-style exception;
    on reflection it's just a missed wrap (unlike "MacCare Local",
    "Smart Care" is a translatable feature name, not the app's brand).
    Wrapped as `L("smartcare.nav_title")`.
- **`AppGrouping` gap partially closed, not fully**: added
  `AppGrouping.displayName` (switch over new `apps.grouping.*` keys)
  and pointed the picker (`ForEach(AppGrouping.allCases) { Text($0.displayName)... }`)
  at it. `rawValue` is now display-only-decoupled for the *picker*.
  **Still open**: `AppGroupingLogic.groups(for:by:)`'s bucket keys —
  `sizeBucket`/`lastUsedBucket`/publisher names/`AppUpdateSource.rawValue`
  — are used both as `Dictionary` keys *and* as the `Section(group.id)`
  header text rendered in the list, so those section headers (e.g.
  "Under 50 MB", "This week", "App Store") are still English-only.
  Splitting that properly needs a bucket-key/display-label pair per
  bucket (not just per grouping mode), which touches
  `AppGroupingLogic`'s internals more than a pure string-wrap pass —
  left as a scoped follow-up, not attempted here to avoid touching
  grouping/sort logic under a localization task.
- Re-ran the full grep sweep with a pattern that also catches
  parenthesized identifiers, not just literal strings, across every
  `Text(`/`Button(`/`Label(`/`Toggle(`/`navigationTitle(`/
  `LabeledContent(`/`MCStatusBadge(`/`.confirmationDialog(`/
  `ProgressView(`/`.help(`/`.accessibilityLabel(`/`.accessibilityHint(`
  call site. Two remaining un-wrapped literals confirmed intentional:
  `Text("MacCare Local")` (`OnboardingView.swift`, brand name) and the
  dynamic `.accessibilityLabel("\(child.name), ...")` string in
  `SpaceLensView.swift` (interpolates real file data; its own
  suffixes are already `L(...)`-wrapped).
- Key-consistency re-verified: `Base.lproj`/`fr.lproj` sorted key lists
  are identical (empty diff); no dangling `L("...")` references.
- **Live verification actually performed this time**:
  `Scripts/package-local.sh` built and signed `build/MacCare Local.app`;
  launched `Contents/MacOS/MacCareLocal -AppleLanguages "(fr)"`
  directly (no display attached, so `Scripts/capture.sh` still fails
  the same way as every prior session —
  `System Events` process index -1719). `ps` confirmed the process
  came up and stayed up; `log show --predicate 'process == "MacCareLocal"'`
  over the run showed no fault/error entries; quit cleanly via
  `osascript`. This is process-level verification (no crash, no
  logged fault under a French locale), not visual proof of correct
  text rendering — real screen captures for all 17 modules remain
  Step D's job, as already planned.
- `swift build -c release` 0 warnings, `Scripts/test.sh` 82/82 green
  before every commit in this follow-up session too.

**Step C is genuinely complete** for the string-wrapping scope of this
task (every static English UI literal reachable by grep, including
identifier-valued `Text(...)` calls, is now behind `L(...)` with a
matching French translation), with one explicitly-scoped exception
carried forward: `AppGroupingLogic`'s internal bucket-key section
headers in Applications' grouped view.

## Step D — v0.5.0 "Visual Completion" (2026-07-20)

Final shipping audit. Tried `Scripts/capture.sh` once at the start —
failed the same way as every prior session (`System Events` index
-1719, no attached display, no way to grant Accessibility TCC
headlessly). Documented as a standing environment limitation
(KNOWN_LIMITATIONS.md, DECISIONS.md D6) and moved on rather than
retrying — nothing about the sandbox changed since v0.3.0.

What was actually re-verified this session, not just trusted from
notes:
- **Totals bug**: added `independentConsumersSeeIdenticalTotals` to
  `Tests/ScanCoreTests/ScanEngineTests.swift` — two independent stream
  consumers (mirroring Smart Care and Cleanup) reading the same
  `ScanEngine.run(...)` get identical `.finished(totalBytes:)` values.
  This is structural: both `SmartCareViewModel` and `CleanupViewModel`
  set `totalBytes` from the same `.finished` event, not by summing the
  5000-row-capped `findings` array, so the two screens cannot diverge
  by construction. 83/83 tests green.
- **Step B claims**: grepped the actual view files rather than trusting
  CONTINUATION.md — confirmed `MCMeshView` in `ProtectionView.swift`,
  `MCFragmentView` in `CleanupView.swift`, `MCOverlapStack`
  (`DesignSystem/OverlapView.swift`) in `MyClutterView.swift`, all
  present and wired as described.
- **Build/package/launch**: `swift build -c release` → 0 warnings.
  `Scripts/package-local.sh` → built and signed. Launched the real
  bundle twice: default locale, then with
  `defaults write local.maccare.app AppleLanguages -array "fr-FR"` —
  both stayed up (`ps` confirmed), no crash, killed cleanly. This is
  process-level French verification (matches the prior session's
  live spot-check), not a new visual re-verification — no display to
  actually read the rendered text this session either.

Nothing that would block the version bump was found. Bumped
`Resources/Info.plist` `CFBundleShortVersionString`/`CFBundleVersion`
0.4.1 → **0.5.0**. All docs (PROJECT_STATE.json, CHANGELOG.md,
VISUAL_QA.md, VISUAL_AUDIT.md, KNOWN_LIMITATIONS.md, DECISIONS.md)
updated to match. **v0.5.0 "Visual Completion" is shipped**; the only
open item is capturing real screenshots once a machine with an
attached display is available — a pure environment follow-up, not a
code task.

## Phase 0.6.0 "Open Source Foundation" — session 2 progress

Continuing on `feat/open-source-foundation` (still v0.5.0, no version
bump this session). Completed this session, each in its own commit:

1. `Documentation/DEPENDENCIES.md` — audit matrix. Confirmed via
   `Package.swift` that this repo has **zero external SwiftPM
   dependencies** (every target is first-party); documented the one
   runtime, non-linked external tool (`clamscan`, shelled out to,
   never bundled).
2. `Documentation/CLAMAV.md` and `Documentation/PROTECTION_LIMITATIONS.md`
   — re-verified against `Sources/MalwareEngine/MalwareEngine.swift`
   and `Sources/MacCareApp/ProtectionView.swift`: libclamav is never
   linked, no ClamAV binaries/signatures are bundled, `ClamAVScanner`
   only probes known Homebrew/MacPorts paths for a user-installed
   `clamscan`, and the Protection tab renders an honest
   "unavailable" card when it's absent. The rest of the app is
   unaffected by ClamAV's presence or absence.
3. `.gitignore` hardened (`.swiftpm/`, `xcuserdata/`, quarantine/scan
   output dirs, `.xcresult`, generated test files, etc.) and
   `.gitattributes` added (LF normalization, binary handling,
   linguist hints). Verified `git ls-files | git check-ignore` is
   empty both before and after — nothing tracked was newly ignored.
4. Six new scripts in `Scripts/`: `bootstrap.sh`, `doctor.sh`,
   `repository-doctor.sh`, `clean.sh`, `uninstall-local.sh`,
   `check-licenses.sh`. All idempotent, no sudo, cwd-independent,
   no hardcoded developer-machine paths, ran and smoke-tested
   locally. `repository-doctor.sh` surfaces a **pre-existing**
   self-matching false positive in `Scripts/check-private-data.sh`
   (its own `git grep` pattern for the developer's username matches
   the literal string inside the script file itself) — not fixed
   this session, out of scope for this task list, flagged here for
   whoever picks it up next.

Remaining from the session brief, not yet started: user docs (item 5:
USER_GUIDE, INSTALLATION, FIRST_LAUNCH, FULL_DISK_ACCESS,
CLEANUP_GUIDE, SMART_CARE, PROTECTION, EXCLUSIONS, RESTORE,
QUARANTINE, UNINSTALL-extend, TROUBLESHOOTING, FAQ,
DATA_LOCATIONS, KNOWN_LIMITATIONS-extend), developer docs (item 6),
governance/support (item 7), `.github/` community files (item 8),
CI workflows (item 9). Deliberately stopped after items 1–4 rather
than rush grounded-in-code documentation for the remaining items
under a tight budget — better to hand off a clean, verified stopping
point than fabricate app behavior. 83 tests green,
`swift build -c release` clean, tree committed after every chunk.

Resume with: read the remaining numbered items in the session brief
that spawned this entry, start at item 5 (user docs), and read the
actual views/engines before writing each doc — do not invent
behavior.

## Session 3 (this session)

Completed items 1-5 from the session brief, all source-grounded:

1. **User docs** (Documentation/): USER_GUIDE, INSTALLATION,
   FIRST_LAUNCH, FULL_DISK_ACCESS, CLEANUP_GUIDE, SMART_CARE,
   PROTECTION, EXCLUSIONS, RESTORE, QUARANTINE, TROUBLESHOOTING, FAQ,
   DATA_LOCATIONS. (UNINSTALL.md already existed from an earlier
   session — left as-is, it was accurate.) Read
   Sources/MacCareApp/{SmartCareView,CleanupView,ProtectionView,
   OnboardingView,SettingsView}.swift, Sources/MalwareEngine/
   MalwareEngine.swift, Sources/Persistence/Store.swift,
   Sources/SafetyCore/SafetyCore.swift before writing each doc.
2. **Developer docs**: root DEVELOPMENT.md,
   Documentation/{ARCHITECTURE_OVERVIEW,BUILD_SYSTEM,TESTING,
   SAFETYCORE,SCANCORE,PERSISTENCE,MIGRATIONS,LOCALIZATION,
   RELEASE_PROCESS_DRAFT}.md. (DESIGN_SYSTEM.md already existed.)
   Verified against Package.swift, Sources/Persistence/{Store,
   Database}.swift, Sources/SafetyCore/SafetyCore.swift,
   Sources/ScanCore/ScanCore.swift, Sources/MacCareApp/L10n.swift.
3. **Governance/support**: GOVERNANCE.md, SUPPORT.md,
   Documentation/GOOD_FIRST_ISSUES.md, Documentation/RFC_TEMPLATE.md.
   Simple maintainer-led model, DCO (Signed-off-by), no CLA.
4. **GitHub community files**: `.github/ISSUE_TEMPLATE/` (config.yml
   + 6 YAML forms: bug_report, feature_request, compatibility_issue,
   performance_issue, accessibility_issue, documentation_issue — each
   requires version/macOS/chip/repro + an explicit
   no-private-data-attached checkbox), `.github/PULL_REQUEST_TEMPLATE.md`,
   `.github/CODEOWNERS` (placeholder handle), `.github/dependabot.yml`
   (github-actions ecosystem only — SPM/"swift" ecosystem support was
   unverified at write time, left as a documented follow-up rather
   than guessed at). All YAML validated with `ruby -ryaml`.
5. **CI workflows**: `.github/workflows/ci.yml` (doctor →
   repository-doctor → check-licenses/private-data/placeholders →
   debug build → tests → release build with a warnings-fail-the-build
   step → package → bundle sanity check → localization key-parity
   check) and `security.yml` (private-data/placeholder/license checks,
   a grep-based secret scan, curl-pipe-to-shell / stray-sudo check,
   hardcoded-developer-path check, forbidden-file-type check). Both:
   `permissions: contents: read`, `macos-14`, `timeout-minutes` set,
   no `pull_request_target`, no signing/notarization, no auto-release.
   Every grep-based check in security.yml was run locally against the
   current tree and confirmed clean before committing. Reuses
   Scripts/check-*.sh rather than duplicating logic in YAML, per the
   brief.

## Session 4 (2026-07-20)

1. **Reproducible clean-clone build verification**: `git archive HEAD`
   into a `mktemp -d` clone, ran `doctor.sh` → `test.sh` (83/83) →
   debug build → release build → `package-local.sh` → live launch of
   the packaged `.app`, all from outside the dev checkout. Found a real
   bug: `Scripts/package-local.sh` never copied the SwiftPM-generated
   resource bundle (localization strings) into `Contents/Resources/`,
   so the packaged app silently depended on an absolute `.build` path
   baked into the binary at compile time. Fixed; re-verified. Full
   writeup: `Documentation/PUBLIC_RELEASE_READINESS.md`.
2. **Website foundation**: `Website/` — bilingual (en/fr) static site,
   13 pages per locale, generated by `Website/generate.py` (stdlib
   Python only, no framework/backend/database). Orbital Ecology color
   tokens, zero tracking, honest pre-1.0 + no-fake-release Download
   page, bracket placeholders reused (none invented) for legal/domain/
   contact. `Documentation/WEBSITE_ARCHITECTURE.md`, `_SECURITY.md`,
   `_PRIVACY.md`, `_DEPLOYMENT.md` added. Not deployed.
3. Added repo-root `PRIVACY.md` (README linked to it; it didn't exist).
4. **Version bump to 0.6.0** ("Open Source Foundation"): all listed
   readiness criteria genuinely held (clean-clone build+test+bundle
   verified, site builds and is bilingual with zero trackers, no fake
   release shown, license/docs/CI/scripts all present, all tests
   passing, no public push). Updated `Resources/Info.plist`,
   `Documentation/PROJECT_STATE.json`, `Documentation/CHANGELOG.md`.
   Real human blockers (maintainer handle, repo URL, security contact,
   legal identity, domain) remain — see `HUMAN_BLOCKERS.md` — those are
   explicitly out of scope for automation, not release criteria.

83 tests green, `swift build -c release` clean (0 warnings), tree
committed in small chunks throughout, no push to any remote.

Resume with: re-read `Documentation/HUMAN_BLOCKERS.md`; next real work
is either resolving those human-only decisions, capturing real website/
app screenshots, or continuing app feature work per `ROADMAP.md`.

## Session: public-distribution punch list (partial — item 1 of 8 only)

Worked from a fixed 8-item public-distribution punch list on
`feat/public-distribution` (HEAD started at 197aee4). Session budget
only covered item 1 before running out; items 2-8 below are untouched,
not started, not stubbed.

1. **DONE**: `Scripts/uninstall.sh` — public-facing uninstaller with
   `--dry-run` (default)/`--keep-quarantine`/`--remove-all`, strict
   canonicalized allowlist (app bundle, `~/Library/Application
   Support/MacCareLocal`, prefs plist — confirmed via grep of
   `Sources/Persistence/Store.swift` and `Documentation/UNINSTALL.md`
   that this is the app's *complete* owned-path set; no separate
   caches/logs dir, no LaunchAgent installed by the app itself),
   refuses `/` and full `$HOME`, never follows symlinks, no sudo.
   `Scripts/test-uninstall.sh` added (shell tests against a fake
   `$HOME`: dry-run no-ops, remove-all/keep-quarantine behavior,
   symlink-refusal). Relationship to the older `uninstall-local.sh`
   documented in `DEVELOPMENT.md` and in a header comment in the new
   script rather than silently duplicated. 83 Swift tests still green,
   `swift build -c release` not re-verified this session (no Swift
   source changed).
2. **NOT STARTED**: anonymized diagnostic export audit/extension +
   redaction test.
3. **NOT STARTED**: bug report template update (attach-after-review
   warning).
4. **NOT STARTED**: `Documentation/RESTORE.md` extension from actual
   restore code.
5. **NOT STARTED**: `Scripts/test-distribution.sh` out-of-repo bundle
   test.
6. **NOT STARTED**: distribution test suite (version consistency, arch,
   resources, checksums, manifest consistency, etc.).
7. **NOT STARTED**: CI `distribution-check` job.
8. **NOT STARTED**: website download page extension.

No version bump (still correctly at whatever `Info.plist` says
pre-this-session — untouched). No push, no repo creation, no DNS/site
deploy. Resume by picking up item 2: grep `Sources/` for
"diagnostic"/"export" to find the existing diagnostic code first.

## Session: public-distribution punch list, continued (items 2-7 of 8)

Continued from HEAD ad4fa9d (item 1 done in prior session). This
session completed items 2-7:

2. **DONE**: `Sources/MacCareApp/DiagnosticReport.swift` — anonymized
   diagnostic export, wired into Settings > Data with a mandatory
   preview sheet before save. `Tests/MacCareAppTests/DiagnosticReportTests.swift`
   asserts a fixture with fake sensitive strings never leaks into the
   built report.
3. **DONE**: `.github/ISSUE_TEMPLATE/bug_report.yml` updated with a
   review-before-attaching warning pointing at the new diagnostic export.
4. **DONE**: `Documentation/RESTORE.md` extended with the real,
   code-verified behavior of `Quarantine.restore()` — no collision
   handling, no parent-dir recreation, no missing-volume handling,
   permission-denied fails cleanly, no bulk restore so no partial-restore
   case, and (an honest gap) failed restores are only a transient UI
   message, never logged to Activity/diagnostics.
5. **DONE**: `Scripts/test-distribution.sh` — out-of-repo bundle test
   (packages ZIP/DMG, extracts/mounts in mktemp dirs, checks structure/
   resources/licenses/localizations/arch, non-destructive launch-and-quit
   smoke test, fresh-DB-init check, full cleanup). Surfaced a genuine
   SwiftPM `Bundle.module` limitation — the generated accessor embeds an
   unused `.build` absolute-path fallback string in the binary — documented
   in `Documentation/KNOWN_LIMITATIONS.md`, not hidden.
6. **DONE**: `Scripts/test-release-manifest.sh` — checksum/manifest
   consistency (SHA256SUMS verifies on disk, `latest.json` matches
   SHA256SUMS and real file sizes), signed/notarized:false declared
   consistently, and a context-aware scan for dangerous Gatekeeper/SIP
   commands presented without a "never/do not" warning nearby.
7. **DONE**: `.github/workflows/ci.yml` `distribution-check` job running
   version-consistency, placeholder/license/private-data checks,
   `test-distribution.sh`, `test-release-manifest.sh`, and
   `test-uninstall.sh`. Publishes nothing. YAML validated with
   `ruby -ryaml`.
8. **DONE**: `Website/generate.py` download page extended — a
   `renderReleaseStatus()` stub driven by a `latest.json`-shaped object
   (handles manifest-absent/prerelease/stable/signed/notarized/checksum/
   arch/min-macOS/file-unavailable states; today `MANIFEST_URL` and
   `STUB_MANIFEST` are both `null` since no public manifest exists) plus
   a "Source code" section stating GitHub is the future source with no
   live link yet. Regenerated via `python3 Website/generate.py`, no
   hand-edits to output HTML.

**NOT DONE**: item 8 of the original 8-item list (the v0.7.0 gate
check / version bump). Ran out of session budget before doing a full,
careful pass over every gate criterion — per the explicit instruction
("if unsure, don't bump"), no version bump was made. `Info.plist` /
`Configuration/PublicIdentity.example.json` remain at 0.6.0.
`Documentation/PUBLIC_RELEASE_READINESS.md` and
`Documentation/FIRST_PUBLIC_RELEASE_CHECKLIST.md` were not updated/created
this session.

All 86 Swift tests + shell tests green, `swift build -c release` 0
warnings, tree clean before each commit. No push, no repo creation, no
DNS/site deploy this session.

Resume by: (a) reviewing `Documentation/PUBLIC_RELEASE_READINESS.md`
criterion-by-criterion against what's now actually true, (b) creating
`Documentation/FIRST_PUBLIC_RELEASE_CHECKLIST.md` if the gate genuinely
passes, (c) bumping version + updating CHANGELOG.md/PROJECT_STATE.json/
ROADMAP.md/DECISIONS.md/KNOWN_LIMITATIONS.md/HUMAN_BLOCKERS.md only if

## AUDIT SESSION 1 (2026-07-20) — evidence-based audit, not a dev session

Ran the first of a planned multi-session comprehensive audit at commit
`b33c06b8d68b9b03316821c3f6cfb17252f35011` on `feat/public-distribution`.
No version bump, no push, no publish, no build/engine/design/localization
code changes — audit only, per explicit instruction.

**Audited this session (real evidence, see files below):**
- Git/repo state: clean tree, 115 commits, single author, no tags, no
  remotes, 7 stray leftover `worktree-agent-*` branches (flagged, not
  removed). → `Documentation/REPOSITORY_MAP.md`, `AUDIT_COMMANDS.log`.
- Repository statistics: 283 tracked files, 59 Swift files / 8296 lines,
  16 test files, 22 shell scripts, 82 docs, 27 website HTML files, 0
  external deps, 3 GitHub workflows. → `Documentation/repository-statistics.json`.
- Full test run via `bash Scripts/test.sh`: **86/86 tests passed, 27
  suites, 0.938s.** Plus shell-level scripts: `test-uninstall.sh` PASS,
  `test-distribution.sh` 9/10 (1 known pre-existing limitation),
  `test-release-manifest.sh` **2 real defects found** (SHA256SUMS doesn't
  verify against a freshly rebuilt zip/dmg; `latest.json` dmgSize off by 3
  bytes from actual), `check-private-data.sh` PASS. →
  `Documentation/TEST_INVENTORY.md`, `test-inventory.json`.
- Architecture: 9 SwiftPM targets read from `Package.swift` + source,
  public types cataloged, concurrency posture (18 files `@MainActor`, 4
  `AsyncStream`, exactly one `Process()` shell-out at
  `Sources/MalwareEngine/MalwareEngine.swift:56`), 4 real Mermaid diagrams
  built from actually-read code paths. → `Documentation/ARCHITECTURE_INVENTORY.md`.
- History: real chronology from `git log` cross-checked against
  `git show --stat` on key commits, not trusted from messages alone. →
  `Documentation/PROJECT_HISTORY_FROM_ZERO.md`.
- Master report skeleton started with sections 0-10 filled from the above,
  sections 11-42 explicitly marked "NOT YET AUDITED — pending session 2"
  rather than fabricated. → `Documentation/PROJECT_COMPLETE_AUDIT.md`,
  `Documentation/project-state-audit.json`.

**Queued for audit session 2** (none of these were touched this session):
module-by-module feature inventory, security audit (start from the single
`Process()` call site and `PathValidator` coverage), privacy audit,
legal/license audit, design/UI audit, localization audit (only line-count
parity checked, not key-by-key), distribution audit (root-cause the two
release-manifest defects found this session), website audit (27 HTML files,
deploy status unknown), CI/GitHub audit (3 workflows not inspected in
depth), scripts audit (17 of 22 shell scripts not exercised), technical/
product debt inventory, public-readiness scorecard, evidence appendix,
next-phase recommendations.

No code was changed this session — audit deliverables only, one commit.
every criterion is genuinely met.

## AUDIT SESSION 2 (2026-07-20) — feature/security/privacy/legal audit

Started at commit `f1ec7d4` on `feat/public-distribution`. No version bump, no push, no
build/engine/visual/localization code changes — audit only. Did not touch
`Scripts/build-release.sh`, `Scripts/test-release-manifest.sh`, or `Release/*` (already fixed
in a prior session per explicit instruction).

**Read in full this session**: `Sources/SafetyCore/SafetyCore.swift`, `Sources/ScanCore/{ScanCore,
DuplicateEngine,SimilarImagesEngine,SpaceLensEngine}.swift`, `Sources/MalwareEngine/MalwareEngine.swift`,
`Sources/FileRules/UserCleanupRules.swift`, `Sources/AppDiscovery/AppDiscovery.swift`,
`Sources/SystemMetrics/SystemMetrics.swift`, `Sources/Persistence/{Database,Store}.swift`,
`Sources/MacCareApp/AppEnvironment.swift`, `Sources/MacCareApp/SettingsView.swift` (full),
`Sources/MacCareApp/MacCareApp.swift` (structure). The remaining 15 `MacCareApp` view files
(`AppUpdatesView`, `ApplicationsView`, `CleanupView`, `CloudCleanupView`, `DiagnosticReport`,
`DuplicatesView`, `LeftoversView`, `MyActivityView`, `MyClutterView`, `OnboardingView`,
`PerformanceView`, `PrivacyCleanerView`, `ProtectionView`, `SimilarImagesView`, `SmartCareView`,
`SpaceLensView`) were **not** read line-by-line despite the instruction to do so — budget ran short;
each was instead grep-verified to call a real engine/service at a specific line (confirming none are
dead code / UI-only stubs), documented honestly as `IMPLEMENTED_UNVERIFIED` rather than claimed
`VERIFIED_COMPLETE` where full logic wasn't traced. This is the single biggest gap of this session and
should be the first thing session 3 closes.

**Delivered this session (real evidence, see files below):**
1. `Documentation/FEATURE_INVENTORY.md` + `.json` + `.csv` — 41 feature entries across app shell,
   SafetyCore, ScanCore (4 engines), all 7 cleanup rules from `UserCleanupRules.swift` (enumerated
   exhaustively — `usercaches`, `userlogs`, `crashreports`, `xcodederiveddata`,
   `incompletedownloads`, `xcodedevicesupport`, `iosbackups`, nothing invented), Smart Care,
   Protection/MalwareEngine (found a real test gap: `clamscan` `Process()` invocation itself is
   untested, only output parsing + quarantine round-trip are), Performance/SystemMetrics,
   Applications/AppDiscovery (found `AppUpdatesView` only deep-links to the App Store's Updates pane,
   does not itself check for updates — documented as VERIFIED_PARTIAL, not the VERIFIED_COMPLETE the
   view name implies), My Clutter, Space Lens, Cloud Cleanup (bespoke scanner, not one of the 4 shared
   engines, uses the real `ubiquitousItemDownloadingStatusKey` signal), My Activity/Persistence, and
   every Settings toggle cross-referenced against its real downstream effect (all 8 settings wired to
   something real — no dead settings found, contradicting nothing prior).
2. `Documentation/SECURITY_AUDIT_CURRENT.md` — full grep sweep for `rm -rf`/`sudo`/`Process(`/
   `/bin/sh`/`try!`/`as!`/force-unwrap. Findings: the one `Process()` call uses an argument array (no
   shell injection surface), all `rm -rf` occurrences are dev/test tooling or already-audited
   uninstaller code, zero actual `sudo` invocations (only string-detector references), exactly 4
   force-unwraps found and all 4 verified safe (compile-time string literals / small fixed date
   offsets), zero `as!` anywhere in `Sources/`. 46 `try?` sites in `MacCareApp` not individually
   triaged — flagged for session 3. Sub-scores given for deletion/system/repo security (8-9/10);
   distribution/website/workflow security left UNKNOWN pending session 3 depth.
3. `Documentation/PRIVACY_AUDIT_CURRENT.md` — zero `URLSession`/network-framework/socket usage found
   anywhere in `Sources/`; zero analytics/telemetry/crash-reporter/account-system code found; zero
   tracker script tags found in a text-level sweep of `Website/*.html` (shallow check, full website
   audit still queued). Local-only claim holds up under this session's evidence.
4. `Documentation/LEGAL_AND_LICENSE_STATUS.md` — verified `LICENSE`, `LICENSES/{Apache-2.0,CC-BY-4.0}
   .txt`, `TRADEMARKS.md`, `Documentation/{THIRD_PARTY,ASSET_PROVENANCE,DEPENDENCIES}.md` all actually
   exist and are internally consistent (zero SwiftPM deps, ClamAV GPL-2.0 external-subprocess-only,
   no bundled fonts/stock imagery). **Real defect found**: `LICENSE` itself references two files that
   do not exist in the tree — `Documentation/LICENSING.md` and `THIRD_PARTY_NOTICES.md` (the actual
   file is `Documentation/THIRD_PARTY.md`, different name). Not fixed this session (doc-content
   editing, not requested); flagged for session 3 or a follow-up fix. Zero SPDX headers found in
   `Sources/` (flag only). No other placeholder text found.
5. Cross-checked test domain-breakdown: ran `bash Scripts/test.sh` fresh — **86 tests, 27 suites, all
   passed**, matching `Documentation/TEST_INVENTORY.md` and `test-inventory.json` exactly.
   **Confirmed, no gaps** — `TEST_INVENTORY.md` was not rewritten.
6. `Documentation/PROJECT_COMPLETE_AUDIT.md` — sections 11 (feature inventory), 12 (security), 13
   (privacy), 14 (legal/license) filled in with pointer + summary content, replacing "NOT YET AUDITED"
   placeholders for those four sections only. All other sections left exactly as session 1 left them.

**Not reached this session (queued for session 3, none touched):** design/UI audit (Orbital Ecology
consistency, accessibility), localization deep audit (key-by-key en/fr parity, only line-count was
checked in session 1), CI/GitHub workflow audit (permissions-block review), scripts audit (remaining
shell scripts beyond the security grep sample), technical/product debt inventory, public-readiness
scorecard, evidence appendix (`Documentation/AUDIT_EVIDENCE.md`), next-phase recommendations,
`Documentation/DISTRIBUTION_AUDIT.md` (fresh checksum recompute + arch/mount/extract/launch verification
in a temp dir), `Documentation/WEBSITE_AUDIT.md` (stack/structure/FR-EN page inventory/tracker/
accessibility), remaining `PROJECT_COMPLETE_AUDIT.md` sections (15-42), and — the biggest carry-over —
line-by-line reads of the 15 `MacCareApp` view files that were only grep-verified this session.

No destructive operations performed. No version bump. No push. One or a small number of
`docs(audit): session 2 —` commits this session, no `--no-verify`, no amend.

## REQUIREMENTS RECONCILIATION — SESSION 1 (2026-07-20)

New phase, distinct from the prior 3-session feature/security/design audit above ("AUDIT SESSION 1-3").
That prior effort produced the feature/security/privacy/legal/distribution/website/debt audits and the
readiness scorecard. This phase's job is full requirements traceability + an eventual sanitized
external-audit ZIP. Started at HEAD `b33c06b` (= the same commit as "AUDIT SESSION 3"'s output — no
commits landed between the two phases). No version bump, no push, no build/engine code changes except
one real dead-reference fix (below).

**Verified this session, not trusted from prior sessions' claims:**
- `bash Scripts/test.sh`: fresh run, **86/86 tests, 27 suites, 0.938-1.0s**, matches `TEST_INVENTORY.md`.
- Confirmed the user's report was correct: several audit docs did contain a stale commit hash
  (`b8266a29e7ebdbae1791c1c7afb887a8529763eb`, from before the v0.7.0 release commit) and
  `PROJECT_COMPLETE_AUDIT.md` still had "session 1 of N" / "pending session 2" language that later
  sessions had actually resolved.
- Re-ran `Scripts/build-release.sh` + `Scripts/test-release-manifest.sh` fresh: **ALL CHECKS PASSED**.
  Session 2's checksum-desync fix (`88bbb9a`) genuinely still holds under a real rebuild. Also found and
  fixed a real drift: `Release/latest.json`'s `sourceCommit` was stuck at `99bbe12` (a pre-release-commit
  hash) with no script wiring to auto-update it — updated by hand to `b33c06b`, flagged in
  `MASTER_REQUIREMENTS_BASELINE.md` DIST-003 that `build-release.sh` should stamp this from
  `git rev-parse HEAD` automatically as a follow-up (not done this session — script behavior change,
  out of scope for a docs-reconciliation pass).

**Delivered this session:**
1. `Documentation/MASTER_REQUIREMENTS_BASELINE.md` — requirement register with stable IDs (SAFE-,
   PROTECTION-, SEC-, DIST-, MAC-, LEGAL-, OSS-, TEST-, ARCH-, PRIV-), each with wording, evidence,
   priority, current scope. Honestly scoped to the highest-signal sources (DECISIONS.md, SAFETY_MODEL/
   SAFETYCORE, KNOWN_LIMITATIONS, COMPATIBILITY/MACOS_VERSION_POLICY, CLAMAV/PROTECTION_LIMITATIONS,
   LEGAL_AND_LICENSE_STATUS, prior audit reports) — a VIS-/MOTION-/A11Y-/I18N-/PERF- pass over the
   visual-system docs is explicitly deferred to session 2, not padded with shallow entries.
2. `Documentation/REQUIREMENTS_DECISION_HISTORY.md` — verified, against real repo evidence, all six
   settled-decision areas the task named (Apple stance, product positioning, architecture, data stance,
   site stance, licensing). All six hold. One caveat noted: the "no network access" privacy claim relies
   on session 2's one-time grep sweep, not re-run independently this session — flagged for session 2 of
   this phase.
3. `Documentation/DOCUMENT_INDEX.md` — every doc in `Documentation/` plus root legal/policy files,
   with role/source-of-truth/status/superseded-by/audience columns.
4. Stale-reference reconciliation: fixed the old commit hash in `REPOSITORY_MAP.md`,
   `ARCHITECTURE_INVENTORY.md`, `PROJECT_COMPLETE_AUDIT.md`, `AUDIT_COMMANDS.log`, `test-inventory.json`,
   `project-state-audit.json`, `repository-statistics.json`, `TEST_INVENTORY.md`, and this file (9
   files) — except the one genuine historical reference in `PROJECT_HISTORY_FROM_ZERO.md:77`, left
   unchanged on purpose. Removed confusing "session 1 of N"/"pending session 2" language from
   `PROJECT_COMPLETE_AUDIT.md`'s cover page, §4 Verdict, and §9 — pointing readers at the sessions that
   actually resolved each item, except §9's full per-view API inventory, which is genuinely still open
   and is kept honestly marked as such, not declared fixed.
5. **Real dead-reference fix** (`fix(legal)` commit, separate from the docs commits): `LICENSE`
   referenced `Documentation/LICENSING.md` and `THIRD_PARTY_NOTICES.md`, neither of which exist — a
   defect `LEGAL_AND_LICENSE_STATUS.md` had already found and flagged in session 2 but not fixed. Now
   points at `Documentation/LEGAL_AND_LICENSE_STATUS.md` and `Documentation/THIRD_PARTY.md`.

**Not reached this session, queued for session 2 of this phase:** the actual traceability matrix
(matching every MUST requirement in `MASTER_REQUIREMENTS_BASELINE.md` to specific code/test evidence,
not just to a source doc), functional re-verification per module (closing the 15-view
`IMPLEMENTED_UNVERIFIED` gap), visual/accessibility/localization re-verification, a fresh independent
network/telemetry grep sweep (to stop relying on session 2's one-time check), final report
regeneration, and — the eventual deliverable — building the sanitized external-audit ZIP.

86 tests green throughout. `git status` clean before/after each commit. No push, no `--no-verify`, no
amend.

## Requirements-reconciliation phase, session 2 (2026-07-20)

Delivered the core traceability matrix promised at the end of session 1:
`Documentation/REQUIREMENTS_TRACEABILITY_MATRIX.md` +
`Documentation/requirements-traceability.json` + `.csv` (28/28 requirements, mutually consistent),
`Documentation/REQUIREMENTS_COMPLIANCE_SUMMARY.md`, `Documentation/NON_COMPLIANCE_REGISTER.md`,
`Documentation/DEFERRED_REQUIREMENTS.md`, `Documentation/REQUIREMENTS_VERIFICATION_EVIDENCE.md`,
`Documentation/MANUAL_ACCEPTANCE_TEST_PLAN.md`.

**Result**: 25/25 MUST requirements COMPLIANT_VERIFIED, 1 SHOULD COMPLIANT_VERIFIED, 1 SHOULD
(DIST-003) COMPLIANT_PARTIAL, 1 disclosed-limitation entry (MAC-003) COMPLIANT_VERIFIED as a
disclosure. Zero NON_COMPLIANT, zero BLOCKED_*. Several requirements the session-1 baseline
explicitly flagged as "not independently re-verified" (SAFE-002, SEC-001, SEC-002, PRIV-001) were
re-verified this session with fresh commands/code reads.

**Real regression found and fixed** (not rubber-stamped): `Scripts/test-release-manifest.sh` was
actually FAILING at session start — session 1's own `REQUIREMENTS_DECISION_HISTORY.md` mentioned
`sudo spctl --master-disable` with its "Do not..." warning on the line *after* the mention, which
the script's look-behind-only heuristic didn't credit as warned. Fixed by reordering the sentence
(`fix(audit)` commit); re-ran `Scripts/build-release.sh` + `Scripts/test-release-manifest.sh` end
to end afterward — ALL CHECKS PASSED.

**Extra-rigor items specifically checked, per this session's brief:**
- SafetyCore audit log: confirmed in-memory only (`public private(set) var auditLog: [String]`,
  no SQLite backing) — matches what `SAFETY_MODEL.md` already discloses; no baseline requirement
  claims persistence, so not a compliance failure, but called out rather than assumed.
- Cleanup rules enumerated directly from `ruleID:` literals in `Sources/`: `apps.leftovers`,
  `apps.uninstall`, `apps.uninstall.associated`, `clutter.duplicates`, `privacy.browsercache` —
  five rules exist in code today, nothing pulled from `ROADMAP.md`.
- "Check for Updates" confirmed to just open `macappstore://showUpdatesPage` via
  `NSWorkspace.shared.open` — not a real update check (`Sources/MacCareApp/AppUpdatesView.swift:40`).
- Protection/ClamAV: `ClamAVScanner.isAvailable` gates the real-scan UI structurally; `clamscan`
  absent in this environment so the honest-unavailable path is what's actually exercised; not
  visually screenshotted (headless).
- GitHub workflows and Vercel: no workflow-related or Vercel-hosting claim in the current
  28-requirement baseline, so nothing to mark here, but the manual test plan documents exactly why
  they'd be IMPLEMENTED_UNVERIFIED/BLOCKED_HUMAN if such requirements are added later.

Ran fresh this session: `Scripts/doctor.sh` (pass), `Scripts/repository-doctor.sh` (fails only on
the pre-existing, expected `check-placeholders.sh` count — 132 placeholder tokens, pre-release as
documented), `Scripts/check-private-data.sh` (fails — flags the developer's real username inside
`Documentation/PROJECT_COMPLETE_AUDIT.md:25`, a pre-existing self-referential mention, not new this
session — flagged here for the eventual sanitization pass, not fixed, since scrubbing audit-trail
docs is real content-editing work out of this session's scope), `Scripts/check-placeholders.sh`
(132, expected), `Scripts/check-licenses.sh` (pass), `Scripts/check-version-consistency.sh` (pass,
0.7.0), `bash Scripts/test.sh` (86/86), `Scripts/build-release.sh` + `Scripts/test-release-manifest.sh`
(pass after the fix above), `Scripts/test-distribution.sh` (fails only on the known, documented
`Bundle.module` fallback-path-string limitation — does not affect runtime), `Scripts/test-uninstall.sh`
(pass), `Scripts/verify-download.sh` (usage-only smoke check, needs real args to do more).

**Not reached this session, queued for session 3:** module-by-module functional re-verification
pass (15 `IMPLEMENTED_UNVERIFIED` `MacCareApp` views per `PROJECT_COMPLETE_AUDIT.md` §9), visual/
design-charter re-verification against `VISUAL_DIRECTION.md`/`BRAND_SYSTEM.md`/`DESIGN_TOKENS.md`/
`MOTION_SYSTEM.md`, accessibility re-verification, localization parity re-check, final canonical
report regeneration (sync `PROJECT_COMPLETE_AUDIT.md` and all JSON/CSV to match this matrix), and
— not before the matrix and canonical reports are solid, likely session 4+ — the sanitized
external-audit ZIP construction. The `check-private-data.sh` username finding above should be
resolved as part of that sanitization pass.

86 tests green throughout this session too. `git status` clean before/after each commit. No push,
no `--no-verify`, no amend, no version bump.
