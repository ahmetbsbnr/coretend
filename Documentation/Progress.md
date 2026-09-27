# Reconstruction progress

**Relevé :** 2026-09-27. **État :** reconstruction en cours, non finalisée. Derniers jalons fusionnés : favoris/récents SQLite v4, palette clavier bilingue et écriture batch des récents (PR #40–#44). UI macOS native et VoiceOver non qualifiés. Cahier et plan approuvés; développement sur lignée `next` du dépôt public historique. Le dépôt greenfield initial `rebuild/` reste copie locale de provenance.

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
- Installateur local prend source et dossier destination explicites, refuse symlinks et bundle existant, stage dans le volume cible puis déplace sans écraser. Smoke synthétique et install du vrai bundle release dans HOME fixture passent; aucune app lancée. FR-14 reste PARTIEL avant lancement, retrait documenté en conditions testées, et gate compatibilité/signature.
- CLI compilable : `scan --root` explicite, `record list --store` explicite et lecture seule, help/version honnête. Scan distingue succès complet (0), résultat partiel (2), erreur commande/store (1), annulation (130); JSON donne `files`, `issues`, `complete`. Tests fixtures couvrent racine manquante et scan complet. FR-13 reste PARTIEL : parité aide/localisation et validation CLI complète restent ouvertes.
- Site statique EN/FR, manifeste 51 capacités, CSP, navigation sémantique, sans scripts ni analytics; tests de routes, liens, langues, contenu manifest.
- Cahier utilisateur, développeur, confidentialité, accessibilité, données, migration, CLI et release evidence présents.
- `make qualify` passe sur `next` après l’ajout de l’historique Performance : contrôles site/traçabilité/sûreté, tests XCTest et builds app + CLI. Tests Persistence ciblés 14/14 passent. `make package-local verify-package` avait passé dans `rebuild/` avant migration; ancien ZIP unsigned SHA-256 `8a0cb259df23e7324866201be51026e78989b3f11464c7d876f92b89b589c984`. Aucun test n’utilise le vrai store ou la vraie Corbeille.

## En cours ou non livré

- Tests UI d’accessibilité et de parcours restent à construire. L’accès Trash natif n’a pas été exécuté sur de vraies données.
- Record UI, filtres, CSV/JSON et clear history livrés; les parcours Duplicates/Cleanup écrivent propositions, approbations, annulations, succès/échecs. Diagnostic expurgé couvert par test de contrat. Retention et tests UI du parcours restent à faire.
- Migrations : schéma v1/v2→v3 avec fixtures; import v1 prefs copy-only livré pour format synthétique reconnu. Formats historiques alternatifs, sauvegarde/interruption forcée et analyse migration UI plus complète restent ouverts.
- Explore : carte proportionnelle, recherche, tri, Quick Look sur fichier choisi, filtre ≥1 Gio d’octets alloués connus et filtre âge de 365 jours livrés. Le critère « ancien » affiche son instant limite ISO et fuseau; mesures/dates inconnues sont exclues. Tests ScanCore couvrent seuil inclusif, valeur inconnue et cutoff exact. Doublons/Images similaires proposent Quick Look. Prise en charge cloud reste non livrée. Images similaires restent partielles (heuristique non calibrée, corpus et accessibilité à vérifier).
- Réglages explique accès aux seuls dossiers choisis, causes pratiques de refus/indisponibilité, reprise par nouveau choix, et limites des protections macOS; aucune demande d’Accès complet au disque. Cela améliore l’aide mais FR-10 reste partiel : aucune sonde exhaustive par permission ni deep link système.
- Les commandes Quick Look d’Explorer/Doublons/Image similaires annoncent le nom du fichier et leur action en hints EN/FR. NFR-07 devient PARTIEL; noms accessibles implémentés, mais clavier/focus, Dynamic Type, contraste, Reduce Motion et essais VoiceOver manuels restent à qualifier.
- Diagnostic Réglages montre désormais le JSON expurgé exact (texte sélectionnable) avant choix de destination; l’annulation ne lance pas l’exporteur. Test Persistence confirme omission des chemins/détails sur fixture. FR-21 et NFR-05 restent PARTIELS jusqu’au parcours UI, preuve d’annulation/export et limites d’effacement documentées.
- Audit sécurité rejette maintenant imports/APIs réseau Swift courants et références aux SDK analytics connus dans `Sources/`. NFR-04 est PARTIEL : vérification statique seulement; pas de capture réseau en exécution ni revue indépendante.
- Applications discovery et signal code-signature livrés; revue consultative des reliquats ajoutée sur un dossier choisi avec correspondance exacte bundle ID, sans attribution confirmée ni action sur ces reliquats. Le déplacement confirmé du seul bundle `.app` vers la Corbeille est relié à SafetyCore et au journal; désinstallation complète des éléments associés/hérités et source de mise à jour non livrées. Performance conserve des points locaux de charge; présentation graphique améliorée en marqueurs datés, axes lisibles et dernière valeur accessible, sans interpolation de données. Qualification UI native toujours ouverte.
- Le site EN/FR explique désormais favoris explicites, récents opt-in (off par défaut, maximum 100), recherche ⌘K et conservation locale des chemins/tailles. Entrées sauvegardées retirables; pas de synchronisation réseau. Génération et contrôles statiques passent; FR-15 demeure partiel jusqu’à revue navigateur/accessibilité et déploiement.
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

- Homepage française: Lighthouse Accessibilité 100, Bonnes pratiques 100. Tab atteint le lien d’évitement avec contour visible 3 px; vue d’accessibilité expose les régions principales. À 640 px CSS (approximation d’un viewport 1280 px à 200 %), aucun débordement horizontal.
- Audit et limites détaillés dans `Documentation/Evidence/SiteAccessibilitySmoke.md`. Réduction du mouvement uniquement observée dans CSS, pas émulée au runtime; autres routes, navigateurs et vraie commande zoom restent à vérifier. NFR-11 passe à `PARTIEL`, pas vérifié.

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

- NFR-10 architecture gate added to `make qualify`: it reads `swift package dump-package` and checks Swift tools ≥6.0, macOS ≥14.0, no external SwiftPM package dependencies, and no SafetyCore/Persistence dependency from ScanCore. Four synthetic contract tests cover compliant graph and rejection cases; existing safety audit checks the production Trash boundary. NFR-10 moves from `EN_COURS` to `PARTIEL`; independent architecture review is still open.
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
- Comptage courant : 78 Must `PARTIEL` / aucun clos; pondération indicative à 50 % Must et 46 % registre entier (83 `PARTIEL`, 2 `EN_COURS`, 6 `À_CONSTRUIRE`). UI, accessibilité, hôtes, vraie Corbeille et release demandent preuves restantes.


### FR-08 — allocations physiques uniques — 2026-09-27

- ScanCore conserve device/inode comme identité d’allocation observée. Les lignes Explorer gardent tailles logiques/allouées par chemin; treemap déduplique les chemins hard linkés par identité, sélectionne le chemin visible lexicographiquement premier et indique des allocations distinctes plutôt que des fichiers. Les mesures inconnues restent exclues.
- Fixtures synthétiques valident deux chemins partageant une identité physique, une seule aire de treemap pour eux, et un fichier sparse de 8 Mio dont l’allocation observée est inférieure à la taille logique. `swift test --filter 'ScanCoreTests/testHardLinkResultsSharePhysicalAllocationIdentity|TreemapLayoutTests/testHardLinksContributePhysicalAllocationOnlyOnce|ScanCoreTests/testSparseFixtureKeepsLogicalAndAllocatedSizesDistinct'` passe.
- FR-08 reste `PARTIEL` : rendu visuel/VoiceOver, fournisseurs cloud et couverture de systèmes de fichiers restent à qualifier. Aucun comportement utilisateur natif n’est déclaré vérifié. PR #55 mise à jour sur `356d7c7`; revue indépendante sans blocage et CI `qualify` réussie.
