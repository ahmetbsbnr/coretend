# Passation — CoreTend Next

Point d’entrée unique pour reprendre le travail. Mode d’emploi du système :
[`Documentation/Passation/README.md`](Documentation/Passation/README.md). Commandes, lancement
en fixture, invariants et particularités de l’hôte :
[`Documentation/Passation/Reference.md`](Documentation/Passation/Reference.md).

## Où on en est

- **Mis à jour :** 28-09-2026, 4.3 accepté ; poursuite de toute P4 autorisée.
- **Phase :** P4 — Qualification → [`P4-qualification.md`](Documentation/Passation/P4-qualification.md).
- **Lot courant :** **4.5 en cours — qualification site**.
- **G3 :** passée ; aucune observation détaillée supplémentaire reçue, aucun statut du registre promu.
- **Livraison P3 :** `fa9132ed` poussé, CI `qualify` PASS le 28-09 à 09:49:42 UTC.
- **Registre :** Must `VÉRIFIÉ` **3 / 78** (Should 0 / 11), NFR-07 PARTIEL.
- **4.3 :** uniform/mixed 0,873/1,069 s ; fenêtre app médiane 0,469 s.
  `PerformanceBaseline.md` et trois JSON datés ; `make qualify` PASS. NFR-09 PARTIEL.
- **Qualification 4.2 :** `make qualify`, `make traceability`, paquet et runtime isolé PASS.
- **Qualification précédente 4.1 :** `make qualify` PASS (code 0), `git diff --check` PASS.
- **4.1 accepté :** revue statique et protocole dans `Documentation/Evidence/Accessibility.md`.
  Aucun réglage d’accessibilité de l’hôte modifié ; aucune mutation du vrai HOME/store/Trash.

## Prochaine action

1. Revue 4.4 et correctifs livrés, qualification PASS ; finir les contrôles site 4.5.
2. Enchaîner 4.5 site puis 4.6 import, autorisation explicite du mainteneur.
3. Conclure P4 avec preuves et réserves ; aucun push ni P5 autorisé.

## En attente du mainteneur

- Chemin d’une copie déjà créée du store/préférences 1.x pour 4.6 ; ne pas lire l’original.
- Hôtes manquants 4.2 et observations d’assistance réelle restent des limites de preuve.
- 2 faux fichiers de test (`Safari-2026-09-23-101500.ips`, `…-24-…`, octets aléatoires) sont dans
  sa Corbeille depuis l’incident du 28-09 ; à jeter par lui.
- Optionnel : publier 1.0.3 depuis `fix/1.x-trash-sqlite` (P5, piste 1.x).

## Phases

| Phase | Fichier | Statut |
|---|---|---|
| P0 Remise à plat | [`P0-remise-a-plat.md`](Documentation/Passation/P0-remise-a-plat.md) | Terminée (27-09) |
| P1 Direction visuelle (G1) | [`P1-direction-visuelle.md`](Documentation/Passation/P1-direction-visuelle.md) | Terminée (27-09) |
| P2 Fondations Serre (G2) | [`P2-fondations-interaction.md`](Documentation/Passation/P2-fondations-interaction.md) | Terminée (27-09) |
| P3 Destinations (G3.x) | [`P3-destinations.md`](Documentation/Passation/P3-destinations.md) | Terminée — G3 acceptée (28-09) |
| P4 Qualification (G4) | [`P4-qualification.md`](Documentation/Passation/P4-qualification.md) | En cours — 4.5 |
| P5 Release 2.0 (G5) | [`P5-release.md`](Documentation/Passation/P5-release.md) | À faire |

## Références

- Règles d’agent : `AGENTS.md`. Méthode : [`Pilotage.md`](Documentation/Project/Pilotage.md).
  Programme : [`Implementation-plan.md`](Documentation/Project/Implementation-plan.md).
- Produit : [`Cahier-des-charges.md`](Documentation/Project/Cahier-des-charges.md).
  Preuves : `Documentation/Progress.md`, `Documentation/Evidence/`.
- Passation précédente, archivée telle quelle : [`Documentation/Archive/passation-2026-09-27.md`](Documentation/Archive/passation-2026-09-27.md).
