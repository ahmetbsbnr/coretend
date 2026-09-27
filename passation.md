# Passation — CoreTend Next

Point d’entrée unique pour reprendre le travail. Mode d’emploi du système :
[`Documentation/Passation/README.md`](Documentation/Passation/README.md). Commandes, lancement
en fixture, invariants et particularités de l’hôte :
[`Documentation/Passation/Reference.md`](Documentation/Passation/Reference.md).

## Où on en est

- **Mis à jour :** 27-09-2026, fin de session.
- **Phase :** P1 — Direction visuelle et guide UI → [`P1-direction-visuelle.md`](Documentation/Passation/P1-direction-visuelle.md)
- **Lot courant :** 1.1 (kit de captures) **livré, recette en attente** (`3098745`) ; 1.2 (séance G1) est la
  prochaine étape et demande le mainteneur.
- **Branche :** `next`, en avance sur `origin/next` (lot 1.1 non poussé ; push sur demande).
- **Registre :** Must `VÉRIFIÉ` **2 / 78** (Should 0 / 11). Source : `Documentation/Traceability.csv`.
- **Apparence :** refonte Observatoire appliquée, **non validée** (gate G1 en P1). Aucun
  changement d’apparence avant G1.

## Prochaine action

1. Protocole de démarrage (`Documentation/Passation/README.md` › Démarrer).
2. Séance **G1 (1.2)** avec le mainteneur : `P1-direction-visuelle.md` › Point d’arrêt et ordre du jour.

## En attente du mainteneur

- Recette 1.1 : ouvrir `Artifacts/Captures/2026-09-27/index.html`.
- Séance G1 (P1.2).
- Optionnel : publier 1.0.3 depuis `fix/1.x-trash-sqlite` (P5, piste 1.x).

## Phases

| Phase | Fichier | Statut |
|---|---|---|
| P0 Remise à plat | [`P0-remise-a-plat.md`](Documentation/Passation/P0-remise-a-plat.md) | Terminée (27-09) |
| P1 Direction visuelle (G1) | [`P1-direction-visuelle.md`](Documentation/Passation/P1-direction-visuelle.md) | En cours |
| P2 Fondations d’interaction (G2) | [`P2-fondations-interaction.md`](Documentation/Passation/P2-fondations-interaction.md) | À faire |
| P3 Destinations (G3.x) | [`P3-destinations.md`](Documentation/Passation/P3-destinations.md) | À faire |
| P4 Qualification (G4) | [`P4-qualification.md`](Documentation/Passation/P4-qualification.md) | À faire |
| P5 Release 2.0 (G5) | [`P5-release.md`](Documentation/Passation/P5-release.md) | À faire |

## Références

- Règles d’agent : `AGENTS.md`. Méthode : [`Pilotage.md`](Documentation/Project/Pilotage.md).
  Programme : [`Implementation-plan.md`](Documentation/Project/Implementation-plan.md).
- Produit : [`Cahier-des-charges.md`](Documentation/Project/Cahier-des-charges.md).
  Preuves : `Documentation/Progress.md`, `Documentation/Evidence/`.
- Passation précédente, archivée telle quelle : [`Documentation/Archive/passation-2026-09-27.md`](Documentation/Archive/passation-2026-09-27.md).
