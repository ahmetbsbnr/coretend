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
| Cleanup | ✅ | ✅ | — | — | à densifier (identité module) |
| Protection | ✅ | — | — | — | état ClamAV honnête, refonte maille à venir |
| Applications | ✅ | — | — | — | |
| My Clutter | ✅ | — | — | — | |
| Space Lens | ✅ | — | — | — | |
| Cloud Cleanup | ✅ | ✅ | — | — | |
| My Activity | ✅ | — | — | — | |
| Settings | ✅ | ✅ | — | — | version 0.4.0 affichée |
