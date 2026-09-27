# P2 — Fondations d’interaction

**Objectif :** composants communs conformes au guide UI (survol, zone cliquable pleine, focus, pressé, désactivé), utilisés partout, et interdits ailleurs par un gate.
**Gate :** G2 — recette survol/clic/clavier sur chaque écran, clair et sombre.
**Statut de la phase :** À faire — ne commence qu’après la gate précédente.
**Plan :** `Documentation/Project/Implementation-plan.md` § Programme 2.0.

## Lots

| Lot | Intitulé | Statut |
|---|---|---|
| 2.1 | Composants communs dans `DesignSystem` | À faire |
| 2.2 | Application aux 8 destinations, Réglages, palette, onboarding ; gate `check_architecture.py` (pas de `.buttonStyle(.plain)` ni couleur littérale hors `DesignSystem`) | À faire |
| 2.3 | Clavier et pointeur : focus visible, `.help`, raccourcis, Échap | À faire |

## Journal

_(une entrée datée par lot : commits, vérifications PASS/FAIL/NON LANCÉ, résultat de recette)_

## Point d’arrêt

Point de départ connu : six `.buttonStyle(.plain)` (`CleanupView.swift:60`, `CoreTendApp.swift:129`, `ApplicationsView.swift:89`, `DuplicateScanView.swift:96,100`, `CommandPaletteView.swift:58`), aucun `onHover`. Ne commencer qu’avec un guide UI accepté (G1).

## Problèmes ouverts

_(aucun)_
