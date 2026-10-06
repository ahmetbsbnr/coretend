# Passation — CoreTend Next

Point d’entrée unique pour reprendre le travail. Mode d’emploi du système :
[`Documentation/Passation/README.md`](Documentation/Passation/README.md). Commandes, lancement
en fixture, invariants et particularités de l’hôte :
[`Documentation/Passation/Reference.md`](Documentation/Passation/Reference.md).

## Où on en est

- **04-10 (lenteurs) :** corrections de performance des analyses et build 202 exporté/signé ; upload bloqué par l’accès App Store Connect de Xcode ; vidéo de revue montée. Détail : journal P8 du 04-10.
- **Reprise 04-10 :** motif confirmé (Guideline 2.1 — Information Needed, build 201) ; aucun défaut de code exigé. Audit : droits sandbox minimaux, aucun appel réseau ni URL dans `Sources`, pas de demande d’accès complet au disque. Copie de `/Applications` = PKG Organizer sans `_MASReceipt` (d’où le refus de lancement) → installer depuis TestFlight avant la vidéo. Brouillon de réponse mis à jour (macOS 27.0.1 26A434, dossier de démo). ASC non connecté dans Chrome/navigateur intégré : réponse non envoyée, rien resoumis.
- **Mis à jour :** 02-10-2026 — site public réparé et déployé ; macOS 2.0.0 (201) reste **Rejected**, Guideline 2.1 ; invitation TestFlight acceptée par le mainteneur, vidéo physique et réponse/envoi à Apple restent à faire.
- **Correctif local 02-10 :** `check_traceability.py` conserve les dates d’observation historiques au lieu de les invalider au changement de date générale de Progress ; les dates futures/invalides restent rejetées. `make traceability` et `make qualify` passent (log `/tmp/coretend-next-qualify-traceability-fix.log`) ; aucun statut n’a changé.
- **Règle visuelle mainteneur 02-10 :** aucun libellé eyebrow/overline au-dessus des titres de page/section. Documentée dans `AGENTS.md`, la décision 0002 et le guide UI; générateur du site bilingue corrigé, `make build-site site-check` et `make qualify` PASS.
- **Tests modules 02-10 :** couverture AppShell et parcours natif Accessibilité ajoutés. `make test-native-ui` a passé 19 points sur les huit routes, Réglages, palette et huit modules en HOME/store temporaires; les confirmations destructives sont annulées. `TestStoreOverrideTests` couvre l’isolation de la fausse Corbeille (7/7). `make qualify` passe après l’ajout de l’adaptateur et de son contrôle de sûreté. Une relance UI a échoué avant d’exposer une fenêtre AX, malgré l’autorisation active; stabiliser le lancement. La couverture ne remplace pas une qualification VoiceOver ni chaque état d’interface. Matrice : [`ModuleTestCoverage.md`](Documentation/Evidence/ModuleTestCoverage.md).
- **Phase :** P8 — Mac App Store → [`P8-app-store.md`](Documentation/Passation/P8-app-store.md).
- **Lot courant :** 8.6 — TestFlight accepté selon le mainteneur ; enregistrer la vidéo physique demandée, compléter les six réponses avec les valeurs réellement observées, puis transmettre la vidéo et la réponse à Apple.
- **Clôture locale 29-09 :** `make qualify` PASS ; `make appstore-check traceability` et
  `git diff --check` PASS. Script d'export corrigé et six régressions isolées PASS.
- **Distribution publique :** ZIP et DMG retéléchargés, SHA-256, signatures, tickets et
  Gatekeeper PASS. Contrôles HTTP support/confidentialité/téléchargement PASS.
- **Site :** boucle `/en`/`/fr` corrigée sur le projet Vercel existant `coretend`, domaine
  `coretend.ahmetbsbnr.com` aliasé au déploiement READY `dpl_65AVX5VgY33RUCB3rBRRK235h31t` ;
  15 chemins de route et 51 URL internes testés sans erreur. Inventaire Vercel :
  [`Vercel-audit-2026-09-30.md`](Documentation/Evidence/Vercel-audit-2026-09-30.md).
- **Modifications locales :** corrections/docs d’export et du site non commités ; preuves ajoutées à relire. Aucun push ni fusion effectué. Build App Store 201 envoyé via Organizer et soumission à la revue confirmée le 29-09.
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

1. Sur le Mac physique, enregistrer le lancement et le parcours typique du build TestFlight 201 accepté ; joindre la vidéo dans App Store Connect.
2. Répondre au message Guideline 2.1 et copier les mêmes six réponses dans App Review Information → Notes ; brouillon : [`App-Review-response-2026-09-30.md`](Documentation/Release/App-Review-response-2026-09-30.md). Compléter le modèle Mac/OS avec les valeurs observées.
3. Réconcilier les changements locaux, puis demander/obtenir une décision explicite avant commit, push ou intégration de `next` dans `main`. La release 2.0.0 historique et les pointes de branches sont consignées dans P7 et `Reference.md`.

## En attente du mainteneur

- Safari authentifié confirme une seule entrée rejetée, build 201, motif « 2.1.0 Performance: App Completeness ». Le mainteneur confirme le 02-10 que l’invitation TestFlight est acceptée ; la vidéo physique reste à capturer. Brouillon de réponse dans `Documentation/Release/App-Review-response-2026-09-30.md`.
- Audit Vercel : `app` et `coretend-static-project.any8` semblent être des projets CoreTend en double sans domaine canonique ; `dash-stage` n’a pas de déploiement et renvoie 404. Ils sont conservés sans suppression ; détails et sources dans le rapport d’audit.
- Le dépôt supplémentaire `ahmetbsbnr/ahmetbsbnr` est le README de profil GitHub, pas un clone de CoreTend ; sa description a été clarifiée.
- Les recettes et exigences dont la validation n’est pas établie restent réservées avec leur statut inchangé.
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
| P7 Sortie publique 2.0 (G7) | [`P7-release-2.0.md`](Documentation/Passation/P7-release-2.0.md) | Terminée ; artefacts revalidés le 29-09 |
| P5 Release 2.0 (G5) | [`P5-release.md`](Documentation/Passation/P5-release.md) | Historique, remplacé par P7 |
| P8 Mac App Store (G8) | [`P8-app-store.md`](Documentation/Passation/P8-app-store.md) | Build 201 rejeté ; Guideline 2.1, informations et vidéo physique demandées (30-09-2026) |

## Références

- Règles d’agent : `AGENTS.md`. Méthode : [`Pilotage.md`](Documentation/Project/Pilotage.md).
  Programme : [`Implementation-plan.md`](Documentation/Project/Implementation-plan.md).
- Produit : [`Cahier-des-charges.md`](Documentation/Project/Cahier-des-charges.md).
  Preuves : `Documentation/Progress.md`, `Documentation/Evidence/`.
- Passation précédente, archivée telle quelle : [`Documentation/Archive/passation-2026-09-27.md`](Documentation/Archive/passation-2026-09-27.md).
