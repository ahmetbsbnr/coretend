# Passation — CoreTend Next

Point d’entrée unique pour reprendre le travail. Mode d’emploi du système :
[`Documentation/Passation/README.md`](Documentation/Passation/README.md). Commandes, lancement
en fixture, invariants et particularités de l’hôte :
[`Documentation/Passation/Reference.md`](Documentation/Passation/Reference.md).

## Où on en est

- **Mis à jour :** 28-09-2026, arrêt demandé par le mainteneur au milieu du lot 3.9.
- **Phase :** P3 — Destinations → [`P3-destinations.md`](Documentation/Passation/P3-destinations.md)
- **Lot courant :** **3.9** (Réglages, palette ⌘K, barre des menus, langue, import ancien) **En
  cours, arrêté**. Dernier commit de code : `ab0cd928` (WIP : compile sans avertissement,
  **non qualifié, non vérifié à l’écran**).
- **Lots P3 :** 3.1, 3.4, 3.5, 3.6 acceptés ; 3.2, 3.3 livrés sans recette explicite ; 3.7, 3.8
  livrés et vérifiés par l’agent (décision du mainteneur du 28-09 : finir P3 sans recette par
  lot) ; 3.9 en cours ; 3.10 à faire.
- **Branche :** `next`, **49 commits d’avance** sur `origin/next`, non poussé. Push **autorisé
  par le mainteneur à la fin de 3.10** (« puis push next si nécessaire »).
- **Registre :** Must `VÉRIFIÉ` **3 / 78** (Should 0 / 11) ; tout le reste `PARTIEL` avec preuves
  datées. Aucune ligne ne passe `VÉRIFIÉ` sans observation du mainteneur.
- **Apparence :** Serre complète sur toutes les destinations sauf Réglages (en cours) et le site
  (3.10). Pièces partagées : `Sources/CoreTendApp/SerreActionKit.swift` (bandeaux, feuille vers
  la Corbeille, indicateur Corbeille, exécution élément par élément).

## Prochaine action

1. Protocole de démarrage (`Documentation/Passation/README.md` › Démarrer) ; vérifier
   `git status` propre sur `next`.
2. **Finir 3.9** (détail : `P3-destinations.md` › Point d’arrêt) :
   1. `make qualify` sur `ab0cd928` ; corriger ce qui échoue.
   2. Vérifier à l’écran, app en fixture avec `CORETEND_TEST_MENU_BAR_ENABLED=1` : feuille
      Réglages (clair/sombre, FR/EN), menu de la barre des menus (icône pousse, destinations).
   3. Palette ⌘K : la passer aux mêmes composants (déjà Serre depuis P2 ; vérifier seulement
      textes, accords, états vides).
   4. Registre : preuves datées pour settings.*, ui.commandpalette, shell.menubar, FR-21, FR-22,
      l10n.languagepicker, migration.* (statut `PARTIEL`).
   5. Commit de clôture, journal 3.9 dans `P3-destinations.md`.
3. **3.10 — Site** : pages publiques en Serre (`Scripts/build_site.py`, `Website/site.css`),
   captures réelles de l’app (`make capture-screens`), `make build-site site-check`.
4. `make qualify`, puis **`git push origin next`** (autorisé), puis vérifier le check CI `qualify`.
5. Ensuite gate **G3** : recette groupée de P3 par le mainteneur (voir « En attente »).

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
