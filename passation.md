# Passation — CoreTend Next

Point d’entrée unique pour reprendre le travail. Mode d’emploi du système :
[`Documentation/Passation/README.md`](Documentation/Passation/README.md). Commandes, lancement
en fixture, invariants et particularités de l’hôte :
[`Documentation/Passation/Reference.md`](Documentation/Passation/Reference.md).

## Où on en est

- **Mis à jour :** 28-09-2026, recette groupée P3 acceptée (« validé, continue »).
- **Phase :** P4 — Qualification → [`P4-qualification.md`](Documentation/Passation/P4-qualification.md).
- **Lot courant :** **4.1 en cours, recette humaine d’accessibilité préparée**.
- **G3 :** passée ; aucune observation détaillée supplémentaire reçue, aucun statut du registre promu.
- **Livraison P3 :** `fa9132ed` poussé, CI `qualify` PASS le 28-09 à 09:49:42 UTC.
- **Registre :** Must `VÉRIFIÉ` **3 / 78** (Should 0 / 11), NFR-07 PARTIEL.
- **Qualification 4.1 :** `make qualify` PASS (code 0), `git diff --check` PASS.
- **4.1 :** revue statique et protocole dans `Documentation/Evidence/Accessibility.md`.
  Aucun réglage d’accessibilité de l’hôte modifié ; aucune mutation du vrai HOME/store/Trash.

## Prochaine action

1. Recevoir les observations du mainteneur sur la matrice 4.1 dans la preuve accessibilité.
2. Reproduire et corriger en fixture les défauts éventuels, puis qualifier et faire accepter 4.1.
3. Après acceptation, 4.2 : préparer macOS 14 et un second Mac ; pas de gate G4 à ce stade.

## En attente du mainteneur

- Recette 4.1 : VoiceOver parlé, focus clavier, texte agrandi/zoom, contraste des états,
  Reduce Motion et Reduce Transparency, FR/EN clair/sombre. Protocole et critères dans
  `Documentation/Evidence/Accessibility.md`. Ne jamais confirmer un déplacement dans l’app packagée.
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
| P4 Qualification (G4) | [`P4-qualification.md`](Documentation/Passation/P4-qualification.md) | En cours — 4.1 |
| P5 Release 2.0 (G5) | [`P5-release.md`](Documentation/Passation/P5-release.md) | À faire |

## Références

- Règles d’agent : `AGENTS.md`. Méthode : [`Pilotage.md`](Documentation/Project/Pilotage.md).
  Programme : [`Implementation-plan.md`](Documentation/Project/Implementation-plan.md).
- Produit : [`Cahier-des-charges.md`](Documentation/Project/Cahier-des-charges.md).
  Preuves : `Documentation/Progress.md`, `Documentation/Evidence/`.
- Passation précédente, archivée telle quelle : [`Documentation/Archive/passation-2026-09-27.md`](Documentation/Archive/passation-2026-09-27.md).
