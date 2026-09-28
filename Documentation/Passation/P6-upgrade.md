# P6 — Upgrade (retour du test M5)

**Objectif :** appliquer `Documentation/Project/Upgrade-plan-2026-09-28.md` avant la release 2.0.
**Gate :** G6 — retest du mainteneur sur le M5 avec un nouveau build notarisé.
**Statut de la phase :** Terminée — G6 acceptée le 28-09-2026.

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
| U8 | Qualification et retest M5 | Accepté 28-09-2026 (« tous les tests fonctionnent parfaitement ») |
| U9 | La serre vivante (thème complet, motions) | Livré (dernier : vrille de page `f9d645bd`, non vue à l'écran) |

## Journal

### 28-09-2026 — ouverture

- Test du mainteneur sur MacBook Air M5, macOS 27, build notarisé `0.1.0-local` : l'app
  s'installe et fonctionne (Vue d'ensemble, Nettoyage, Applications, Réglages, menu de barre
  des menus). Captures : `Documentation/Evidence/Captures/2026-09-28-M5/`. Preuve 4.2 (second
  Mac, même macOS) ; macOS 14 toujours non qualifié.

### 28-09-2026 — U8, build 2.0.0-beta.1 notarisé

- `CORETEND_BUNDLE_ID=app.coretend.next CORETEND_VERSION=2.0.0-beta.1 CORETEND_BUILD=2 make
  package-local` (commit `8dc36b35` + paramètres de version), signé Developer ID, archive
  manuelle, Organizer › Direct Distribution. Soumission `B38974BF-4AB4-4232-BBDD-1BF1CC837AF6`,
  acceptée en moins de 2 min. Export Organizer (Xcode resigne : agrafer sa propre copie échoue).
- Vérifié : `stapler validate` OK ; `spctl` : accepted, `Notarized Developer ID` ; `codesign
  --verify --strict` OK.
- Livrable : `~/Documents/CoreTend-2.0.0-beta.1/CoreTend-2.0.0-beta.1.zip`, SHA-256
  `f971e4d2e3241782996037aa12e12a18cf423c0fd42ceba485647e84ed3f2f00`. Identifiant distinct des
  démos : peut coexister avec l'ancien build de test.
- Trousseau : deux identités « Developer ID Application » identiques (Xcode en a créé une
  seconde) ; signer par empreinte SHA-1, jamais par nom.
- Ancien export 0.1.0 renommé `~/Documents/CoreTend-0.1.0-local.app` (rien supprimé).

## Point d'arrêt

- P6 terminée. Suite : `Documentation/Release/2.0-release-checklist.md` (décisions A, puis B–E).

## Problèmes ouverts

_(aucun)_
