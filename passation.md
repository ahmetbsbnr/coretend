# Passation complète — CoreTend Next

### FR-22 — mesures dans le menu visible — 27-09-2026

- La fenêtre `MenuBarExtra` affiche charge, mémoire, espace libre avec sources, puis type/heure de la dernière activité sans détail ni chemin. Snapshot immédiat et rafraîchissement toutes les 30 s via `.task`; annulation liée à la disparition. Aucune ligne Performance ajoutée; valeurs gardées en mémoire.
- `SQLiteStore.latestActivity()` sélectionne uniquement date/type et un seul événement. Fixtures vérifient ordre du dernier événement; AppShell vérifie arrêt de la boucle après annulation. Build App et tests ciblés passent. Qualification native ouverture/fermeture, activation menu, VoiceOver reste ouverte; FR-22 PARTIEL.
- Registre : 91 lignes, 86 PARTIEL, 3 À_CONSTRUIRE, 2 VÉRIFIÉ. Pondération indicative : 51,3 % Must, 45,5 % Should, 49,5 % global; aucune n’est mesure officielle de complétion.
- `Documentation/Project/Implementation-plan.md` réconcilié : fixtures/code cochés seulement quand présents; qualification native, release, hôtes/revue externes restent explicitement ouverts. Le plan local non suivi `Remaining-musts-plan.md` reste préservé.

### Reprise dev — 27-09-2026

- NFR-13 CI PR #55: source des deltas confirmée — `LC_UUID` aléatoire et `N_OSO.n_value` basé sur mtime `.o`. `-no_uuid` faisait échouer dyld macOS 26; linker Apple `-reproducible` dans réglages Release standards garde UUID déterministe. `make qualify` passe local et GitHub #36304912826 sur macOS 26-arm64; App/CLI cold-build pairs identiques, paquet lance avec `LC_UUID`. NFR-13 VÉRIFIÉ sur hôtes/toolchains observés; aucune identité des hashes entre hôtes revendiquée.
- FR-25 — audit Task 1: l’implémentation existante couvre absent/HTTPS/invalide, rejette HTTP, credentials, espaces, contrôles et valeurs >2 048, conserve disponibilité inconnue; 5 tests `ApplicationDiscoveryTests` passent. UserGuide documente lecture Info.plist sans réseau. `Link` ouvre l’HTTPS déclaré au clic, mais interaction native/browser non qualifiée; FR-25 reste PARTIEL.
- NFR-09 — enrichi `app-runtime-smoke`: deux mesures Popen→SQLite fixture (**1,094 s** chacune), 13 échantillons `ps` par run; `%CPU` cumulatif median 0/max 55,2–69,1; RSS médian 92,5–96,3/max 95,4–97,6 MiB. `Scripts.test_runtime_metrics` couvre valeurs finies/non négatives et formats invalides; `make qualify` passe. Store-ready n’est pas fenêtre prête; aucune latence UI/scan corpus réel; NFR-09 reste PARTIEL.
- FR-14: le smoke lancé depuis `make qualify` construit maintenant le ZIP/.app Release réel sous dossier temporaire, vérifie bundle/ZIP/Mach-O, installe le `.app` packagé, lance l’exécutable installé, prélève 14 échantillons réseau (zéro socket Internet), vérifie SQLite/sidecars isolés, puis désinstalle et conserve la DB fixture. Hash du ZIP temporaire testé `5904b8efb73fac47054153a2ca578204b7399c30b0e09cd62824112f4b388868`. FR-14 reste PARTIEL pour Finder/Launch Services, GUI uninstall, signature/notarisation et hôte macOS minimum.
- NFR-11: serveur local relancé; Chrome a vérifié les 10 pages EN/FR à 320 × 800 CSS px, `lang` correct et scrollWidth document/corps à 320. Il s’agit d’un viewport étroit, pas d’un zoom réel. Capture visuelle affichée, mais l’outil refuse l’écriture d’un fichier dans les racines configurées; aucun screenshot persistant prétendu.
- NFR-11: `site-check` vérifie maintenant par fixtures la présence de `prefers-reduced-motion: reduce`, le désactivage du smooth scroll et la réduction des durées animation/transition. Trois tests passent, et le contrat est branché à `make qualify`. Le gate complet passe après changement. Le navigateur DevTools accessible ne permet pas l’émulation runtime; qualification runtime toujours ouverte.
- `make qualify` complet repassé après FR-22 : génération/site, 91 lignes de traçabilité, sécurité/architecture, install/uninstall fixture, app Release isolée avec MenuBarExtra activé et zéro socket Internet sur 13 échantillons, builds propres App/CLI byte-identiques, suites XCTest (dont AppShell 40), builds Debug et CLI/SIGINT. Résultat vert.
- Hash observés: App `c96e5a32739ef31b1b580419724942eb62fa416dfc5bbe9cfa26d19be59d4c22`; CLI `9800f0d19f839ef82a57ebee7616966672195871b7510f7a6a11193b228af2ba`.
- Comptage CSV actuel: 91 lignes; 86 PARTIEL, 3 À_CONSTRUIRE, 2 VÉRIFIÉ. Must: 76 PARTIEL + 2 VÉRIFIÉ = 51,3 % pondéré; Should: 10 PARTIEL + 1 À_CONSTRUIRE = 45,5 %; ensemble = 49,5 % (PARTIEL=50 %, EN_COURS=25 %, VÉRIFIÉ=100 %, À_CONSTRUIRE=0 %). Indice de couverture de preuve, pas % officiel de produit recréé.
- Aucun Must n’est EN_COURS/À_CONSTRUIRE, mais 76/78 restent PARTIEL. Restent qualifications natives/accessibilité, vraie Corbeille/parcours d’action, FDA, compatibilité hôtes, distribution et preuves par exigence. Pas de clôture fictive.
- Les Tasks 1–22 du plan non suivi décrivent du travail déjà présent selon inspection ciblée; `make qualify` valide l’état général du worktree. Cela ne remplace pas les qualifications manuelles listées par exigence. Le fichier non suivi reste intact.

### Should — menu-bar facultatif — 27-09-2026

- `MenuBarExtra` donne accès aux huit destinations existantes et à Réglages avec état de navigation partagé. Réglage persistant `coretend.menuBar.enabled`, désactivé par défaut, copie et aide EN/FR.
- Suite `UserDefaults` injectée vérifie le défaut et la persistance; copie bilingue et `make qualify` passent. Le runtime Release fixture démarre avec menu activé, store isolé et aucun socket réseau observé. Visibilité native, activation des commandes, parcours toggle et accessibilité restent à qualifier; `shell.menubar` et `settings.menubar` PARTIEL. Hash Release courant App `c96e5a32…`, CLI `9800f0d1…`.

### FR-16 — catégories explicites dans Explorer — 27-09-2026

- Explorer filtre par catégories définies via extensions explicites, insensibles à la casse : images, vidéos, audio, documents, archives; « autres » prend extensions non listées et fichiers sans extension. Critères affichés dans l’interface, filtres catégorie/taille/âge combinés.
- ScanCore couvre correspondances, casse, extension inconnue, fichier sans extension et non-correspondance. `swift build --product CoreTendApp`, test ciblé et `make qualify` passent, dont builds propres identiques et suite Swift complète. Interaction UI native reste à qualifier; FR-16 PARTIEL.
- Registre après FR-22 : 91 lignes, 86 PARTIEL, 3 À_CONSTRUIRE, 2 VÉRIFIÉ; pondération indicative 51,3 % Must et 49,5 % global. Pas un score officiel de complétion.

### FR-11 — migration simultanée au lancement — 27-09-2026

- AX sur app Debug isolée reproduisait « Données locales indisponibles » dans Overview; SQLite fixture était valide. Shell et SavedFilesView ouvraient simultanément le store neuf; les deux migrations pouvaient lire version 0 avant attente du verrou puis rejouer les mêmes créations de tables.
- `SQLiteStore.migrate()` relit `user_version` sous `BEGIN IMMEDIATE`; deuxième connexion applique seulement migrations manquantes. Test fixture force deux connexions derrière un writer lock : rouge auparavant (`table performance_samples already exists`), vert après; schéma v5 et lecture `saved_files` disponibles.
- AX relancé avec HOME/store/TMPDIR isolés : Overview montre son état vide normal sans erreur de stockage. Aucun store personnel touché. FR-11 reste PARTIEL; test ciblé et `make qualify` passent.

### NFR-06 — compteur de progression réel — 27-09-2026

- Les vues Explorer, Nettoyage et Doublons affichent désormais le compteur `ScanCore.progress(completed:)` pendant l’analyse; le compteur est remis à zéro au départ/annulation. Aucun total ni taux de progression inventé.
- Moteurs Doublons/Images similaires émettent maintenant progrès mesuré par candidat haché/décodé et paire comparée. Travail déplacé vers tâche utilitaire détachée; annulation UI relayée au worker, flux borné à dernière valeur. Tests ScanCore/AppShell passent. Builds Release propres identiques : App `022d65ca…`, CLI `e2d6987d…`; hashes complets dans `Documentation/Evidence/ReleaseReproducibility.md`. NFR-06 reste PARTIEL jusqu’à qualification native, VoiceOver et accessibilité.

### FR-10 — erreurs d’accès sur éléments internes — 27-09-2026

- Explorer, Doublons et Nettoyage conservent désormais l’ensemble des causes `itemFailure`; messages séparent refus `permission_denied`, élément `missing`, indisponibilité/autres erreurs, et cas combinés. Aucun chemin ignoré n’est rendu, aucune conclusion de sûreté ou d’absence.
- AppShell vérifie distinction EN/FR; app compile. `make qualify` passe après la logique FR-10; FR-10 reste PARTIEL sans diagnostic TCC/FDA exhaustif et qualification native. Hash Release actuel après NFR-06 documenté dans la section ci-dessus et `Documentation/Evidence/ReleaseReproducibility.md`.

### Suite Must — FR-03/FR-06 — 27-09-2026

- FR-03 : lignes Cleanup montrent octets alloués, taille logique, date et risque; Explore ajoute date aux mesures. Description VoiceOver inclut nom, source, état/risque, mesures EN/FR, avec unknown conservé. Test AppShell de résumé bilingue et build App passent. Native visual/VoiceOver reste à qualifier.
- FR-06 : nouvelle fixture Domain exerce proposition→refus et proposition→annulation, confirme événements distincts, contenu original inchangé et aucun appel Fake Trash. Test ciblé passe. Statut reste PARTIEL jusqu’aux parcours natifs/Trash macOS.
- Qualification précédente FR-03/FR-06 : `make qualify` passe avec 31 tests AppShell et le nouveau test Domain, runtime fixture, builds et subprocess CLI/SIGINT. Hashes Release à ce point étaient App `acad10e6…`, CLI `803ab48a…`; les hashes courants FR-10 sont consignés dans section ci-dessus et `Documentation/Evidence/ReleaseReproducibility.md`. Changements restent locaux.

### Reprise en cours — 27-09-2026

- Quick Look Explore/Doublons/Images similaires vérifie le candidat juste avant aperçu : racine réelle, fichier régulier, chemin toujours sous racine. Scope d’accès conservé pendant aperçu puis libéré à fermeture/départ; chemins disparus, symlinks, dossiers et extérieurs refusés. Deux tests AppShell couvrent acceptation/refus; interaction native reste à qualifier, FR-23/`quicklook.extended` PARTIEL.
- Guide utilisateur précise ce refus de candidats invalides. NFR-12 traceability gate couvre maintenant 91 lignes, exige docs/preuve ISO à jour/owner partout, code+tests pour tout statut actif et référence cahier pour scope différé. Fixtures rejettent Should actif sans tests, preuve périmée/mal formée et CSV irrégulier; NFR-12 reste PARTIEL jusqu’à revue indépendante.
- `make qualify` complet passe après FR-11 : gates site/traceabilité/sûreté/architecture, smokes install/uninstall et runtime Release, XCTest, builds Debug et CLI/SIGINT. Les builds Release propres App/CLI sont byte-identiques (`022d65ca…` / `e2d6987d…`); test migration concurrente, tests AppShell FR-10/NFR-06 et `git diff --check` passent.
- État registre à cette reprise : 91 lignes = 86 PARTIEL, 3 À_CONSTRUIRE, 2 VÉRIFIÉ. Must = 76 PARTIEL, 2 VÉRIFIÉ; pondération indicative 51,3 % Must / 49,5 % total. Pas score de complétion produit. Plan local `Documentation/Project/Remaining-musts-plan.md` conservé non suivi.

**État au 27-09-2026.** Reconstruction active, pas finalisée, aucune release publique. Dépôt `ahmetbsbnr/coretend`; worktree `next/`; base distante `origin/next` à `55e8628`. Branche courante `feat/reconstruction-open-musts`, PR brouillon #55 ouverte vers `next`; dernier head distant avec CI réussi `0f29b90`. La tranche locale NFR-13 ajoute un smoke de builds Release propres et passe `make qualify`; elle reste non commitée/non poussée. Aucun merge/tag/release/publication.

## État immédiat

- PR #46–#52 fusionnées; tous les checks GitHub `qualify` requis réussissent. Protection `next` exige `qualify` strict; force-push et suppression de branche interdits. Aperçus Vercel ont atteint leur quota sur les PR récentes; ces contrôles ne sont pas requis par la protection. Aucun déploiement/publication CoreTend effectué.
- Cahier des charges complet et approuvé : QQOQCCP, MoSCoW, RACI, objectifs, exigences, architecture, risques et séquence. Voir `Documentation/Project/Cahier-des-charges.md`.
- Traceability contient 40 FR/NFR + 51 capacités; 91 statuts renseignés. La ligne NFR-07 a été réalignée sur les colonnes CSV; statut PARTIEL tant que revue clavier/VoiceOver/Dynamic Type/contraste/Reduce Motion n’est pas faite.
- App SwiftUI macOS, CLI Swift, persistance SQLite, modules métier, site statique EN/FR et scripts de paquet sont présents. Résultats/états restent partiels selon `Documentation/Traceability.csv`; aucun jalon ne signifie produit final.
- Dernière qualification locale : `make qualify` après FR-22, le 27-09. Elle couvre génération/site, intégrité et dates du registre CSV, audits sûreté/architecture, install/uninstall fixtures, smoke runtime Release avec MenuBarExtra fixture activé et aucun socket réseau, quatre builds Release propres octet-identiques par paires, 40 tests AppShell, tests XCTest, builds Debug App/CLI et subprocess CLI/SIGINT. Hashs dans `Documentation/Evidence/ReleaseReproducibility.md`. CI GitHub `qualify` passe sur le head distant `0f29b90` (sans ces commits locaux). Aucune interaction native d’ouverture/fermeture du menu ni VoiceOver n’est qualifiée par ce gate.
- Paquet courant : `Artifacts/CoreTend-local-unsigned.zip`, arm64, produit depuis le code app `b0287bf`. SHA-256 `94503244830030785388e6ea2359dc844af22d719d5e82729f14408f1697a299`. `make package-local verify-package` passe; vérification limitée à Info.plist, archive et Mach-O. Non lancé, installé sur le Mac, signé, notarié ou publié. Preuve dans `Documentation/ReleaseEvidence.md`.
- Copie greenfield historique `rebuild/` conservée localement comme provenance. Passation/documents 1.x archivés sous `Documentation/Archive/Legacy-Reconstruction/`; ils ne décrivent pas le code actuel.
- État courant après FR-22 (27-09-2026) : 91 lignes, 86 `PARTIEL`, 3 `À_CONSTRUIRE`, 2 `VÉRIFIÉ`. Parmi les Must : 76 `PARTIEL`, 2 `VÉRIFIÉ`. Estimation indicative pondérée (VÉRIFIÉ=100 %, PARTIEL=50 %, EN_COURS=25 %, À_CONSTRUIRE=0 %) : 51,3 % des Must, 45,5 % des Should, 49,5 % du registre. Ce n’est pas un indicateur officiel; critères UI/macOS, compatibilité et distribution restent ouverts.

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

### Avancement de reconstruction — 27-09-2026

- Must: 78; 77 PARTIEL, 1 VÉRIFIÉ. Score indicatif pondéré (PARTIEL=0,5; VÉRIFIÉ=1): **50,6 %**.
- Should: 11; 10 PARTIEL, 1 À_CONSTRUIRE; score indicatif **45,5 %**. Total 89 critères, 87 PARTIEL, 1 À_CONSTRUIRE, 1 VÉRIFIÉ; score pondéré **50,0 %**.
- Aucun pourcentage officiel. Les checks humains/macOS natif et gates release restent ouverts; prochaine priorité: diagnostiquer byte-diff Release sur GitHub `macos-26-arm64` (CI #36302085482), puis continuer tâches restantes du plan local `Documentation/Project/Remaining-musts-plan.md` en ordre.
- **Task 10 — Integrity LaunchAgents (`569cc4d`, `fcbb687`)** : revue consultative plist dans seul dossier explicitement choisi, plafonds 500 candidats/1 Mio, lecture sans suivre symlinks et ancrage au descripteur de racine; erreurs visibles. Tests synthétiques couvrent plist valide/malformé/trop grand, symlink, limite et remplacement de racine. N’affirme ni activité ni sûreté; `integrity.loginitems` reste PARTIEL avant qualification native et intégration aux services système.
- **NFR-13 — builds Release** : deux scratch builds propres indépendants produisent des binaires octet-identiques pour App/CLI via préfixe logique stable, sans avertissement, arm64/macOS 27.0. Pas de dépendance SwiftPM externe ni `Package.resolved`; `make qualify` n’exige pas de secret. NFR-13 est `VÉRIFIÉ` sur l’hôte observé; matrice de compatibilité relève de NFR-08.
- **FR-10 — erreurs de racine distinctes** : `permission_denied` affiche un refus explicite, `missing` l’absence de racine, `metadata_unavailable` la disponibilité indéterminée. Test AppShell bilingue rouge/vert; `make qualify` passe. Aucun diagnostic TCC/FDA exhaustif ni qualification UI native.
- **NFR-11 — smoke navigateur site local** : la première passe homepage FR (résumée dans l’entrée historique ci-dessous) a été étendue ensuite aux 11 routes. Résultat courant : Lighthouse Accessibilité/Bonnes pratiques/Agentic Browsing 100 sur chacune; les 10 pages contenu passent clavier skip-link et largeur 640 CSS. Réduction du mouvement en runtime, zoom réel et VoiceOver restent ouverts. Détails dans `Documentation/Evidence/SiteAccessibilitySmoke.md`.
- **FR-13 — contrat CLI** : script subprocess vérifie help/usage/store inaccessible/scan partiel et codes 0/1/2 avec stderr stable; paths/store non créés implicitement. Scan Control-C sur 30 000 fichiers temporaires sort 130, pas terminaison POSIX `-2`. Intégré à `make qualify`, matrice passe Debug et Release. Parseur distingue store manquant et argument invalide; aide/localisation CLI restent à compléter.

## Jalons récents intégrés

- **PR #46 — backend import et présentation Performance (`abb0d58`)** : import prefs legacy ouvre avec `O_NONBLOCK | O_NOFOLLOW`; lit un fichier régulier seulement; revalide device, inode, mode, taille, mtime et ctime après lecture. FIFO est rejeté sans blocage; source reste intacte. Test fixture FIFO et test d’import idempotent passent. Premier raffinement du graphique Performance.
- **PR #47 — site et confidentialité (`c87d01d`)** : contenu EN/FR décrit palette ⌘K, favoris explicites, récents opt-in (off par défaut, 100 max), chemins/dernières tailles mémorisés localement et retrait des entrées. `make build-site site-check` passe. FR-15 est maintenant VÉRIFIÉ dans son périmètre statique; contrôles navigateur/OS relèvent de NFR-11, déploiement de NFR-14.
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
- À cette étape historique, toutes les lignes Must étaient `PARTIEL` (78), aucune `EN_COURS`/`À_CONSTRUIRE`/`VÉRIFIÉ`. Ce statut ne clôt pas les critères; les gaps visibles restent notamment UI/accessibilité native, vraie Corbeille, FDA exhaustive, compatibilité macOS 14/autre hôte, attribution des données Apps et release. Avancement pondéré estimé à 50 % des Must et 46 % du registre (PARTIEL=50 %, EN_COURS=25 %, À_CONSTRUIRE=0 %, VÉRIFIÉ=100 %). Chiffre indicatif uniquement; aucun Must n’est vérifié de bout en bout.
- L’onboarding a des clés `ProductCopy` EN/FR pour portée, confidentialité et action de démarrage; test rouge/vert AppShell couvre dossiers choisis, scans lecture seule, confirmation Corbeille et politique FDA. Sheet/interaction première ouverture restent à qualifier.
- `make qualify` a repassé après réconciliation du registre et extraction/tests d’onboarding; code sortie 0. Il inclut smoke Release isolé, XCTest, builds App/CLI, audits et CLI SIGINT. `git diff --check` et `check_traceability.py` passent. Aucun artefact dans `Artifacts/` remplacé; plan `Documentation/Project/Remaining-musts-plan.md` préservé et non suivi.


### Correctifs de revue et gate — 27-09-2026

- Finding désinstallateur : ajout fixture `Library` symlinkée vers arbre temporaire extérieur avec base existante. Le test passe sans changement production : `check_target` canonicalise le parent complet via `cd -P`, détecte l’écart et refuse avant retrait. Le risque TOCTOU entre validation et `rm` reste distinct et n’est pas clos par cette fixture.
- CLI : `version` localise maintenant son statut EN/FR. Test unitaire rouge/vert et subprocess sur binaire réel intégrés au gate. FR-13 reste `PARTIEL`.
- Traçabilité : chaque Must exige une date ISO valide ancrée en début de preuve et identique à la date `Relevé` de `Progress.md`. Fixtures rejettent date périmée, calendrier invalide et date non ancrée. NFR-13 normalisée.
- `make qualify` passe après ces changements; `git diff --check` passe. `Documentation/Project/Remaining-musts-plan.md` reste fichier local non suivi à préserver.


### État de branche actuel — 27-09-2026

- Commits de reprise : `8918503`, `47ec49e`, `1dec13b`, `f39cc3f`, `ba6e7a5`, `356d7c7`, `0f29b90`. Branche poussée sur `origin/feat/reconstruction-open-musts`; PR brouillon #55 vers `next`: https://github.com/ahmetbsbnr/coretend/pull/55.
- CI GitHub `qualify` de PR #55 passe sur le head distant `0f29b90` le 27-09; contrôles Vercel également verts à ce head. PR reste ouverte en brouillon. Aucun merge/tag/release/publication.
- `Documentation/Project/Remaining-musts-plan.md` reste préservé et exclu des commits. Changements NFR-13 actuels restent locaux après revue indépendante sans finding.


### FR-08 — déduplication des allocations treemap — 27-09-2026

- `ScanResult` porte identité device/inode issue de `lstat`; `TreemapLayout` déduplique seulement la carte, choisit de façon stable le chemin visible lexicographiquement premier et laisse les mesures ligne inchangées. Libellé bilingue parle d’allocations distinctes.
- Tests ScanCore : scan d’un hard link expose identité/allocation identiques sur deux chemins; treemap attribue une seule aire à l’inode; fixture sparse distingue 8 Mio logiques et allocation locale plus faible. Tests ciblés et `make qualify` passent. `git diff --check` passe.
- Le gate de traçabilité couvre aussi les lignes CSV surnuméraires; cette vérification a détecté puis corrigé une colonne décalée dans la preuve FR-08.
- FR-08 reste `PARTIEL` jusqu’aux vérifications native/VoiceOver, cloud et volumes représentatifs. Le head `0f29b90` inclut la correction hard links/sparse et sa documentation; revue indépendante sans blocage; CI GitHub passe. Le plan local non suivi reste préservé.


### NFR-13 — deux builds Release propres — 27-09-2026

- `Scripts/test_clean_release_builds.py` compile les deux produits Release dans deux scratch dirs temporaires, contrôle absence d’avertissement et présence de binaire, puis affiche SHA-256. Intégré à `make qualify` via `make clean-release-build-smoke`.
- Deux builds propres par produit utilisent des scratch dirs physiques distincts via le même symlink workspace stable; quatre builds réussissent sans warning et chaque paire est octet-identique. Hashes dans `Documentation/Evidence/ReleaseReproducibility.md`.
- Revue indépendante valide le nettoyage ownership-checked du symlink et les tests de collision/remplacement. `make qualify`, `git diff --check`, checker de traceabilité et fixtures unitaires passent. NFR-13 est `VÉRIFIÉ` pour source/host/toolchain/checkout observés; compatibilité autre hôte/version reste NFR-08. Pas de push/merge/publication.

### Revue MoSCoW — 27-09-2026

- Les six capacités `shell.menubar`, `settings.menubar`, `quicklook.extended`, `favrec.module`, `ui.commandpalette` et `clutter.largeold` sont bien classées `Should` selon le §7 du cahier. Les statuts restent fondés sur leurs preuves : menus système `À_CONSTRUIRE`, palette/filtres/Quick Look `PARTIEL`, favoris/récents `EN_COURS`.
- Les 22 tâches du plan local sont couvertes par implémentation/preuve. Il reste 76 Must `PARTIEL` et deux `VÉRIFIÉ`; preuves d’interface native, compatibilité hôte, Corbeille réelle et distribution restent à faire sans simulation de validation humaine.
- Gate complet rejoué après correctif de langue : `make qualify` passe, dont 28 tests AppShell, smoke runtime isolé, quatre builds Release propres (App/CLI en paires octet-identiques), builds Debug App/CLI et subprocess CLI/SIGINT. `git diff --check`, `check_traceability.py` et `test_traceability.py` passent. Hash Release App `9bc252b070a11d8ebf4a2143b6b73d5635941d494c7ccdaad94fc1b25e34397c`; CLI `803ab48ab6c0fcd03aead4fac192a85c50caf9e1f3632bafbb27c349d3ff9161`.
- Calcul registre : 76/78 Must PARTIEL, 2/78 VÉRIFIÉ = 51,3 % pondéré (PARTIEL 50 %, VÉRIFIÉ 100 %). Registre entier : 81 PARTIEL, 2 EN_COURS, 6 À_CONSTRUIRE, 2 VÉRIFIÉ = 47,3 %. Score de preuve, pas complétion produit ni score des Should.

### FR-14 — smoke install→lancement — 2026-09-27

- Runtime smoke copie le Release executable dans `.app` fixture, installe via `install_local.sh` sous HOME temporaire, lance 8 s, puis retire seulement l’app via `uninstall_local.sh --keep-data`; SQLite reste présent au store fixture après retrait.
- Revue a détecté absence de recherche des autres bases SQLite fixture et besoin de rescanner après arrêt. Smoke balaie `.sqlite`/`.sqlite3`/`.db` et sidecars WAL/SHM/journal avant et après `wait()`, chemin résolu comparé au store; deux tests acceptent l’intérieur et rejettent l’extérieur. Test rouge d’intégration, puis 4 tests helper verts.
- `make qualify` repasse (site/traceability/safety/architecture/install/uninstall/runtime/reproducible Release/XCTest/builds/CLI SIGINT). FR-14 reste PARTIEL : Finder/Launch Services, désinstallation interactive, signature, notarisation, macOS minimum et autre hôte non qualifiés.
- Preuve AX d’origine reste correctement séparée : fenêtre/titres observés sur `.app` fixture, tandis que test d’installation confirme seulement processus vivant + store fixture. Voir `Documentation/Evidence/AppWindowRuntimeQualification.md`.

### FR-15 / NFR-11 — routes du site local — 2026-09-27

- Lighthouse Chrome mobile sur 11 routes locales (language chooser + 5 EN + 5 FR) : Accessibilité, Bonnes pratiques et Agentic Browsing 100 par route. Sur 10 pages contenu à 640 × 900 CSS px : aucun overflow; première touche Tab focalise lien d’évitement traduit, contour 3 px, cible existante.
- SEO 50 attendu en partie par `noindex,nofollow` tant que l’aperçu n’est pas publié; descriptions meta manquantes. Zoom navigateur réel, VoiceOver, taille texte OS, reduced-motion runtime, headers publiés et deuxième navigateur non vérifiés. FR-15 est VÉRIFIÉ dans son périmètre; NFR-11 reste PARTIEL.

### Qualification fenêtre SwiftUI isolée — 27-09-2026

- Lancement Release dans un `.app` fixture, avec HOME/TMPDIR/store sous racine temporaire; CoreGraphics observe une fenêtre écran `CoreTend` appartenant au processus et SQLite reste sous le store fixture.
- Test d’acceptation fixture ensuite : AX voit l’accueil français; 8 lancements avec chaque route env rendent le heading attendu, ID obsolète retombe sur Vue d’ensemble. Preuve dans `Documentation/Evidence/AppWindowRuntimeQualification.md`; pas de preuve pour clic de sidebar, VoiceOver parlé, Finder/Launch Services ou distribution. FR-01, FR-14 et `shell.launch` demeurent `PARTIEL`.

### Isolation des préférences en fixtures — 27-09-2026

- `HOME`/`CFFIXED_USER_HOME` n’isolent pas à eux seuls `UserDefaults` derrière `cfprefsd`. `CoreTendPreferences` contourne CFPreferences lorsqu’un override de store test est présent; valeurs explicites `CORETEND_TEST_*`, écritures no-op. Recent Files passe par un binding racine partagé.
- 7 tests AppShell passent, dont priorité de la langue fixture sur valeur SQLite; revue finale sans finding. `make qualify` passe après correctif. Matrice Release/AX utilise uniquement valeurs d’environnement et store fixture; persistance production via UserDefaults reste hors de cette preuve.


### Suite FR-15 / NFR-10 — 2026-09-27

- Revue indépendante : aucun critère FR-15 non satisfait identifié. Statut `VÉRIFIÉ` limité au périmètre approuvé de contenu/capacités/OS/langues/état publication, génération statique et gate browser/accessibilité existant. Pas d’URL/checksum fictif. Zoom réel, VoiceOver, reduced-motion runtime, autres navigateurs et déploiement restent sous NFR-11/NFR-14.
- `Scripts/check_architecture.py` suit maintenant les dépendances transitives de ScanCore; test couvre chemin ScanCore → ScanAdapter → Persistence. Cinq cas synthétiques passent; revue indépendante architecture reste ouverte.
- Comptage actuel: 76 Must `PARTIEL`, 2 `VÉRIFIÉ`; 81 `PARTIEL`, 2 `EN_COURS`, 6 `À_CONSTRUIRE`, 2 `VÉRIFIÉ` sur 91. Pondération indicative: 51,3 % Must, 47,3 % registre.

### NFR-04 — observation des sockets runtime — 2026-09-27

- Smoke d’installation Release fixture observe le processus avec `lsof` toutes les ~0,5 s pendant huit secondes. Exécution réelle : 14 échantillons, aucun socket Internet IPv4/IPv6 ouvert; test unitaire détecte un listener loopback détenu par son propre processus.
- Le gate est ajouté à `make qualify` via `app-runtime-smoke` et test helper. `NFR-04` reste `PARTIEL`: pas de capture paquets, le lien de mise à jour déclenché explicitement n’a pas été suivi, et une socket de durée inférieure à l’intervalle peut échapper aux échantillons.

### Revue gate traçabilité et migration concurrente — 27-09-2026

- `Scripts/check_traceability.py` refuse maintenant les IDs dupliqués, exigences dupliquées dans le cahier et priorités CSV divergentes du cahier. NFR sont Must; priorités capacités dérivées de la réconciliation explicite section 7. Fixtures couvrent doublons et rétrogradation Must. NFR-12 reste PARTIEL jusqu’à revue indépendante.
- Test migration utilise barrière conditionnelle interne à `SQLiteStore` : les deux connexions observent version 0 avant migration concurrente, sans délai 100 ms heuristique. Test ciblé passe.
- `make qualify` complet passe après ces changements, y compris reproduction des builds Release propres App/CLI (`9fa47b9ca35f992318f0b3e427e44de6f729c5acab3206ffbe813fe1103ee2ec` / `64b8c3a65986cf915fa778ea2531cbf581899673e4726e30f959287621716ace`), runtime isolé, XCTest, builds Debug et CLI/SIGINT.
- Registre recalculé : 91 lignes; 78 Must = 76 PARTIEL, 2 VÉRIFIÉ; pondération indicative inchangée 51,3 %. Changements locaux uniquement, PR #55 non actualisée.

### Gate inventaire capabilities — 27-09-2026

- Revue du checker a trouvé qu’un `set` masquait des IDs de capabilities dupliqués dans la source Swift, ce qui pouvait réduire le registre attendu sans alerte. Fixture rouge ajoutée; checker échoue maintenant avec la liste des IDs dupliqués. Fixture positive actuelle et registre de 91 entrées passent.
- `make qualify` complet passe après ce renforcement (runtime isolé, builds Release propres, tests Swift, builds Debug, CLI/SIGINT). `Documentation/Project/Remaining-musts-plan.md` reste non suivi. Comptage Must inchangé : 76 PARTIEL, 2 VÉRIFIÉ, 51,3 % pondéré.

### Fixtures de doublons du cahier et des capabilities — 27-09-2026

- Tests du checker exigent maintenant le motif exact pour IDs capabilities dupliqués dans Swift et exigences dupliquées dans Cahier; ces cas ne passent pas pour une erreur accessoire. `test_traceability.py`, gate réel, et `git diff --check` verts. `make qualify` avait passé juste avant l’élargissement des asserts (aucun code production modifié).

### Integrity — racine LaunchAgents symlink refusée — 27-09-2026

- Fixture crée dossier LaunchAgents réel avec plist candidat puis alias symlink; inspection de l’alias rend zéro candidat et `directoryUnreadable`. Guide utilisateur précise refus racine alias; Traceability `integrity.loginitems` référence fixture et limites humaines/service de lancement restent ouvertes. Statut PARTIEL inchangé.
- `make qualify` passe après fixture/documentation : site, checker 91 lignes, audits, runtime isolé, builds Release byte-identiques, XCTest, Debug App/CLI et CLI/SIGINT. Aucun dossier système ni HOME réel examiné.

### FR-24 / favrec.module — état de disponibilité des chemins — 27-09-2026

- `SavedFilesView` affiche état présent (accès courant non vérifié) ou absent/inaccessible à partir de métadonnée d’existence seulement; taille reste la dernière mesure connue et aucune lecture/réouverture de chemin n’est déclenchée. Helper `ProductCopy.savedFileAvailability` testé dans les deux langues; build App et `make qualify` passent.
- FR-24 et `favrec.module` passent de EN_COURS à PARTIEL, preuve de wording/état présente; navigation native, lecture VoiceOver et accès actuel restent à qualifier. Registre recalculé : 83 PARTIEL, 6 À_CONSTRUIRE, 2 VÉRIFIÉ; score pondéré total 47,8 %. Must inchangé à 51,3 %.

### FR-24 — recherche palette bilingue — 27-09-2026

- Corrige un écart entre guide (recherche FR ou EN) et catalogue (alias jusque-là limités à la langue affichée). Recherche palette contient maintenant alias français et anglais pour huit destinations et Réglages; test rouge initial trouvait `home` depuis interface française et `historique` depuis interface anglaise sans résultat, tests verts couvrent toutes destinations dans les deux directions.
- `make qualify` complet passe. Traceability confirme preuve AppShell et garde interaction native arrows/Settings non qualifiée. Aucun statut Must/Should ou score ne change; plan local reste non suivi.
