# Passation courante — CoreTend Next

**Date :** 26-09-2026. **État :** reconstruction en cours, sans release. Dépôt actif : worktree `next/`, branche `next` publiée sur `ahmetbsbnr/coretend` et issue de `main`. L’ancien dépôt indépendant `rebuild/` reste une copie locale de provenance.

## Reprise active — 26-09-2026

L’utilisateur demande de poursuivre le projet jusqu’à finalisation et de tenir cette passation à jour à chaque étape pour reprise après arrêt abrupt. Tête actuelle : `b1888ad` (documentation de build); code du paquet actuel issu de `894c107` (packaging propre). Dernier ZIP local observé : SHA-256 `e1e87a2a611d4793b2043c396ea2d957b34fe9205e73434fa3ce51620c3473fa`; il contient le code de `894c107`, pas le commit documentaire `b1888ad`. La passation doit être actualisée et commit/push à chaque tranche terminée.

Ordre de reprise retenu : (1) refermer fonctions Must Applications/Integrity/permissions; (2) compléter les états de navigation, données, export et migration; (3) traiter les capacités restantes et mettre à jour `Website/`, README et cahier; (4) qualification en fixtures isolées, gates et builds; (5) relever précisément limites native/macOS/publication sans revendiquer une release non signée. Utiliser les langues utiles au résultat; Swift reste app macOS, Python dépôt/site, sans contrainte générale. Ne jamais ouvrir le vrai store CoreTend ni la vraie Corbeille pendant les tests. Aucune release signée/notarisée/publication.

## Lire d’abord

1. [`Documentation/Project/Cahier-des-charges.md`](Documentation/Project/Cahier-des-charges.md) : QQOQCCP, MoSCoW, RACI, exigences, huit destinations.
2. [`Documentation/Project/Repository-strategy.md`](Documentation/Project/Repository-strategy.md) : politique de branches, contribution et release.
3. [`Documentation/Progress.md`](Documentation/Progress.md) et [`Documentation/Traceability.csv`](Documentation/Traceability.csv) : état et preuves par capacité.
4. [`Documentation/Archive/Legacy-Reconstruction/passation.md`](Documentation/Archive/Legacy-Reconstruction/passation.md) : passation historique complète et sa famille documentaire. Ne pas confondre ses résultats 1.x avec la reconstruction neuve.

## État de travail

- Application SwiftUI, huit destinations, CLI, modules de scan/sûreté/persistance, site EN/FR et paquet local unsigned existent. Les parcours restent partiels selon la traçabilité.
- Dernière tranche : images similaires consultatives et recherche de fichiers associés aux apps par identifiant bundle dans un dossier choisi. Compilation `swift build` réussie; tests ciblés sur images synthétiques, symlink, limite de candidats et correspondance exacte réussis. Couverture produit encore partielle.
- Aucun accès aux données réelles CoreTend ni à la vraie Corbeille pendant les tests. Aucune publication, signature, notarisation ou mise à jour distante.
- Les documents anciens ont été copiés dans `Documentation/Archive/Legacy-Reconstruction/` sans modifier le worktree historique.
- `next` a intégré l’arbre de reconstruction sur l’historique public. `make qualify` passe dans `next/`. Branches locales réduites à `main` et `next`; trois anciennes branches `origin` supprimées après archivage de leurs pointes. Détails : `Documentation/Project/Branch-cleanup.md`.
- Développement après intégration : charge système sur une minute et historique Performance SQLite v3 (30 jours/500 entrées, points mesurés). Tests Persistence ciblés 14/14 et `make qualify` passent; qualification UI native encore ouverte.
- Intégrité ajoute lecture du marqueur de quarantaine macOS sur l’app choisie; états présent/absent/indisponible et test fixture. La provenance réelle reste non vérifiée.
- Applications propose désormais le déplacement du seul bundle `.app` choisi vers la Corbeille, avec proposition journalisée, revue nominative et confirmation. L’identité du répertoire est comparée à l’inventaire, à la revue et à l’exécution; tests sur Corbeille fixture et remplacement de répertoire. Données associées/héritées inchangées; FR-26 reste PARTIEL.
- Cleanup et Doublons utilisent désormais une présentation de confirmation explicite, figent les contrôles pendant l’action et libèrent l’accès temporaire au dossier sur tous les chemins d’échec. Le parcours UI natif reste à qualifier.
- Applications montre le flux HTTPS `SUFeedURL` déclaré localement et permet son ouverture explicite dans le navigateur; aucune disponibilité de version n’est affirmée. FR-25 reste PARTIEL.
- Réglages expose la conservation locale; Performances offre l’effacement confirmé de ses relevés sans effacer activité ou préférences. L’effacement SQLite est logique, sans garantie forensique; NFR-05 reste PARTIEL.
- Explorer, Nettoyage et Doublons distinguent racine indisponible, vide et erreurs partielles, avec annulation visible et rejet des résultats de tâches anciennes. NFR-06 reste PARTIEL sans qualification UI native.
- Navigation mémorise la dernière destination en préférence locale (identifiant seulement), avec repli Vue d’ensemble; aucun chemin de scan restauré. Relancement natif à qualifier.
- Packaging local refait le `.app` en dossier temporaire sous `Artifacts/` avant remplacement; les anciens fichiers du bundle ne contaminent plus le ZIP. Dossier `Artifacts` symbolique refusé. Build de packaging réussi.
- ScanCore donne des causes distinctes pour racine absente, permission refusée, symlink, type incorrect et exclusion. UI EN/FR reprend la cause. `swift test --filter ScanCoreTests`: 14/14, fixtures temporaires uniquement. FR-10 reste À_CONSTRUIRE pour le diagnostic complet des permissions système; NFR-06 PARTIEL.

## Suite prioritaire

1. Finir les fonctions Must encore partielles ou absentes; prioriser attribution des fichiers liés aux apps, sources de mise à jour, états d’accès, favoris et accessibilité selon `Documentation/Project/Implementation-plan.md`.
2. Vérifier chaque capacité avec fixtures isolées et tests utiles, puis parcours macOS natifs. Corriger la documentation quand la preuve change.
3. Vérifier CI distante de `next` et régler la protection des branches dans l’hébergement. Ne pas déplacer la version publique `main` avant qualification.
4. Préparer une version publique uniquement après matrice de compatibilité, signature/notarisation et vérification des artefacts.

### Quick Look fichiers sélectionnés — 26-09-2026

- Quick Look SwiftUI est ajouté dans Explore et Doublons : ligne de fichier listé, keeper/copie de doublon exact, chacune des deux images similaires. Dossiers non proposés en aperçu; action d’écriture indépendante inchangée.
- Le scope security-scoped du dossier sélectionné est conservé pendant l’aperçu et libéré à sa fermeture ou à la disparition de la vue. `swift build --product CoreTendApp` et build release réussis.
- Guide utilisateur et FR-23 / `quicklook.extended` mis à jour. Statut PARTIEL : compilation et packaging ne qualifient pas le comportement Quick Look natif ni VoiceOver.
- `make package-local` et `make verify-package` réussis. ZIP local non signé SHA-256 `7d885f8fa0bac32487205e5faa435e05fd16ed2e096a64dbc21fb50758070fee`; aucune signature, installation, ouverture ou publication.
- Reprise conseillée : examiner besoins Must restants par ordre sécurité/usage, en commençant permissions et aide d’accès macOS (FR-10), sans prétendre que dialogues de scan diagnostiquent permissions complètes. Construire petit jalon, mettre à jour traceability/Progress/UserGuide/passation, builder/packager, puis commit/push `next`.

### Aide sur accès aux dossiers — 26-09-2026

- Réglages décrit les accès limités au dossier choisi dans le picker macOS, les vérifications pratiques (existence, volume monté, lecture), puis le re-choix. Explique que protections système et exclusions peuvent produire des résultats partiels, sans demander Accès complet au disque.
- Ajout EN/FR; UserGuide/Progress/FR-10 mis à jour. `swift build --product CoreTendApp`, `make traceability`, `make safety-audit` et `git diff --check` passent.
- FR-10 reste PARTIEL : pas de sondes exhaustives par permission ni de liens profonds vers réglages système; l’aide n’infère pas l’absence d’un élément depuis un scan incomplet.
- Avant prochaine tranche : release build + paquet local, inscrire le SHA ZIP puis mettre cette passation au même commit que le jalon. Ordre produit après : compléter FR-10 prudemment et qualifier les parcours UI; FR-23 Quick Look natif nécessite aussi essai interactif/accessibilité.
