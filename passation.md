# Passation — CoreTend Next

Point d’entrée unique pour reprendre le travail. Mode d’emploi du système :
[`Documentation/Passation/README.md`](Documentation/Passation/README.md). Commandes, lancement
en fixture, invariants et particularités de l’hôte :
[`Documentation/Passation/Reference.md`](Documentation/Passation/Reference.md).

## Où on en est

- **Mis à jour :** 28-09-2026, fin des lots 3.9 et 3.10 ; qualification finale PASS.
- **Phase :** P3 — Destinations → [`P3-destinations.md`](Documentation/Passation/P3-destinations.md)
- **Lot courant :** **3.10 livré, recette groupée P3 en attente avant G3**.
- **Lots P3 :** 3.1, 3.4, 3.5, 3.6 acceptés ; 3.2 et 3.3 livrés sans recette explicite ;
  3.7 à 3.10 livrés avec preuves agent et limites documentées, sans acceptation du mainteneur.
- **Commits :** 3.9 `4e573a1d`, formats menu et observations supplémentaires `53dfac36` ;
  site prêt au commit. Push `next` autorisé, résultat CI à consigner après push.
- **Registre :** Must `VÉRIFIÉ` **3 / 78** (Should 0 / 11), aucun statut promu durant cette session.
- **Apparence :** destinations, Réglages et site en Serre. Pièces partagées :
  `Sources/CoreTendApp/SerreActionKit.swift` et `DesignSystem`.
- **Limite de 3.9 :** Réglages haut/milieu/bas et palette FR/EN clair/sombre relus, FR → EN → FR
  observé ; panneau MenuBarExtra non obtenu par automatisation, icône pousse visible.
- **Preuves :** `Documentation/Evidence/P3-39-2026-09-28.md` et `P3-310-2026-09-28.md`.

## Prochaine action

1. Commit site, `git push origin next` (autorisé), vérifier le check CI `qualify` et consigner le résultat.
2. **Arrêt avant G3** : demander la recette groupée P3, avec recettes explicites de 3.2
   (vrai déplacement vers la Corbeille sur dossier jetable, réalisé par le mainteneur) et 3.3.
3. Ne pas commencer P4 avant acceptation de G3. Les lignes du registre restent inchangées
   jusqu’aux observations du mainteneur.

## En attente du mainteneur

- Recette groupée de P3 avant G3, dont les recettes explicites de **3.2 (Nettoyage, avec un vrai
  passage par la Corbeille sur un dossier jetable)** et **3.3 (Explorer)**, et un regard sur 3.7,
  3.8, 3.9, 3.10.
- 2 faux fichiers de test (`Safari-2026-09-23-101500.ips`, `…-24-…`, octets aléatoires) sont dans
  sa Corbeille depuis l’incident du 28-09 ; à jeter par lui.
- Optionnel : publier 1.0.3 depuis `fix/1.x-trash-sqlite` (P5, piste 1.x).

## Phases

| Phase | Fichier | Statut |
|---|---|---|
| P0 Remise à plat | [`P0-remise-a-plat.md`](Documentation/Passation/P0-remise-a-plat.md) | Terminée (27-09) |
| P1 Direction visuelle (G1) | [`P1-direction-visuelle.md`](Documentation/Passation/P1-direction-visuelle.md) | Terminée (27-09) |
| P2 Fondations Serre (G2) | [`P2-fondations-interaction.md`](Documentation/Passation/P2-fondations-interaction.md) | Terminée (27-09) |
| P3 Destinations (G3.x) | [`P3-destinations.md`](Documentation/Passation/P3-destinations.md) | En cours |
| P4 Qualification (G4) | [`P4-qualification.md`](Documentation/Passation/P4-qualification.md) | À faire |
| P5 Release 2.0 (G5) | [`P5-release.md`](Documentation/Passation/P5-release.md) | À faire |

## Références

- Règles d’agent : `AGENTS.md`. Méthode : [`Pilotage.md`](Documentation/Project/Pilotage.md).
  Programme : [`Implementation-plan.md`](Documentation/Project/Implementation-plan.md).
- Produit : [`Cahier-des-charges.md`](Documentation/Project/Cahier-des-charges.md).
  Preuves : `Documentation/Progress.md`, `Documentation/Evidence/`.
- Passation précédente, archivée telle quelle : [`Documentation/Archive/passation-2026-09-27.md`](Documentation/Archive/passation-2026-09-27.md).
