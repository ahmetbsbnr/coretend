# P2 — Fondations Serre

**Objectif :** l’app et le site en direction Serre : jetons, logo, icônes, composants avec tous leurs états, coquille de l’app et motion du guide.
**Gate :** G2 — recette survol/clic/clavier sur chaque écran, clair et sombre.
**Statut de la phase :** À faire — ne commence qu’après la gate précédente.
**Plan :** `Documentation/Project/Implementation-plan.md` § Programme 2.0.

## Lots

| Lot | Intitulé | Statut |
|---|---|---|
| 2.1 | Jetons Serre (couleurs Nuit/Jour, typographie, motion, formes) + tests | À faire |
| 2.2 | Logo Serre et germination ; jeu d’icônes ; feuilles de risque | À faire |
| 2.3 | Composants et états (guide § 7) + gate `check_architecture.py` | À faire |
| 2.4 | Coquille de l’app : barre latérale, transition « pousse », recherche ⌘K, clavier/focus | À faire |
| 2.5 | Site en Serre : jetons exportés, logo, navigation, racine au défilement (CSS seul) | À faire |

## Journal

_(une entrée datée par lot : commits, vérifications PASS/FAIL/NON LANCÉ, résultat de recette)_

## Point d’arrêt

Point de départ connu : six `.buttonStyle(.plain)` (`CleanupView.swift:60`, `CoreTendApp.swift:129`, `ApplicationsView.swift:89`, `DuplicateScanView.swift:96,100`, `CommandPaletteView.swift:58`), aucun `onHover`. Référence : `Documentation/Design/UI-guide.md`. Ne commencer qu’avec ce guide accepté (G1).

## Problèmes ouverts

_(aucun)_
