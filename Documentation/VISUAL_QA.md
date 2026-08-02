# VISUAL QA — checklist par écran

Procédure par tranche: build Release → package → lancer le bundle →
`Scripts/capture.sh <out.png> "<Module>"` en clair + sombre → comparer avec la
capture précédente (VisualAudit/After) → corriger → commit.

Forcer clair: `defaults write com.ahmetbsbnr.coretend NSRequiresAquaSystemAppearance -bool yes`
(supprimer la clé ensuite).

## Checklist commune (chaque écran)
- [ ] Hiérarchie: un seul point focal; titres MCFont; pas de texte orphelin.
- [ ] Tokens: aucun spacing/couleur/rayon hors MC*.
- [ ] Clair + sombre cohérents (contraste texte secondaire ≥ 4.5:1 approx).
- [ ] Redimensionnement 860×580 → plein écran sans casse ni troncature.
- [ ] Reduce Motion: aucun mouvement continu.
- [ ] Reduce Transparency: surfaces opaques.
- [ ] VoiceOver: labels sur contrôles iconiques, valeurs de graphiques annoncées.
- [ ] Clavier: focus visible, ordre logique, Échap ferme feuilles.
- [ ] États: vide / chargement / erreur / indisponible réels et honnêtes.

## Limitation d'environnement (standing, depuis v0.3.0)
`Scripts/capture.sh` échoue dans ce sandbox à chaque session testée
(v0.3.0 → v0.5.0 inclus): aucun écran attaché, `System Events` renvoie
l'erreur -1719 (impossible de contrôler un process sans affichage/accord
Accessibility TCC actif). Toutes les lignes « capture pending » ci-dessous
reflètent ce fait d'environnement, pas un défaut produit — le code de
chaque écran est vérifié (composants design-system utilisés, tokens
adaptatifs, Reduce Motion/Transparency câblés) même sans capture visuelle.
Voir KNOWN_LIMITATIONS.md et DECISIONS.md D6. À refaire sur une machine
avec un vrai écran.

## Mise à jour — phase 0.8.0 Functional Completion (2026-07-24)
Le fait "aucun écran attaché" ci-dessus ne tient plus dans cette session:
`screencapture -x` et l'automation `System Events` fonctionnent tous les
deux sans prompt TCC. Reconstruit l'app (`Scripts/package-local.sh`),
lancée, une capture réelle fenêtre-seule prise (`Scripts/capture.sh` sans
argument de module → écran Smart Care idle) confirme un rendu correct et
conforme à `FEATURE_MATRIX.md`. Le chemin avec argument de module (navigue
la sidebar via AppleScript avant de capturer) a échoué au second appel
(`-1719`, index de fenêtre invalide malgré `count windows` = 1) — non
diagnostiqué plus avant cette tranche (campagne complète FR/EN × clair/
sombre × tous modules = tranche séparée, plus large que cette
synchronisation documentaire). Toute la table "État au 2026-07-20" ci-
dessous reste donc `⏳ capture pending`, mais ce n'est plus un blocage
d'environnement — c'est du travail de capture restant. Voir
`KNOWN_LIMITATIONS.md` pour le détail. Statut Step 15 (plan 0.8.0):
`READY_FOR_MANUAL_QA`, pas `FULLY_VISUALLY_VERIFIED`.

## État au 2026-07-20 (v0.4.0)
| Écran | Sombre | Clair | Redim. | RM/RT | Notes |
|---|---|---|---|---|---|
| Smart Care | ✅ | ✅ | ✅ | ✅ code (RM via env) | hero validé idle/scanning/review dans le bundle |
| Performance | ✅ (layout unchanged) | ✅ (layout unchanged) | ✅ | ✅ | anneaux OK, graphe grille+aire. Harmonisation audit (2026-07-20): tokens/typo déjà cohérents avec Cleanup/Protection; données 100% réelles (SystemMetrics, aucune courbe décorative); cadence 2s raisonnable; états indisponibles honnêtes (aucun placeholder faux). Gap trouvé et corrigé: aucune pause idle-fenêtre — ajouté `@Environment(\.scenePhase)` gating `start()`/`stop()` pour que le sampling s'arrête quand la fenêtre est masquée/arrière-plan. VoiceOver déjà correct sur `MCMetricCard` (valeur+tendance en texte) et le graphe CPU (`accessibilityLabel`). Pas de hero Core Bloom sur cet écran (n/a). |
| Menu bar | ⏳ capture native exhaustive pending | ⏳ capture native exhaustive pending | — | ✅ code (no continuous animation; symbol template) | Icône monochrome template (`MenuBarTemplate.png`, `isTemplate=true`, 18px) + fallback SF Symbol. Badge d'attention piloté par `MenuBarIconModel`; le panneau réutilise `MetricsCollector`, échantillonne uniquement lorsqu'il est ouvert et expose le dernier résultat Smart Care sans scanner externe. |
| Onboarding ×4 | ✅ | — | fixe 560×460 | ✅ | étapes capturées |
| Cleanup | ⏳ non re-capturé | ⏳ non re-capturé | — | ✅ code (RM/RT branchés dans MCFragmentView) | Motif fragments agrégés implémenté (`MCFragmentSpec`/`MCFragmentView`), câblé dans `CleanupView`; build release 0 warning + tests verts. Capture bloquée: session sans écran attaché (`screencapture` échoue, aucun accès Accessibility TCC) — à recapturer sur une machine avec affichage. |
| Integrity | ✅ ciblé | — | — | — | provenance, signature et login items natifs; lecture seule, aucune promesse antivirus |
| Applications | ⏳ code done, capture pending — no display in this environment | ⏳ code done, capture pending — no display in this environment | — | ✅ code (MCMotion.snappy on grouping change) | Motif capsules: liste native `List` toujours vue primaire, groupement (aucun/éditeur/taille/état de mise à jour/dernière utilisation) via `Picker` segmenté + `Section`s, `matchedGeometryEffect` par ligne pour préserver la position lors des transitions de groupement. Données réelles uniquement: `AppUpdateSource.detect` (Sparkle/App Store/manuel, partagé avec l'onglet Updates), `lastUsedDate` (Spotlight `kMDItemLastUsedDate`, `nil` honnête si non indexé), `isQuarantined` (xattr réel). Leftovers: items `group.*` ou préfixe éditeur partagé par >1 entrée marqués "Shared / review" (badge + couleur, jamais couleur seule). Build release 0 warning, 4 nouveaux tests de groupement + 2 tests d'ambiguïté verts, bundle lancé sans crash. |
| My Clutter | ⏳ code done, capture pending — no display in this environment | ⏳ code done, capture pending — no display in this environment | — | ✅ code (`MCOverlapStack` hover-driven, Reduce Motion aware) | Motif superposition partagé (`MCOverlapStack`, DesignSystem/OverlapView.swift): éléments légèrement chevauchés, séparation au survol réel (jamais un timer). Duplicates: superposition d'icônes au-dessus des lignes accessibles existantes, "Suggested keeper" reste badge+texte; liens durs déjà exclus des doublons par `DuplicateEngine` (jamais comptés dans `wastedBytes`) — texte explicite ajouté, test `hardLinksNotTreatedAsDuplicates` déjà vert le confirme. Similar Images: superposition de vraies vignettes `AsyncThumbnail`/QuickLook existantes (aucun second pipeline), "Best resolution" marqué via dimensions pixel réelles lues par `ImageIO` (`SimilarImageGroup.bestResolutionURL`, jamais une estimation), aucune suppression automatique. Large & Old: tri natif taille/âge (`Picker` segmenté), Quick Look via `.quickLookPreview`, nombres de taille en `title3` pour rester lisibles. Build release 0 warning, 2 nouveaux tests `SimilarImageGroup` verts, bundle lancé sans crash. |
| Space Lens | ⏳ non re-capturé | ⏳ non re-capturé | — | ✅ code (matchedGeometryEffect + a11y list) | Continuité de zoom `matchedGeometryEffect`, breadcrumb, hover/sélection/focus clavier, liste accessible alternative câblés dans `SpaceLensView`/`SpaceLensEngine`. Même blocage de capture que Cleanup ci-dessus. |
| Cloud Cleanup | ⏳ code done, capture pending — no display in this environment | ⏳ code done, capture pending — no display in this environment | — | ✅ code (native VStack/List, no timers/continuous motion) | Motif plein/contour: `SyncState` (local/partial/placeholder) dérivé du vrai signal `ubiquitousItemDownloadingStatusKey` (fallback ratio d'octets seulement quand ce signal est absent), rendu par SF Symbol rempli (local) vs contour (online-only), jamais couleur seule — badge texte "partially local"/"online only" en renfort. Pas de badge "pinned": aucune API publique ne rapporte l'état "Keep Downloaded" de Finder pour un fichier iCloud Drive arbitraire, donc le module ne l'invente pas. Total "recoverable" renommé honnêtement (`recoverableLocalBytes`) et le libellé rappelle explicitement qu'aucun téléchargement ni suppression n'est déclenché — `measure()` reste lecture seule (`resourceValues`/`contentsOfDirectory`, jamais `startDownloadingUbiquitousItem`). Liste native accessible conservée comme vue primaire; build release 0 warning, 4 nouveaux tests `CloudSyncStateTests` verts. |
| My Activity | ✅ light/dark artifact capture verified | ✅ light/dark artifact capture verified | EN/FR strings exercised in the release harness | ✅ code (native List/DisclosureGroup, no timers) | Regroupement par jour réel (`ActivityGrouping.byDay`, pur/testé), filtres par nature et plage de dates, résumé des octets réellement déplacés, détail extensible et exports CSV/JSON. Les anciens enregistrements de prévisualisation restent uniquement dans les bases héritées pour compatibilité descendante et ne sont pas exposés par l’API actuelle. |
| Settings | ⏳ capture native exhaustive pending | ⏳ capture native exhaustive pending | — | — | Sections natives, états de permission réels, notifications jamais simulées, helper privilégié honnêtement indisponible et version lue depuis le bundle. Aucun réglage de mode aperçu n'est exposé. |

---

## Mise à jour — 0.9.0 public beta (2026-07-27)

Passe d'accessibilité et de QA visuelle avant la première version publique.
Chaque ligne indique la preuve. **L'accessibilité n'est pas déclarée validée
parce que le build passe.**

### Vérifié automatiquement (dans les 296 tests)

| Point | Preuve | Résultat |
|---|---|---|
| Contraste, surfaces sombres | `PaletteContrastTests.canonicalAccentsAreReadableOnCoreInk` — luminance relative WCAG 2.1, seuil 4.5:1 | **PASS** pour freshMint, orbitIris, warmAmber, signalCoral |
| Contraste, surfaces claires | `lightSiblingsAreReadableOnSoftPorcelain` — même calcul | **PASS** pour mossDeep, irisDeep, amberDeep, coralDeep, slateDeep |
| Piège documenté | Un test échoue volontairement si un accent canonique repassait le seuil en mode clair — c'est l'hypothèse sur laquelle repose toute la séparation clair/sombre | **PASS** |
| Accessibilité du site | `Scripts/check-website.sh` : `lang`, `title`, un seul `h1`, lien d'évitement, `alt`/label, `viewport` | **PASS** |
| Parité des locales | `check-website.sh` | **PASS** — EN/FR, 13 pages chacune |

### Vérifié par revue de code

| Point | Constat |
|---|---|
| Labels accessibles | 39 `accessibilityLabel`, 19 `accessibilityElement`, 6 `accessibilityDescription` dans `Sources/`. Les contrôles iconiques (Reveal in Finder, bascules, lignes de la barre de menus) sont libellés. |
| Éléments décoratifs | 31 `accessibilityHidden`. Les vues d'animation (Fragment, Mesh, Overlap, CoreBloom, HeroCore) sont masquées à VoiceOver ; l'état réel est lu depuis le texte localisé adjacent. |
| Hero Smart Care | `MCHeroCoreView` porte un label anglais en dur, **mais il n'est jamais annoncé** : l'unique site d'appel (`SmartCareView`) applique `.accessibilityHidden(true)`, et l'état est lu depuis `heroTitle`/`heroSubtitle`, qui sont localisés. Vérifié en lisant le site d'appel, pas en supposant. Risque latent uniquement : un futur appelant qui ne masquerait pas la vue entendrait de l'anglais. |
| Reduce Motion | Câblé via `MCMotion.animation(_:reduce:)` et `@Environment(\.accessibilityReduceMotion)` dans 9 fichiers. Aucun `.repeatForever`, `scheduledTimer` ni `Timer.publish` dans `Sources/`. |
| Sans couleur seule | Les avertissements de la barre de menus combinent un glyphe et un label « needs attention » ; les badges d'état sont symbole + texte. |
| États vides / erreur | `MCEmptyState` / `MCErrorState` existent dans `Sources/DesignSystem/Components.swift` et masquent leurs icônes décoratives. |
| Placeholders visibles | `Scripts/check-placeholders.sh` : **0**. |

### NON vérifiable dans cet environnement — ne pas présenter comme validé

L'environnement est en ligne de commande seule (Command Line Tools, sans Xcode,
sans session graphique). Les points suivants restent **BLOCKED_ENVIRONMENT** :

- **VoiceOver interactif** : ordre d'annonce réel, rotor, navigation par en-têtes.
- **Navigation clavier réelle** : ordre de tabulation, visibilité du focus, Échap
  qui ferme les feuilles. Le code ne contient que 1 `focusable` et 5
  `keyboardShortcut`, et **aucun** `FocusState` — l'ordre de focus repose donc
  entièrement sur l'ordre par défaut de SwiftUI, qui n'a pas été observé.
- **Dynamic Type** : rendu aux tailles de texte élevées, troncatures.
- **Rendu clair/sombre réel** et redimensionnement 860×580 → plein écran.
- **Reduce Transparency** appliqué par le système.
- **Campagne de captures** : le jeu « After » reste incomplet.

Ces limites sont également listées dans les notes de version 0.9.0 et dans
`Release/latest.template.json` sous `knownLimitations`, afin qu'aucun lecteur
ne déduise d'un build vert que l'accessibilité a été validée à l'usage.

### Constat ouvert

Aucun `FocusState` dans le projet. Pour une application de bureau, un ordre de
focus explicite sur les écrans à formulaires vaudrait mieux que l'ordre implicite.
Non corrigé pour 0.9.0 : sans session graphique, une modification de l'ordre de
focus ne pourrait pas être vérifiée, et la modifier à l'aveugle risquerait de
dégrader ce qui fonctionne peut-être déjà.
