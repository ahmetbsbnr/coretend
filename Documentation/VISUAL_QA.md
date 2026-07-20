# VISUAL QA — checklist par écran

Procédure par tranche: build Release → package → lancer le bundle →
`Scripts/capture.sh <out.png> "<Module>"` en clair + sombre → comparer avec la
capture précédente (VisualAudit/After) → corriger → commit.

Forcer clair: `defaults write local.maccare.app NSRequiresAquaSystemAppearance -bool yes`
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

## État au 2026-07-20 (v0.4.0)
| Écran | Sombre | Clair | Redim. | RM/RT | Notes |
|---|---|---|---|---|---|
| Smart Care | ✅ | ✅ | ✅ | ✅ code (RM via env) | hero validé idle/scanning/review dans le bundle |
| Performance | ✅ | ✅ | ✅ | ✅ | anneaux OK, graphe grille+aire |
| Onboarding ×4 | ✅ | — | fixe 560×460 | ✅ | étapes capturées |
| Cleanup | ⏳ non re-capturé | ⏳ non re-capturé | — | ✅ code (RM/RT branchés dans MCFragmentView) | Motif fragments agrégés implémenté (`MCFragmentSpec`/`MCFragmentView`), câblé dans `CleanupView`; build release 0 warning + tests verts. Capture bloquée: session sans écran attaché (`screencapture` échoue, aucun accès Accessibility TCC) — à recapturer sur une machine avec affichage. |
| Protection | ✅ | — | — | — | état ClamAV honnête, refonte maille à venir |
| Applications | ⏳ code done, capture pending — no display in this environment | ⏳ code done, capture pending — no display in this environment | — | ✅ code (MCMotion.snappy on grouping change) | Motif capsules: liste native `List` toujours vue primaire, groupement (aucun/éditeur/taille/état de mise à jour/dernière utilisation) via `Picker` segmenté + `Section`s, `matchedGeometryEffect` par ligne pour préserver la position lors des transitions de groupement. Données réelles uniquement: `AppUpdateSource.detect` (Sparkle/App Store/manuel, partagé avec l'onglet Updates), `lastUsedDate` (Spotlight `kMDItemLastUsedDate`, `nil` honnête si non indexé), `isQuarantined` (xattr réel). Leftovers: items `group.*` ou préfixe éditeur partagé par >1 entrée marqués "Shared / review" (badge + couleur, jamais couleur seule). Build release 0 warning, 4 nouveaux tests de groupement + 2 tests d'ambiguïté verts, bundle lancé sans crash. |
| My Clutter | ⏳ code done, capture pending — no display in this environment | ⏳ code done, capture pending — no display in this environment | — | ✅ code (`MCOverlapStack` hover-driven, Reduce Motion aware) | Motif superposition partagé (`MCOverlapStack`, DesignSystem/OverlapView.swift): éléments légèrement chevauchés, séparation au survol réel (jamais un timer). Duplicates: superposition d'icônes au-dessus des lignes accessibles existantes, "Suggested keeper" reste badge+texte; liens durs déjà exclus des doublons par `DuplicateEngine` (jamais comptés dans `wastedBytes`) — texte explicite ajouté, test `hardLinksNotTreatedAsDuplicates` déjà vert le confirme. Similar Images: superposition de vraies vignettes `AsyncThumbnail`/QuickLook existantes (aucun second pipeline), "Best resolution" marqué via dimensions pixel réelles lues par `ImageIO` (`SimilarImageGroup.bestResolutionURL`, jamais une estimation), aucune suppression automatique. Large & Old: tri natif taille/âge (`Picker` segmenté), Quick Look via `.quickLookPreview`, nombres de taille en `title3` pour rester lisibles. Build release 0 warning, 2 nouveaux tests `SimilarImageGroup` verts, bundle lancé sans crash. |
| Space Lens | ⏳ non re-capturé | ⏳ non re-capturé | — | ✅ code (matchedGeometryEffect + a11y list) | Continuité de zoom `matchedGeometryEffect`, breadcrumb, hover/sélection/focus clavier, liste accessible alternative câblés dans `SpaceLensView`/`SpaceLensEngine`. Même blocage de capture que Cleanup ci-dessus. |
| Cloud Cleanup | ✅ | ✅ | — | — | |
| My Activity | ✅ | — | — | — | |
| Settings | ✅ | ✅ | — | — | version 0.4.0 affichée |
