# CoreTend — cahier des charges greenfield

**Statut :** proposition complète pour revue mainteneur; aucun code autorisé avant revue de ce cahier et plan d’exécution.

**Date :** 2026-09-26. **Périmètre :** application macOS, moteurs, stockage local, CLI lecture seule, site, documentation et qualité de livraison.
**Référence produit :** direction CoreTend 2.0 observée dans le dépôt source; ce document tranche les contradictions d’archives sans les réécrire.

## 1. Décision proposée

Reconstruire CoreTend dans un nouveau projet isolé, sans copier ni importer le code de l’application existante. Repartir des besoins, comportements prouvés, décisions produit et invariants de sûreté. Le dépôt actuel reste intact et sert de référence de comportement, de contenu et de compatibilité. Aucun reset, nettoyage global, push, tag, publication ou déploiement.

Le produit cible est une application macOS native qui aide à comprendre l’occupation du disque et certains signaux locaux, à examiner des candidats, puis à décider. Les analyses sont en lecture seule. Une action de retrait admissible requiert examen, confirmation explicite et revalidation au moment de l’action; elle utilise exclusivement la Corbeille macOS. CoreTend ne prétend pas que l’espace est libéré tant que la Corbeille n’est pas vidée — fait que l’application ne mesure pas.

### Source de vérité et résolution des divergences

1. **Direction à reconstruire :** branche produit 2.0 active, README de branche et programme CoreTend 2.0; huit destinations métier.
2. **Comportement et sécurité :** implémentation/tests actuels lorsqu’ils sont cohérents avec les invariants de ce cahier; défaut testé le plus sûr prévaut sur prose ancienne.
3. **Publication :** aucun badge, manifest ou état JSON seul ne prouve une release. Faits publics exigent artefact publié et vérification cryptographique correspondante.
4. **Historique :** mentions de 0.9.x, 1.0.0, 1.0.1, 1.0.2, comptes de tests et matrices visuelles restent des instantanés datés, jamais chiffres courants sans re-mesure.
5. **Code source existant :** référence en lecture seulement; toute capacité reconstruite part d’une nouvelle implémentation et d’un contrat observable.

## 2. QQOQCCP

| Question | Décision produit |
|---|---|
| **Qui ?** | Propriétaires de Mac souhaitant comprendre espace, fichiers et état local sans confier leur décision à un nettoyeur automatique. Mainteneur porte décisions et acceptation; ingénierie réalise; sécurité/qualité et UX vérifient selon disponibilité. |
| **Quoi ?** | Application macOS CoreTend complète : huit destinations, onboarding et réglages; moteurs locaux; historique; CLI en lecture seule; site statique; documentation; tests et chaîne locale de build/packaging. |
| **Où ?** | Analyse et base locale sur le Mac de l’utilisateur. Code, aide et site dans le dépôt/source publique une fois publiés par décision séparée. Pas de serveur de données produit. |
| **Quand ?** | Actions déclenchées par l’utilisateur. Analyses planifiées et suppression sans présence exclues. Vérification de mise à jour seulement sur demande; aucun téléchargement ni installation automatique. |
| **Comment ?** | Mesurer et expliquer les preuves; distinguer inconnu, refus, échec et succès; laisser inspecter et exclure; confirmer; revalider; déplacer vers Corbeille; inscrire le résultat localement. Construire depuis un répertoire vide en tranches testables. |
| **Combien ?** | Gratuit et open source selon licences confirmées dans le dépôt de référence. Aucun budget financier ou seuil de performance inventé; mesures de départ puis seuils proposés dans le plan et soumis au mainteneur. |
| **Pourquoi ?** | Donner contrôle, compréhension et actions récupérables, sans peur marketing, faux scores, collecte distante ni promesse supérieure aux preuves. |

## 3. Objectifs et non-objectifs

### Objectifs de reconstruction

- Recréer les comportements Must des huit destinations dans un projet propre, modulaire, compilable et vérifiable.
- Faire de la sûreté, de la traçabilité, de l’honnêteté des mesures, de l’accessibilité et de la confidentialité des contrats testables.
- Recréer site et documentation à partir de la même vérité produit; EN/FR cohérents.
- Pouvoir vérifier build, tests, sécurité et packaging sans lire ni modifier le store réel de l’utilisateur.
- Conserver un chemin de compatibilité pour les données existantes; ne migrer que des fixtures synthétiques/versionnées durant ce goal.

### Hors périmètre

- Copier des fichiers Swift, vues, assets générés ou historique du dépôt source dans le nouveau projet.
- Ouvrir, lister, migrer, écrire ou supprimer le vrai store utilisateur pendant développement ou tests.
- Effacement permanent, vidage de Corbeille, action planifiée, privileged helper, diagnostic malware/antivirus, compte, cloud sync, télémétrie ou analytics.
- Mise à jour qui télécharge/installe; App Store comme canal de cette reconstruction.
- Signature avec identité réelle, notarisation, publication, déploiement, push et tag.
- Affirmer version/release ou compatibilité sans artefact et preuve correspondants.

## 4. Périmètre fonctionnel — huit destinations

Les sous-fonctions restent dans leur destination de travail; paramètres et accueil sont transverses, pas des destinations métier supplémentaires.

| ID | Destination | Responsabilités et limites |
|---|---|---|
| MOD-01 | **Overview** | État récent, espace disponible rapporté par macOS, accès aux tâches et changements observés. Pas de score santé ni d’agrégat inventé. |
| MOD-02 | **Record** | Historique local des scans, propositions, refus, annulations, réussites et échecs. Distingue événements et espace récupéré; filtrage et effacement utilisateur documentés. |
| MOD-03 | **Cleanup** | Règles explicites pour caches/journaux admis. Scan lecture seule; résultats avec règle, chemin, taille/date connues et limites; revue/exclusion/confirmation; Corbeille uniquement. |
| MOD-04 | **Explore** | Navigation disque, treemap proportionnelle à tailles observées, recherche, plus grands/anciens, images similaires et footprint cloud. Octets locaux séparés de taille logique/placeholders; ouverture Finder après action explicite. |
| MOD-05 | **Duplicates** | Correspondance de contenu exacte via hashing progressif. Groupe toujours garde un exemplaire; suggestion explicable et modifiable; aucun scan ne déplace un fichier. |
| MOD-06 | **Applications** | Inventaire local, provenance d’installation disponible, fichiers associés attribués avec conservatisme, mises à jour annoncées par source. Désinstallation seulement après revue et vers Corbeille. Aucune mise à jour automatique. |
| MOD-07 | **Integrity** | Provenance de téléchargement, classe de signature et éléments lancés à la connexion à partir de signaux natifs accessibles. Lecture seule; aucune conclusion antivirus ou verdict « sain » par absence de signal. |
| MOD-08 | **Performance** | Mesures système disponibles, horodatées et contextualisées; graphiques ancrés sur mesures réelles; unités inconnues représentées comme inconnues. Pas de diagnostic médical du Mac. |
| MOD-X | **Onboarding, réglages, CLI** | Accès expliqué au moment utile; exclusions/préférences/langue; diagnostic exporté seulement sur demande et aperçu; CLI documentée et strictement lecture seule. |

## 5. Exigences fonctionnelles et critères d’acceptation

Priorité selon §7. **M** est obligatoire pour reconstruction livrable. Statut initial de chaque exigence : `À CONSTRUIRE`; aucune feature existante ne compte comme preuve de nouvelle implémentation.

| ID | Prio | Exigence et preuve d’acceptation minimale |
|---|---|---|
| FR-01 | M | Application native ouvre les huit destinations, restaure une navigation définie et fournit états chargement/vide/erreur/accès limité/annulé. Contrats UI et parcours fonctionnels vérifiés. |
| FR-02 | M | Scan ne peut invoquer aucune primitive d’écriture fichier. Tests de contrat prouvent absence de mutation sur fixtures et annulation bornée. |
| FR-03 | M | Chaque résultat expose source/règle, mesures connues, limites et état. Valeur absente demeure inconnue; test de copy interdit claims de santé/espace récupéré. |
| FR-04 | M | Exclusions persistantes modifient réellement périmètre; chemins utilisateur ne deviennent jamais cibles implicites. Tests relance et limites de chemin. |
| FR-05 | M | Chaque déplacement vers Trash provient d’une sélection revue et confirmation explicite; autorisation typée et validation répétée à exécution. Le seul adapter production appelle API Trash macOS. |
| FR-06 | M | Événements de proposition, refus, annulation, succès et échec restent distincts, consultables, durables selon contrat; échec de Trash laisse original intact et journalise erreur. |
| FR-07 | M | Duplicates identifie copies exactes; un survivant minimum est invariant même avec entrée concurrente/race. |
| FR-08 | M | Treemap/liste reflètent les octets observés et agrègent selon règle explicite; fichier inaccessible, sparse, cloud placeholder et hard link n’inventent pas taille locale. |
| FR-09 | M | Integrity n’affiche que signaux natifs effectivement observés et leurs limites; aucun verdict malware/absence de risque. |
| FR-10 | M | Chaque permission est sondée; refus/absence/indisponibilité distingue absence de menace; parcours propose réglage système pertinent sans boucle coercitive. |
| FR-11 | M | Données CoreTend restent locales; schéma versionné, transactions et migration idempotente; fixtures synthétiques anciennes préservent contenu lors migration. Aucun test lit vraie base utilisateur. |
| FR-12 | M | EN/FR couvrent UI, erreurs, site et aides critiques; gate parité de clés/route et revue terminologique. |
| FR-13 | M | CLI si présente est lecture seule; aide, règles, chemins user-scoped et erreurs d’argument stables/documentés. Test d’absence d’API mutation/élévation. |
| FR-14 | M | Installation locale depuis paquet construit permet ouverture et désinstallation documentée; paquet ne cible aucun dossier utilisateur par script d’installation. Vérification en compte HOME temporaire. |
| FR-15 | M | Site statique correspond aux capacités, OS/langues et états réels; aucune URL de release/checksum ne prétend publier artefact inexistant. Build isolé et gate browser/accessibilité. |
| FR-16 | S | Presets/filtres catégorie réutilisables rendent chaque critère visible et résultats reproductibles. |
| FR-17 | S | Cask de package manager seulement généré depuis artefact publié avec checksum vérifié; aucun cask fictif dans cette reconstruction non publiée. |
| FR-18 | C | Locales supplémentaires, sur demande démontrée et relecture humaine complète. |
| FR-19 | W | Nettoyage planifié/destructif, purge permanente, vidage Trash, scan malware, cloud sync, assistant privilégié, auto-updater installant. |

## 6. Exigences non fonctionnelles et invariants

| ID | Domaine | Critère obligatoire |
|---|---|---|
| NFR-01 | Sûreté | `ApprovedFileOperation`/contrat équivalent est seule entrée d’opération; aucun appel suppression permanente. Validation portée, volume/racine et symlink à approbation et exécution. Refus fermé par défaut. |
| NFR-02 | Réversibilité | API Trash seulement. Échec de Trash n’entraîne pas fallback de suppression, copie destructive ou succès. Succès signifie déplacé à Trash, jamais espace récupéré. |
| NFR-03 | Isolation tests | Toute mutation de test vise un sandbox temporaire dédié; adapter Trash fake utilise sa Corbeille fixture. Gate statique/runtime prouve tests ne ciblent pas `$HOME`, vrai Trash ou chemins personnels. |
| NFR-04 | Confidentialité | Pas télémétrie/compte/analytics/cloud. Réseau uniquement vérification de mise à jour initiée par user, si cette fonction reste incluse; aucun téléchargement. Chemins privés absents des logs partageables. |
| NFR-05 | Données | SQLite/local native ou stockage retenu documenté, données minimales, expiration/effacement défini, transaction/migration avec backup fixture et chemin d’échec. Export diagnostic opt-in, aperçu, redaction. |
| NFR-06 | Robustesse | Erreurs typées par élément, tâches annulables, progression causale, pas de race reportée comme succès, aucun blocage UI pour scan/hash. |
| NFR-07 | Accessibilité | Clavier, focus, VoiceOver, Dynamic Type/zoom, contraste, Reduce Motion/Transparency, états distingués autrement que par couleur. Automatisation + observation humaine à qualification. |
| NFR-08 | Compatibilité | Cible initiale arm64 et macOS 14+; revendication limitée aux OS/architectures effectivement testés. Seconde version macOS/hôte requis pour déclarer matrice complète. |
| NFR-09 | Performance | Baseline représentative pour startup, scan, UI, CPU/RSS; budgets proposés après mesure, jamais choisis au hasard. Aucune animation continue au repos. |
| NFR-10 | Architecture | Swift 6, SwiftUI natif, SwiftPM, zéro dépendance runtime par défaut; UI séparée des moteurs; SafetyCore en frontière centrale; décisions d’ajout de dépendance documentées. |
| NFR-11 | Site | Génération statique, EN/FR, sécurité CSP, navigation clavier, 200 % zoom, reduced motion, sans tracker; contenu utile sans JS si applicable aux pages critiques. |
| NFR-12 | Documentation | Exigences tracées jusqu’au code/test/critère; faits mesurés séparés d’hypothèses, dates/sources/owners; les documents générés ont générateur et gate. |
| NFR-13 | Build | Reproductible depuis source et dépendances déclarées; build de release locale à zéro warning accepté; dépendances verrouillées; aucun secret requis pour tests. |
| NFR-14 | Release | Aucun statut signé/notarisé/publié annoncé sans octets candidats et preuve. La création d’un paquet local n’autorise aucun push/tag/publication. |

## 7. MoSCoW

| Priorité | Livrables retenus |
|---|---|
| **Must** | Cahier et registre décisions; app native huit destinations; scan en lecture seule; SafetyCore Trash-only/confirmation/revalidation; Record local; migrations synthétiques; exclusions; EN/FR; onboarding/réglages; CLI lecture seule; site statique; docs user/dev; tests isolés; sécurité/confidentialité/accessibilité; build, packaging local, provenance honnête. |
| **Should** | Filtres/presets; cask généré depuis vraie release future; capture automatisée; profiling multi-macOS; audit ergonomie externe; compatibilité seconde machine; enrichissement historique et diagnostic export. |
| **Could** | Langues additionnelles; App Store après redesign ciblé sandbox; update installant après modèle signature/rollback; widget/Shortcuts; catégories supplémentaires cache/métadonnées. |
| **Won’t** | Effacement permanent, opération automatique/schedule, télémétrie, cloud/account, score santé, claim antivirus, helper privilégié, App Store dans le livrable actuel, publication de cette reconstruction. |

Règle : Must fermé par preuve avant qualification; Should ne bloque pas le socle mais reste transparent; Could nécessite nouveau cadrage; Won’t ne doit pas apparaître par accident via dépendance ou UI.

## 8. Matrice RACI

R réalise; A assume l’approbation/résultat; C consulté; I informé. Rôles logiques; ne pas inventer collaborateurs. Si même mainteneur remplit plusieurs rôles, l’absence de revue indépendante est déclarée.

| Activité | Mainteneur produit | Ingénierie | Sécurité/qualité | UX/accessibilité | Release |
|---|---|---|---|---|---|
| Vision, scope, MoSCoW | A | C | C | C | I |
| Cahier, critères et décisions | A | R | C | C | I |
| Architecture et implémentation | A | R | C | C | I |
| Opérations fichiers et protection | A | R | R | I | I |
| Schéma, rétention, migration | A | R | C | I | I |
| Langage, navigation, contenu | A | C | C | R | I |
| Vérification et traceability | A | R | R | C | I |
| QA accessibilité et visuelle | A | C | C | R | I |
| Paquet local et provenance | A | C | C | I | R |
| Signature/publication/push/tag | A/R | I | C | I | R — **hors mandat courant** |
| Incident sécurité/support | A | R | R | I | C |

## 9. Architecture greenfield retenue

### Composants

- `CoreTendApp`: cycle de vie, navigation, accessibilité et composition SwiftUI.
- `DesignSystem`: tokens, composants et formatage localisés.
- `SafetyCore`: validation des cibles, types approuvés, adapter Trash production et interfaces fixture.
- `ScanCore` / domaines: scan stream cancellable, `FileRules`, doublons, images, exploration, applications, intégrité et métriques. Aucun moteur de scan n’écrit.
- `Persistence`: acteur SQLite local, événements, préférences, exclusions, migrations.
- `CoreTendCLI`: lecture seule, partage règles/catalogues sans API mutation.
- `Website`: site statique public distinct du runtime app; textes/capacités dérivés d’un manifeste produit.
- `Tests`: support partagé et fakes; aucun test n’opère sur store ou Trash réel.

Dépendances orientées: UI → cas d’usage → moteurs; UI/actions passent par SafetyCore; moteurs ne dépendent ni de UI ni de Persistence; persistence reçoit événements typés; adapter macOS derrière protocoles. Le projet greenfield n’importe aucune cible/source/asset compilé du dépôt actuel.

### Contrat d’action fichier

États possibles : `proposé → approuvé → déplacé | refusé | échoué | annulé`. Approbation émet une capacité limitée liée à l’identité/path, règle et date courte; l’exécution revalide l’existence, la racine, la portée, symlink, volume et allowlist. La production appelle `FileManager.trashItem`; le fake de test déplace seulement sous root temporaire. Si Trash échoue : source conservée, résultat échec et événement journalisé. Aucun fallback destructif.

### Données et réseau

Store versionné local; événement append-only pour actions et refus; séparation entre fait d’analyse et action. Rétention/effacement explicités dans Settings. Aucune synchronisation. Check update seulement à demande, public metadata sans binaire; possibilité de retirer cette fonction sans impacter modules.

## 10. Séquence de reconstruction

1. **Contrat/registre** : nouveau repo vide; manifest projet, exigences versionnées, modèle des erreurs et règles de sécurité; build/test harness minimal.
2. **Fondations** : SafetyCore, persistance/events, files d’exclusions; tests fixture prouvant Trash failure preservation et aucun accès au vrai HOME.
3. **Moteurs** : scan/files rules, Explore, Duplicates, Integrity, SystemMetrics, AppDiscovery; preuves par domaine et intégration.
4. **Expériences** : shell, huit destinations, onboarding, réglages, états et localisation; aucune UI appelle filesystem mutation directement.
5. **CLI/site/docs** : interfaces read-only, website et aides conformes aux capacités réellement construites.
6. **Qualification locale** : gates complètes, accessibilité, compatibilité, performance, paquet local et audit des claims. Aucune publication.

Chaque étape a plan détaillé indépendant, build/test ciblés, audit sûreté, mise à jour traceability et critères d’entrée/sortie. Aucun transfert du code existant comme raccourci. Comparaison comportementale autorisée avec fixtures synthétiques.

## 11. Critères de fin

- Chaque FR/NFR Must a implémentation greenfield actuelle, test/gate adapté et preuve reliée dans traceability.
- Les huit destinations ont parcours réussi et états vide/erreur/annulation/accès restreint; EN/FR et accessibilité validées.
- Aucun appel delete permanent; scan sans mutation; toute action passe par SafetyCore + Trash, review, confirmation, revalidation; échec laisse source intacte.
- Suite tests et gates inspectées, isolées; aucun test ne lit/écrit vrai store ou vraie Corbeille. Tests contre DB historique emploient fixtures artificielles.
- Sites/docs/CLI décrivent implémentation, network et limites honnêtement.
- Build et packaging locaux reproductibles, sans claim public ni action release.
- Revue manuelle du mainteneur sur fonctionnement et apparence avant toute qualification.

## 12. Risques et décisions maintenues ouvertes

| ID | Risque/décision | Valeur par défaut | Preuve ou déclencheur de réexamen |
|---|---|---|---|
| D-01 | Produit cible 1.x vs v2 | v2, 8 destinations, car ligne active et README | Mainteneur corrige avant plan si autre produit visé |
| D-02 | OS/CPU | macOS 14+, Apple silicon initialement | Vérifier chaque version/hardware supporté en CI/host |
| D-03 | Destination publique | GitHub releases/site statique comme intention, aucun publish dans goal | Artefact public vérifié; action exige autorisation distincte |
| D-04 | Données issues ancien app | Aucune vraie DB lue; maintenir formats documentés et fixtures synthétiques | Contrat de migration accepté et fixture anonymisée créée |
| D-05 | Visibilité du chantier | Nouveau dépôt dans `../rebuild/` (à côté de `app/`); référence originale intacte; reconstruction non fusionnée avant qualification | Dossier reste isolé jusqu’à acceptation d’une candidate locale; toute bascule ultérieure est une décision distincte |
| D-06 | Performance budgets | Mesurer d’abord, proposer ensuite | Corpus/machine cible et mesures reproductibles |
| D-07 | Review sécurité indépendante | Non disponible présumée; risque signalé | Reviewer distinct assigné avant qualification candidate |
| D-08 | Backups/export | Export diagnostic user-opt-in; backup/restore DB en procédure locale | Tests de restauration fixture avant migrations de compatibilité |

## 13. Registre de traçabilité

Chaque ligne de `traceability.csv/json` suit: `ID, priorité, description, code, tests, documentation, classe de preuve, statut, écart/propriétaire`. Statuts: `PROPOSÉ`, `À_CONSTRUIRE`, `EN_COURS`, `VÉRIFIÉ`, `PARTIEL`, `BLOQUÉ`, `EXCLU`. Une mention documentaire seule n’est pas preuve de comportement.

## 14. Approbation et transition

Cette proposition fige une direction greenfield mais n’autorise pas implicitement une migration réelle de données ni une publication. Après revue mainteneur, corriger ce cahier, établir baseline de contexte/traceability et écrire plans d’exécution par tranche. Aucun code/scaffold ne commence avant approbation de cette version du cahier. Aucun push/tag/release/publication ne fait partie du goal.
