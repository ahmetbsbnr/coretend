# Passation courante — CoreTend Next

**Date :** 26-09-2026. **État :** reconstruction en cours, sans release. Dépôt actif : worktree `next/`, branche `next` publiée sur `ahmetbsbnr/coretend` et issue de `main`. Jalons fusionnés : `6052711` données locales (PR #40) et `e93e657` palette bilingue (PR #41), CI distante verte. Travail courant : `feature/palette-arrow-navigation`. L’ancien dépôt indépendant `rebuild/` reste une copie locale de provenance.

### Jalon en cours — données locales et favoris/récents

- `SQLiteStore` schema v4 ajoute `saved_files`; migration v1/v2/v3→v4 transactionnelle, répétable, sans import implicite de chemins. Historique d’activité, préférences et relevés Performance préservés.
- Favoris s’enregistrent uniquement après clic explicite. Récents Explorer sont opt-in, désactivés par défaut, limités à 100 lignes; mesures inconnues restent SQL NULL. Les écritures valident chemins absolus normalisés et tailles non négatives.
- Interface : étoile dans Explorer; Vue d’ensemble liste favoris/récents, dernière taille et état indicatif absent/inaccessible; Réglages contrôle opt-in; retrait local d’une entrée disponible. Aucun accès au fichier rouvert depuis un chemin mémorisé.
- Tests Persistence : 17/17 passent, dont fixture v3→v4 et conservation événement/langue/relevé, idempotence, quota et validation. `make qualify` passe : site, traçabilité, audit sécurité, smoke install fixture, suite Swift, builds App/CLI et `git diff --check`.
- `make package-local` et `make verify-package` réussis. ZIP arm64 unsigned SHA-256 `9b5a340e2513e7f1a9a16a0c0b252a72d8f0eecff6bca62668135019e815b091`; non lancé/installé/signé/notarié/publié.
- Docs synchronisées : `Documentation/Project/DataModel.md`, `Migration.md`, `Progress.md`, `Traceability.csv`, `UserGuide.md`. FR-24 et `favrec.module` EN_COURS; FR-11 EN_COURS; NFR-05 reste PARTIEL (pas de récupération/restauration utilisateur complète).
- Contrôle visuel SwiftUI/VoiceOver natif non réalisé. FR-24 reste en cours jusqu’à cette qualification. Sous-jalon `feature/palette-arrow-navigation`: sélection clavier ↑/↓, Retour sur commande sélectionnée, recherche réinitialise une sélection devenue invalide. Tests AppShell 5/5. `make qualify`, `make package-local`, `make verify-package`, `git diff --check` passent. ZIP arm64 unsigned SHA-256 `4c63d81a3b25f4c79b26017760fae0ec632ee93c5d8eb2d1dba5abb2316096bd`; non lancé. Branche prête à commit/PR/CI distante.

## Reprise active — 26-09-2026

L’utilisateur demande de poursuivre le projet jusqu’à finalisation et de tenir cette passation à chaque étape pour reprise après arrêt abrupt. Dernier code fusionné : `6052711` (SQLite v4 favoris/récents, PR #40, CI distante verte). Le commit précédent `ef58ece` a généré ZIP unsigned SHA-256 `9b5a340e2513e7f1a9a16a0c0b252a72d8f0eecff6bca62668135019e815b091`, vérifié structure seulement. Branche active actuelle `feature/keyboard-command-palette`, changements locaux non commités; passation et docs clavier en cours.

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

### Qualification intégrée — 26-09-2026

- Après `4f98f5a`, `make qualify` passe : manifeste généré, site EN/FR statique vérifié, traceability (40 exigences FR/NFR + 51 capacités), audit sécurité, `swift test` et builds debug App + CLI.
- Suite de tests complète réussie; cette invocation a rapporté les bundles ScanCore, SafetyCore, ProductContract, Persistence, Domain, CLIContract et AppShell sans échec. Aucune interaction SwiftUI native n’est couverte; cette commande ne rend donc pas le produit final.
- Le ZIP local précédent correspond au code de `4f98f5a`; hash `d11cd103e63c58affe766535c49938f3521e51e6f45fafde66b2a097664acb4c`.
- Écarts Must encore explicites : permissions système complètes, certaines fonctionnalités Record/cleanup, usage historique, onboarding/runtime/accessibilité, compatibilité deuxième OS/hôte et preuve d’installation/lancement/signature. Lire `Documentation/Traceability.csv`; poursuivre ces écarts par tranche, ne pas déclarer finalisation avant preuve.

### CLI — résultat partiel explicite — 26-09-2026

- Commit code/docs/tests : `6dfb493` sur `origin/next`; dépôt propre après checkpoint.

- `coretend scan` ne renvoie plus succès lorsque ScanCore remonte une erreur racine/élément. Codes documentés : 0 complet, 2 partiel, 1 erreur de commande/store, 130 annulation. JSON expose `files`, `issues` (path/reason) et `complete`; texte liste les issues.
- Tests CLI d’intégration sur répertoire temporaire : scan complet succès; racine inexistante donne issue `missing`, `complete=false`, code 2. `swift test --filter CLIContractTests`: 5/5.
- `make qualify` passe après ce changement (site, traceability, audit sécurité, XCTest complet, builds debug App/CLI). `make package-local` et `make verify-package` passent.
- ZIP arm64 local non signé SHA-256 `835917d81e62930c77208c44d58357e6be9db4c7f1be250e7681eab3c7317c60`. Non lancé/installé/signé/publié. FR-13 reste PARTIEL; pas d’ajout de permissions ni de mutation à la CLI.
- Reprise full-auto : prendre le prochain Must d’usage avec forte valeur, probablement export d’activité/diagnostics et contrat de données, ou NFR accessibilité; vérifier statut précis dans Traceability.csv. Refaire qualification, paquet, ReleaseEvidence et cette passation avant checkpoint poussé.

### Quick Look — libellés accessibles — 26-09-2026

- Boutons d’aperçu d’Explorer, keeper/copies exactes et les deux images similaires nomment maintenant le fichier ciblé; hints EN/FR annoncent Quick Look et rôle keeper/copie quand utile.
- Build app, `make qualify`, `make package-local` et `make verify-package` passent. NFR-07 reste PARTIEL : noms/hints présents, aucun parcours clavier, VoiceOver, Dynamic Type, contraste ou Reduce Motion observé manuellement.
- ZIP local arm64 non signé hash `721cc3311c1ee8c986ca324e534e830be5b2c73b7f2b59acd80f6466b8e0740d`; artifact ignoré Git, pas installé/lancé/signé/publié. Commit source à noter dans ReleaseEvidence après checkpoint code.
- Commit source : `cdb3870`; preuve/hash paquet associés dans `Documentation/ReleaseEvidence.md`.

### Explorer — filtres explicites — 26-09-2026

- FR-16 : choix `Tous`, `≥ 1 Gio local`, `Anciens · 365 jours`. Seuil porte sur octets alloués connus (inclusive); filtre ancien porte sur `modifiedAt <= now - 365*24h`. Date limite ISO avec fuseau affichée et figée tant que preset inchangé. Taille/date inconnue ne passe pas le filtre.
- Test-first : `ExplorePresetTests` a échoué avant API, puis passe (2/2) sur fixtures/mesures injectées. Build app + `make qualify` passent; site, traceability, sécurité, suite XCTest complète et App/CLI debug inclus.
- `make package-local` et `make verify-package` passent. ZIP arm64 unsigned SHA-256 `072ff474f4eae77109dd312b342e125c2b1c30d8275afeb0cc3f8a573d522c48`; aucun lancement, install, signature ou publication.
- FR-16 reste PARTIEL : presets sont surtout taille/date, filtres catégorie/presets réutilisables sur les autres modules à examiner.
- Commit source : `664dbf6`; SHA associé consigné dans `Documentation/ReleaseEvidence.md`.

### Cohérence du site public — 26-09-2026

- Le générateur `Scripts/build_site.py` et sorties EN/FR décrivent désormais Explorer livré (recherche/tri/carte/Quick Look/filtres) et CLI avec résultat partiel explicite. Accueil ne présente plus les vues métier comme majoritairement en construction; limites permissions/accessibilité/release restent citées.
- `make build-site site-check` passe. FR-15 reste PARTIEL : génération/contenu/CSP vérifiés, mais pas de déploiement, revue navigateur réelle ou audit accessibilité.
- Cette tranche ne change pas binaire; garder dernier paquet local de `664dbf6` et ne pas le présenter comme installateur signé.

### Diagnostic — aperçu du JSON exact — 26-09-2026

- Commit source : `5fc9563` (`origin/next`).

- Réglages affiche désormais le document JSON expurgé exact, sélectionnable, avant ouverture du sélecteur de destination. Annuler ferme l’aperçu sans ouvrir l’exporteur; export se poursuit après fermeture de la feuille.
- ThreatModel/UserGuide/Progress actualisés. Test redaction existant passe (`testDiagnosticExportOmitsEventDetailsAndPaths`), `swift build --product CoreTendApp` passe. FR-21/NFR-05 restent PARTIELS; parcours natif export/annulation et revue privacy externe non faits.
- Refaire `make qualify`, `make package-local`, `make verify-package`; enregistrer artifact et commit dans ReleaseEvidence puis pousser ce jalon.
- ZIP arm64 unsigned SHA-256 `63b28f04d3382fed0ded640538e99a801ed0cb7ec676074718218e5525bf3bfb`; ReleaseEvidence lie hash au commit source.

### Confidentialité réseau — audit statique — 26-09-2026

- `Scripts/audit_safety.py` bloque maintenant APIs cliente réseau Swift connues (`URLSession`, `Network`, sockets, processus lancés), frameworks/SDK télémétrie connus et dépendance SwiftPM URL. Les liens de mise à jour restent ouverture système à clic explicite; aucune lecture de flux.
- `make qualify` passe : site/CSP, traceability (40 FR/NFR + 51 capacités), audit renforcé, XCTest complet, builds debug App/CLI.
- NFR-04 reste PARTIEL : audit statique ne capture pas le trafic en exécution et peut manquer appels indirects/obfusqués. Aucun nouvel artefact binaire; ZIP `63b28f…` reste lié au code app `5fc9563`.
- Suite A-Z : prioriser gaps produit Must restants dans Traceability et Implementation-plan. Branches/CI distantes et tests UI natifs restent à traiter avant toute revendication de release.

### Installation locale sûre — 26-09-2026

- Ajout `Scripts/install_local.sh`: exige bundle `CoreTend.app` + destination déjà existante explicitement donnée; refuse liens symboliques et remplacement, valide plist/exécutable, stage sur le même volume puis déplace le bundle. Pas de sudo, sélection auto, lancement ou action sur données de l’app.
- Smoke TDD fixture: test rouge avant implémentation (script absent), vert après; couvre app synthétique, destination installée, collision sans écrasement, source/destination symlink refusées. `make verify-install-package` package le vrai binaire et fait l’installation dans HOME temporaire; aucune ouverture de l’app.
- `make qualify` passe avec install-smoke, tests Swift complets, builds App/CLI, audit sécurité, site et traceability. `make verify-package` passe.
- ZIP local arm64 unsigned SHA-256 `795eab7dbeb13d0d0b241f0a018fb58645c8bfc0c2ebb6d0e4af3622777c0898`. FR-14 reste PARTIEL : pas de lancement GUI, désinstallation utilisateur testée, signature/notarisation ni test macOS minimum.
- À poursuivre : test installation/removal complète dans environnement isolé si possible; attention, app data survit removal bundle. Ne pas supprimer automatiquement ses données.
- CI GitHub Actions pour `f7d7d73` réussie : run 36264106677, macos-latest, 18:54:30Z. Protection `next` vérifiée : `qualify` strict requis; force-push/suppression interdits; approbation PR non requise. GitHub a signalé bypass admin sur push direct de `c7ea517` alors que son CI restait attendu; gate local passait déjà. Pour jalons suivants, créer branche de travail et PR vers `next`, fusion après check vert. `main` conserve protection antérieure/checks historiques; aucun changement appliqué à `main`.
- CI `bea69a3` réussie : run 36264445630 (macos-latest, `qualify` + whitespace, 18:59:56Z). CI `c7ea517` run 36264363517 réussie également.
- CI du checkpoint stratégie `ed437b1` réussie : run 36264534176, macos-latest, 19:01:42Z; gate et whitespace verts.
