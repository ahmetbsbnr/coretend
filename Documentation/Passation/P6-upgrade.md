# P6 — Upgrade (retour du test M5)

**Objectif :** appliquer `Documentation/Project/Upgrade-plan-2026-09-28.md` avant la release 2.0.
**Gate :** G6 — retest du mainteneur sur le M5 avec un nouveau build notarisé.
**Statut de la phase :** En cours depuis le 28-09-2026.

## Lots

| Lot | Intitulé | Statut |
|---|---|---|
| U1 | Espace (largeur adaptative, deux colonnes) | Livré (`eddb70d6`) |
| U2 | Menu de la barre des menus | En partie (`eddb70d6` : apparence, texte) |
| U3 | Vue d'ensemble « tableau de serre » | Livré (activité avec contexte, scène, quatre chemins `296da923`) |
| U4 | Applications (taille, tri, détail, échecs expliqués) | Livré (`cb338241`) |
| U5 | Accueil | Livré (`035207c2`) |
| U6 | Réglages en onglets | Livré (`b6254f74`) — feuille à onglets, pas de scène séparée (état partagé) |
| U7 | Modules enrichis | Livré en grande partie : Doublons/Nettoyage espace (`dfee09b8`), Performances mémoire, Explorer sous-dossiers (`fece24bd`), Intégrité pépinière (`3a7cf47a`) ; Historique : recherche existante suffit |
| U8 | Qualification et retest M5 | À faire |
| U9 | La serre vivante (thème complet, motions) | En cours — décision 0003 acceptée ; socle + scène Vue d'ensemble (`af7ba932`) |

## Journal

### 28-09-2026 — ouverture

- Test du mainteneur sur MacBook Air M5, macOS 27, build notarisé `0.1.0-local` : l'app
  s'installe et fonctionne (Vue d'ensemble, Nettoyage, Applications, Réglages, menu de barre
  des menus). Captures : `Documentation/Evidence/Captures/2026-09-28-M5/`. Preuve 4.2 (second
  Mac, même macOS) ; macOS 14 toujours non qualifié.

## Point d'arrêt

- Livrés : U1–U7 ; U9 très avancé. Dernier commit `296da923`.
- Suite : **U8** — build notarisé avec `CORETEND_BUNDLE_ID` définitif distinct des démos
  (proposé : `app.coretend.next`), version `2.0.0-beta.1`, signature Developer ID, archive
  manuelle, Xcode Organizer › Direct Distribution, export, `stapler validate`, `spctl`, ZIP +
  SHA-256 ; retest du mainteneur sur son Mac et le M5 (G6).
- U9 restant (optionnel) : transitions de page en tiges/vrilles.

## Problèmes ouverts

_(aucun)_
