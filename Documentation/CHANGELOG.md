# CHANGELOG

## 0.4.1 — 2026-07-20 « Totals & scope audit »
- Audit du scope de scan (ScanEngine/ScanRule): confirmé déjà correct —
  chaque règle déclare ses propres racines, exclusions filtrées avant
  descente (`skipDescendants`), symlinks jamais suivis, chemins canonicalisés.
  Ajout de tests de régression (`Scan root isolation`) prouvant qu'un scan
  Downloads-only ne touche jamais Music/Documents/Library, et qu'un run
  multi-règles (style Smart Care) ne visite que les racines de ses règles.
- Correction des totaux Smart Care / Cleanup: `totalFoundBytes` de Smart Care
  était calculé sur la liste `findings` plafonnée à l'affichage (5000), ce qui
  pouvait diverger du total réel affiché dans l'état "done" du module. Les
  deux vues exposent maintenant `totalFindingCount`/`totalFoundBytes` accumulés
  pendant le streaming (jamais depuis la liste plafonnée), avec indicateur de
  troncature honnête ("N of M shown") quand un scan dépasse 5000 résultats.
- Nouveau test `ScanCoreTests`: 5001 résultats synthétiques, confirme que le
  moteur ne plafonne jamais en interne (le cap est strictement un choix UI).
- 60 tests verts (57 → 60), 0 warning.

## 0.4.0 — 2026-07-20 « Visual Foundation »
- Direction artistique « Orbital Ecology »; signature Core Bloom (noyau + 3 arcs
  asymétriques) partagée logo/icône/héro (MCBloomGeometry).
- DesignSystem refondu: MCColor adaptatif clair/sombre (Core Mint, Ion Violet,
  Solar Amber, Pulse Coral + rôles), MCSpacing/MCRadius/MCSize/MCMotion/MCOpacity,
  MCFont, composants (MCCard+, MCSectionHeader, MCStatusBadge, MCMetricCard,
  MCEmptyState/MCErrorState, MCModuleIdentity, CoreBloomMark, OrbitalProgressView,
  MCHeroCoreView). Reduce Motion/Transparency respectés à la source.
- Icône macOS générée nativement (CoreGraphics → iconset → icns, 16→1024 px),
  icône barre des menus template; assets copiés dans le bundle (plus de
  dépendance au dépôt). Version 0.4.0.
- Sidebar groupée (Soin/Espace/Optimiser/Protéger/Activité), fenêtre min 860×580,
  tint Core Mint.
- Smart Care recomposé: Hero Core lié aux états réels (idle/scanning/review/
  executing/success), microcopy honnête, footer dédupliqué.
- Performance: MCMetricCard (fini les troncatures), graphe CPU grille+aire+état vide.
- Onboarding 4 étapes, skippable, reprenable (étape persistée), FDA honnête.
- Tests design system (tokens, géométrie, couleurs adaptatives, ressources): 57 verts.
- Docs: VISUAL_DIRECTION, BRAND_SYSTEM, DESIGN_TOKENS, MOTION_SYSTEM,
  VISUAL_AUDIT, VISUAL_QA, VISUAL_TOOLING, ASSET_PIPELINE; captures Before/After.
- Bugs données consignés (prompts TCC média pendant scan; totaux plafonnés 5000)
  → prochain audit fonctionnel.

## 0.1.0 — 2026-07-19
- SwiftPM foundation, SafetyCore, ScanCore, FileRules (4 user cleanup rules),
  DesignSystem tokens, SwiftUI shell with working Cleanup module
  (scan → review → dry-run/Trash), 24 tests green, packaging script.

## 0.2.0 — 2026-07-19
- Persistence SQLite (actor, migrations), My Activity, Settings (+exclusions honorées par les scans).
- Smart Care orchestrateur dry-run; Cleanup regroupé par règle, 3 nouvelles règles.
- My Clutter: Large & Old, Doublons (hachage étagé, hard links, gardien suggéré,
  garantie de survivant), Images similaires (Vision, vignettes à la demande).
- Space Lens (treemap + liste), Applications (inventaire, désinstallation Corbeille,
  leftovers conservateurs), Performance (métriques live + LaunchAgents),
  Protection (ClamAV + quarantaine, état honnête), Cloud Cleanup (empreinte locale),
  barre de menus, onboarding avec sonde FDA réelle.
- 46 tests verts, 0 warning, paquet Release arm64.

## 0.3.0 — 2026-07-19
- Protection: onglet Privacy (profils navigateurs, nettoyage caches uniquement,
  avertissement navigateur ouvert; historique/cookies affichés mais non modifiés).
- Applications: onglet Updates (canal de mise à jour par app, aucun téléchargement).
- Accessibilité: labels VoiceOver sur les cases de sélection.
- Script create-test-volume.sh (image APFS isolée pour tests destructifs).
