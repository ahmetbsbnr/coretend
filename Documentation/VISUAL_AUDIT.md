# VISUAL AUDIT — baseline v0.3.0 (captures: VisualAudit/Before, 2026-07-20)

## Constats transverses (avant refonte)
| # | Problème | Gravité | Statut 0.4.0 |
|---|---|---|---|
| 1 | Sidebar plate 10 items identiques, aucun groupe | haute | ✅ groupes (Soin/Espace/Optimiser/Protéger/Activité) |
| 2 | Aucune identité: pas d'icône app, symbole cœur générique | haute | ✅ Core Bloom (icône, menu bar, hero) |
| 3 | Smart Care: 40 % d'écran vide au-dessus des cartes | haute | ✅ composition hero + statut + catégories |
| 4 | Troncatures « Mem… » « Stor… » (Gauge accessoryCircular) | haute | ✅ MCMetricCard (anneau custom + minimumScaleFactor) |
| 5 | Graphe CPU invisible au démarrage (Canvas vide sans message) | moyenne | ✅ état « Collecting samples… » + grille + aire |
| 6 | 5 valeurs codées en dur dans MCTheme, aucune adaptativité light/dark de marque | haute | ✅ MCColor adaptatif + tokens complets |
| 7 | Espacements arbitraires (8/10/12/14/16/20/24/28/48 mélangés) | moyenne | ◐ tokens créés; vues migrées: SmartCare, Performance, Onboarding |
| 8 | Cartes material invisibles en sombre (regularMaterial sur fond sombre) | moyenne | ✅ MCCard: overlay + trait séparateur + fallback Reduce Transparency |
| 9 | Onboarding: sheet dense unique, non reprenable | moyenne | ✅ 4 étapes, skippable, étape persistée |
| 10 | Bouton principal vert système sans lien avec l'identité | basse | ✅ tint Core Mint (accent système respecté pour prominent) |
| 11 | Version affichée 0.1.0 dans Settings (plist obsolète) | basse | ✅ 0.4.0 |
| 12 | Aucune animation d'état (apparition sèche) | moyenne | ◐ hero animé; modules secondaires à faire |
| 13 | Duplication texte review (héro + footer) | basse | ✅ supprimée |

## Bugs données découverts pendant l'audit (à traiter au prochain audit fonctionnel)
- **Scan Smart Care déclenche les prompts TCC Apple Music + Téléchargements**:
  les règles parcourent ~/Music (bibliothèque média). Exclure les bundles média
  des racines de scan, demander Téléchargements en contexte.
- **Incohérence totaux**: carte Cleanup affiche 72 154 items / 2.97 GB mais le
  héro « 182.7 MB found » — totalFoundBytes est calculé sur la liste findings
  plafonnée à 5000. Calculer les totaux sur le flux complet, pas la liste UI.

## Écrans restant à densifier (0.4.x)
Cleanup (regroupement animé), Protection (maille), Space Lens (zoom continu),
Applications (capsules), My Clutter (superposition), Cloud Cleanup, My Activity
(chronologie riche). Tous fonctionnels, aucun placeholder, mais identité de
module secondaire encore légère.

## Step D — audit final v0.5.0 (2026-07-20)
Toutes les identités visuelles ci-dessus sont maintenant code-complete (vérifié
par grep sur les vues, pas seulement déclaré) :
`MCMeshView` dans `ProtectionView.swift`, `MCFragmentView`/`MCFragmentSpec` dans
`CleanupView.swift`, `MCOverlapStack` dans `MyClutterView.swift`
(`DesignSystem/OverlapView.swift`), continuité `matchedGeometryEffect` dans
`SpaceLensView`/`ApplicationsView`, chronologie par jour dans `MyActivityView`,
état plein/contour dans `CloudCleanupView`.

**Captures**: toujours bloquées — aucun écran attaché dans ce sandbox depuis la
v0.3.0 (voir KNOWN_LIMITATIONS.md). Vérification effectuée à la place:
lecture du code source de chaque vue secondaire (utilise bien les tokens
`MC*`/composants du design system, pas de couleur/rayon en dur), lancement réel
du bundle Release packagé (`Scripts/package-local.sh`) sans crash, et un
second lancement sous `AppleLanguages (fr-FR)` — processus stable dans les
deux cas (`ps` + pas d'entrée fautive côté process). Ce n'est pas une preuve
visuelle du rendu; c'est une preuve que rien ne crashe et que le code utilisé
correspond à ce que ce document et CONTINUATION.md décrivent.

**Cohérence clair/sombre**: vérifiée au niveau code — toutes les vues
utilisent `MCColor` (adaptatif) plutôt que des couleurs système ou codées en
dur; aucune régression trouvée lors du grep de cette session.

**Reduce Motion / Reduce Transparency**: vérifiés au niveau code — chaque
composant animé (`MCMeshView`, `MCFragmentView`, `MCOverlapStack`,
`matchedGeometryEffect` sites) lit `@Environment(\.accessibilityReduceMotion)`
et route vers un état statique; `MCCard` bascule en surface opaque sous
Reduce Transparency. Pas de nouvelle régression introduite ce cycle (code
inchangé depuis Step B, seule la version et les tests ont changé).

**Bug totaux v0.4.1**: re-vérifié à neuf ce cycle (pas seulement relu dans les
notes) — nouveau test `independentConsumersSeeIdenticalTotals` dans
`Tests/ScanCoreTests/ScanEngineTests.swift` prouve que deux consommateurs
indépendants du même flux `ScanEngine.run(...)` (imitant Smart Care et
Cleanup) obtiennent des totaux identiques, parce que les deux lisent le
même événement `.finished(scanned:totalBytes:)` plutôt que de resommer la
liste plafonnée à l'affichage — 83/83 tests verts.

**Verdict**: rien de bloquant trouvé. Version portée à **0.5.0 "Visual
Completion"**. Le seul écart restant est la capture d'écran physique, déjà
documenté comme limitation d'environnement, pas comme défaut produit.
