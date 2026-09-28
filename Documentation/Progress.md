# Reconstruction progress

**Relevé :** 2026-09-27. **État :** reconstruction en cours, non finalisée. Derniers jalons fusionnés : favoris/récents SQLite v4, palette clavier bilingue et écriture batch des récents (PR #40–#44). UI macOS native et VoiceOver non qualifiés. Cahier et plan approuvés; développement sur lignée `next` du dépôt public historique. Le dépôt greenfield initial `rebuild/` reste copie locale de provenance.



### P3 lot 3.4 — Doublons — 2026-09-28

- Recette mainteneur acceptée : groupes exacts en parcelles, exemplaire gardé choisi par la personne et jamais déplaçable (`DuplicateKeepers`, 3 tests), étiquette « Gardé » qui saute. FR-07, scan.duplicates, clutter.duplicates, scan.similarimages, clutter.similarimages : preuves datées, `PARTIEL` (déplacement réel et images proches non observés).
- Incident du 28-09 (confirmation Corbeille validée par Retour) corrigé : Retour annule toutes les confirmations destructives, contrôle d’architecture ajouté.
### P3 lot 3.1 — Vue d’ensemble et premier lancement — 2026-09-27

- Recette mainteneur acceptée : premier lancement (logo qui germe, trois étapes, Commencer) et Vue d’ensemble Serre (chiffre héros dans la langue de l’app, bande de sol mesurée, dernière activité, chemins vers Explorer et Historique), FR/EN, clair/sombre.
- `shell.onboarding` devient `VÉRIFIÉ`. FR-01, FR-03, shell.launch, shell.nav restent `PARTIEL` : les autres destinations sont recettées dans les lots 3.2–3.9 ; Finder, UserDefaults de production et VoiceOver restent non qualifiés.
### NFR-13 — reproductibilité après échec CI — 2026-09-27

- PR #55 a révélé `LC_UUID` aléatoire et timestamp objet dans `N_OSO.n_value`. Après détection que dyld macOS 26 refuse un binaire sans `LC_UUID`, `Package.swift` applique le linker Apple `-reproducible` en Release, qui conserve UUID déterministe et fixe metadata; minimum macOS reste 14.0.
- `make qualify` complet passe local et GitHub run 36304912826 (`macos-26-arm64`): App/CLI hash pairs byte-identical sur deux hôtes. Paquet Release démarre/se désinstalle en HOME/store fixture et conserve `LC_UUID`. NFR-13 devient VÉRIFIÉ dans environnements observés; aucun hash inter-hôtes promis, couverture support macOS reste NFR-08.

### NFR-09 — lancement paquet et échantillons résidentiels — 2026-09-27

- Deux runs Release fixture arm64/macOS 27: 1.094 s jusqu’au premier store SQLite; 13 échantillons `ps` par run; RSS médian 92.5–96.3/max 95.4–97.6 MiB; `%CPU` cumulative médiane 0/max 55.2–69.1. Parseur de métriques testé. Ce n’est pas prêt-fenêtre ni CPU idle instantané; NFR-09 PARTIEL faute latence UI, scan représentatif et autres hôtes.

### FR-14 — smoke du vrai paquet local — 2026-09-27

- `make app-runtime-smoke` teste maintenant le vrai bundle produit par `package_local.sh`: paquet ZIP généré sous un dossier temporaire isolé, structure/plist/Mach-O vérifiés, `.app` installée sous HOME fixture, exécutable installé lancé puis retiré. Store fixture préservé; 14 échantillons de sockets sans connexion Internet; aucun sidecar SQLite hors store.
- ZIP temporaire testé: SHA-256 `5904b8efb73fac47054153a2ca578204b7399c30b0e09cd62824112f4b388868`. Smoke ciblé passe. FR-14 reste `PARTIEL`: Finder/Launch Services, désinstallation GUI, signature/notarisation et hôte macOS minimum ne sont pas couverts.

### NFR-11 — contrat reduced-motion du site — 2026-09-27

- `site-check` valide désormais le CSS `prefers-reduced-motion: reduce`: défilement fluide neutralisé, animations et transitions ramenées à une durée minimale avec `!important`. Trois tests couvrent règle complète, media query absente et protections manquantes.
- Chrome local a aussi parcouru les dix routes EN/FR à 320 × 800 CSS px: langue du document correcte, largeur scroll document/corps égale à 320 partout. Viewport étroit uniquement, pas zoom navigateur réel.
- Test statique ne remplace pas l’émulation navigateur. L’interface Chrome DevTools disponible ne permet pas d’émuler cette préférence; zoom réel, réglages OS, contraste exhaustif, VoiceOver et navigateur déployé restent à qualifier. NFR-11 reste `PARTIEL`.

### FR-11 — migrations simultanées au démarrage — 2026-09-27

- L’observation AX native sur fixture a reproduit `Données locales indisponibles.` dans Overview quand le store neuf était ouvert simultanément par shell et vue Favoris/Récents. Le schéma était valide ensuite; les deux connexions avaient capturé `user_version` obsolète avant `BEGIN IMMEDIATE`.
- Migration relit désormais `user_version` une fois le verrou acquis; le second writer ne rejoue pas DDL déjà validé. Le test rouge force deux migrateurs à attendre le verrou, échouait sur `table performance_samples already exists`, puis passe avec schéma v5 et lecture `saved_files`.
- Après correctif, nouveau lancement isolé puis clic AX Overview ne montre plus l’erreur; SQLite est resté sous store fixture. FR-11 demeure `PARTIEL` pour récupération de vrai store et matrice hôte ancienne.

### NFR-07 — route clavier palette native — 2026-09-27

- Dans un `.app` fixture isolé, `⌘K` ouvre la palette, AX confirme le focus du champ, saisie « Performances » + Retour affiche le contenu de la vue Performances. Preuve limitée à une route sur arm64/macOS 27.
- NFR-07 reste `PARTIEL`: sidebar par flèches, VoiceOver parlé, Dynamic Type/zoom, contrastes, Reduce Motion/Transparency et revue humaine non qualifiés.

### NFR-06 — progression de scan observée — 2026-09-27

- Explorer, Nettoyage et Doublons consomment les événements `progress(completed:)` de ScanCore et montrent le nombre de fichiers mesurés, sans total ni pourcentage estimé. Annulation remet le compteur à zéro.
- Doublons expose désormais progression causale du hachage des candidats, du décodage image et des comparaisons (total des paires effectivement décodées). Ces moteurs tournent dans une tâche utilitaire détachée; l’annulation de la tâche UI est relayée au worker. Les compteurs ne promettent ni taux ni durée.
- Tests ScanCore vérifient les comptes finaux mesurés des trois phases; AppShell couvre copies EN/FR et bornage. NFR-06 reste `PARTIEL`: réactivité/cancellation UX native, VoiceOver et accessibilité restent à qualifier.

### FR-10 — causes de lecture partielle — 2026-09-27

- Les trois vues de scan conservent maintenant les causes des échecs internes au lieu d’un booléen. Messages EN/FR distinguent refus d’accès macOS, éléments disparus, métadonnées/lecture indisponibles et combinaisons; les chemins ne sont pas affichés et aucune absence/sûreté n’est déduite.
- AppShell test couvre refus permission vs indisponibilité, en anglais et français; `swift build --product CoreTendApp` passe. FR-10 reste `PARTIEL`: aucun sondage TCC/FDA exhaustif ni parcours natif de Réglages n’est prétendu.

### FR-03 et FR-06 — détails des résultats et audit de décision — 2026-09-27

- Cleanup affiche désormais octets alloués localement, taille logique, date modifiée et risque; Explore ajoute aussi date modifiée aux deux mesures. Valeurs absentes demeurent « Unknown/Inconnu ». Les descriptions accessibles EN/FR incluent nom, source, état/risque et mesures distinctes; test AppShell couvre composantes bilingues et inconnues.
- FR-03 reste `PARTIEL`: preuves SwiftUI source/test seulement; ordre visuel, Dynamic Type et VoiceOver natif non qualifiés.
- `FileActionService` fixture démontre propositions suivies de refus ou annulation distincts; les deux originaux restent octet-identiques et Fake Trash reçoit zéro appel. FR-06 demeure `PARTIEL`, l’expérience native et Trash réel ne sont pas qualifiés.

### Suite de développement — traceabilité et Quick Look — 2026-09-27

- Quick Look Explore/Doublons/Images similaires valide maintenant chaque candidat au moment de l’ouverture : racine choisie réelle, fichier régulier existant, chemin restant strictement dans cette racine. Accès security-scoped conservé pendant l’aperçu et libéré à fermeture/départ; candidat disparu, remplacé par symlink, dossier ou extérieur refusé avec message EN/FR.
- `QuickLookCandidateTests` couvre fichiers ordinaires/nestés et refus des racines symlink, dossiers, chemins externes, liens, absences et racines invalides. Tests ciblés passent; interaction/fermeture Quick Look native et course TOCTOU restent non qualifiées. FR-23 et `quicklook.extended` restent `PARTIEL`.
- Gate NFR-12 étendu aux 91 entrées : références code/tests requises pour tout statut actif et toute priorité, sources documentaires/proof datée/owner pour chaque ligne; reports À_CONSTRUIRE pointent vers cahier et raison explicite. Fixtures rejettent preuve périmée/invalide/non ancrée, colonnes mal formées et Should actif sans tests. Independent documentation review remains open; NFR-12 stays PARTIEL.
- Les six capacités Should et reports C/W sont réconciliés dans le registre. Cela suit l’état présent, sans marquer les menus système livrés ni les interactions natives qualifiées.

## Livré et prouvé

- Cahier complet : QQOQCCP, 8 destinations, 26 FR, 14 NFR, MoSCoW, RACI, architecture et risques; plan d’exécution par 8 tranches.
- Dépôt Swift 6 vide au départ; cahier, baseline et plan conservés sous `Documentation/Project/`.
- ProductContract catalogue les 51 IDs de capacité et huit destinations.
- SafetyCore : capacités à durée courte, revalidation d’existence/chemin/volume/inode/allowlist; adapter prod uniquement `FileManager.trashItem`; fake Trash dans Tests. Cinq tests sur racine refusée, règle inconnue, identité changée, expiration, préservation à l’échec et déplacement fixture.
- SQLite schema v4 : événements, préférences/imports, mesures Performance et favoris/récents séparés; migrations transactionnelles v1/v2/v3→v4, URL injectée; mode CLI read-only. Récents opt-in désactivé par défaut, 100 chemins maximum; favoris explicites; tests en bases temporaires synthétiques.
- Import legacy renforcé : ouverture non bloquante et comparaison identité/taille/horodatages du descripteur après lecture; les FIFO nommés comme prefs sont rejetés sans bloquer et une source modifiée pendant lecture échoue explicitement.
- Palette clavier ⌘K en anglais/français : recherche des huit destinations et Réglages par libellé/alias; utilise le routeur existant. Tests AppShell couvrent catalogue et recherche. Le contrôle ↑/↓ de la sélection et le comportement natif du raccourci restent à qualifier manuellement.
- Palette amélioration clavier : ↑/↓ déplace sélection avec limites, Retour ouvre la commande sélectionnée; tests du modèle AppShell couvrent liste vide, sélection initiale et bornes. Qualification UI native reste manuelle.
- Enregistrement des récents groupé : Explorer valide puis écrit son lot dans une transaction SQLite unique; entrée invalide rejette avant mutation. Persistence ciblé 18/18, incluant lot invalide et quota.
- ScanCore : parcours explicite, exclusions, symlinks exclus, tailles logique/allouée inconnues conservées; tests de lecture seule sur fixtures.
- ScanCore n’a maintenant aucune dépendance SafetyCore/Persistence; audit statique bloque imports et primitives d’écriture. Fixture compare contenu, types, tailles et dates de tout l’arbre avant/après scan. Test déterministe annule le consommateur pendant une lecture contrôlée et prouve qu’aucun fichier suivant n’est lu; qualification UI reste ouverte, FR-02 PARTIEL.
- Doublons exacts : bucket par taille puis SHA-256 par blocs, déduplication d’inodes, un exemplaire proposé à garder; tests sur copies identiques, contenus distincts et hard links.
- FR-01 : routage extrait en correspondance exhaustive des huit destinations; dernière destination valide restaurée, préférence manquante/obsolète retombe sur Overview. Contrat AppShell couvre les huit routes; lancement natif, parcours des états et accessibilité restent à qualifier.
- FR-11 : fixture v3 sauvegardée via SQLite Online Backup puis restaurée vers un nouveau fichier temporaire; version, événements, préférence et mesures conservés. Fixture corrompue refusée sans destination partielle. Procédure locale hors ligne documentée; aucun store réel lu ni restauré. FR-11 reste PARTIEL, restauration macOS réelle non qualifiée.
- FR-03 : chaque métrique Performances affiche sa source/API macOS; valeurs manquantes du volume restent « Inconnu ». Limites visibles en EN/FR, sans diagnostic de santé ni estimation d’espace récupérable. Tests de copy vérifient sources et refusent formulations affirmatives répertoriées; revue native reste ouverte.
- FR-04 : test SQLite ferme puis rouvre un store temporaire et retrouve exclusions triées/dédupliquées; test ScanCore confirme que racine et sous-arbre exclus ne produisent aucun résultat. Settings natifs et relance app restent à qualifier.
- NFR-01 / `safety.pathvalidator` : PathValidator refuse désormais une racine autorisée finale qui est un symlink; test rouge/vert sur fixture. Même contrôle s’exécute pendant approbation et revalidation. Course concurrente résiduelle et stress hostile restent documentés.
- App SwiftUI compilable, huit routes EN/FR. Explore, Duplicates et Cleanup ont sélection de dossier et scan. Duplicates/Cleanup relient sélection manuelle → proposition journalisée → revue nominative → confirmation → validation → adapter Trash; le keeper n’est jamais sélectionnable, sélection vide par défaut, refus/cancel distincts. Actions non lancées sur l’hôte.
- Applications inventorie les `.app` du seul dossier explicitement choisi et affiche disponibilité de mise à jour inconnue; Integrity inspecte localement le statut de signature du seul bundle choisi sans verdict malware.
- Exclusions stockées SQLite et utilisées dans les trois scans; import legacy prefs JSON v1 opt-in, allowlist/digest/trace/idempotence/source intact; onboarding, diagnostic sans chemins/détails et preview d’export ajoutés.
- Explore ajoute recherche nom/dossier, tri nom/date/taille locale et carte proportionnelle exacte des seuls octets alloués connus; layout couvert par tests.
- Explore permet désormais de sélectionner des fichiers réguliers du dossier choisi, de revoir noms/chemins, puis de confirmer leur déplacement vers la Corbeille via FileActionService/SafetyCore. Journalisation préalable obligatoire; annulation et résultats tracés; échecs restent visibles. Sélecteur de dossier bloqué pendant l’action. `spacelens.delete` reste PARTIEL en attente de parcours natif et qualification Trash réelle.
- Script crée un `.app` + ZIP local unsigned sous `Artifacts/`; structure vérifiée et installation testée seulement dans HOME fixture, aucune ouverture Finder réalisée.
- Installateur local prend source et dossier destination explicites, refuse symlinks et bundle existant, stage dans le volume cible puis déplace sans écraser. Smokes synthétique et bundle release passent sous HOME fixture; smoke runtime installe puis lance le bundle installé, avec SQLite sous le store fixture. Finder/Launch Services, désinstallation GUI, signature et compatibilité restent à qualifier; FR-14 reste PARTIEL.
- CLI compilable : `scan --root` explicite, `record list --store` explicite et lecture seule, help/version honnête. Scan distingue succès complet (0), résultat partiel (2), erreur commande/store (1), annulation (130); JSON donne `files`, `issues`, `complete`. Tests fixtures couvrent racine manquante et scan complet. FR-13 reste PARTIEL : parité aide/localisation et validation CLI complète restent ouvertes.
- Site statique EN/FR, manifeste 51 capacités, CSP, navigation sémantique, sans scripts ni analytics; tests de routes, liens, langues, contenu manifest.
- Cahier utilisateur, développeur, confidentialité, accessibilité, données, migration, CLI et release evidence présents.
- `make qualify` passe sur `next` après l’ajout de l’historique Performance : contrôles site/traçabilité/sûreté, tests XCTest et builds app + CLI. Tests Persistence ciblés 14/14 passent. `make package-local verify-package` avait passé dans `rebuild/` avant migration; ancien ZIP unsigned SHA-256 `8a0cb259df23e7324866201be51026e78989b3f11464c7d876f92b89b589c984`. Aucun test n’utilise le vrai store ou la vraie Corbeille.

## En cours ou non livré

- Tests UI d’accessibilité et de parcours restent à construire. L’accès Trash natif n’a pas été exécuté sur de vraies données.
- Record UI, filtres, CSV/JSON et clear history livrés; les parcours Duplicates/Cleanup écrivent propositions, approbations, annulations, succès/échecs. Diagnostic expurgé couvert par test de contrat. Retention et tests UI du parcours restent à faire.
- Migrations : schéma v1/v2→v3 avec fixtures; import v1 prefs copy-only livré pour format synthétique reconnu. Formats historiques alternatifs, sauvegarde/interruption forcée et analyse migration UI plus complète restent ouverts.
- Explore : carte proportionnelle, recherche, tri, Quick Look sur fichier choisi, filtre ≥1 Gio d’octets alloués connus et filtre âge de 365 jours livrés. Le critère « ancien » affiche son instant limite ISO et fuseau; mesures/dates inconnues sont exclues. Tests ScanCore couvrent seuil inclusif, valeur inconnue et cutoff exact. Doublons/Images similaires proposent Quick Look. Prise en charge cloud reste non livrée. Images similaires restent partielles (heuristique non calibrée, corpus et accessibilité à vérifier).
- Réglages explique accès aux seuls dossiers choisis, causes pratiques de refus/indisponibilité, reprise par nouveau choix, et limites des protections macOS; aucune demande d’Accès complet au disque. Applications distingue maintenant dossier disparu, accès refusé, mauvais type, lien symbolique et lecture impossible, avec messages EN/FR. Tests Domain sur racines fixture couvrent ces distinctions et erreurs Cocoa permission. `make qualify`, `make package-local`, `make verify-package` et `git diff --check` passent sur `feat/access-diagnostics`; PR #54 `qualify` distant passe. ZIP arm64 unsigned SHA-256 `20a72cf36d3327018b8c78fef76e2f8aab835629b0558345f2b99749693c6024`. FR-10 reste partiel : aucune sonde exhaustive par permission ni deep link système.
- Les commandes Quick Look d’Explorer/Doublons/Image similaires annoncent le nom du fichier et leur action en hints EN/FR. NFR-07 devient PARTIEL; noms accessibles implémentés, mais clavier/focus, Dynamic Type, contraste, Reduce Motion et essais VoiceOver manuels restent à qualifier.
- Diagnostic Réglages montre désormais le JSON expurgé exact (texte sélectionnable) avant choix de destination; l’annulation ne lance pas l’exporteur. Test Persistence confirme omission des chemins/détails sur fixture. FR-21 et NFR-05 restent PARTIELS jusqu’au parcours UI, preuve d’annulation/export et limites d’effacement documentées.
- Audit sécurité rejette maintenant imports/APIs réseau Swift courants et références aux SDK analytics connus dans `Sources/`. NFR-04 est PARTIEL : vérification statique seulement; pas de capture réseau en exécution ni revue indépendante.
- Applications discovery et signal code-signature livrés; revue consultative des reliquats ajoutée sur un dossier choisi avec correspondance exacte bundle ID, sans attribution confirmée ni action sur ces reliquats. Le déplacement confirmé du seul bundle `.app` vers la Corbeille est relié à SafetyCore et au journal; désinstallation complète des éléments associés/hérités et source de mise à jour non livrées. Performance conserve des points locaux de charge; présentation graphique améliorée en marqueurs datés, axes lisibles et dernière valeur accessible, sans interpolation de données. Qualification UI native toujours ouverte.
- Le site EN/FR explique désormais favoris explicites, récents opt-in (off par défaut, maximum 100), recherche ⌘K et conservation locale des chemins/tailles. Entrées sauvegardées retirables; pas de synchronisation réseau. Génération et contrôles statiques passent; FR-15 est maintenant `VÉRIFIÉ` dans son périmètre statique documenté; contrôles OS/navigateur et déploiement restent sous NFR-11/NFR-14.
- Garde-fous SQLite livrés : rejeter horodatages non finis avant écriture d’événement ou transaction/retention Performance; tests régression fixtures démontrent refus et absence de ligne parasite (PR #48).
- Axe X Performance affiche maintenant jour, mois et heure pour distinguer dates avec même heure; `swift build --product CoreTendApp`, `make qualify` et `git diff --check` passent. Essai visuel natif/VoiceOver reste à faire.
- Performance accepte sélection graphique du curseur et l’ancre au point valide le plus proche; égalité choisit l’observation la plus récente. Vue affiche valeur et horodatage mesurés avec repère, sans calcul/interpolation. Domain tests couvrent points connus, inconnus, tie-break et curseur invalide; interactions natives restent à qualifier.
- Paquet de production reconstruit après #50 : ZIP local arm64 unsigned vérifié structurellement, SHA-256 `94503244830030785388e6ea2359dc844af22d719d5e82729f14408f1697a299`. App non lancée/signée/notariée/publiée.
- CLI a des tests end-to-end fixture pour scan complet et racine manquante; parité complète d’aide/localisation et annulation de processus restent ouvertes.
- Paquet `.app`/ZIP unsigned construit; installation/ouverture et lancement non vérifiés. Profilage performance, hôte macOS 14, capture UI, vérification VoiceOver/clavier manuelle et revue sécurité indépendante manquent.
- Must FR/NFR restent `EN_COURS`, `À_CONSTRUIRE` ou `PARTIEL` dans la traceability; aucune qualification finale n’est acquise.

## Frontières respectées

- La source runtime a été reconstruite indépendamment. La passation et sa famille documentaire historiques ont été importées sous `Documentation/Archive/Legacy-Reconstruction/`; la branche `next` descend maintenant de l’historique public pour préserver la continuité des releases.
- Aucun scan exécuté sur données personnelles; tests exclusivement synthétiques et temporaires.
- L’app n’a pas été lancée; aucune vraie base CoreTend ni vraie Corbeille ouverte.
- `next` a été poussée sur `origin`; `main`, tags et releases sont inchangés. Aucune signature, notarisation ni distribution de la reconstruction.
# Tranche images similaires — 2026-09-26

- Ajout d’un moteur local d’empreinte différence 64 bits. Il lit des miniatures ImageIO, accepte extensions image courantes, ignore liens symboliques et fichiers illisibles, limite taille à 100 Mio et candidats à 5 000.
- Destination Doublons propose deux modes: copies exactes et paires d’images similaires. Similarité utilise seuil initial de 8 bits différents sur 64; c’est heuristique, sans calibration sur corpus représentatif.
- Aucun bouton de suppression pour ces paires. Action Trash existante reste réservée au parcours copies exactes avec revue/confirmation.
- Validation effectuée: `swift build` réussi; ensuite deux tests ciblés sur copie visuelle, symlink et limite de candidats ont passé. D’autres cas représentatifs restent nécessaires avant statut vérifié.
- Statut: intégration de base présente, capacité encore partielle. À faire: fixture d’images représentatives, tests orientation/format/limites, réglage seuil fondé sur corpus, accessibilité UI et mesure performance.

### Revue consultative des reliquats d’apps — 2026-09-26

- Dans Applications, l’utilisateur choisit une app inventoriée puis un dossier à analyser. Recherche lecture seule; candidats seulement si un composant du chemin ou le nom sans extension correspond exactement à l’identifiant bundle.
- Aucune attribution n’est affirmée, aucun nettoyage/suppression proposé. Compilation `swift build` et test de correspondance exacte passent. Capacité reste PARTIELLE. À faire: tests d’inventaire sur fixtures, association par provenance de signature/métadonnées, UX d’accès limité et revue accessibilité.

### Dépôt public et mesures Performance — 2026-09-26

- Branches anciennes : pointes locales et distantes archivées sous `refs/archive/2026-09-26/`; branches locales actives `main` et `next`. Trois branches `origin` anciennes supprimées. `next` créée depuis `origin/main`, puis poussée sans réécriture de `main`.
- Passation historique et documents cités conservés dans le projet; passation courante, licence, contribution, sécurité, stratégie, CI et formulaires publics ajoutés.
- Performance : `getloadavg` macOS lu lors d’un rafraîchissement, SQLite v3 conserve charge une minute et espace disponible connus/inconnus, 30 jours/500 entrées; graphique de points. Tests Persistence ciblés 14/14, `make qualify` et `git diff --check` passent. Qualification UI native reste ouverte.
- Intégrité : lecture locale du marqueur de quarantaine du bundle choisi, avec états présent/absent/indisponible; test sur bundle fixture et symlink réussi. `make qualify` repasse après cette tranche. Ce seul marqueur ne prouve pas la provenance réelle. Signal de login items et qualification UI restent à faire.

### Déplacement du bundle d’app — 2026-09-26

- Applications peut proposer le seul bundle `.app` inventorié, après journalisation de proposition, revue nominative et confirmation. Les données associées et héritées restent en place; aucune désinstallation complète n’est revendiquée.
- L’identité du répertoire est comparée à l’inventaire lors de la revue, puis à la revue lors de l’approbation et de l’exécution. Un remplacement au même chemin échoue. Les tests utilisent une Corbeille fixture, couvrent déplacement du bundle seul, conservation des données associées et deux courses de remplacement.
- Cette tranche ne prouve pas les parcours UI natifs, l’accès réel à la Corbeille macOS, l’attribution des reliquats ou les composants de lancement. FR-26 reste PARTIEL.
- Revue des boîtes de confirmation Cleanup/Doublons : fermeture journalisée, sélection et racine figées pendant revue/exécution, accès temporaire au dossier libéré même si la proposition ne peut pas être journalisée. Compilation SwiftUI passe; interaction native non exécutée.

### Source de mise à jour déclarée — 2026-09-26

- L’inventaire Applications lit localement `SUFeedURL` depuis `Info.plist`. Seule une adresse HTTPS valide sans identifiants devient un lien explicite vers le navigateur; une adresse invalide ou absente reste signalée. Aucune requête réseau, lecture de flux ou comparaison de versions au moment de l’inventaire.
- `apps.updates` et FR-25 restent PARTIELS : aucune preuve de source App Store, aucune page produit confirmée, aucune comparaison de versions et aucun parcours natif qualifié.

### Conservation locale des données — 2026-09-26

- Réglages expose la politique : activité conservée jusqu’à effacement explicite dans Historique; préférences/exclusions jusqu’à modification ou retrait de la base; relevés Performance limités à 30 jours et 500 points.
- Performances permet de retirer les relevés enregistrés après confirmation, indépendamment des événements et préférences. L’effacement est logique dans SQLite, sans promesse d’effacement physique des sauvegardes. Compilation app réussie; parcours natif et preuve de restauration non effectués. NFR-05 reste PARTIEL.

### États de scan et annulation — 2026-09-26

- Explorer, Nettoyage et Doublons exposent une commande d’annulation. Chaque analyse a un identifiant de génération; les résultats d’une ancienne tâche annulée ne remplacent plus le nouvel état de la vue.
- Échec de lecture de la racine, dossier vide et erreurs partielles restent distincts. Nettoyage retire ses candidats incomplets à l’annulation. Compilation SwiftUI réussie; parcours natif et tests de course non exécutés dans cette tranche. NFR-06 devient PARTIEL; FR-10 reste À_CONSTRUIRE pour les permissions système détaillées.
- La dernière destination de navigation est conservée sous identifiant local; une valeur inconnue revient à Vue d’ensemble. Aucun chemin de dossier n’est restauré. Build app réussi; relancement natif non observé, FR-01 et `shell.nav` restent EN_COURS.
- Le packaging local construit le bundle et son ZIP dans un dossier temporaire sous `Artifacts/`, puis remplace le bundle généré. Cela évite d’emporter des fichiers résiduels d’un ancien `.app`; `Artifacts` symbolique est refusé. Build de packaging réussi, signature/notarisation inchangées.

### Causes d’échec à la racine d’un scan — 2026-09-26

- ScanCore distingue racine absente/inaccessible, lien symbolique, élément qui n’est pas un dossier et racine exclue. Refus de permission et absence restent séparés dans l’UI; échec de lecture interne reste partiel.
- Explorer, Nettoyage et Doublons présentent la cause locale connue en EN/FR. 14 tests ScanCore passent sur fixtures temporaires; symlink racine et absence testés. Aucun répertoire système ni donnée utilisateur inspecté. FR-10 reste À_CONSTRUIRE pour les permissions globales et leur réglage; NFR-06 reste PARTIEL.

## Qualification intégrée — 26-09-2026

`make qualify` passe après Quick Look et l’aide d’accès dossiers : génération du manifeste/site, contrôles statiques site, traçabilité (40 FR/NFR + 51 capacités), audit sécurité, suite XCTest complète, builds debug App + CLI. Les bundles XCTest listés terminent sans échec. Ce gate n’inclut aucun parcours SwiftUI natif; les Must restent incomplets comme détaillé dans la traçabilité. Aucun statut de livraison finale n’est acquis.

## Continuation de la reconstruction — 27-09-2026

- Tranche de Musts ciblés terminée jusqu’à Task 9 du plan local `.superpowers/sdd/Remaining-musts-plan/`: validation locale de l’URL de mise à jour (FR-25); rollback/retry import legacy (FR-20); allowlist export diagnostic (FR-21); tailles Explore logique/allouée (FR-08); audit échec Trash avec motif persistant (FR-06/26); rollback/retry migration SQLite v3 (FR-11); correction MoSCoW; localisation EN/FR Record par `failure_code` v5 (FR-06/12); classification metadata-only des placeholders cloud (cloud.detect).
- Vérifications récentes sur fixtures : `make qualify` passe, dont tests Persistence 27, Domain 19, AppShell 11, ScanCore 18 et builds app/CLI. Revue ciblée Task 8 et Task 9 sans constat ouvert. `Traceability.csv` se parse en 91 lignes/9 colonnes; 78 Must: 35 `EN_COURS`, 36 `PARTIEL`, 7 `À_CONSTRUIRE`, 0 `VÉRIFIÉ`. FR-06/FR-08/FR-20/FR-21/FR-25/FR-26 et `cloud.detect` gardent les limites natives explicites.
- Schéma SQLite courant v5 ajoute `activity_events.failure_code` nullable. Une app v4 ne peut pas relire la base migrée v5; retour arrière demande restauration d’une sauvegarde antérieure. Aucune base réelle migrée.
- Estimation d’avancement fonctionnel : environ 40 %, estimation de portée non calculée par le registre. Aucun Must n’a son critère de qualification complet marqué `VÉRIFIÉ`.
- Aucun push, merge, tag, signature, notarisation ou publication. UI native/VoiceOver, vraie Corbeille macOS, second hôte/OS, sauvegarde-restauration utilisateur et gates navigateur/release ne sont pas déclarés qualifiés. La passation historique archivée ci-dessus reste contexte; cette section est l’état courant de la reconstruction.

### Suite Musts — Integrity LaunchAgents — 27-09-2026

- Task 10 ajoute une revue locale et consultative des fichiers plist directement présents dans un dossier LaunchAgents explicitement choisi. Lecture plafonnée à 500 candidats et 1 Mio/plist, symlinks exclus, erreurs visibles, aucune activation/suppression ni détection d’état actif revendiquée.
- Les lectures utilisent un descripteur du dossier sélectionné et `openat`/`O_NOFOLLOW`; une fixture remplace le chemin sélectionné par un symlink vers un dossier extérieur après ouverture et prouve que la lecture reste dans le dossier d’origine. FR-`integrity.loginitems` reste `PARTIEL`, faute de lecture native du service de lancement et de qualification UI.
- Revue Task 10 : deux constats P2 corrigés (champ evidence CSV et course de remplacement racine), relecture propre. `swift test --filter LaunchAgentInspectionTests` 5/5, AppShell 11/11, `make qualify` et `git diff --check` passent.
- Comptage CSV précédent (91 lignes) avait 35 `EN_COURS`, 38 `PARTIEL`, 5 `À_CONSTRUIRE` parmi 78 Musts. Depuis, le registre courant a été plus largement réconcilié; voir le comptage actualisé ci-dessous.
- Commits après le relevé précédent : `569cc4d` LaunchAgents, `fcbb687` root-fd et preuve, précédés du handoff `cf01d4c`. Aucun push/merge/publication.
- FR-07 : Domain fixture prouve qu’une revue refusant le keeper garde les copies intactes et ne touche pas la Corbeille fixture; moteur garde un keeper déterministe. Race externe supprimant ce keeper et UI native restent à qualifier.
- FR-14 / NFR-08 : lancement runtime du binaire debug avec `HOME`, `CFFIXED_USER_HOME` et `TMPDIR` isolés; processus vivant après 8 s, SQLite créé sous le HOME temporaire. GUI visible, bundle empaqueté et matrice hôte restent non qualifiés.
- FR-07 race de lot : revue reçoit identité de keeper pour chaque groupe sélectionné et la vérifie avant chaque copie. Fixture retire keeper après première copie déplacée; copie suivante reste intacte, aucun second appel Trash, échec journalisé. Course étroite entre validation et API Trash et UI native restent ouvertes.
- NFR-09 baseline initiale : CLI Release sur fixture synthétique de 10 000 fichiers/100 dossiers, arm64/macOS 27.0; 4 runs chauds médiane 0,913 s wall, 0,979 s CPU, RSS max 74,18 MiB. `make benchmark-scan` reproduit. Aucun budget fixé; UI, corpus réel et mesures multi-hôte restent ouvertes.

### NFR-13 — builds Release locaux — 27-09-2026

- `swift build -c release --product CoreTendApp` et `swift build -c release --product CoreTendCLI` réussissent sur arm64/macOS 27.0 sans avertissement émis. `make qualify` a également réussi (XCTest et builds debug App/CLI).
- `Package.swift` ne déclare aucune dépendance SwiftPM externe et aucun `Package.resolved` n’existe. Reproductibilité entre builds propres/hôtes et compatibilité multi-hôte restent non prouvées; NFR-13 demeure `PARTIEL`.

### FR-10 — causes d’échec de racine — 27-09-2026

- ScanCore distingue `permission_denied`, `missing` et indisponibilité technique. ProductCopy présente maintenant refus macOS, absence et disponibilité indéterminée avec messages EN/FR distincts; test rouge/vert AppShell couvre le mapping.
- Pas de sonde TCC/FDA exhaustive ni d’ouverture des réglages Confidentialité. FR-10 reste `PARTIEL`; ne pas inférer l’absence d’un élément depuis un scan incomplet.

### NFR-11 — smoke navigateur local — 27-09-2026

- Chrome Lighthouse mobile couvre les 11 routes EN/FR et sélecteur de langue : Accessibilité, Bonnes pratiques, Agentic Browsing 100 sur chaque page. Les 10 pages de contenu à 640 px CSS n’ont pas de débordement; Tab atteint sur chacune le lien d’évitement avec contour visible 3 px.
- Détails et limites dans `Documentation/Evidence/SiteAccessibilitySmoke.md`. Zoom réel, VoiceOver, taille système, contrastes tous états, emulation reduced-motion, headers déployés et autres navigateurs restent à vérifier. SEO 50 en raison du noindex voulu + description meta absente. NFR-11 reste `PARTIEL`; FR-15 est `VÉRIFIÉ` pour son périmètre de contenu statique et de routes.

### FR-13 — annulation SIGINT du CLI — 27-09-2026

- Cause prouvée : `Task.isCancelled` retournait 130 si tâche déjà annulée, mais exécutable n’interceptait pas Control-C; test subprocess avant correction finissait par signal POSIX (`-2`). L’exécutable installe un Dispatch signal source pour annuler la tâche du scan et restaure le gestionnaire après fin.
- `Scripts/test_cli_interrupt.py` vérifie l’exécutable réel: help 0; commande inconnue, valeur mal formée, store absent 2 et messages stables; store explicite inaccessible 1 sans création; scan racine absente 2 en JSON sans création de racine. Puis crée 50 000 fichiers temporaires, interrompt le scan et exige code 130 (pas terminaison signal `-2`). Intégré à `make qualify`; matrice passe aussi sur CLI Release.
- Parser refuse une valeur d’option qui commence par `-`, au lieu d’avaler silencieusement l’option suivante; tests distinguent `.storePathRequired` et `.invalidArguments`. Un chemin relatif commençant par tiret s’écrit `./-nom`.
- `--lang en|fr` avant commande localise aide, erreurs et sortie texte; défaut anglais. Tests XCTest et subprocess couvrent langue absente/invalide/mal placée, aide/erreurs bilingues, raison JSON stable et scan partiel français. FR-13 reste `PARTIEL` en attente de qualification CLI complète et revue de l’absence d’API mutation/élévation.
- La matrice SIGINT a exposé le cas où le signal clôt le flux avant son prochain événement : le `for await` terminait alors par 0. Le runner vérifie aussi l’annulation après la boucle et retourne 130; subprocess passe Debug et Release sur 50 000 fichiers.

### Capacités restantes — signature et données héritées — 27-09-2026

- Réglages inspecte la signature du bundle CoreTend courant par Security.framework et affiche l’état, identifiant et équipe disponibles. Copy EN/FR limite explicitement ce que prouve ce signal; build app et test de copy passent. `settings.appsignature` reste `PARTIEL` jusqu’au parcours natif.
- `Scripts/uninstall_local.sh` présente dry-run par défaut; `--keep-data` retire uniquement le bundle explicitement nommé; `--remove-all` inclut base et préférences courantes après confirmation. `--include-legacy` opt-in ajoute les deux anciens dossiers MacCare et plist, toujours en dernier. Validation stricte d’allowlist, refusal de symlinks, zéro élévation.
- `Scripts/test_uninstall_local.py` ne crée et retire que fixtures dans un HOME temporaire : dry-run, conservation des données héritées par défaut, opt-in héritées et refus de symlink. `make uninstall-smoke` entre dans `make qualify`. Aucune donnée utilisateur réelle touchée; procédure Finder/non destructive et macOS restent non qualifiées. `uninstall.legacydata` reste `PARTIEL`.
- `TestStoreOverride` n’accepte que le double opt-in concordant (`CORETEND_TEST_MODE`, `CORETEND_TEST_STORE_DIR`) avec HOME/CFFIXED_USER_HOME temporaires identiques; symlink, store absent, HOME inclus et racine temp refusés. Cinq tests Persistence passent. Smoke app debug sous profil temporaire crée sa base seulement au store fixture; aucun chemin HOME réel utilisé. Profile Release/Finder reste à qualifier; `testing.storeisolation` passe à `PARTIEL`.
- Historique filtre maintenant dates calendaires (7/30/tout) et type, groupe du plus récent au plus ancien; CSV/JSON reprennent les filtres visibles. Tests couvrent borne incluse, jours futurs écartés, ordre, copie EN/FR et effacement limité aux événements. Parcours file-exporter natif reste non qualifié.
- Les descriptions placeholder de 26 capacités ont été remplacées par des comportements verts explicites; `check_traceability.py` rejette ces placeholders. Comptage actuel : 91 lignes, 18 Musts `EN_COURS`, 60 `PARTIEL`, 0 `À_CONSTRUIRE`, 0 `VÉRIFIÉ`. Progression fonctionnelle estimée ≈42 % des Musts, ≈40 % des 91 lignes du registre. Estimation qualitative; aucun statut Must vérifié de bout en bout.

- NFR-10 architecture gate added to `make qualify`: it reads `swift package dump-package` and checks Swift tools ≥6.0, macOS ≥14.0, no external SwiftPM package dependencies, and no SafetyCore/Persistence dependency from ScanCore. Five synthetic contract tests cover compliant graph and rejection cases, including transitive write-capable dependencies; existing safety audit checks the production Trash boundary. NFR-10 moves from `EN_COURS` to `PARTIEL`; independent architecture review is still open.
- FR-14 runtime smoke is now repeatable: `make app-runtime-smoke` builds Release and runs its executable from a temporary `.app` fixture for eight seconds with a fail-closed test-store override. SQLite appears under the fixture store. This improves runtime startup evidence but leaves visible GUI/Finder, signature, notarization and minimum-OS host checks open.

### Mise à niveau du registre Must — 2026-09-27

- `check_traceability.py` impose maintenant à chaque ligne Must des références code/test, une preuve datée et un owner; toutes les références fichier code/test doivent exister. Le registre couvre 40 FR/NFR et 51 capacités. Les preuves déclarent explicitement quand une qualification macOS/native ou une revue indépendante manque.
- Revue actuelle : 78 Must `PARTIEL`, 0 `EN_COURS`, 0 `À_CONSTRUIRE`, 0 `VÉRIFIÉ`. Ce changement de statut signifie qu’un comportement partiel et sa preuve sont tracés; il ne signifie pas que critère utilisateur complet est satisfait. L’estimation globale reste qualitative, environ 42 % des Musts.
- L’onboarding est extrait dans `ProductCopy` et un test AppShell vérifie en EN/FR le choix des dossiers, la lecture seule, la confirmation Corbeille et l’absence de demande Full Disk Access. Première fenêtre et interactions natives non observées.
- Gate final du 2026-09-27 après onboarding et réconciliation traceability : `make qualify` code 0. `git diff --check` et `python3 Scripts/check_traceability.py` passent. Release runtime isolé confirmé; aucune UI visible, release signée ou qualification multi-hôte n’est revendiquée.


### Revue de date et correction du CLI — 2026-09-27

- Désinstallateur : fixture HOME isolée avec `Library` symlinkée vers un autre dossier temporaire confirme refus sans toucher aux données extérieures. Le code canonise déjà le parent complet; la fixture documente cette garantie. Fenêtre TOCTOU validation/suppression reste ouverte.
- CLI `version` suit `--lang en|fr`; XCTest et test subprocess valident texte exact et code 0. FR-13 reste `PARTIEL`, les validations terminal/macOS plus larges manquent.
- `check_traceability.py` compare toute preuve Must à date ISO valide du relevé Progress et refuse lignes CSV mal formées; tests couvrent date courante, périmée, calendrier invalide, non ancrée et colonnes surnuméraires. Gate complet `make qualify` réussi.
- Comptage courant : 76 Must `PARTIEL`, 2 `VÉRIFIÉ`; pondération indicative à 51,3 % Must et 47,3 % registre entier (81 `PARTIEL`, 2 `EN_COURS`, 6 `À_CONSTRUIRE`, 2 `VÉRIFIÉ`). UI, accessibilité, hôtes, vraie Corbeille et distribution demandent preuves restantes.


### FR-08 — allocations physiques uniques — 2026-09-27

- ScanCore conserve device/inode comme identité d’allocation observée. Les lignes Explorer gardent tailles logiques/allouées par chemin; treemap déduplique les chemins hard linkés par identité, sélectionne le chemin visible lexicographiquement premier et indique des allocations distinctes plutôt que des fichiers. Les mesures inconnues restent exclues.
- Fixtures synthétiques valident deux chemins partageant une identité physique, une seule aire de treemap pour eux, et un fichier sparse de 8 Mio dont l’allocation observée est inférieure à la taille logique. `swift test --filter 'ScanCoreTests/testHardLinkResultsSharePhysicalAllocationIdentity|TreemapLayoutTests/testHardLinksContributePhysicalAllocationOnlyOnce|ScanCoreTests/testSparseFixtureKeepsLogicalAndAllocatedSizesDistinct'` passe.
- FR-08 reste `PARTIEL` : rendu visuel/VoiceOver, fournisseurs cloud et couverture de systèmes de fichiers restent à qualifier. Aucun comportement utilisateur natif n’est déclaré vérifié. PR #55 mise à jour sur `356d7c7`; revue indépendante sans blocage et CI `qualify` réussie.

### NFR-13 — builds Release propres — 2026-09-27

- `Scripts/test_clean_release_builds.py` construit deux fois `CoreTendApp` et `CoreTendCLI` depuis deux racines et scratch directories temporaires vides et indépendants, exposés au linker via un symlink au chemin stable `.build/qualify-clean-release-scratch`. Le gate échoue sur avertissement, erreur de build, binaire absent ou hash différent; il est inclus dans `make qualify`.
- Les quatre builds réussissent sans warning sur arm64/macOS 27.0 et les deux paires sont octet-identiques. Cette méthode stabilise le chemin OSO embarqué sans partager le contenu des scratch dirs. SHA et limites dans `Documentation/Evidence/ReleaseReproducibility.md`.
- NFR-13 est `VÉRIFIÉ` pour le source, host, toolchain et chemin de checkout observés. La compatibilité autres hôtes/versions reste sous NFR-08.

### shell.launch — fenêtre visible en fixture — 2026-09-27

- Lancement du binaire Release dans un `.app` temporaire avec `HOME`, `CFFIXED_USER_HOME`, `TMPDIR` et store SQLite isolés. CoreGraphics observe une fenêtre écran `CoreTend`; son arbre AX expose accueil FR et huit destinations. La base apparaît uniquement sous le store fixture.
- Preuve et limites dans `Documentation/Evidence/AppWindowRuntimeQualification.md`. Observation sur arm64/macOS 27.0; Finder/Launch Services, activation des routes, VoiceOver parlé et autres critères a11y restent non qualifiés. `shell.launch`, FR-01 et FR-14 restent `PARTIEL`.

### Isolation des préférences fixtures et routes natives — 2026-09-27

- Probe Foundation : `HOME`/`CFFIXED_USER_HOME` temporaires ne redirigent pas assez sûrement `UserDefaults` adossé à `cfprefsd`. `CoreTendPreferences` choisit donc les valeurs `CORETEND_TEST_*` et désactive les écritures persistantes dès qu’un override de store test existe. `SettingsView` et `ExploreScanView` partagent maintenant les bindings détenus par la racine.
- 7 tests AppShell couvrent overrides, profil incomplet fermé, écritures no-op, profil production et priorité de langue. Revue finale sans finding : environnement fixture prévaut sur la langue stockée et SQLite n’est lu qu’en production. `make qualify` passe après correctif. Matrice AX antérieure : routes natives 8/8, fallback ID obsolète 1/1, premier lancement français; SQLite uniquement sous chaque fixture.
- Lancement distinct par préférence env ne prouve pas persistance UserDefaults de production ni clic clavier/souris dans la sidebar. `FR-01`, `shell.nav` et NFR-03 restent `PARTIEL`; détail dans `Documentation/Evidence/AppWindowRuntimeQualification.md`.

### Revue du plan Remaining Musts — 2026-09-27

- Audit du registre contre le MoSCoW §7 : `shell.menubar`, `settings.menubar`, `quicklook.extended`, `favrec.module`, `ui.commandpalette` et `clutter.largeold` sont classés `Should`. Les deux capacités de barre système restent `À_CONSTRUIRE`; les autres gardent leur état partiel/en cours selon les preuves natives manquantes.
- Les 22 tâches du plan local sont représentées dans le code, les tests ou les preuves documentées. Les qualifications manuelles/macOS, multi-hôte et publication ne sont pas remplacées par des assertions de complétion.
- Gate complet rejoué après correctif de langue : `make qualify` passe, dont 28 tests AppShell, smoke runtime isolé, quatre builds Release propres (App/CLI en paires octet-identiques), builds Debug App/CLI et subprocess CLI/SIGINT. Hash App `9bc252b070a11d8ebf4a2143b6b73d5635941d494c7ccdaad94fc1b25e34397c`; CLI `803ab48ab6c0fcd03aead4fac192a85c50caf9e1f3632bafbb27c349d3ff9161`.
- Pondération actuelle : Must 76/78 PARTIEL + 2/78 VÉRIFIÉ = 51,3 %; registre entier 81 PARTIEL, 2 EN_COURS, 6 À_CONSTRUIRE, 2 VÉRIFIÉ = 47,3 %. Mesure de preuve, pas complétion produit ni score des Should.

### FR-14 — lancement depuis l’installation fixture — 2026-09-27

- `Scripts/test_app_runtime_isolation.py` installe son `.app` Release fixture via `Scripts/install_local.sh` sous HOME temporaire, lance l’exécutable installé huit secondes puis l’arrête et le retire avec `uninstall_local.sh --keep-data`. Il rescane SQLite/sidecars après arrêt, avant retrait. La base fixture reste après retrait; tests synthétiques couvrent artefacts permis et rejetés.
- Tests rouges préalables exigeaient installation et retrait de l’app; tests verts après ajout des étapes install→lancement→retrait. `make qualify` passe. Cela ne couvre pas Finder/Launch Services, désinstallation interactive, signature/notarisation ou macOS minimum; FR-14 reste PARTIEL.


### Mise à jour FR-15 et audit transitif NFR-10 — 2026-09-27

- Revue indépendante conclut qu’aucun critère FR-15 ne reste ouvert dans son périmètre : contenu statique fidèle, état de publication honnête, routes EN/FR, CSP et smoke browser local sont contrôlés. FR-15 passe à `VÉRIFIÉ`; zoom réel, VoiceOver, reduced-motion en exécution, autre navigateur et publication restent suivis sous NFR-11/NFR-14.
- NFR-10 gate vérifie maintenant fermeture transitive du graphe ScanCore. Test synthétique refuse ScanCore → ScanAdapter → Persistence. Cinq cas d’architecture au total; revue indépendante du gate restant à tracer.
- Comptage recalculé depuis CSV : 91 lignes, 81 `PARTIEL`, 2 `EN_COURS`, 6 `À_CONSTRUIRE`, 2 `VÉRIFIÉ`; Must : 76 `PARTIEL`, 2 `VÉRIFIÉ`. Score pondéré indicatif : 51,3 % Must, 47,3 % registre.

### NFR-04 — socket observation du runtime Release — 2026-09-27

- `Scripts/test_app_runtime_isolation.py` échantillonne les sockets Internet du processus `.app` installé par fixture avec `lsof` pendant huit secondes. Exécution observée : 14 échantillons, aucun socket IPv4/IPv6 ouvert; HOME/TMPDIR/store restent isolés, app retirée et base fixture conservée.
- `Scripts/test_runtime_network_scope.py` crée un listener loopback dans le processus test et vérifie que l’observateur le détecte; ce trafic est local et ne contacte pas Internet. Le helper échoue fermé si `lsof` manque ou échoue.
- NFR-04 reste `PARTIEL`: échantillonnage de sockets au repos, pas capture de paquets; lien HTTPS déclenché par l’utilisateur et fenêtres entre échantillons non exercés. Audit source statique continue de bloquer les clients réseau usuels et SDK analytics connus.

### Gate traçabilité durci — 27-09-2026

- Le checker compare chaque priorité du registre à sa source approuvée, rejette ID dupliqués et exigences répétées. Section 7 documente la réconciliation des 51 capacités et six Should; NFR (§6) classés Must. Fixtures couvrent doublon, promotion/rétrogradation et dates.
- Test SQLite concurrent déterministe via barrière après lecture version, sans temporisation d’attente. `make qualify` complet passe; releases propres App/CLI byte-identiques. FR-11 reste PARTIEL, NFR-12 attend revue indépendante.
- Comptage conservé : 78 Must, dont 76 PARTIEL et 2 VÉRIFIÉ; pondération indicative 51,3 %.

### Inventaire capabilities sans doublons — 27-09-2026

- Le gate NFR-12 refuse désormais les IDs capabilities répétés dans `Capability.swift`; fixture démontre le rejet, registre courant de 91 IDs passe. `make qualify` complet passe. Aucun statut produit modifié; revue indépendante NFR-12 toujours requise.

- Fixtures de `check_traceability.py` vérifient explicitement diagnostics attendus pour doublons source capabilities et exigences du cahier; le code retour seul ne suffit plus à valider ces cas.

### Integrity — racine LaunchAgents explicite — 27-09-2026

- Test fixture confirme qu’un dossier sélectionné via symlink ne produit aucun candidat et signale `directoryUnreadable`; guide et preuve Traceability alignés. `make qualify` passe. `integrity.loginitems` reste PARTIEL, faute d’observation du service launchd et de qualification native.

### FR-24 — état des fichiers favoris/récents — 27-09-2026

- La disponibilité affichée utilise uniquement `fileExists` et libellé prudent : présent sans confirmer accès, ou absent/inaccessible. Taille reste mesure sauvegardée; aucun chemin n’est ouvert. Helper de copy EN/FR ajouté au module testable AppShell et utilisé par la vue; test ciblé, build App et `make qualify` passent.
- FR-24 et `favrec.module` deviennent PARTIEL (preuve comportement/libellé automatisée); navigation native et VoiceOver/accessibilité restent ouverts. Registre : 83 PARTIEL, 6 À_CONSTRUIRE, 2 VÉRIFIÉ (47,8 % pondéré); Must : 76 PARTIEL, 2 VÉRIFIÉ (51,3 %).

### FR-24 — alias bilingues Command Palette — 27-09-2026

- Le guide promettait recherche EN ou FR sans dépendre de langue UI, mais le catalogue n’incluait que l’alias courant. Fixtures rouges reproduisent `home` dans UI française et `historique` dans UI anglaise sans résultat; catalogue ajoute les alias deux langues, test couvre les huit destinations et Réglages dans les deux sens. `make qualify` passe.
- Navigation flèches native et activation Réglages native restent non qualifiées; aucun statut ou score de conformité ne change.
- FR-16 avance : Explorer combine catégories par extensions explicites insensibles à la casse et presets taille/ancienneté. Critères visibles, extensions listées; tests ScanCore couvrent catégories et repli « autres ». Interaction native reste à qualifier.
- Should `shell.menubar` et `settings.menubar` avancent : `MenuBarExtra` facultatif, préférence locale désactivée par défaut, routes partagées vers les huit destinations et Réglages, copie EN/FR. Suite `UserDefaults` injectée vérifie le défaut et la persistance; `make qualify` démarre aussi l’app Release avec menu activé sous fixture et sans socket réseau. Activation, visibilité native et accessibilité du menu restent à qualifier.
- FR-22 avance : le menu fenêtre lit charge, mémoire, capacité libre et type/heure de dernière activité; relevés à 30 s uniquement pendant présentation, mémoire seulement, sans ajout Performance. `VisibleSamplingLoop` est annulée par la disparition SwiftUI; fixtures testent annulation et requête d’activité bornée sans détail. Ouverture/fermeture et accessibilité natives restent à qualifier.

### FR-26 — décision de périmètre des données associées — 27-09-2026

- Décision produit : aucune source de preuve d’appartenance (receipt d’installation, manifeste) n’est approuvée. La désinstallation reste limitée au retrait du bundle choisi; les candidats trouvés par identifiant de bundle restent consultatifs, sans action. Aucun code modifié; guide et modèle de menace décrivent déjà ce comportement.
- FR-26 reste PARTIEL : parcours UI natif et Corbeille réelle non qualifiés. Toute future attribution exige d’abord un contrat de preuve approuvé; jamais par simple nom.

### Smoke runtime — locale de `ps` — 27-09-2026

- `make app-runtime-smoke` échouait sous locale française : `ps` imprimait `68,8` et le parseur strict rejetait la mesure. `runtime_metrics.py` lance désormais `ps` avec `LC_ALL=C`/`LANG=C`; le parseur reste strict et refuse toujours la virgule décimale. Tests de régression ajoutés; `make qualify` passe. Aucun statut modifié.

### Site — meta descriptions — 27-09-2026

- `build_site.py` génère une meta description par page à partir du texte d’introduction échappé; `check_site.py` exige exactement une description non vide. Le fichier `index.html` de choix de langue porte une description bilingue. Lighthouse SEO n’a pas été relancé; NFR-11 reste PARTIEL (zoom réel, VoiceOver, réglages OS).

### Qualification clavier native — palette et Réglages — 27-09-2026

- Parcours natif sur `.app` Release en fixture isolée (arm64/macOS 27) : navigation clavier de la barre latérale observée sur les huit destinations. Trois défauts trouvés et corrigés : flèches ignorées dans la palette (champ focalisé), ligne sélectionnée hors vue sans défilement, feuille Réglages sans contrôle de sortie et textes tronqués. Correctifs observés sur l’app reconstruite.
- Échap n’atteint pas l’app sur cet hôte (moniteur `NSEvent` temporaire), ni par automatisation ni au clavier réel : fermeture par Échap non qualifiée. Détails : `Documentation/Evidence/AppWindowRuntimeQualification.md`. `make qualify` passe. Aucun statut ne change.

### Direction artistique Porcelain / Slate / Teal et mouvement — 27-09-2026

- Nouveau module `DesignSystem` (exigé par l’architecture §9) : palette Porcelain / Slate / Teal clair/sombre reprise des valeurs de la direction CoreTend retenue (réécrites, aucun fichier importé), calcul de contraste WCAG et jetons de mouvement 150/300/550 ms. Tests : textes ≥ 4,5:1 sur le fond dans les deux apparences, texte sur accent ≥ 4,5:1, animation absente sous Reduce Motion.
- App : teinte teal, fond porcelaine/ardoise du détail, risques Nettoyage en ambre/corail en plus du libellé, carte proportionnelle en tons de teal, transition fondu + glissement entre destinations, transition numérique de l’espace libre, surlignage animé de la palette; toutes les animations passent par `accessibilityReduceMotion`. `⌘,` ouvre Réglages; barre latérale élargie (libellé FR « Vue d’ensemble » tronqué observé puis corrigé); feuille Réglages bornée en hauteur. La sélection de la barre latérale suit l’accent système macOS de l’utilisateur.
- Site : `site.css` suit la même direction (couleurs, rayons 9/14 px, apparition échelonnée, survol des cartes, halo teal lent), contrat reduced-motion inchangé et renforcé (délais et répétitions neutralisés). Observé dans Chrome en mode sombre; largeur mobile réelle et Lighthouse non relancés.
- `make qualify` passe. Aucun statut ne change : Dynamic Type, VoiceOver, contraste de tous les états et Reduce Motion réel restent à qualifier.

### Direction artistique — vérifications clair/sombre et largeur réduite — 27-09-2026

- Override fixture `CORETEND_TEST_APPEARANCE=light|dark`, actif uniquement avec un profil de test (test AppShell), pour qualifier l’apparence sans modifier le réglage de l’hôte. App Release observée en sombre sur Nettoyage et Performances : fond ardoise, accent teal éclairci, ambre/corail éclaircis, textes lisibles.
- Site à 500 px (largeur minimale d’une fenêtre Chrome headless; 390 px non atteignable ainsi) : deux défauts corrigés. L’entrée animait l’opacité depuis 0, laissant le contenu invisible tant que l’animation n’avait pas joué; elle n’anime plus que la translation. Le halo débordait et élargissait la page; il est désormais borné dans `main`.
- `make qualify` passe. Reduce Motion réel, Dynamic Type et VoiceOver restent non qualifiés.

### NFR-11 — smoke du site après refonte — 27-09-2026

- Chrome DevTools local a relancé Lighthouse mobile navigation sur 11 routes après refonte Porcelain / Slate / Teal et génération des meta descriptions. Chaque route obtient Accessibilité 100, Bonnes pratiques 100, Agentic Browsing 100 et SEO 60; les dix routes contenu passent 42 audits chacune, la page de choix de langue 35.
- Les dix routes EN/FR ont été vérifiées après refonte à 640 × 900 puis 320 × 800 CSS px (DPR 1). `lang` correct, scrollWidth document/corps égal à la largeur, meta description non vide. À 320 px, premier Tab focalise lien `#main` traduit; cible présente et contour `solid 3px`.
- Ces vues sont des émulées viewport, pas un vrai zoom navigateur/écran physique. Zoom réel, VoiceOver, Dynamic Type, contraste tous états, reduced-motion runtime, headers déployés et second navigateur restent ouverts. NFR-11 reste PARTIEL; aucun statut ne change.

### P3 — lot 3.9 — 28-09-2026

- Réglages Serre, palette et icône pousse relus en fixture FR/EN clair/sombre ; accords des
  exclusions et événements diagnostic corrigés, nombres `ProductFormat`. Preuves et limites :
  `Documentation/Evidence/P3-39-2026-09-28.md`.
- Le panneau MenuBarExtra n’a pas été obtenu par automatisation ; navigation du menu, import/export
  natifs restent à la recette groupée ; changement FR → EN → FR et état vide de palette observés en fixture. Aucun statut promu.

### P3 — lot 3.10 — 28-09-2026

- Site Serre avec vitrine réelle et 24 captures FR/EN clair/sombre, provenance et limites.
  `make capture-screens` : 44/44 ; `make build-site site-check` PASS. Contrôle des images
  locales/alt renforcé, contenu jamais masqué par l’animation d’entrée, commandes Développeur
  groupées avec leur paragraphe.
- Chrome isolé : dix pages × trois variantes, 30 contrôles sans débordement horizontal,
  images chargées, langue correcte, sans scripts ; Reduce Motion émulé.
  Preuves : `Documentation/Evidence/P3-310-2026-09-28.md`. Aucun statut promu.

### P3 — livraison poussée, arrêt avant G3 — 28-09-2026

- `next` poussé à `b923f013` (3.9 `4e573a1d`, complément `53dfac36`, 3.10 `b923f013`).
- `make qualify` final PASS, code 0 ; `git diff --check` PASS. CI GitHub `qualify` sur
  `b923f013` PASS, terminé à 09:44:37 UTC. Registre : Must 3/78, Should 0/11 VÉRIFIÉ,
  inchangé. Recette groupée P3 due avant G3 ; aucun démarrage P4.

### G3 acceptée ; P4 lot 4.1 préparé — 28-09-2026

- Mainteneur : « validé, continue » après la recette groupée P3 ; G3 passée, P4 autorisée.
  Aucun détail d’observation supplémentaire, aucun statut de traceabilité promu.
- Lot 4.1 : revue des composants d’accessibilité et calcul des contrastes RGB exécutés ;
  protocole humain par surface dans `Documentation/Evidence/Accessibility.md`.
  Focus individuel Rechercher/Réglages à observer ; aucun défaut runtime affirmé.
- VoiceOver parlé, zoom/texte agrandi et Reduce Motion/Transparency système non lancés
  par l’agent. NFR-07 PARTIEL ; lot 4.1 ouvert jusqu’à recette humaine, G4 non passée.
- Vérification de préparation : `make qualify` PASS (code 0), `git diff --check` PASS.


### P4 — 4.1 accepté, 4.2 limité aux hôtes disponibles — 28-09-2026

- Mainteneur : « validé, continue chaque lot/phase/recette une par une » ; 4.1 accepté,
  sans observation détaillée supplémentaire. NFR-07 reste PARTIEL.
- Seul MacBook Air M1 sous macOS 27 disponible, confirmé par le mainteneur. Paquet arm64,
  minimum déclaré 14.0, structure et lancement isolé PASS sur macOS 27.0 (26A428).
  Artefact et preuves dans `Documentation/ReleaseEvidence.md`, section P4 4.2.
- macOS 14 et second Mac NON LANCÉS ; NFR-08 PARTIEL. Résultat limité de 4.2 à accepter
  avant 4.3 ; G4 non passée.
- `make qualify` PASS (code 0), `make traceability` et `git diff --check` PASS.


### P4 — 4.2 accepté avec réserve, lot 4.3 livré — 28-09-2026

- Mainteneur : « continue » après le résultat limité de 4.2 ; réserve des hôtes conservée.
- Benchmarks CLI uniform/mixed reproductibles et JSON, sonde de fenêtre app en cinq fixtures.
  Médians chauds wall 0,873/1,069 s ; RSS maximale médiane 74,08/81,45 MiB.
  Fenêtre app médiane 0,469 s, RSS maximum échantillonné 98,63 MiB.
- Corpus varié synthétique documenté, cinq budgets locaux proposés après mesure (2× référence
  arrondie). Données brutes et réserves dans PerformanceBaseline. Aucun code produit optimisé.
- Explorer : progression jusqu’à 9 875 fichiers, puis erreur AX -10000 ; fin non observée.
  Réessai resté à l’état initial, sélection non confirmée. Pas de preuve de temps total natif.
- `make qualify` PASS (code 0) ; seuils et résultat limité soumis à recette. NFR-09 PARTIEL,
  aucun statut promu ; arrêt avant 4.4, G4 non passée.
- Vérification finale : `make qualify` code 0, `make traceability` et `git diff --check` PASS.
