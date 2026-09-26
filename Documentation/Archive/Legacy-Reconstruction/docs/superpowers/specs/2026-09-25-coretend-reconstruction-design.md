# CoreTend — Cahier des charges de reconstruction

> Statut : cahier validé par le mainteneur pour cadrage et reconstruction. Les questions ouvertes du §15 restent des propositions; leur fermeture requiert décision explicite.
> Date : 2026-09-25. Périmètre : produit CoreTend et dépôt complet, pas seulement interface.

## 1. Résumé de décision

Reconstruire CoreTend comme produit cohérent et maintenable en repartant des besoins et invariants vérifiés, puis remplacer ses composants par étapes. Garder identité, données utilisateur, provenance des versions publiées et invariants de sécurité. Remplacer ou retirer toute implémentation après preuve de parité. Pas de réécriture destructrice de l’historique Git ni de suppression globale du dépôt.

Produit cible : utilitaire macOS natif, local et transparent qui aide à comprendre l’usage disque, examiner des éléments candidats et suivre l’état de certaines applications et signaux système. L’utilisateur garde décision et contrôle. Les opérations sur fichiers admissibles vont dans la Corbeille macOS après examen et confirmation explicite; CoreTend ne promet jamais d’espace effectivement récupéré.

Ce cahier des charges fixe la destination et les critères de succès. Il ne prétend pas que l’état actuel est propre : plusieurs documents d’état se contredisent et exigent une réconciliation avant de servir de référence.

## 2. QQOQCCP

| Question | Réponse retenue |
|---|---|
| **Qui ?** | Utilisateurs de Mac qui veulent comprendre l’occupation du disque et examiner les éléments avant action. Mainteneur produit décide direction, sécurité et publication. Contributeurs construisent et vérifient. |
| **Quoi ?** | Application macOS native CoreTend, moteurs d’analyse, persistance locale, site produit, documentation, automatisation de qualité et chaîne de distribution. |
| **Où ?** | Sur Mac de l’utilisateur pour analyse et données; GitHub et site CoreTend pour code, documentation, aide et versions publiées. |
| **Quand ?** | Utilisation à la demande. Analyses planifiées pourront être évaluées plus tard; aucune action sur fichiers sans utilisateur présent et confirmation. |
| **Comment ?** | Analyser en lecture, expliquer preuves et limites, permettre inspection/exclusion, revalider avant action, déplacer les candidats admis vers Corbeille, écrire un registre intelligible. Reconstruire sous forme de tranches livrables avec critères vérifiables. |
| **Combien ?** | Gratuit et open source sous licence actuelle tant qu’une décision contraire n’est pas prise. Coûts de développement/distribution à suivre. Aucun budget numérique n’est établi par les sources consultées. |
| **Pourquoi ?** | Donner contrôle et compréhension sur maintenance Mac, avec preuves et limites honnêtes, en se distinguant d’un nettoyeur opaque ou alarmiste. |

## 3. Contexte établi et qualité des sources

### Faits observés

- Dépôt Git sous `app/`, branche active `claude/keen-gates-6dtpoi`; branches locales `main`, `develop/v2`, `feature/app-store-migration`, `maintenance/1.x`.
- Architecture Swift Package Manager; macOS 14+, Swift 6, SwiftUI. Modules présents : `SafetyCore`, `ScanCore`, `FileRules`, `DesignSystem`, `Persistence`, `SystemMetrics`, `AppDiscovery`, `IntegrityCore`, application UI et CLI.
- Huit destinations fonctionnelles décrites par README : Overview, Record, Cleanup, Explore, Duplicates, Applications, Integrity, Performance; paramètres et parcours d’accueil transverses.
- Site statique HTML/CSS/JS généré, anglais/français, sans backend ni analytique selon sa documentation.
- Historique et docs montrent un passage de 1.x publié vers une reconstruction 2.0 pré-alpha; branche actuellement ouverte porte changements d’interface 2.0.
- Le répertoire courant contenait des éléments non suivis `.claude-flow/`, `Documentation/Captures/`, `Xcode/`, `graphify-out/`; ils ne font pas partie de ce cahier et doivent être préservés jusqu’à inventaire.
- `origin` et `archive` sont configurés. Aucune opération de publication ou de push ne fait partie du présent cahier.

### Sources de cadrage

Sources lues : `app/README.md`, `app/Package.swift`, `app/docs/PRODUCT.md`, `app/docs/PROJECT_METHOD.md`, `app/docs/ENGINEERING_RULES.md`, `app/docs/CORETEND_V2_PROGRAM.md`, `app/docs/CORETEND_V2_AUDIT_AND_PLAN.md`, `app/docs/PRODUCT_VOCABULARY.md`, `app/Documentation/ARCHITECTURE.md`, `FEATURE_MATRIX.md`, `SAFETY_MODEL.md`, `THREAT_MODEL.md`, `CURRENT_PROJECT_STATE.json`, `PROJECT_STATE.md`, `MASTER_REQUIREMENTS_BASELINE.md`, `HUMAN_BLOCKERS.md`, ainsi que dossiers Sources/Tests.

### Contradictions à réconcilier avant toute affirmation de version

1. README décrit une version 1.x signée et 2.0 pré-alpha; `CURRENT_PROJECT_STATE.json` décrit v0.9.1-rc.5 non signée; `PROJECT_STATE.md` décrit v1.0.0; programme v2 annonce v1.0.1.
2. Product brief évoque beta publique non signée et l’ancienne proposition de valeur « Living System »; README courant décrit distribution signée/notarisée et langage plus récent.
3. `Documentation/SAFETY_MODEL.md` dit que l’activité enregistre de l’espace « reclaimed », incompatible avec README, vocabulaire canonique et politique actuelle interdisant ces affirmations.
4. Mesures d’audit changent entre documents (338, 677, 687 tests notamment); aucun nombre n’est repris ici comme état actuel.
5. App Store, canal direct, cask Homebrew et identité de version ne sont pas uniformément décrits comme décidés ou livrés.

Règle de réconciliation : priorité aux artefacts publiés vérifiés pour les faits de publication; code et gates actuels pour comportement; décisions produit approuvées pour direction; anciennes notes restent archive historique étiquetée. Aucun document ancien ne devient vérité courante par simple ancienneté.

## 4. Objectifs, indicateurs et limites

### Objectifs

- Reconstruire une base produit claire, modulaire, testable et compréhensible par contributeurs.
- Préserver les propriétés qui différencient CoreTend : contrôle utilisateur, preuves visibles, refus traçables, actions réversibles, honnêteté des quantités.
- Mettre documentation, code, site, captures, version publiée et automatisation en accord mesurable.
- Réduire dérive et coûts de modification sans ajouter dépendance runtime injustifiée.

### Mesures d’acceptation globales

- Chaque exigence MUST possède identifiant, critères d’acceptation et preuve de vérification.
- Aucun chemin produit de déplacement vers Corbeille ne contourne validation typée et revalidation juste avant exécution.
- Aucun « espace libéré/récupéré », score santé ou verdict de sécurité non prouvé ne paraît dans interface, site ou documentation courante.
- L’application démarre, parcours principaux réussissent, état erreur/vide/permission limitée est intelligible.
- Build, suites requises, audit sécurité/confidentialité, localisation, accessibilité, site et paquet de livraison passent les gates projet avant candidate release.
- Chaque fait de livraison publique pointe vers artefact et checksum effectivement vérifiés.
- Tous les écarts connus sont recensés avec propriétaire, priorité, preuve manquante et décision.

Les seuils chiffrés (performance, couverture, versions OS finales, locales supplémentaires, budget) restent à fixer dans le plan après mesure reproductible. Aucune cible arbitraire n’est inventée ici.

### Hors objectifs

- Suppression permanente, nettoyage automatique sans présence, ou assistant privilégié.
- Télémétrie, compte utilisateur, publicité, collecte de fichiers ou backend d’analyse.
- Détection de malware ou promesse d’assainissement.
- Effacer historique Git, reconditionner rétroactivement une release ou publier sans autorisation dédiée.
- Ajouter App Store, mise à jour automatique installante, moteur d’IA ou nouvelle plateforme au seul motif qu’ils seraient possibles.

## 5. Périmètre produit

### Inclus

1. **Overview** : état compréhensible, changements récents et prochaine action fondée sur données présentes.
2. **Record** : historique local des analyses, opérations, refus et échecs; événements séparés de faits démontrés; export/restauration selon politique de données.
3. **Cleanup** : candidats des règles explicites; preuve, taille/date connues, exclusions, sélection revue, confirmation immédiate et déplacement vers Corbeille.
4. **Explore** : tailles de répertoires, arborescence/carte proportionnelle, recherche, navigation, inspection et ouverture Finder.
5. **Duplicates** : correspondance exacte fondée sur contenu; suggestion modifiable; au moins un élément par groupe conservé.
6. **Applications** : inventaire, fichiers associés prudemment attribuables, déplacement réversible; mises à jour déclarées observées sans téléchargement automatique.
7. **Integrity** : signaux natifs macOS vérifiables, avec limites à proximité des résultats; aucun diagnostic antivirus.
8. **Performance** : mesures système datées et contexte temporel; distingue mesure live des résultats historiques.
9. **Réglages, onboarding, accès** : permissions réellement sondées, exclusions et préférences contrôlables.
10. **Site, documentation, CLI et chaîne de distribution** dans la mesure où ils servent compréhension, installation, support et vérifiabilité.

### Limites de décision

- Statut commercial précis, prix futur et financement non décidés ici; conserver distribution gratuite/open source connue jusqu’à décision du mainteneur.
- App Store reste décision produit distincte; par défaut, ne pas bloquer le cœur natif sur sandbox/App Store.
- Intel, minimum macOS au-delà du plancher actuel, locales autres que EN/FR : non engagés sans preuve de demande, coût et capacité de support.

## 6. Exigences fonctionnelles

Priorité **M** Must, **S** Should, **C** Could, **W** Won’t dans programme courant. Chaque M doit être satisfaite avant 1.0 de la reconstruction. S n’est pas promesse de cette livraison.

| ID | Priorité | Exigence | Critère d’acceptation |
|---|---|---|---|
| FR-01 | M | Parcours natif cohérent vers les onze destinations du shell retenu en Programme 3 | Chaque destination peut être ouverte, état courant/restauration de navigation défini, aucun lien mort |
| FR-02 | M | Analyse disque en lecture seule avant revue | Aucune API de déplacement/suppression appelée par scan; progression, annulation et erreurs affichées |
| FR-03 | M | Résultats expliquent origine et limites | Élément relié à règle/provenance, mesures disponibles identifiées, inconnu affiché comme inconnu |
| FR-04 | M | Exclusions persistantes et compréhensibles | Exclusion survit relance; changement de périmètre visible; ne transforme pas contenu utilisateur en cible implicite |
| FR-05 | M | Opération candidate examinée avant transfert Corbeille | Aperçu sélection, confirmation explicite; chaque élément revalidé à l’exécution; résultat par élément |
| FR-06 | M | Record distingue opération, refus et échec | Événement persistant/visiblement classé; aucune conversion silencieuse de refus en succès |
| FR-07 | M | Duplicates exacts gardent un survivant | Groupe ne peut être soumis avec zéro gardé; identité suggestion expliquée et choix modifiable |
| FR-08 | M | Explore montre vraies proportions et tailles connues | Somme et unités cohérentes; place inconnue ou cloud logique séparée des octets locaux |
| FR-09 | M | Intégrité présente uniquement signaux système documentés | Aucun mot « malware détecté », aucun état vert par défaut pour valeur OS inconnue |
| FR-10 | M | Permissions et limitations sont explicites | FDA/accès sondés réellement; refus mène à état dégradé utile et lien vers réglage système pertinent |
| FR-11 | M | Données locales survivent migrations sans perte non annoncée | Migration répétable/transactionnelle; schéma courant indiqué; sauvegarde/rollback documentés |
| FR-12 | M | Interface EN/FR et site restent concordants | Parité de clés et pages critiques; terminologie suit `PRODUCT_VOCABULARY.md` réconciliée |
| FR-13 | M | CLI, si conservé, reste lecture seule | Commandes et format documentés; aucune action fichier ou privilege elevation |
| FR-14 | S | Filtres et presets par catégorie | Choix rendus visibles et reproductibles, unités et règle exposées |
| FR-15 | S | Analyses planifiées, uniquement lecture | Planification désactivable; aucun transfert vers Corbeille planifié |
| FR-16 | S | Cask Homebrew | Formule dérivée d’une release réellement publiée; checksum correspond artefact |
| FR-17 | C | Support localisations additionnelles | Locale complète, relue humainement, pas de fallback trompeur |
| FR-18 | C | Mise à jour in-app installante | Seulement après modèle de signature, validation, rollback et autorisation distincte |

## 7. Exigences non fonctionnelles et invariants

| ID | Domaine | Exigence / preuve exigée |
|---|---|---|
| NFR-01 | Sécurité | Opérations fichier acceptent un type approuvé, jamais chemin arbitraire issu UI; contrôle à approbation et exécution. Tests d’évasion, liens symboliques, chemins protégés et races pertinentes. |
| NFR-02 | Réversibilité | Destination Corbeille macOS; succès n’implique pas que Corbeille sera vidée ou stockage rendu à l’OS. |
| NFR-03 | Confidentialité | Pas télémétrie/analytics/comptes; requête réseau éventuelle déclenchée par utilisateur et décrite. Aucun chemin privé dans artefact public. |
| NFR-04 | Données | Stockage local minimisé; événements de sûreté durables; données sensibles expurgées; migration testée. Rétention et export restent à spécifier. |
| NFR-05 | Robustesse | Annulation prévisible; erreurs typées; panne partielle par élément représentée; aucune erreur aval transformée en succès. |
| NFR-06 | Performance | Mesurer démarrage, analyse, mémoire et réponse UI sur corpus représentatif; fixer budgets après baseline et matériel pris en charge. |
| NFR-07 | Accessibilité | Navigation clavier, VoiceOver, focus, Dynamic Type/zoom, contraste, Reduce Motion, états non-colorimétriques et langue. Vérifier par automatisation et observation humaine. |
| NFR-08 | Utilisabilité | Première analyse compréhensible sans lecture de manuel; permissions demandées au moment utile; aucun mur d’avertissements. |
| NFR-09 | Compatibilité | macOS 14+ arm64 comme plancher de départ; matrice CI et test matériel décrivent la vraie couverture, pas l’intention. |
| NFR-10 | Maintenabilité | Moteurs sans UI; dépendances dirigées et explicites; source unique des faits dérivables; modules de responsabilité nette. |
| NFR-11 | Dépendances | Zéro dépendance runtime externe par défaut. Exception documentée avec bénéfice, surface sécurité, licence, maintenance et approbation. |
| NFR-12 | Distribution | Signature, notarisation, checksums et provenance seulement annoncés après validation des octets candidats. Release exige autorisation explicite. |
| NFR-13 | Documentation | Décisions séparées de données dérivées; documents courants pointent propriétaires, date/source, statut et preuve. |
| NFR-14 | Site | Contenu essentiel au premier rendu, CSP restrictive, langues EN/FR, navigation clavier, reduced motion, sans analytics. |

## 8. Choix d’architecture proposés

### Principes

- Construire en Swift/SwiftUI natif, SwiftPM comme build system initial; pas de migration de langage/framework sans preuve.
- Couches : interface/coquille; cas d’usage/application; moteurs de scan et domaines de fonctionnalité; SafetyCore comme unique porte d’opérations; persistance locale; adaptateurs macOS.
- Flux d’analyse asynchrone annulable et résultats typés. Aucune écriture issue d’un moteur d’analyse.
- La UI soumet intention typée. SafetyCore vérifie racines protégées, portée, nature de cible et état courant avant acte.
- Événement d’audit émis pour approbation/refus/exécution/échec; persistance durable séparée du rendu UI.
- Le site public ne duplique pas manuellement version/checksum/capacités de release si elles peuvent être générées depuis un enregistrement publié vérifié.
- Code courant remplacé par strangler migration : une capacité à la fois, nouvelle implémentation derrière contrat commun, comparaison de résultats, bascule, retrait après parité.

### Modules cibles indicatifs

`SafetyCore`, `ScanCore`, `FileRules`, `Persistence`, `SystemMetrics`, `AppDiscovery`, `IntegrityCore`, `DesignSystem`, `CoreTendApp`, `CoreTendCLI`. Garder module seulement s’il possède frontière et consommateurs réels; scinder CoreTendApp au niveau dossiers/responsabilités, pas en cibles artificielles. Architecture finale et graphe dérivés du code.

### Données

- Fichiers macOS : chemins locaux et métadonnées minimales; ne jamais suivre un lien hors périmètre.
- SQLite local (si confirmé comme besoin actuel) : version schéma, transactions, migrations idempotentes, sauvegarde avant migration risquée.
- Registre : faits connus + provenance + résultat + horodatage; événement de refus n’est ni omission ni succès.
- Nuage : distinguer octets locaux, taille logique et placeholder non téléchargé.
- Aucune synchronisation distante prévue.

### Gestion des erreurs

Résultat structuré par élément : proposé, refusé, déplacé, échoué, annulé ou non pris en charge. Montrer cause utile sans divulguer chemin sensible dans télémétrie (qui n’existe pas). État de permission inconnue/refusée demeure distinct d’absence de problème.

## 9. Design et expérience

- Registre produit : calme, précis, premium, technique, macOS contemporain; expliquer données avant action.
- Apparence doit découler d’une identité CoreTend originale, non copie de concurrent ou d’Apple.
- Chaque écran sert tâche claire; densité lisible; hiérarchie, typographie, espacement et surfaces remplacent empilement de cartes décoratives.
- Données réelles uniquement. Pas de scores synthétiques, graphiques sans historique, métriques présentées sans origine.
- Chaque destination définit loading, vide, résultat, erreur, annulation, accès réduit et contenu volumineux.
- Animation informative, courte, interruptible et respectueuse de Reduce Motion.
- EN/FR; vocabulaire canonique à réconcilier avec interface réelle avant modification des textes.
- Maquettes/captures doivent représenter version et données honnêtes; démo explicitement marquée.

## 10. MoSCoW global

| Classe | Livrables |
|---|---|
| **Must** | Cahier de charges réconcilié; shell/app stable; huit fonctions présentes ou décisions explicites de retrait; SafetyCore et workflow Corbeille; analyses locales; registre, persistance/migrations; EN/FR; accessibilité; sécurité/confidentialité; installation reproductible; site et documentation exacts; release gates vérifiables. |
| **Should** | cask Homebrew; filtres/presets utiles; scans planifiés sans action; performances mesurées; threat model et limitations maintenus; captures produit renouvelées; test matériel/macOS élargi. |
| **Could** | langues supplémentaires; installateur updater; catégories cache additionnelles; outil menu-bar enrichi; vidéo produit; distribution App Store après étude indépendante. |
| **Won’t pour cette reconstruction** | suppression définitive; nettoyage planifié; télémétrie; compte/cloud-sync; scan antivirus revendiqué; helper privilégié; expérience App Store qui compromet fonctions cœur; promises d’espace récupéré ou score de santé. |

## 11. RACI

R = réalise; A = assume décision/résultat final; C = consulté; I = informé. Rôles, pas personnes secondaires supposées.

| Activité | Mainteneur produit | Ingénierie | Revue sécurité/qualité | UX/accessibilité | Publication/distribution |
|---|---|---|---|---|---|
| Vision, périmètre, MoSCoW | A | C | C | C | I |
| Exigences et acceptation | A | R | C | C | I |
| Architecture et code | A | R | C | C | I |
| Politique de sûreté et données | A | R | C | I | I |
| Design, contenu et navigation | A | C | I | R | I |
| Vérification et traçabilité | A | R | R | C | I |
| Migration données/code | A | R | C | I | I |
| Signature, notarisation, release | A | C | C | I | R |
| Publication publique, push/tag/site | A/R | I | C | I | R |
| Support incidents/vulnérabilité | A | R | R | I | C |

Le mainteneur reste seul A pour décisions produit, posture de sûreté et acte de publication. Si un poste manque, activité reste non attribuée; on n’invente pas personne.

## 12. Risques et traitements

| Risque | Effet | Traitement / preuve de fermeture |
|---|---|---|
| Cahier basé sur documents périmés | Mauvais comportement ou promesse | Inventaire des sources, faits/propositions étiquetés, approbation de décisions ouvertes |
| Réécriture totale détruit stabilité ou apprentissages | Régression et délai indéfini | Remplacement par capacité, contrats, comparaison, retour arrière par tranche |
| Suppression accidentelle de données personnelles | Dommage grave | Aucun delete; type approuvé, racines protégées, revalidation, confirmation, tests d’évasion |
| Corbeille interprétée comme stockage libéré | Tromperie produit | Terminologie gardée; aucune quantité de récupération |
| Événements perdus | Record incomplet et audit trompeur | Politique durabilité/échec explicite; test de persistance et injection de panne |
| Migration SQLite incompatible | Perte ou duplicata | Sauvegarde, migrations versionnées idempotentes, fixtures anciennes, rollback défini |
| Dépendance supplémentaire étend surface | Maintenance et risque supply chain | Zéro runtime deps par défaut; examen et consentement mainteneur |
| Scope gonfle vers App Store/installer multi-canal | Retard de reconstruction | Canal direct cœur; décisions App Store séparées avec business case |
| Claims d’intégrité confondus avec antivirus | Faux sentiment sécurité | Limites au résultat, copy review, assertions/gates |
| États site/code/release divergent | Install ou information incorrecte | Manifeste source vérifié et génération/checksums automatisés |
| Preuves uniquement sur un Mac | Compatibilité surestimée | Matrice explicite; tests seconde machine comme gate de confiance avant stable |
| Branche ou fichiers non suivis écrasés | Perte de travail utilisateur | Inventaire initial, travail isolé/commit ciblé, aucun nettoyage/reset global |

## 13. Migration depuis l’existant

1. Geler et décrire baseline réelle par branche, commit, artefacts publiés, DB et fonctionnalités; ne pas prendre `PROJECT_STATE` ancien comme vérité.
2. Établir contrat données et comportement pour un module; capturer tests/cas, états UI et format persistance.
3. Construire nouvelle capacité sous interface stable; exécuter ancien et nouveau sur fixtures non destructives, comparer sorties.
4. Migrer schema si nécessaire avec lecture des versions réellement rencontrées, sauvegarde, transaction et chemin d’échec.
5. Basculer capacité, garder rollback de code et données; observer gates.
6. Retirer ancien chemin seulement quand preuve de parité et migration validée. Archive historique explicite si utile.
7. Reconcilier docs dérivées depuis code; taguer documents historiques et éviter double source de vérité.

Pas de migration automatique destructive de fichiers utilisateur. Pas de conversion ou effacement de la base avant sauvegarde vérifiée.

## 14. Plan de validation / critères de sortie

### Avant reconstruction

- Une source de vérité projet/release identifiée; contradictions listées, décisions ouvertes assignées.
- Inventaire de la branche et changements non suivis sauvegardés/protégés.
- Baseline build, tests, gates et captures recueillie sans reprendre de chiffres non reproduits.

### Par tranche

- Tests de contrat et cas de refus/échec couvrent le comportement ajouté.
- Module build/test ciblé; intégration au package; aucune nouvelle warning non acceptée.
- Audit de chemin d’écriture, permission et réseau associé au changement.
- UI capturée et lue pour écrans modifiés; interaction/accessibilité vérifiée par méthode indiquée.
- Traçabilité exigences → code/tests/docs mise à jour.

### Candidate reconstruction

- Tous critères Must FR/NFR reliés à preuve; aucun Must ouvert.
- Migration historique depuis chaque schéma supporté validée; sauvegarde et restauration éprouvées.
- Build release propre; suite projet complète; repository doctor, sécurité, confidentialité, localisation, accessibilité, site et packaging verts.
- Matrice macOS/hardware observée et limitations affichées.
- DMG installée en environnement propre, signature/notarisation/checksum vérifiées si canal direct publié.
- Produit/site/readme/manifest décrivent mêmes fonctions, versions et limitations.
- Mainteneur accepte manuellement qualité visuelle, comportement et texte.

Pas de push, tag, déploiement, publication ou dépense externe sans autorisation propre à cette action. L’approbation du cahier autorise cadrage et préparation, pas actes publics.

## 15. Questions ouvertes à maintenir explicites

1. Quelle version/branche représente candidat courant et quelle release est actuellement publique? Vérifier manifest et artefacts.
2. App Store : futur produit dérivé ou abandon? Décision séparée après évaluation des capabilities sandbox.
3. Cibles OS/architecture à supporter au-delà arm64/macOS 14? Décider selon données réelles d’usage/support.
4. Quels événements persistent, combien de temps et comment l’utilisateur les exporte/efface?
5. Ordre de reconstruction des destinations selon coût/valeur après baseline de qualité.
6. Seuils de performance et couverture fondés sur mesures initiales.
7. Quelles options v2 2.x sont réellement des décisions approuvées (look, cask, locales, scheduled scans)?

## 16. Traçabilité documentaire

Ce cahier devient document maître pour la reconstruction après validation du mainteneur. Les documents sources ne sont pas supprimés à ce stade. Après plan d’exécution, créer matrice de traçabilité par requirement ID et lier chaque contrat/test. Découper en programmes autonomes : (1) cohérence documentaire/baseline; (2) cœur de sûreté et persistance; (3) moteurs domaine; (4) shell/UI/accessibilité; (5) site/distribution; (6) release candidate. Chaque programme obtient son propre plan et critères de sortie.
