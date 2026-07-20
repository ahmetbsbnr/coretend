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

## Step B — Space Lens capture verification (v0.4.1, 2026-07-20, resumed session)
- This environment has an attached display this time (`screencapture` works).
  Ran `Scripts/package-local.sh`, launched the real bundle, captured Space
  Lens in light + dark via `Scripts/capture.sh` — both saved to
  `Documentation/VisualAudit/After/spacelens-{dark,light}.png`. Reviewed
  visually: sidebar/typography/icon tinting consistent with the rest of the
  app in both themes, no orphaned text, single focal point. VISUAL_QA.md
  Space Lens row updated to ✅/✅ (was ⏳/⏳).
- 60 tests green, release build 0 warnings, package + real launch verified.
- **Still pending in Step B**: Applications (capsules), My Clutter
  (overlap), My Activity (chronologie), Cloud Cleanup (plein/contour),
  Performance (harmonisation), menu bar, Settings (états permission) —
  not started this session (ran out of reasoning/session budget after the
  capture-verification pass). Step C (fr) and Step D (0.5.0 audit) not
  started. Resume with Applications next, per the ordered list in
  PROJECT_STATE.json / the top-level task instructions.
