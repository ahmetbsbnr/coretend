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
