# Passation complète — CoreTend Next

**État au 26-09-2026.** Reconstruction active, pas finalisée, aucune release publique. Dépôt `ahmetbsbnr/coretend`; worktree `next/`, branche de travail `feat/access-diagnostics` basée sur `next` au commit documentaire #53 (`55e8628`). Dernière tranche app fusionnée #50 (`b0287bf`). Tranche FR-10 en cours dans ce worktree; qualification complète et paquet mis à jour à faire avant PR. Prochaine reprise sur `feat/access-diagnostics` jusqu’à PR, puis `next`.

## État immédiat

- PR #46–#52 fusionnées; tous les checks GitHub `qualify` requis réussissent. Protection `next` exige `qualify` strict; force-push et suppression de branche interdits. Aperçus Vercel ont atteint leur quota sur les PR récentes; ces contrôles ne sont pas requis par la protection. Aucun déploiement/publication CoreTend effectué.
- Cahier des charges complet et approuvé : QQOQCCP, MoSCoW, RACI, objectifs, exigences, architecture, risques et séquence. Voir `Documentation/Project/Cahier-des-charges.md`.
- Traceability contient 40 FR/NFR + 51 capacités; 91 statuts renseignés. La ligne NFR-07 a été réalignée sur les colonnes CSV; statut PARTIEL tant que revue clavier/VoiceOver/Dynamic Type/contraste/Reduce Motion n’est pas faite.
- App SwiftUI macOS, CLI Swift, persistance SQLite, modules métier, site statique EN/FR et scripts de paquet sont présents. Résultats/états restent partiels selon `Documentation/Traceability.csv`; aucun jalon ne signifie produit final.
- Dernière qualification locale : `make qualify` sur `feat/access-diagnostics`. Elle couvre génération, site, traçabilité, audit statique de sûreté, installation fixture en HOME temporaire, XCTest complet, builds debug App/CLI et whitespace. Aucune UI native/VoiceOver n’est qualifiée par ce gate.
- Paquet courant : `Artifacts/CoreTend-local-unsigned.zip`, arm64, construit depuis `feat/access-diagnostics`. SHA-256 `20a72cf36d3327018b8c78fef76e2f8aab835629b0558345f2b99749693c6024`. `make verify-package` passe; vérification limitée à Info.plist, archive et Mach-O. Non lancé depuis cette tranche, non installé sur le Mac, signé, notarié ou publié. Preuve dans `Documentation/ReleaseEvidence.md`.
- Essai UI isolé du 26-09-2026 : copie du bundle lancée depuis HOME temporaire; fenêtre nommée `CoreTend` observée. Lecture détaillée des contrôles via System Events échoue (`-10827`); aucune vérification clavier/VoiceOver/zoom/contraste/mouvement réalisée. NFR-07 reste PARTIEL. Voir `Documentation/Evidence/Accessibility.md`.
- FR-10 — tranche prête pour PR : Applications distingue racine disparue, accès refusé, mauvais type, symlink et lecture impossible; messages EN/FR ajoutés. `make qualify`, packaging, vérification paquet et whitespace passent. FR-10 demeure PARTIEL faute de sondes TCC complètes et parcours de réglages système.
- Copie greenfield historique `rebuild/` conservée localement comme provenance. Passation/documents 1.x archivés sous `Documentation/Archive/Legacy-Reconstruction/`; ils ne décrivent pas le code actuel.

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
- SQLite schema v4 : événements, préférences/exclusions/imports, Performance, favoris/récents. Migrations transactionnelles v1–v4; store URL injectable. CLI ouverte explicitement en lecture seule. Favoris exigent clic explicite. Récents désactivés par défaut, maximum 100, écritures en batch. Aucun chemin mémorisé ne rouvre automatiquement un fichier.
- Mutations fichier seulement via SafetyCore et adaptation macOS Trash; scans ne changent pas l’arbre choisi. Tests utilisent fixtures temporaires et fausse Corbeille. Pas de suppression permanente.
- App associée : inventaire `.app` seulement sous racine choisie; recherche de reliquats par identifiant exact dans autre dossier choisi, consultation seulement. Attribution de propriété pas prouvée. Action existante déplace uniquement bundle `.app` choisi avec revue/confirmation; données associées/héritées restent intactes.
- Réseau runtime limité par conception; audit statique bloque API cliente courante et SDK analytiques connus. NFR-04 reste PARTIEL sans capture trafic runtime et revue indépendante.

## Gaps et limites à garder visibles

La traçabilité est source de vérité par exigence. Elle suit 40 FR/NFR et 51 capacités; Must ont encore états EN_COURS/PARTIEL/À_CONSTRUIRE. Ne convertir aucun statut sans preuves correspondant au critère complet.

- **UI/accessibilité :** lancer/observer app en environnement isolé, vérifier clavier, focus, VoiceOver, Dynamic Type/zoom, contraste, Reduce Motion/Transparency, Quick Look, graphique et états vides/erreur/annulation. FR-01, FR-23, FR-24 et NFR-07 incomplets tant que cette qualification manque.
- **FR-26 Apps :** correspondance de nom/bundle ID n’est pas preuve de propriété. Ne pas supprimer données associées ni héritées; priorité à une méthode d’attribution documentée, contrôlable et sûre avant toute action. Garder parcours consultatif et déplacement bundle seul tant que preuve insuffisante.
- **FR-10 Permissions :** l’aide actuelle explique accès au dossier choisi et récupération; pas de sondes exhaustives TCC/Full Disk Access ni deep links système. Ne pas inférer absence d’élément depuis résultat partiel.
- **FR-14 Distribution :** install smoke en HOME fixture et validation de structure passent; app jamais ouverte. Pas de preuve GUI install/désinstall, signature, notarisation, compatibilité deuxième hôte/version macOS ni release.
- **Données/migration :** import JSON legacy v1 reconnu et copy-only; formats anciens non reconnus, restauration complète, interruption/reprise élargie et qualification UI restent ouverts. Effacement SQLite logique, aucune garantie forensique.
- **Applications/Integrity :** aucun contrôle App Store/version update; `SUFeedURL` déclaré seulement. Marqueur quarantine et signature sont des signaux limités, aucun verdict malware/provenance.
- **Features partielles :** images similaires heuristique non calibrée/corpus à établir; cloud, menu bar et login items non livrés; certains filtres et usages système encore incomplets; CLI localisation/cas d’annulation restent incomplets.
- **Perf/release :** pas de baseline représentative start/scan/CPU/RSS; pas de capture réseau runtime; aucune review sécurité indépendante; paquet courant unsigned.

## Ordre de reprise conseillé

1. Après cette PR, reprendre `Documentation/Traceability.csv` et `Documentation/Project/Implementation-plan.md`; travailler l’attribution FR-26 avec une source de preuve documentée et contrôlable. Garder toute donnée associée consultative tant que propriété non démontrée. Qualification UI/accessibilité clavier/VoiceOver reste à compléter avec inspection native fonctionnelle; l’essai System Events précédent n’a pas suffi.
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
