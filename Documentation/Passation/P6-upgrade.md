# P6 — Upgrade (retour du test M5)

**Objectif :** appliquer `Documentation/Project/Upgrade-plan-2026-09-28.md` avant la release 2.0.
**Gate :** G6 — retest du mainteneur sur le M5 avec un nouveau build notarisé.
**Statut de la phase :** En cours depuis le 28-09-2026.

## Lots

| Lot | Intitulé | Statut |
|---|---|---|
| U1 | Espace (largeur adaptative, deux colonnes) | Livré (`eddb70d6`) |
| U2 | Menu de la barre des menus | En partie (`eddb70d6` : apparence, texte) |
| U3 | Vue d'ensemble « tableau de serre » | En partie (`eddb70d6` : activité avec contexte) |
| U4 | Applications (taille, tri, détail, échecs expliqués) | À faire |
| U5 | Accueil | À faire |
| U6 | Réglages en fenêtre dédiée | À faire |
| U7 | Modules enrichis | À faire |
| U8 | Qualification et retest M5 | À faire |
| U9 | La serre vivante (thème complet, motions) | À faire — amendement de la règle « aucune animation au repos » à valider |

## Journal

### 28-09-2026 — ouverture

- Test du mainteneur sur MacBook Air M5, macOS 27, build notarisé `0.1.0-local` : l'app
  s'installe et fonctionne (Vue d'ensemble, Nettoyage, Applications, Réglages, menu de barre
  des menus). Captures : `Documentation/Evidence/Captures/2026-09-28-M5/`. Preuve 4.2 (second
  Mac, même macOS) ; macOS 14 toujours non qualifié.

## Point d'arrêt

- `eddb70d6` : U1 livré ; U2/U3 en partie. Suite : **U4 Applications** (taille, tri, panneau de détail, échec Corbeille expliqué, « Fichiers autour » par nom), puis U2/U3 restants, U5, U6, U7, U8.
- Capture d'écran d'une app en fixture quand le Terminal est en plein écran : `swiftc Scripts/capture_window_helper.swift`, puis `screencapture -l <fenêtre>`.

## Problèmes ouverts

_(aucun)_
