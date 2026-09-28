# Passation — CoreTend Next

Point d’entrée unique pour reprendre le travail. Mode d’emploi du système :
[`Documentation/Passation/README.md`](Documentation/Passation/README.md). Commandes, lancement
en fixture, invariants et particularités de l’hôte :
[`Documentation/Passation/Reference.md`](Documentation/Passation/Reference.md).

## Où on en est

- **Mis à jour :** 28-09-2026, P4 — travaux disponibles 4.1–4.6 consignés ; G4 reste ouverte.
- **Phase :** P7 — Sortie publique 2.0 → [`P7-release-2.0.md`](Documentation/Passation/P7-release-2.0.md).
- **Lot courant :** P7 terminée — 2.0.0 publiée le 28-09-2026 (release GitHub, site, tap Homebrew `ahmetbsbnr/coretend`).
- **G3 :** passée ; aucune observation détaillée supplémentaire reçue, aucun statut du registre promu.
- **Livraison P3 :** `fa9132ed` poussé, CI `qualify` PASS le 28-09 à 09:49:42 UTC.
- **Registre :** Must `VÉRIFIÉ` **3 / 78** (Should 0 / 11), NFR-07 PARTIEL.
- **4.3 :** uniform/mixed 0,873/1,069 s ; fenêtre app médiane 0,469 s.
  `PerformanceBaseline.md` et trois JSON datés ; `make qualify` PASS. NFR-09 PARTIEL.
- **Qualification finale 4.6 :** `make qualify` PASS code 0 ; tests/captures isolés et
  revue indépendante ; commit `ac27e45b` (`feat(migration): import exclusions from standalone
  legacy SQLite copies`) ; `Documentation/Evidence/P4-46-import-2026-09-28.md`.
- **Qualification 4.2 :** `make qualify`, `make traceability`, paquet et runtime isolé PASS.
- **Qualification précédente 4.1 :** `make qualify` PASS (code 0), `git diff --check` PASS.
- **4.1 accepté :** revue statique et protocole dans `Documentation/Evidence/Accessibility.md`.
  Aucun réglage d’accessibilité de l’hôte modifié ; aucune mutation du vrai HOME/store/Trash.

## Prochaine action

1. Au prochain démarrage, exécuter `git status --short --branch && git pull --ff-only`, puis
   lire cette passation et `Documentation/Passation/P4-qualification.md`. Le CI `qualify` du
   SHA `1f62627e` a été vérifié SUCCESS ; il ne couvre pas les commits locaux.
2. Si P4 reprend : traiter les réserves une par une selon `Documentation/Passation/P4-qualification.md`.
   Pour 4.6, attendre un chemin de copie 1.x déjà créée et autorisée ; ne lire que cette copie
   dans une fixture temporaire. Pour les autres lignes, faire consigner les observations et
   hôtes effectivement disponibles ; conserver G4 ouverte tant qu’un critère manque.
3. Ne pas pousser, ouvrir P5, promouvoir le registre ni déclarer G4 passée sans autorisation
   et preuves correspondantes. Aucun code n’est actuellement ouvert.

## En attente du mainteneur

- Relire le brouillon `Documentation/Release/2.0-notes-draft.md` (5.2).
- Build de test **notarisé** prêt : `~/Documents/CoreTend-notarized.zip` (SHA-256 dans P5) — à
  installer sur le Mac M5 et tester selon `Documentation/Evidence/P4-42-second-mac-protocol.md`,
  puis renvoyer la liste remplie (preuve 4.2).
- Chemin d’une copie cohérente, autonome, déjà créée du store 1.x pour 4.6 ; lire uniquement
  cette copie en fixture (protocole ci-dessous), ne jamais lire l’original ni omettre son WAL.
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
| P4 Qualification (G4) | [`P4-qualification.md`](Documentation/Passation/P4-qualification.md) | Travaux disponibles livrés — réserves G4 |
| P6 Upgrade (G6) | [`P6-upgrade.md`](Documentation/Passation/P6-upgrade.md) | Terminée (28-09) |
| P7 Sortie publique 2.0 (G7) | [`P7-release-2.0.md`](Documentation/Passation/P7-release-2.0.md) | En cours |
| P5 Release 2.0 (G5) | [`P5-release.md`](Documentation/Passation/P5-release.md) | À faire |

## Références

- Règles d’agent : `AGENTS.md`. Méthode : [`Pilotage.md`](Documentation/Project/Pilotage.md).
  Programme : [`Implementation-plan.md`](Documentation/Project/Implementation-plan.md).
- Produit : [`Cahier-des-charges.md`](Documentation/Project/Cahier-des-charges.md).
  Preuves : `Documentation/Progress.md`, `Documentation/Evidence/`.
- Passation précédente, archivée telle quelle : [`Documentation/Archive/passation-2026-09-27.md`](Documentation/Archive/passation-2026-09-27.md).
