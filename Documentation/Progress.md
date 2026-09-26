# Reconstruction progress

**Relevé :** 2026-09-26. **État :** reconstruction en cours, non finalisée. Cahier et plan approuvés; travail actif sur `next`, branche issue du dépôt public historique. Le dépôt greenfield initial `rebuild/` reste copie locale de provenance.

## Livré et prouvé

- Cahier complet : QQOQCCP, 8 destinations, 26 FR, 14 NFR, MoSCoW, RACI, architecture et risques; plan d’exécution par 8 tranches.
- Dépôt Swift 6 vide au départ; cahier, baseline et plan conservés sous `Documentation/Project/`.
- ProductContract catalogue les 51 IDs de capacité et huit destinations.
- SafetyCore : capacités à durée courte, revalidation d’existence/chemin/volume/inode/allowlist; adapter prod uniquement `FileManager.trashItem`; fake Trash dans Tests. Cinq tests sur racine refusée, règle inconnue, identité changée, expiration, préservation à l’échec et déplacement fixture.
- SQLite schema v3 : événements, préférences/imports et mesures Performance séparés; migrations transactionnelles v1/v2→v3, URL injectée; mode CLI read-only. Tests sous répertoires temporaires.
- ScanCore : parcours explicite, exclusions, symlinks exclus, tailles logique/allouée inconnues conservées; tests de lecture seule sur fixtures.
- Doublons exacts : bucket par taille puis SHA-256 par blocs, déduplication d’inodes, un exemplaire proposé à garder; tests sur copies identiques, contenus distincts et hard links.
- App SwiftUI compilable, huit routes EN/FR. Explore, Duplicates et Cleanup ont sélection de dossier et scan. Duplicates/Cleanup relient sélection manuelle → proposition journalisée → revue nominative → confirmation → validation → adapter Trash; le keeper n’est jamais sélectionnable, sélection vide par défaut, refus/cancel distincts. Actions non lancées sur l’hôte.
- Applications inventorie les `.app` du seul dossier explicitement choisi et affiche disponibilité de mise à jour inconnue; Integrity inspecte localement le statut de signature du seul bundle choisi sans verdict malware.
- Exclusions stockées SQLite et utilisées dans les trois scans; import legacy prefs JSON v1 opt-in, allowlist/digest/trace/idempotence/source intact; onboarding, diagnostic sans chemins/détails et preview d’export ajoutés.
- Explore ajoute recherche nom/dossier, tri nom/date/taille locale et carte proportionnelle exacte des seuls octets alloués connus; layout couvert par tests.
- Script crée un `.app` + ZIP local unsigned sous `Artifacts/`; structure lue dans le bundle, aucune installation ou ouverture Finder réalisée.
- CLI compilable : `scan --root` explicite, `record list --store` explicite et lecture seule, help/version honnête; parsing testé.
- Site statique EN/FR, manifeste 51 capacités, CSP, navigation sémantique, sans scripts ni analytics; tests de routes, liens, langues, contenu manifest.
- Cahier utilisateur, développeur, confidentialité, accessibilité, données, migration, CLI et release evidence présents.
- `make qualify` passe sur `next` après l’ajout de l’historique Performance : contrôles site/traçabilité/sûreté, tests XCTest et builds app + CLI. Tests Persistence ciblés 14/14 passent. `make package-local verify-package` avait passé dans `rebuild/` avant migration; ancien ZIP unsigned SHA-256 `8a0cb259df23e7324866201be51026e78989b3f11464c7d876f92b89b589c984`. Aucun test n’utilise le vrai store ou la vraie Corbeille.

## En cours ou non livré

- Tests UI d’accessibilité et de parcours restent à construire. L’accès Trash natif n’a pas été exécuté sur de vraies données.
- Record UI, filtres, CSV/JSON et clear history livrés; les parcours Duplicates/Cleanup écrivent propositions, approbations, annulations, succès/échecs. Diagnostic expurgé couvert par test de contrat. Retention et tests UI du parcours restent à faire.
- Migrations : schéma v1/v2→v3 avec fixtures; import v1 prefs copy-only livré pour format synthétique reconnu. Formats historiques alternatifs, sauvegarde/interruption forcée et analyse migration UI plus complète restent ouverts.
- Explore : carte proportionnelle, recherche et tri livrés; gros/anciens presets, cloud et Quick Look restent non livrés. Images similaires sont intégrées au parcours Doublons, mais encore partielles (heuristique non calibrée, corpus et accessibilité à vérifier).
- Applications discovery et signal code-signature livrés; revue consultative des reliquats ajoutée sur un dossier choisi avec correspondance exacte bundle ID, sans attribution confirmée ni action sur ces reliquats. Le déplacement confirmé du seul bundle `.app` vers la Corbeille est relié à SafetyCore et au journal; désinstallation complète des éléments associés/hérités et source de mise à jour non livrées. Performance a un historique local de points de charge système, mais pas de qualification UI native; états d’accès, menu bar, favoris/récents et palette restent incomplets. Onboarding de premier lancement livré.
- CLI n’a pas de test end-to-end qui invoque un scan fixture ni parité complète d’aide/localisation.
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
