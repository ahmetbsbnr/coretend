# Passation — CoreTend `next`

**État relevé : 27 septembre 2026.** Reconstruction en cours, non finalisée; aucune release publique. Cette passation remplace les anciens résumés contradictoires. Pour l’historique détaillé des jalons, lire `Documentation/Progress.md` et l’historique Git.

## État courant

- Dépôt canonique : `ahmetbsbnr/coretend`, worktree `next/`.
- Branche : `feat/reconstruction-open-musts`, HEAD `904f17e33c58ebeb4cb7dfebc5cde6ad59091030` (`chore: keep local execution plan untracked`), synchronisée avec `origin/feat/reconstruction-open-musts`. Base de PR : `next` (`origin/next` à `55e8628`).
- PR brouillon [#55](https://github.com/ahmetbsbnr/coretend/pull/55), ouverte vers `next`.
- GitHub Actions `qualify` passe sur HEAD `904f17e`, run [36305958446](https://github.com/ahmetbsbnr/coretend/actions/runs/36305958446). Les contrôles Vercel `app` et `coretend` échouent parce que le compte a atteint sa limite de déploiement (« retry in 24 hours »); le contrôle agrégé Vercel reste en attente. Ce blocage n’indique pas un échec de compilation.
- `git status` : branche propre; seul fichier non suivi est `Documentation/Project/Remaining-musts-plan.md`. **Le conserver localement, ne jamais l’ajouter à Git.**
- Aucun merge, tag, signature, notarisation, publication ni déploiement CoreTend n’a été effectué.

## Mesure de couverture du registre

Source de vérité : `Documentation/Traceability.csv`, 91 lignes.

| Priorité | PARTIEL | VÉRIFIÉ | À_CONSTRUIRE | Couverture indicative* |
| --- | ---: | ---: | ---: | ---: |
| Must (78) | 76 | 2 | 0 | 51,3 % |
| Should (11) | 10 | 0 | 1 | 45,5 % |
| Conseil (1) | 0 | 0 | 1 | — |
| Won’t (1) | 0 | 0 | 1 | — |
| Total (91) | 86 | 2 | 3 | 49,5 % |

\* Indice de couverture des preuves : `VÉRIFIÉ=100 %`, `PARTIEL=50 %`, `EN_COURS=25 %`, `À_CONSTRUIRE=0 %`. Ce n’est pas un pourcentage officiel de produit recréé. Aucun Must incomplet ne doit être déclaré vérifié sur la seule base de tests unitaires ou d’une compilation.

## Vérifications disponibles

- `make qualify` a passé localement après les changements de code de `904f17e`; il couvre génération/site, traceabilité, audits sûreté/architecture, smokes install/uninstall/runtime isolés, builds Release reproductibles, suites XCTest, builds Debug App/CLI et interruption CLI/SIGINT. Les changements plus récents dans cette session n’ont touché que cette passation; vérifier `git diff --check` avant checkpoint.
- CI GitHub `qualify` a passé sur le même HEAD, run `36305958446` (`macos-26-arm64`). Builds Release locaux observés sur arm64/macOS 27.0; hashes App/CLI et limites sont dans `Documentation/Evidence/ReleaseReproducibility.md`.
- Smoke d’app packagée : deux lancements Release en HOME/store temporaires; première observation SQLite à 1,094 s; 13 mesures réseau par exécution sans socket Internet observée. CPU `ps` et RSS sont des échantillons, pas mesures de fenêtre prête ou de pic CPU. Détails : `Documentation/Evidence/PerformanceBaseline.md`.
- Baseline CLI Release : fixture synthétique de 10 000 fichiers / 100 dossiers, médiane chaude 0,913 s murale, 0,979 s CPU, 74,18 MiB RSS maximal. Aucun budget n’est déduit de cette fixture seule.
- Preuves natives antérieures, limitées à arm64/macOS 27.0 : fenêtre SwiftUI observée, accueil AX, huit routes de lancement et fallback de route inconnue; un parcours ⌘K → Performances. Détails et limites : `Documentation/Evidence/AppWindowRuntimeQualification.md`.
- Site : Lighthouse local, 11 routes EN/FR, Accessibilité/Bonnes pratiques/Agentic Browsing 100; navigation skip-link et largeurs émulées 640/320 CSS px. Pas de preuve de zoom navigateur réel, VoiceOver ou réglages OS. Détails : `Documentation/Evidence/SiteAccessibilitySmoke.md`.
- Le dernier essai DevTools de cette reprise n’a pas établi un vrai zoom navigateur : le viewport est resté fixé par émulation à 640 px malgré les raccourcis envoyés. N’en tirer aucune nouvelle preuve NFR-11.

## Produit et périmètre déjà présent

- Application SwiftUI macOS, CLI Swift en lecture seule, SQLite local, site statique EN/FR. Huit destinations : Overview, Record, Cleanup, Explore, Duplicates, Applications, Integrity, Performance.
- Modules : `ProductContract`, `AppShell`, `ScanCore` (lecture seule), `SafetyCore` (actions sûres/Corbeille), `Persistence`, `Domain`, `CoreTendApp`, `CLIContract`, `CoreTendCLI`. Swift 6, SwiftPM, cible déclarée macOS 14+; seule compatibilité effectivement observée reste arm64/macOS 26 CI et macOS 27 local.
- SQLite schéma v5; migrations transactionnelles, événements d’activité avec `failure_code` nullable, performance, exclusions, favoris/récents et import legacy explicite copie-seule. Les fixtures n’utilisent ni store personnel ni vraie Corbeille.
- Opérations de fichiers uniquement via SafetyCore vers API macOS Trash; aucun effacement permanent. Scans lecture seule, annulation/progrès causaux, validations de racines et symlinks, revue/confirmation/revalidation/audit pour les parcours déjà implémentés.
- Les 22 tâches listées dans le plan local `Documentation/Project/Remaining-musts-plan.md` sont déjà couvertes par code/fixtures selon l’audit consigné. Ce fichier demeure local/non suivi; il ne remplace pas le plan officiel `Documentation/Project/Implementation-plan.md` ni les critères d’acceptation.
- Le ZIP local ignoré par Git `Artifacts/CoreTend-local-unsigned.zip` est un artefact de développement, pas une release candidate. Aucune revendication de signature, notarisation ou publication.

## Musts encore partiels et conditions externes

Les 76 Must `PARTIEL` ont des gaps individuels dans Traceability. Les catégories transversales restantes comprennent :

- Qualification macOS native : interaction sidebar, clavier/focus, Quick Look, MenuBarExtra, confirmations, états d’accès; VoiceOver parlé, Dynamic Type/zoom, contraste et Reduce Motion/Transparency.
- Sûreté et permissions : parcours avec accès refusé, comportements réels de la Corbeille et attribution des données associées; pas de sondage FDA/TCC exhaustif.
- Compatibilité/performance : minimum macOS, deuxième version/hôte, corpus représentatif, startup jusqu’à fenêtre, latence UI et mesures scan CPU/RSS.
- Documentation et release : revue indépendante, capture UI/profiling multi-OS, ergonomie externe, signature/notarisation et artefacts authentiques avant toute publication.

Points précis :

- **FR-26 — attribution de données d’app** : décision utilisateur du 27-09-2026 : **retrait du bundle seul**. Aucune source de preuve d’appartenance approuvée; les candidats par bundle ID restent consultatifs, sans action. Consigné dans Traceability et Progress. Reste PARTIEL pour UI native et Corbeille réelle. Ne pas coder d’action sur données associées sans nouveau contrat approuvé.
- **NFR-11 — zoom du site** : largeur 640 CSS px est seulement un proxy antérieur; vrai zoom navigateur non vérifié. DevTools actuel fixe le viewport et ne permet pas d’en tirer une preuve.
- **NFR-13 — reproductibilité Release** : `VÉRIFIÉ` uniquement pour source/checkout/hôtes/toolchains observés. Pas d’identité de hash revendiquée entre hôtes.
- **FR-15** : `VÉRIFIÉ` dans son périmètre de contenu/génération statique EN/FR et état de publication honnête. Accessibilité navigateur/OS et déploiement restent NFR-11/NFR-14.

Le plan officiel conserve des cases ouvertes pour qualification native/accessibilité, release authentique, hôte macOS minimum/autre machine, capture UI/profiling multi-macOS et revue ergonomique externe. Ne pas les cocher sans preuve correspondante.

## Ordre de reprise

1. FR-26 tranché (bundle seul, voir ci-dessus); aucune implémentation d’attribution à faire.
2. Continuer les qualifications natives/accessibilité réalisables sur app/store fixture; inscrire uniquement observations réellement faites, hôte, protocole et limites.
3. Réconcilier chaque exigence dans `Documentation/Traceability.csv`, puis `Documentation/Progress.md`, preuves dédiées, guide et `passation.md`. Garder `PARTIEL` quand un seul critère requis manque.
4. Avant commit : `make qualify`, `python3 Scripts/check_traceability.py`, `git diff --check`; examiner `git status --short --branch`. Ne pas stage `Documentation/Project/Remaining-musts-plan.md`.
5. Commit/push sur `feat/reconstruction-open-musts`; confirmer les checks PR #55. Vercel peut rester rouge pour quota. Fusion vers `next` seulement conformément à la stratégie du dépôt et après gate requis; pas de merge/tag/release/publication sans conditions formelles.
6. Finir Must avant Should. Ne pas fabriquer de Cask sans release publiée/checksum; ne pas réaliser des fonctions explicitement différées du cahier.

## Commandes et sources à reprendre

- Gate complet : `make qualify`
- Traceabilité : `python3 Scripts/check_traceability.py` et `python3 -m unittest Scripts.test_traceability`
- Site : `make build-site site-check`
- Baseline scan : `make benchmark-scan`
- Smoke app Release isolé : `make app-runtime-smoke`
- Tests Swift ciblés : `swift test --filter PersistenceTests`, `swift test --filter DomainTests`, `swift test --filter ScanCoreTests`, `swift test --filter AppShellTests`
- Références normatives : `Documentation/Project/Cahier-des-charges.md`, `Documentation/Project/Implementation-plan.md`, `Documentation/Traceability.csv`, `Documentation/Project/Repository-strategy.md`.
- Références de preuve : `Documentation/Progress.md`, `Documentation/ReleaseEvidence.md`, `Documentation/Evidence/ReleaseReproducibility.md`, `Documentation/Evidence/PerformanceBaseline.md`, `Documentation/Evidence/AppWindowRuntimeQualification.md`, `Documentation/Evidence/SiteAccessibilitySmoke.md`.

## Invariants de reprise

- Aucun test sur vrai HOME/store CoreTend/Corbeille ou données privées; toute mutation sous fixture temporaire avec Fake Trash.
- Ne pas solliciter FDA, sudo, effacement permanent, accès réseau silencieux, télémétrie, installation de mise à jour ou migration destructive.
- Erreur, inconnue, absence et échec restent distincts. Ne pas affirmer propriété, sûreté, malware, espace récupéré, statut release ou accessibilité sans preuve.
- Préserver `Documentation/Project/Remaining-musts-plan.md` non suivi et artefacts locaux ignorés.
