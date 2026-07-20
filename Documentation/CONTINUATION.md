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
