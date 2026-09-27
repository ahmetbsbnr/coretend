# Passation complète — CoreTend Next

**État au 27-09-2026.** Reconstruction active, pas finalisée, aucune release publique. Dépôt `ahmetbsbnr/coretend`; worktree `next/`; base distante `origin/next` à `55e8628`. Branche courante `feat/reconstruction-open-musts`, PR brouillon #55 ouverte vers `next`; dernier head qualifié `356d7c7`. Dernière tranche code : FR-08 hard links/sparse; `make qualify` local et CI GitHub passent. Aucun merge/tag/release/publication.

## État immédiat

- PR #46–#52 fusionnées; tous les checks GitHub `qualify` requis réussissent. Protection `next` exige `qualify` strict; force-push et suppression de branche interdits. Aperçus Vercel ont atteint leur quota sur les PR récentes; ces contrôles ne sont pas requis par la protection. Aucun déploiement/publication CoreTend effectué.
- Cahier des charges complet et approuvé : QQOQCCP, MoSCoW, RACI, objectifs, exigences, architecture, risques et séquence. Voir `Documentation/Project/Cahier-des-charges.md`.
- Traceability contient 40 FR/NFR + 51 capacités; 91 statuts renseignés. La ligne NFR-07 a été réalignée sur les colonnes CSV; statut PARTIEL tant que revue clavier/VoiceOver/Dynamic Type/contraste/Reduce Motion n’est pas faite.
- App SwiftUI macOS, CLI Swift, persistance SQLite, modules métier, site statique EN/FR et scripts de paquet sont présents. Résultats/états restent partiels selon `Documentation/Traceability.csv`; aucun jalon ne signifie produit final.
- Dernière qualification locale : `make qualify` le 27-09 après la tranche FR-08; elle couvre génération/site, intégrité et dates du registre CSV, audits sûreté/architecture, install/uninstall fixtures, smoke runtime Release isolé, XCTest, builds Debug App/CLI et subprocess CLI/SIGINT. Le CI GitHub `qualify` passe sur le head `356d7c7`. Aucune UI native/VoiceOver n’est qualifiée par ce gate.
- Paquet courant : `Artifacts/CoreTend-local-unsigned.zip`, arm64, produit depuis le code app `b0287bf`. SHA-256 `94503244830030785388e6ea2359dc844af22d719d5e82729f14408f1697a299`. `make package-local verify-package` passe; vérification limitée à Info.plist, archive et Mach-O. Non lancé, installé sur le Mac, signé, notarié ou publié. Preuve dans `Documentation/ReleaseEvidence.md`.
- Copie greenfield historique `rebuild/` conservée localement comme provenance. Passation/documents 1.x archivés sous `Documentation/Archive/Legacy-Reconstruction/`; ils ne décrivent pas le code actuel.
- État courant après reprise du 27-09-2026 : 91 lignes, 83 `PARTIEL`, 2 `EN_COURS`, 6 `À_CONSTRUIRE`. Les 78 Must sont `PARTIEL` (aucun `VÉRIFIÉ`). Estimation indicative pondérée (VÉRIFIÉ=100 %, PARTIEL=50 %, EN_COURS=25 %, À_CONSTRUIRE=0 %) : 50 % des Must, 46 % du registre. Ce n’est pas un indicateur officiel; critères UI/macOS, compatibilité et distribution restent ouverts.

## Jalons locaux depuis la dernière passation

- **Task 15 (`fdc6350`) — fixture backup SQLite** : sauvegarde v3 par Online Backup API, `integrity_check`, restauration vers un fichier séparé avant migration, préservation des lignes en v3 puis migration à v5 après retrait de la collision synthétique. Source corrompue rejetée sans destination partielle. Procédure locale hors ligne documentée; aucune vraie base touchée. Revue indépendante sans finding; test ciblé et `make qualify` passent.
- **Task 16 (`6da08a0`) — annulation bornée ScanCore** : lecteur fixture bloque la première lecture de métadonnées, annulation du consommateur, worker joint par hook interne; deuxième fichier non lu, aucun événement `finished`, arbre inchangé. Revue indépendante approuve; `make qualify` passe. Annulation UI native reste à qualifier.
- **Task 17 (`6eba339`) — provenance des mesures** : Overview/Performances affichent source de chaque métrique (`/`, charge 1 min, `ProcessInfo`), date mesurée et capacité inconnue au lieu d’omission. Note EN/FR écarte diagnostic de santé et promesse d’espace récupéré; tests catalogues bilingues. Revue indépendante sans finding; `make qualify` passe. FR-03 reste PARTIEL jusqu’à qualification UI native.
- **Task 18 (`65b9195`) — exclusion après réouverture** : test écrit des exclusions normalisées dans DB temporaire, libère le store puis rouvre même URL; chemins restent présents et triés. Fixtures ScanCore vérifient racine/sous-arbre exclus. Revue indépendante approuve; `make qualify` passe. Settings et relance app restent à qualifier; FR-04 PARTIEL.
- **Task 19 (`29154a5`) — racine symlink refusée** : PathValidator exige un vrai dossier sur le composant final de chaque racine autorisée avant de canonicaliser et valider volume/confinement. Test temporaire rouge/vert; priorité à l’échec identité racine conservée à l’exécution. Revue indépendante sans finding; `make qualify` passe. TOCTOU étroit et parcours natif restent ouverts.

- Traceability qualifiée localement : NFR-02 et NFR-03 désormais PARTIEL avec preuves fixtures/adapter Trash et audit; NFR-08 PARTIEL, machine observée arm64/macOS 27.0, aucune matrice multi-hôte. Aucun ne vaut clôture.
- `Documentation/Project/Remaining-musts-plan.md` reste un plan local non suivi à préserver sans l’ajouter aux commits.

- **Task 20 — FR-07 keeper protégé** : test Domain temporaire refuse une revue incluant keeper et deux copies; octets préservés et Corbeille fixture vide. Test ciblé et `make qualify` passent.
- Smoke FR-14 isolé : binaire debug lancé avec `CFFIXED_USER_HOME` temporaire; processus vivant 8 s et store créé exclusivement sous ce profil. GUI visible, bundle emballé, accessibilité restent non qualifiés; preuve dans ReleaseEvidence.
- **Task 21 — FR-07 keeper revalidé par action** : DuplicateScanView transmet keeper de chaque groupe sélectionné; FileActionService capture son identité et la revérifie avant chaque Trash. Fixture supprime le keeper après premier déplacement; copie suivante reste, second appel Trash bloqué et échec journalisé. `make qualify` passe. Le TOCTOU avant l’API Trash et UI native restent ouverts.

- **Task 22 — NFR-09 baseline synthétique** : `make benchmark-scan` mesure CLI Release sur 10 000 fichiers. Warm median 0,913 s wall / 0,979 s CPU / 74,18 MiB RSS max sur arm64/macOS 27.0. Aucun budget choisi; mesures UI/corpus réel restent ouvertes. Détails dans `Documentation/Evidence/PerformanceBaseline.md`. `make qualify` passe.
- **Task 10 — Integrity LaunchAgents (`569cc4d`, `fcbb687`)** : revue consultative plist dans seul dossier explicitement choisi, plafonds 500 candidats/1 Mio, lecture sans suivre symlinks et ancrage au descripteur de racine; erreurs visibles. Tests synthétiques couvrent plist valide/malformé/trop grand, symlink, limite et remplacement de racine. N’affirme ni activité ni sûreté; `integrity.loginitems` reste PARTIEL avant qualification native et intégration aux services système.
- **NFR-13 — builds Release** : `swift build -c release --product CoreTendApp` et `CoreTendCLI` réussissent sans avertissement sur arm64/macOS 27.0. Dépendance externe absente de Package.swift; pas de `Package.resolved`. NFR-13 reste PARTIEL faute de preuve de reproductibilité entre builds propres et hôtes.
- **FR-10 — erreurs de racine distinctes** : `permission_denied` affiche un refus explicite, `missing` l’absence de racine, `metadata_unavailable` la disponibilité indéterminée. Test AppShell bilingue rouge/vert; `make qualify` passe. Aucun diagnostic TCC/FDA exhaustif ni qualification UI native.
- **NFR-11 — smoke navigateur site local** : Lighthouse sur homepage FR donne Accessibilité 100/Bonnes pratiques 100; clavier montre skip-link et contour visible; largeur 640 CSS sans débordement. Réduction du mouvement non émulée, zoom réel et autres pages non vérifiés. Détails et limites dans `Documentation/Evidence/SiteAccessibilitySmoke.md`.
- **FR-13 — contrat CLI** : script subprocess vérifie help/usage/store inaccessible/scan partiel et codes 0/1/2 avec stderr stable; paths/store non créés implicitement. Scan Control-C sur 30 000 fichiers temporaires sort 130, pas terminaison POSIX `-2`. Intégré à `make qualify`, matrice passe Debug et Release. Parseur distingue store manquant et argument invalide; aide/localisation CLI restent à compléter.

## Jalons récents intégrés

- **PR #46 — backend import et présentation Performance (`abb0d58`)** : import prefs legacy ouvre avec `O_NONBLOCK | O_NOFOLLOW`; lit un fichier régulier seulement; revalide device, inode, mode, taille, mtime et ctime après lecture. FIFO est rejeté sans blocage; source reste intacte. Test fixture FIFO et test d’import idempotent passent. Premier raffinement du graphique Performance.
- **PR #47 — site et confidentialité (`c87d01d`)** : contenu EN/FR décrit palette ⌘K, favoris explicites, récents opt-in (off par défaut, 100 max), chemins/dernières tailles mémorisés localement et retrait des entrées. `make build-site site-check` passe. FR-15 reste PARTIEL : revue navigateur, a11y et déploiement réel non faits.
- **PR #48 — validation SQLite (`574e646`)** : journal refuse timestamps non finis avant insert; Performance refuse date de mesure ou horloge de retention non finie avant transaction/pruning. Trois tests couvrent +∞/NaN et absence d’écriture. `make qualify` passe.
- **PR #49 — axe du graphique (`5408782`)** : axe X affiche jour/mois/heure. Échantillons demeurent des points mesurés; pas d’interpolation.
- **PR #50 — sélection graphique (`b0287bf`)** : curseur résolu au point connu le plus proche; égalité choisit observation la plus récente; inconnues et curseur invalide ignorés. Repère et lecture valeur/date montrent mesure réelle. Tests Domain : 2/2. UI souris/clavier/VoiceOver native reste à vérifier.
- **PR #51 et #52 (`c4b1077`, `d61e501`)** : passation et preuve de paquet synchronisées avec code/artefact.

Jalons antérieurs restent détaillés dans `Documentation/Progress.md` et dans sections historiques du présent fichier seulement si encore pertinentes. Références de code, tests et statuts font foi dans Traceability.

## Architecture et comportement actuels

- Swift 6, SwiftPM, macOS 14+; code runtime sans dépendances SwiftPM externes. Cible d’artefact vérifiée actuellement arm64.
- Couches : `ProductContract` inventaire; `AppShell` destinations/palette; `ScanCore` scans lecture seule; `SafetyCore` capacités d’action bornées; `Persistence` SQLite/migrations; `Domain` application des contrats; `CoreTendApp` SwiftUI; `CLIContract`/`CoreTendCLI` lecture seule.
- Huit destinations : Overview, Record, Cleanup, Explore, Duplicates, Applications, Integrity, Performance. Interface et site en français/anglais.
- SQLite schema v5 : événements avec failure code nullable, préférences/exclusions/imports, Performance, favoris/récents. Migrations transactionnelles v1–v5; store URL injectable. CLI ouverte explicitement en lecture seule. Favoris exigent clic explicite. Récents désactivés par défaut, maximum 100, écritures en batch. Aucun chemin mémorisé ne rouvre automatiquement un fichier.
- Mutations fichier seulement via SafetyCore et adaptation macOS Trash; scans ne changent pas l’arbre choisi. Tests utilisent fixtures temporaires et fausse Corbeille. Pas de suppression permanente.
- App associée : inventaire `.app` seulement sous racine choisie; recherche de reliquats par identifiant exact dans autre dossier choisi, consultation seulement. Attribution de propriété pas prouvée. Action existante déplace uniquement bundle `.app` choisi avec revue/confirmation; données associées/héritées restent intactes.
- Réseau runtime limité par conception; audit statique bloque API cliente courante et SDK analytiques connus. NFR-04 reste PARTIEL sans capture trafic runtime et revue indépendante.

## Gaps et limites à garder visibles

La traçabilité est source de vérité par exigence. Elle suit 40 FR/NFR et 51 capacités; Must ont encore états EN_COURS/PARTIEL/À_CONSTRUIRE. Ne convertir aucun statut sans preuves correspondant au critère complet.

- **UI/accessibilité :** lancer/observer app en environnement isolé, vérifier clavier, focus, VoiceOver, Dynamic Type/zoom, contraste, Reduce Motion/Transparency, Quick Look, graphique et états vides/erreur/annulation. FR-01, FR-23, FR-24 et NFR-07 incomplets tant que cette qualification manque.
- **FR-26 Apps :** correspondance de nom/bundle ID n’est pas preuve de propriété. Ne pas supprimer données associées ni héritées; priorité à une méthode d’attribution documentée, contrôlable et sûre avant toute action. Garder parcours consultatif et déplacement bundle seul tant que preuve insuffisante.
- **FR-10 Permissions :** l’aide actuelle explique accès au dossier choisi et récupération; pas de sondes exhaustives TCC/Full Disk Access ni deep links système. Ne pas inférer absence d’élément depuis résultat partiel.
- **FR-14 Distribution :** install smoke en HOME fixture et validation de structure passent; app jamais ouverte. Pas de preuve GUI install/désinstall, signature, notarisation, compatibilité deuxième hôte/version macOS ni release.
- **Données/migration :** import JSON legacy v1 reconnu et copy-only; formats anciens non reconnus. Backup/restauration synthétiques vérifiés; restauration réelle, interruption/reprise élargie et qualification UI restent ouvertes. Effacement SQLite logique, aucune garantie forensique.
- **Applications/Integrity :** aucun contrôle App Store/version update; `SUFeedURL` déclaré seulement. Marqueur quarantine et signature sont des signaux limités, aucun verdict malware/provenance.
- **Features partielles :** images similaires heuristique non calibrée/corpus à établir; classification metadata-only des éléments cloud et revue LaunchAgents sont présentes, sans qualification comportementale générale; menu bar non livrée; certains filtres et usages système encore incomplets; CLI localisation/cas d’annulation restent incomplets.
- **Perf/release :** baseline initiale CLI synthétique existe; startup-to-window, UI/idle et corpus représentatif restent non mesurés; pas de capture réseau runtime; aucune review sécurité indépendante; paquet courant unsigned.

## Ordre de reprise conseillé

1. Reprendre `Documentation/Traceability.csv` et `Documentation/Project/Implementation-plan.md`; choisir un petit Must mesurable et sûr. Priorité : qualification UI/accessibilité sur fixtures/app isolée, puis diagnostic FR-10 et attribution FR-26 sans effacement spéculatif.
2. Pour chaque tranche : ajouter preuve test/fixture, implémenter au plus petit scope, actualiser `Documentation/Progress.md`, Traceability si critère est réellement prouvé, UserGuide/ThreatModel selon besoin, puis ce fichier.
3. Exécuter `make qualify` et `git diff --check`; paquet seulement après jalon app utile avec `make package-local verify-package`; inscrire hash + limites dans ReleaseEvidence.
4. Créer branche depuis `next`; commit, push et PR vers `next`; fusionner après `qualify` verte. Ne pas avancer `main`, tags ou release sans décision/conditions formelles prévues dans repository strategy.
5. Continuer jusqu’à clôture documentée de tous critères de fin du cahier. Ne pas appeler « final » tant que Must, compatibilité, test GUI, accessibilité et distribution restent ouverts.

## Commandes utiles

- `make qualify` — gate local complet : site, traceability, safety audit, install smoke fixture, tests, build App/CLI.
- `make package-local verify-package` — construit et inspecte artefact arm64 unsigned; n’ouvre pas l’app.
- `make verify-install-package` — installation du bundle dans HOME temporaire synthétique; ne lance pas l’app.
- `swift test --filter PersistenceTests` — persistance et migration ciblées.
- `swift test --filter DomainTests` — logique métier, applications et sélection graphique.
- `make build-site site-check` — génération/site statique EN/FR.
- Réaliser `git diff --check`; vérifier `git status --short --branch` avant checkpoint.

## Invariants de sûreté et reprise

- Aucun test contre vrai HOME, store CoreTend utilisateur, fichiers privés ou vraie Corbeille. Utiliser chemins/DB/Trash fixture uniquement.
- Ne jamais lancer app sur profil hôte durant smoke non isolé : elle peut créer store local. Ne jamais ouvrir/inspecter les dossiers utilisateur sans choix explicite requis par parcours.
- Pas de `rm` ou purge permanente, privilège/sudo, accès complet disque sollicité, réseau silencieux, collecte télémétrie ou migration destructive.
- Accès dossier temporaire libéré sur chaque chemin; erreurs/unknown demeurent distincts; ne pas annoncer espace récupéré, propriété des données ou état malware sans preuve.
- Artefact local ignoré par Git. Hash représente ce ZIP précis, pas une release ni signature.

## Fichiers à lire en premier

1. `Documentation/Project/Cahier-des-charges.md` — QQOQCCP, exigences, MoSCoW, RACI, critères de fin.
2. `Documentation/Traceability.csv` — état et preuves exigence/capacité.
3. `Documentation/Project/Implementation-plan.md` — tranches de livraison.
4. `Documentation/Project/Repository-strategy.md` — règles main/next, PR et release.
5. `Documentation/Progress.md`, `Documentation/ReleaseEvidence.md` — jalons récents, validations et hashes.
6. `Documentation/ThreatModel.md`, `Documentation/Accessibility.md`, `Documentation/Project/DataModel.md`, `Documentation/Project/Migration.md` — limites de sûreté, a11y et données.
7. `Documentation/Archive/Legacy-Reconstruction/passation.md` — historique complet ancien projet; contexte seulement, pas état runtime courant.

## Reprise Musts — 27-09-2026

État au début de cette reprise (avant commits `8918503` et suivants), branche `feat/reconstruction-open-musts` depuis `3bd0298`; les statuts et indications de publication du bloc ci-dessous sont historiques.

- CLI : `--lang en|fr` avant commande, défaut anglais. Aide, erreurs et texte scan localisés; JSON et codes de cause stables. Parseur refuse langue invalide/mal placée et arguments surnuméraires de `help`/`version`. Annulation SIGINT vérifiée avant et après fin du flux pour garantir code 130 même si annulation ferme le stream sans événement suivant.
- Signature : Réglages inspecte localement la signature du bundle courant via Security.framework, affiche état/identifiant/équipe disponibles et limites de ce signal en EN/FR.
- Désinstallation locale : dry-run par défaut; app uniquement (`--keep-data`) ou app+base/préférences (`--remove-all`) après confirmation. Données MacCare uniquement avec `--include-legacy`, traitées en dernier. Allowlist stricte, symlinks refusés, aucun sudo. Les tests utilisent un HOME temporaire.
- Isolation du store : deux variables de test obligatoires, HOME et CFFIXED_USER_HOME temporaires concordants; store/home doivent être séparés sous racine temporaire réelle, symlinks refusés. Mauvaise configuration échoue fermée. Tests Persistence et smoke du binaire debug prouvent que seule la base fixture est créée.
- Historique : filtre date 7/30 jours calendaires inclusifs ou tout, filtre type, groupe par date locale et exports CSV/JSON alignés sur filtres. Effacement événementiel préserve exclusions et Performance. Tests fixtures et copies EN/FR ajoutés.
- Traceability : descriptions placeholder de 26 capacités remplacées par critères comportementaux; le checker rejette maintenant les placeholders. Les capacités vérifiées uniquement en code/test gardent statut PARTIEL jusqu’aux qualifications natives restantes.
- Gate après reprise : `make qualify` PASS; builds Release `CoreTendApp` et `CoreTendCLI` PASS; matrice subprocess/SIGINT Release PASS; traceability, safety audit, désinstallateur fixture et `git diff --check` PASS. App runtime isolation smoke debug PASS sous HOME/CFFIXED_USER_HOME temporaires. Aucun HOME/store réel touché.
- Registre à cette étape antérieure : 91 lignes; les statuts Must n’avaient pas encore été réconciliés. Voir le comptage courant en tête de passation; aucun Must n’est qualifié de bout en bout.
- Restent : parcours SwiftUI/VoiceOver/focus, vrai Trash/UI d’action, matrice autre macOS/hôte, release/distribution GUI/sig/notarisation, compatibilité et preuve NFR-14; FR-10/FDA exhaustive; attribution prudente Apps et quelques écarts `EN_COURS`. Voir `Documentation/Traceability.csv` pour owners/écarts détaillés.
- À cette étape historique : pas encore de commit/push/PR. Aucun merge/tag/publication. Préserver `Documentation/Project/Remaining-musts-plan.md` local, `.superpowers/sdd/Remaining-musts-plan/`, artefacts de paquet existants et ce fichier.

### NFR-10 — gate d’architecture SwiftPM — 27-09-2026

- `Scripts/check_architecture.py` valide le graphe évalué par SwiftPM : outils Swift ≥6, cible macOS ≥14, zéro package externe et ScanCore sans dépendance SafetyCore/Persistence. `Scripts/test_architecture.py` couvre graphe admis et trois régressions refusées; `make architecture-audit` passe.
- Le gate entre dans `make qualify`. L’audit de sûreté existant reste responsable de la frontière API Trash. NFR-10 passe de `EN_COURS` à `PARTIEL`; revue indépendante d’architecture non réalisée.

### FR-14 — smoke runtime Release isolé — 27-09-2026

- `Scripts/test_app_runtime_isolation.py` enveloppe le binaire Release dans un `.app` temporaire; `HOME`, `CFFIXED_USER_HOME`, `TMPDIR` et le store explicitement autorisé résident sous une racine fixture. Le processus doit rester vivant huit secondes et créer SQLite uniquement dans le store fixture.
- `make app-runtime-smoke` passe et entre dans `make qualify`. `Artifacts/` n’est ni remplacé ni modifié. Cela prouve le démarrage isolé du binaire Release, pas l’affichage d’une fenêtre via Finder; signature/notarisation, parcours visible et hôte macOS minimum restent ouverts. FR-14 demeure `PARTIEL`.

### NFR-12 — gate de complétude des preuves Must — 27-09-2026

- `check_traceability.py` exige maintenant pour chacune des 78 lignes Must : code, tests, preuve datée, owner; chaque référence de fichier dans `code`/`tests` doit exister. Le gate a d’abord échoué sur FR-05 sans preuve, puis passe après réconciliation des preuves disponibles et lacunes restantes.
- Toutes les lignes Must sont désormais `PARTIEL` (78), aucune `EN_COURS`/`À_CONSTRUIRE`/`VÉRIFIÉ`. Ce statut ne clôt pas les critères; les gaps visibles restent notamment UI/accessibilité native, vraie Corbeille, FDA exhaustive, compatibilité macOS 14/autre hôte, attribution des données Apps et release. Avancement pondéré estimé à 50 % des Must et 46 % du registre (PARTIEL=50 %, EN_COURS=25 %, À_CONSTRUIRE=0 %, VÉRIFIÉ=100 %). Chiffre indicatif uniquement; aucun Must n’est vérifié de bout en bout.
- L’onboarding a des clés `ProductCopy` EN/FR pour portée, confidentialité et action de démarrage; test rouge/vert AppShell couvre dossiers choisis, scans lecture seule, confirmation Corbeille et politique FDA. Sheet/interaction première ouverture restent à qualifier.
- `make qualify` a repassé après réconciliation du registre et extraction/tests d’onboarding; code sortie 0. Il inclut smoke Release isolé, XCTest, builds App/CLI, audits et CLI SIGINT. `git diff --check` et `check_traceability.py` passent. Aucun artefact dans `Artifacts/` remplacé; plan `Documentation/Project/Remaining-musts-plan.md` préservé et non suivi.


### Correctifs de revue et gate — 27-09-2026

- Finding désinstallateur : ajout fixture `Library` symlinkée vers arbre temporaire extérieur avec base existante. Le test passe sans changement production : `check_target` canonicalise le parent complet via `cd -P`, détecte l’écart et refuse avant retrait. Le risque TOCTOU entre validation et `rm` reste distinct et n’est pas clos par cette fixture.
- CLI : `version` localise maintenant son statut EN/FR. Test unitaire rouge/vert et subprocess sur binaire réel intégrés au gate. FR-13 reste `PARTIEL`.
- Traçabilité : chaque Must exige une date ISO valide ancrée en début de preuve et identique à la date `Relevé` de `Progress.md`. Fixtures rejettent date périmée, calendrier invalide et date non ancrée. NFR-13 normalisée.
- `make qualify` passe après ces changements; `git diff --check` passe. `Documentation/Project/Remaining-musts-plan.md` reste fichier local non suivi à préserver.


### État de branche actuel — 27-09-2026

- Commits de reprise : `8918503`, `47ec49e`, `1dec13b`, `f39cc3f`, `ba6e7a5`, `356d7c7`. Branche poussée sur `origin/feat/reconstruction-open-musts`; PR brouillon #55 vers `next`: https://github.com/ahmetbsbnr/coretend/pull/55.
- CI GitHub `qualify` de PR #55 réussie le 27-09; contrôles Vercel également verts. PR reste ouverte en brouillon. Aucun merge/tag/release/publication.
- L’unique changement local non suivi `Documentation/Project/Remaining-musts-plan.md` est préservé et absent des commits.


### FR-08 — déduplication des allocations treemap — 27-09-2026

- `ScanResult` porte identité device/inode issue de `lstat`; `TreemapLayout` déduplique seulement la carte, choisit de façon stable le chemin visible lexicographiquement premier et laisse les mesures ligne inchangées. Libellé bilingue parle d’allocations distinctes.
- Tests ScanCore : scan d’un hard link expose identité/allocation identiques sur deux chemins; treemap attribue une seule aire à l’inode; fixture sparse distingue 8 Mio logiques et allocation locale plus faible. Tests ciblés et `make qualify` passent. `git diff --check` passe.
- Le gate de traçabilité couvre aussi les lignes CSV surnuméraires; cette vérification a détecté puis corrigé une colonne décalée dans la preuve FR-08.
- FR-08 reste `PARTIEL` jusqu’aux vérifications native/VoiceOver, cloud et volumes représentatifs. PR #55 mise à jour; revue indépendante sans blocage; CI GitHub qualifie le head `356d7c7`. Le plan local non suivi reste préservé.
