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
| U5 | Accueil | Livré (`035207c2`) |
| U6 | Réglages en fenêtre dédiée | À faire |
| U7 | Modules enrichis | À faire |
| U8 | Qualification et retest M5 | À faire |
| U9 | La serre vivante (thème complet, motions) | En cours — décision 0003 acceptée ; socle + scène Vue d'ensemble (`af7ba932`) |

## Journal

### 28-09-2026 — ouverture

- Test du mainteneur sur MacBook Air M5, macOS 27, build notarisé `0.1.0-local` : l'app
  s'installe et fonctionne (Vue d'ensemble, Nettoyage, Applications, Réglages, menu de barre
  des menus). Captures : `Documentation/Evidence/Captures/2026-09-28-M5/`. Preuve 4.2 (second
  Mac, même macOS) ; macOS 14 toujours non qualifié.

## Point d'arrêt

- Livrés : U1, U5 ; U9 bien avancé (`LayerSway`/`PollenField` Core Animation, scène, plantes
  de page réactives aux analyses, fond vivant, frémissement au survol, parcelles qui respirent,
  menu vivant) — dernier commit `035207c2`.
- Reste U9 : transitions de page en tiges/vrilles ; souffle de pollen à l'arrivée d'une feuille
  dans la Corbeille ; vérifier à l'écran la courbure pendant une analyse et la fleur.
- Puis U4 (Applications), U2/U3 restants, U6 (Réglages en fenêtre), U7, U8 : build notarisé avec
  `CORETEND_BUNDLE_ID=<id distinct>` (ne plus partager l'identifiant des démos) et retest M5.

## Problèmes ouverts

_(aucun)_
