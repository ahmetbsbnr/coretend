# Passation — reconstruction CoreTend

## Où reprendre

- Dépôt : `/private/tmp/coretend-reconstruction`
- Branche : `reconstruction/baseline`
- Base : `23824216fdefce81802da76a34a92042215506e6`
- Programme 1 en cours. Modifications locales non commitées; poursuivre dans ce worktree.
- Référence complète : `docs/superpowers/specs/2026-09-25-coretend-reconstruction-design.md` et feuille de route `docs/superpowers/plans/2026-09-25-coretend-reconstruction-roadmap.md`.

## Demande et mandat

Le mainteneur a demandé une reconstruction complète du projet depuis son contexte, nettoyage du dépôt, cahier des charges complet, QQOQCCP, MoSCoW, RACI et tous documents nécessaires. Choix de conception délégués à l’agent. Mainteneur a approuvé et validé ce mandat.

Le nettoyage exécuté a retiré uniquement des caches régénérables ignorés du checkout initial : `.build/`, `build/`, `Website/dist/`, `graphify-out/cache/`, `__pycache__`, `.DS_Store`. Données, configurations, documents non suivis et secrets locaux ont été conservés. Le travail de reconstruction se fait dans le worktree isolé ci-dessus.

## Livré — Programme 0

Cahier et dossier de référence créés, revus, commités. Comprennent QQOQCCP, exigences FR-01..18 et NFR-01..14, MoSCoW, RACI, invariants de sûreté, risques, critères d’acceptation, baseline, traçabilité et décisions.

Fichiers principaux :

- `docs/superpowers/specs/2026-09-25-coretend-reconstruction-design.md`
- `docs/superpowers/plans/2026-09-25-coretend-reconstruction-roadmap.md`
- `docs/superpowers/plans/2026-09-25-coretend-baseline-reconciliation.md`
- `Documentation/Reconstruction/BASELINE.md`
- `Documentation/Reconstruction/REQUIREMENTS_TRACEABILITY.md`
- `Documentation/Reconstruction/DECISIONS.md`
- `Documentation/README.md`, `docs/README.md`

Commits de cette séquence : `b9be3e2`, `632477a`, `42b2fa9`, `f232f54`, `bffcf43`, `e76be6f`, `c77dafd`, `8a40f32`, `b405ed9`.

État initial mesuré le 25-09-2026 : suite officielle `Scripts/test.sh` réussie (386 tests, 12 suites non vides et une suite vide); build release réussi; parité Base/FR 569/569; repository doctor réussi. Gate du site bloquée par Playwright absent après réussite des contrôles CSP/tokens. Le dépôt ne contient pas de preuve fiable de version publiée actuelle : marquer inconnue, ne pas inventer. Tag local `v1.0.2` observé, pas preuve de release distante.

Décisions déléguées : macOS 14/arm64 initial; sûreté et persistance prioritaires; activité locale conservée jusqu’à effacement explicite; éléments déplacés vont à la Corbeille et ne sont pas comptés comme espace libéré; pas d’App Store, tâches planifiées, nouvelles langues ou installateur dans le périmètre actuel. D-01 release publique inconnue; D-06 seuils de performance en attente de mesures.

## En cours — Programme 1

Plan détaillé : `docs/superpowers/plans/2026-09-25-coretend-safety-persistence-contracts.md`.

But : refuser toute opération destructive si approbation non validée ou journal d’audit non persisté; rendre le vocabulaire honnête sur la Corbeille; comptabiliser précisément les échecs d’approbation; ajouter un gate de copie EN/FR. Aucun changement de schéma SQLite prévu.

Modifiés mais non commités :

- `Sources/SafetyCore/SafetyCore.swift`
- `Sources/Persistence/Store.swift`
- `Sources/CoreTendApp/ApplicationsView.swift`
- `Sources/CoreTendApp/CleanupView.swift`
- `Sources/CoreTendApp/DashboardView.swift`
- `Sources/CoreTendApp/DuplicatesView.swift`
- `Sources/CoreTendApp/ExecutionOutcome.swift`
- `Sources/CoreTendApp/LeftoversView.swift`
- `Sources/CoreTendApp/MyActivityView.swift`
- `Sources/CoreTendApp/PrivacyCleanerView.swift`
- `Sources/CoreTendApp/SpaceLensView.swift`
- `Tests/CoreTendAppTests/ExecutionOutcomeTests.swift`
- `Tests/CoreTendAppTests/MyActivityGroupingTests.swift`
- `Tests/SafetyCoreTests/PathValidatorTests.swift`
- `Scripts/check-copy-honesty.py` (nouveau)
- `passation.md` (présente passation)

Statut Git observé avant création de ce fichier : 14 fichiers suivis modifiés et `Scripts/check-copy-honesty.py` non suivi; ajouter `passation.md` à cette liste.

Changements déjà amorcés :

- `SafetyAuditSink.recordSafetyEvent` devient async et retourne succès durable `Bool`.
- `SafetyCenter.approve` refuse si écriture `.approved` échoue; ajout erreur `.auditUnavailable` et étape `.refused`; codes d’audit stables sans chemin.
- `Store` retourne vrai après écriture SQLite, faux en cas d’échec et incrémente le compteur des événements non enregistrés.
- Résultat d’exécution renomme `freedBytes` en `bytesMovedToTrash`, commence à compter les approbations refusées/éléments sautés et évite faux succès sans déplacement.
- Tests fail-first ajoutés pour sink manquant, échec d’écriture et absence de chemin résolu dans l’audit.
- Nouveau script de contrôle éditorial créé, mais pas encore passé.

## Preuve et blocage actuel

Le script `python3 Scripts/check-copy-honesty.py` a échoué avant corrections : clés EN/FR proposées manquantes, anciens intitulés toujours présents, formulations promettant espace récupéré dans SpaceLens et doublons. C’est un échec attendu de départ; finir les corrections puis le relancer.

Les tests Swift n’ont pas atteint les assertions. `swift test --filter SafetyCenterAuditSinkTests` et `Scripts/test.sh --filter SafetyCenterAuditSinkTests` bloquent pendant analyse de dépendances du produit `CoreTendUITests` : `_TestingInternals` non résolu. Un lancement sandboxé a aussi échoué sur `sandbox_apply`. Ne pas présenter ces tests comme réussis ou comme échec fonctionnel; diagnostiquer la configuration/package/outil et conserver l’erreur exacte.

Aucune validation build complète après les modifications présentes. Programme 1 inachevé.

## Reprise — ordre conseillé

1. Lire le plan Programme 1 puis diff complet. Vérifier protocoles/call sites après changement du sink; mettre à jour commentaire de `Store` sur retour Bool.
2. Compléter journalisation : ajouter localisation de `.refused`, mettre à jour `SafetyLogView` (switch, couleurs, compteurs/accessibilité) et tests Store/round-trip.
3. Finir `ExecutionOutcome`: localisations EN/FR des états aucun déplacement/refus/mixte; traduire `annotate`; écrire tests de comptage. Rechercher chaque constructeur d’`ExecutionOutcome`.
4. Corriger tous les libellés visibles pour ne pas prétendre que la Corbeille libère l’espace. Examiner notamment `activity.freed_real`, `dashboard.reclaimed`, `spacelens.delete.confirm_message`, le résumé doublons, CloudSummary et sidebar. Aligner les clés EN/FR et variables Cloud; aucun changement de schéma SQLite.
5. Mettre à jour `Documentation/SAFETY_MODEL.md`, `Documentation/ARCHITECTURE_OVERVIEW.md`, `Documentation/INSTRUMENT_REDESIGN.md` pour contrat d’audit et sémantique Corbeille. Ne pas retoucher les archives historiques.
6. Brancher `Scripts/check-copy-honesty.py` dans `Scripts/repository-doctor.sh` et `.github/workflows/ci.yml`; faire réussir le contrôle et parité localisation.
7. Réparer ou contourner proprement le blocage `_TestingInternals` sans réseau. Lancer d’abord tests ciblés, puis build et suite officielle. Lancer repository doctor. Vérifier le diff et noter les résultats avec horaires UTC.
8. Rechercher les promesses de récupération d’espace dans les surfaces applicatives (`rg` sur `freed|reclaimed|reclaimable|recoverable`); le site web est hors de ce programme, traité plus tard.
9. Committer uniquement le Programme 1 cohérent quand validations et docs sont à jour. Continuer ensuite Programmes 2–5 du roadmap. Ne pas déclarer la reconstruction complète à la fin du seul Programme 1.

## Contraintes

- Le dépôt demande exclusivement `mcp__web__web_search` pour toute recherche internet/lecture de page. Cet outil n’était pas disponible; ne pas utiliser d’autre outil web. Pas de réseau, `gh`, push, tag ou publication. Les faits de release restent inconnus.
- Le mainteneur a déjà autorisé la reconstruction et le nettoyage décrit. Pas besoin de redemander ces approbations.
- Ne pas supprimer les artefacts locaux utiles conservés pendant le nettoyage.

## Reprise du 25-09-2026 — Programme 1

Implémentation complétée dans worktree `reconstruction/baseline`, encore non
commitée à cette passation. `SafetyAuditSink` retourne `Bool`; `SafetyCenter`
refuse toute approbation sans écriture durable. Les refus ont étape `.refused`
et codes stables sans chemins. Les vues comptent séparément refus et éléments
ignorés; zéro déplacement utilise état d’avertissement et dit que rien n’a
bougé. Les octets sont maintenant nommés et affichés comme taille des éléments
déplacés vers la Corbeille. Clés EN/FR paritaires; doublon `||||||| 2809736`
retiré des deux tables. Ce marqueur faisait ignorer à Foundation toutes les
clés qui suivaient. Le gate de copie détecte maintenant les marqueurs de merge.

Validations finales après correction de revue (25-09-2026) :

- `swift build --skip-update -c release` : réussi; SwiftPM affiche seulement
  dépréciation de `--skip-update`.
- `Scripts/test.sh --skip-update` : 390 tests Swift Testing réussis sur 12
  test runs, 1 test Developer ID ignoré faute d’identité de signature locale.
  UTC : 2026-09-25 21:43:52–21:44:11. Pour contourner sans réseau le
  blocage de compilation `_TestingInternals`, le seul target XCTest
  `CoreTendUITests` a été retiré temporairement de `Package.swift` pendant
  l’exécution puis manifeste restauré byte-for-byte. Tests UI XCTest non
  exécutés; lancement standard reste bloqué avant assertions par ce problème
  d’outil. Aucun changement durable au manifeste.
- `python3 Scripts/check-copy-honesty.py` : réussi, 8 clés critiques × EN/FR.
- Parité des tables : réussie, 576 clés dans chaque locale.
- `Scripts/repository-doctor.sh` : tous contrôles réussis.
- `git diff --check` : réussi.

La revue a relevé des titres positifs après zéro déplacement dans
Doublons, Restes et Privacy Cleaner; elles affichent maintenant état localisé
« aucun élément déplacé » si aucun item exécuté. À faire : obtenir confirmation
finale de revue au besoin, relire `git diff`, commit local cohérent du Programme
1. Aucun push, tag, release, changement de schéma ou téléchargement dépendance.

Conserver `CoreTendUITests` comme limite de validation; ne pas annoncer cette
cible comme testée ni la suite standard comme verte sans résolution toolchain.

## Reprise du 26-09-2026 — état corrigé

La présente section remplace les statuts antérieurs de ce fichier, devenus périmés.

- Worktree : `/private/tmp/coretend-reconstruction`
- Branche : `reconstruction/baseline`
- Programme 1 terminé et commité : `2244aa0 feat: fail closed on audit persistence`.
- Le blocage `_TestingInternals` a été contourné temporairement en excluant `CoreTendUITests` du manifeste pendant la suite; manifeste restauré byte-for-byte. 390 tests Swift Testing passés, 1 test Developer ID ignoré faute d’identité locale. Tests UI XCTest non exécutés. Build release, copy gate, parité EN/FR, repository doctor et `git diff --check` passés selon les preuves consignées plus haut.
- Programme 2 : design accepté en conversation, supplément commité `f94b101 docs: define analysis capability contracts` dans `docs/superpowers/specs/2026-09-26-coretend-analysis-capabilities-design.md`.
- Étape courante : revue mainteneur du supplément Programme 2. Après validation, rédiger son plan exécutable. Aucun code Programme 2 commencé.
- `passation.md` reste non suivi par Git, conformément au fait qu’il était un artefact de passation local.

## Mise à jour du 26-09-2026 — plan Programme 2

Le mainteneur a approuvé le supplément de design. Plan exécutable préparé :
`docs/superpowers/plans/2026-09-26-coretend-analysis-capabilities.md`.
Le plan couvre contrats communs, scan/doublons/images, SpaceLens, inventaire apps,
Integrity, métriques système, adaptateurs UI et preuves. Il reste non suivi et
aucun code Programme 2 n’a commencé. Prochaine étape : choisir exécution par
sous-agents (recommandée par le plan) ou exécution en ligne, puis suivre le plan
avec revue après chaque tranche.

Programme 2 inline execution started. Task 1 complete and committed as
`eae4b08 feat: add typed analysis result contracts`. Three AnalysisReportTests
passed. First test run required `swift test --disable-sandbox` and temporary
removal/restoration of CoreTendUITests target; Package.swift verified unchanged.
Current TDD slice: ScanCore typed reports, no production code for that slice yet.


## Reprise inline — Programme 2, 26-09-2026 08:32 UTC

- Mainteneur a explicitement choisi l’exécution en ligne et confirmé l’accord.
- Commit `eae4b08` contient les contrats typés communs.
- Tranche 2 commitée : `b9ebede feat: report partial scan and duplicate results`.
  Scan, doublons, images similaires retournent `AnalysisReport`; états partiels
  localisés EN/FR et affichés dans Cleanup, My Clutter, Duplicates et Similar
  Images. Politique d’inventaire reste séparée : Duplicate inclut les fichiers
  cachés et ignore les packages; Similar ignore fichiers cachés, packages et
  descendants `.photoslibrary`.
- Preuves tranche 2 : suites typed scan/doublons/images ciblées, exact duplicates,
  image corrupt/exact fallback, cancellation ScanCore; CoreTendAppTests 183/183;
  copy honesty gate, parité EN/FR (577 clés), `git diff --check`. Limite connue :
  `CoreTendUITests` exclu temporairement du manifeste à chaque commande puis
  `Package.swift` restauré byte-for-byte. Tests d’échec hash/cancellation en
  chunks et cloud placeholder restent à compléter avant clôture Programme 2.
- Tranche 3 SpaceLens en cours, non commitée : typed report, missing root,
  logical/allocated/remote placeholder measurements, subtree completeness,
  visit/depth/result bounds; UI banner + rescan typed; SpaceLensTests 10/10 et
  SpaceLensNavigationTests 6/6. Test d’injection d’échec enfant reste à compléter.
  Prochaine action : re-run focused suites after final helper cleanup, review diff,
  commit `feat: bound space analysis and report incomplete trees`; then Task 4
  app discovery and Integrity.
- Plan actif : `docs/superpowers/plans/2026-09-26-coretend-analysis-capabilities.md`.
  `Package.swift` remains unchanged.

## Reprise — Programme 2, inline — 2026-09-26

Worktree `/private/tmp/coretend-reconstruction`, branche
`reconstruction/baseline`. Mainteneur a confirmé exécution inline et accord.

Commits Programme 2 livrés :

- `eae4b08` contrats communs `AnalysisReport`.
- `b9ebede` résultats partiels scan/doublons/images.
- `930fc46` SpaceLens borné et mesures incomplètes.
- `55b6380` rapports Applications et Integrity.
- `fa53142` provenance des métriques système.

Tranche d’intégration Task 6: commit `4d843b2 feat: retain typed analysis state in updates view`.
Documentation et plan: commit `46259b6 docs: record analysis capability evidence`;
refresh final à committer après les tests de fermeture de gaps. `AppUpdatesViewModel`
conserve status/codes; `.rootMissing` reste visible au view-model. Les quatre
anciens streams terminent exactement une fois. Test doublons supprime un candidat
entre passes hash; rapport partial et absent du groupe.

Tests de fermeture des gaps ensuite ajoutés: annulation task au 1er chunk de
hash complet (après passe partielle) et injection deterministic d’échec metadata
SpaceLens; les deux tests verts. Ces tests et hooks ont été livrés dans le commit `7d316e0`; clôture et refresh docs suivent.

Validations finales observées le 26-09-2026 :

- `Scripts/test.sh --disable-sandbox --skip-update`: 427 tests Swift Testing
  passés sur 9 runs (ScanCore 72/72, CoreTendApp 185/185). Pour contourner l’échec toolchain `_TestingInternals`, seul
  target `.testTarget(name: "CoreTendUITests", dependencies: []),` retiré
  temporairement; `Package.swift` restauré byte-for-byte. XCTest UI non exécuté.
- `swift test ... --filter MetricsTests`: 6/6; `CoreTendAppTests`: 185/185;
  `ScanCoreTests`: 70/70; `AppDiscoveryTests`: 26/26;
  `IntegrityCoreTests`: 23/23.
- `swift build --disable-sandbox --skip-update -c release --target CoreTendApp`:
  réussi après ajout des hooks internes et des tests de failure/cancellation. Build executable Release complet a compilé et lié puis `dsymutil`
  échoue `Operation not permitted`; dSYM complet non vérifié.
- `Scripts/repository-doctor.sh`: réussi. Copy honesty : 8 clés × EN/FR.
  Parité localisation : 585/585. `git diff --check`: réussi après nettoyage
  des espaces finaux.
- Le lancement brut `Scripts/test.sh --skip-update` bloque avant compilation,
  SwiftPM ne pouvant écrire dans `~/.cache/clang` dans le sandbox.

Limite de preuve Programme 2 à conserver explicitement :

- Pas de test moteur instrumentant qu’un placeholder cloud n’est jamais ouvert
  ou hydraté. `CloudFileTests`, SpaceLens placeholder et `CloudCleanupTests`
  couvrent classification et comptage des seuls octets locaux.
- L’injection déterministe SpaceLens marque maintenant failure enfant partial.
  Une suppression concurrente peut être omise silencieusement par l’énumérateur
  Foundation; les rapports ne sont pas un snapshot. Cette limite figure dans
  `Documentation/ARCHITECTURE_OVERVIEW.md`.
- AppDiscovery permission-denied n’a pas de fixture stable sur runner root;
  mapping code présent; tests legacy couvrent comportement d’accès.

Plan d’exécution `docs/superpowers/plans/2026-09-26-coretend-analysis-capabilities.md`
et docs d’architecture/traçabilité mis à jour. Le plan garde ces preuves
manquantes en cases non cochées. `passation.md` reste local, non suivi Git.


## Clôture Task 6 — reprise inline, 2026-09-26

- `DuplicateEngine` test seam vérifie exclusion d’un placeholder synthétique
  avant tout hash (aucun callback de chunk). Live iCloud provider reste hors
  couverture. SpaceLens failure enfant et annulation pendant hash complet passent.
- Commits finaux: `7d316e0 fix: report interrupted analysis reads safely` et
  `5d60a72 docs: refresh analysis capability evidence`. Validation finale après
  changements: 431 tests Swift Testing sur 12 runs;
  ScanCore 73/73, CoreTendApp 185/185. Script complet omit temporairement
  `CoreTendUITests` pour blocage `_TestingInternals`; `Package.swift` restauré
  après commande. Cible release `CoreTendApp` compile.
- Doctor, copy-honesty (8 clés EN/FR), diff check passent. Parité locale 585/585
  déjà revérifiée dans ce checkout; relancer après tout changement de ressources.
- Limites inchangées: XCTest UI non exécuté, dSYM bloqué par `Operation not
  permitted`, test réel iCloud absent, runner root ne fournit pas fixture stable
  permission-denied. Handoff reste non suivi.

## Clôture Programme 3 — expérience app

Commits P3 : `b38eb2c feat: restore selected app destination`, `fc521fc fix:
scope visual capture to launched app process`, `8260572 docs: record application
experience evidence`. App-target suites 196/196 et accessibility 2/2 passées.
Release `CoreTendApp` build, repository doctor, copy/localization gates passés.
Smoke GUI 134 sur runner (`nice(5): operation not permitted`, LLDB `no such
process`); matrice 44 captures, XCUITest et revue humaine restent non prouvés.
Détails : `Documentation/UX_ACCEPTANCE_PROGRAMME3.md`.

## Clôture Programme 4 — website/docs/localization/distribution

Commits P4 : `0a47e9f fix: verify published release assets before sync`,
`d48b142 fix: hide unverified release claims from site`,
`514a81f docs: align product and distribution claims`,
`4dfb4fa docs: record public integration evidence`. La parité localisation
585/585 est imposée en doctor et CI. Le sync vérifie Minisign, puis taille/SHA256
des DMG/ZIP avant écritures; il n’a pas été exécuté contre GitHub. Le site cache
les faits de release sans attestation; `/download` pointe génériquement vers
GitHub Releases. Copies vieilles corrigées; le report détaillé est
`Documentation/PUBLIC_INTEGRATION_PROGRAMME4.md`.

Fixtures passées : localisation 4, sync release 8, mode site 3, générateur public
14. Repository doctor, release-sync, copy honesty, localisation, liens Markdown,
first-paint, design tokens et static site build passés. `check-website.sh` bloque
sur Playwright absent. Aucun fetch, `gh`, publication ou déploiement. `passation.md`
reste hors Git.

## Programme 5 — hardening evidence, 2026-09-26

Design `2d32f0a`, plan `45fa2ef`, rapport `cab2faf`, fermeture plan `d8ed086`.
Host arm64/macOS 27.0/Swift 6.4. La recherche source confirme un seul `URLSession`
`UpdateChecker`, derrière le bouton explicite; docs README/FAQ/privacy/threat
model/sécurité ajustées. Pas de `Process` production trouvé. Private-data,
test-isolation, licenses, media-privacy et repository-doctor passent. Uninstall
est isolé par fake HOME et passe 7 scénarios.

SwiftPM ne lance aucune assertion P5. Erreurs : `_TestingInternals` dans
`CoreTendUITests`; package temporairement sans ce target échoue au cache user
non inscriptible; avec HOME sous `/private/tmp`, `sandbox_apply: Operation not
permitted`. `Package.swift` restauré byte-identical; copie de contrôle conservée
à `/private/tmp/coretend-p5-package-original.txt`. Une tentative antérieure est
restée à 1/1496 deferred tasks puis interrompue. Pas de mesures perf, build final,
tests persistence, matrix macOS/Intel ou QA GUI. Le test-distribution lit le vrai
store en empreinte et lance GUI; test-dmg-headless quitte Finder, donc tous deux
laissés inexécutés. Pas de backup/restore utilisateur prouvé.

D-06 reste ouvert; public release UNKNOWN; aucun tag, push, release, sync ou
publication. Rapport : `Documentation/HARDENING_PROGRAMME5.md`. P5 dossier de
preuves livré, mais checkout non qualifié release candidate tant que tests/build,
performance, backup/restore, browser/package/GUI et matrice compatibilité restent
bloqués/non exécutés. Dernier commit `eae455e docs: refine hardening gate record`; branche `reconstruction/baseline`. Validation finale additionnelle: `Scripts/check-version-consistency.sh` passe; `Scripts/test-release-manifest.sh` SKIP faute d’artefacts locaux; liens Markdown 227/267, 0 cassé.
`passation.md` demeure non suivi.

### Reprise post-installation MobileBuildMCP — 2026-09-26

L’utilisateur a installé `mobilebuildmcp 2.7.1`. Binaire disponible; outils MCP non exposés dans cette session. Setup interactif échoue car dépôt SwiftPM sans projet/workspace Xcode. Test via `mobilebuildmcp swift-package test` échoue à l’application du sandbox SwiftPM (`sandbox_apply: Operation not permitted`), sans assertion exécutée.

Tentative npm isolée (`playwright`, `pngjs`, `@axe-core/playwright`) bloquée sans sortie ~40 s, interrompue; aucun module ni fichier projet ajouté, Chromium absent. Le complément au rapport a été commité en `4901c2f` (`docs: record MobileBuildMCP continuation blockers`). Gates P5 restants : tests/build Swift et performance; gate navigateur; packaging/GUI; backup/restore; matrice de compatibilité. Reprendre dans une session où workflows `swift-package`/`macos` sont exposés et où SwiftPM peut s’exécuter, avec accès npm disponible. `passation.md` reste local et non suivi.

## Reprise P5 — résultats Toolchain Swift Testing, 2026-09-26

Vérifications demandées : `xcode-select -p` = `/Applications/Xcode.app/Contents/Developer`; Xcode 27.0 (27A266a); Swift 6.4 / clang 2100.3.34.1 / arm64 macOS 27.0. Avant clean `.build` avait `ExplicitPrecompiledModules` et `SwiftExplicitPrecompiledModules`. `swift package clean` retire caches/produits Xcode; checkout SwiftPM reste. `Package.swift` inchangé. `CoreTendUITests.swift` importe XCTest seulement; target CoreTendUITests déclare aucune dépendance. Aucun réglage explicite modules dans fichiers suivis. Graph Xcode SwiftPM propre résout `_TestingInternals` via package swift-testing; build ne reproduit plus l’erreur. Cause initiale exacte inconnue sans log original; état cache/toolchain est hypothèse, pas preuve causale. Un warning dependency-scan dit que cible UI découvre Testing sans dépendance, contradictoire avec son import XCTest; aucune dépendance ni architecture modifiée.

Résultats gates : PASS `swift test --disable-sandbox --no-parallel --skip CoreTendUITests` (443 tests sur 12 produits); PASS performance 300 fichiers (0,169 s / budget <5 s); PASS build Release `CoreTendApp` (35,20 s). Le test MobileBuildMCP standard échoue encore avant compilation sur `sandbox_apply`; le test direct avec `--disable-sandbox` passe dans sandbox externe workspace-write. Cible UI XCTest reste bloquée (SwiftPM voit 0 test Testing; XCUIApplication nécessite un runner XCTest natif et app).

PASS `repository-doctor` + private-data/test-isolation/licenses/media privacy; uninstall 7/7; website release-mode 3/3 + public release gate 14/14; copy 8 clés EN/FR; localisation 585/585; version 1.0.2 cohérente. BLOCKED `Scripts/check-website.sh` à `listen EPERM 127.0.0.1`, malgré npm deps présentes. BLOCKED release manifest (SKIP, pas d’artefacts). Distribution/DMG non exécutés : vrais store/Finder/GUI. Backup-restore, startup/RSS et compatibilité Intel/autres OS restent non prouvés. Rapport détaillé désormais dans `Documentation/HARDENING_PROGRAMME5.md`. Checkout toujours non qualifié release candidate. Pas de Package.swift change, `_TestingInternals` dependency ajoutée, GUI destructive, tag/push/publish.

## État final de reprise P5 — 2026-09-26

Cette section remplace les statuts SwiftPM/web précédents lorsqu’ils se contredisent. Rapport final commité : `ec12219 docs: record Swift Testing P5 gate results`. Code et `Package.swift` inchangés. `passation.md` reste local/non suivi; ne pas ajouter au commit sans demande explicite.

### Toolchain et `_TestingInternals`

- `xcode-select -p` → `/Applications/Xcode.app/Contents/Developer`; `xcodebuild -version` → Xcode 27.0, build 27A266a; `swift --version` → Swift 6.4 / clang 2100.3.34.1, arm64 macOS 27.0.
- Avant clean, `.build` contenait `ExplicitPrecompiledModules` et `SwiftExplicitPrecompiledModules` avec intermediates Xcode. `swift package clean` a supprimé ces produits/caches; checkout et dépôts SwiftPM ont persisté.
- `Tests/CoreTendUITests/CoreTendUITests.swift` importe XCTest seulement. Target `CoreTendUITests` sans dépendances dans `Package.swift`. Pas de réglage explicite module trouvé dans les configs/sources suivies. Build graph SwiftPM propre contient et résout `_TestingInternals` du package Swift Testing.
- Après clean, compilation propre et build Release terminent sans erreur `_TestingInternals`. Avertissement restant : scanner signale découverte de `Testing` dans produit XCTest UI sans dépendance, malgré import XCTest; aucune dépendance/architecture changée. Cause d’origine pas prouvée sans log du premier échec; état cache/toolchain reste hypothèse.

### Gates et preuves

- **PASS — Swift tests** : `swift test --package-path /private/tmp/coretend-reconstruction --disable-sandbox --no-parallel --skip CoreTendUITests`; code 0, 443 tests/12 produits. Mode séquentiel nécessaire : tentative parallèle stagnait sur stress et a été interrompue (`sysmond service not found`). Le SwiftPM direct avec `--disable-sandbox` passe dans la sandbox externe workspace-write. L’appel MobileBuildMCP standard échoue avant compilation à `sandbox_apply`.
- **PASS — performance** : `swift test --package-path /private/tmp/coretend-reconstruction --disable-sandbox --filter smallDeterministicScanCompletesWithinBudget`; 1/1, 0,193 s isolé (0,169 s pendant suite), seuil <5 s.
- **PASS — Release build** : `swift build --package-path /private/tmp/coretend-reconstruction --disable-sandbox --configuration release --target CoreTendApp`; build terminé, 35,20 s.
- **BLOCKED — UI XCTest** : `swift test ... --filter CoreTendUITests` compile/découvre huit cas, mais lance zéro test Swift Testing. `XCUIApplication` exige runner XCTest natif et app construite; GUI non lancée.
- **BLOCKED — site navigateur** : `Scripts/check-website.sh` échoue au serveur local Node `listen EPERM: operation not permitted 127.0.0.1`. Dépendances npm `playwright`, `pngjs`, `@axe-core/playwright` désormais présentes (`Scripts/site/package.json` + lockfile locaux).
- **PASS — site statique** : `python3 Tests/ScriptTests/test_website_release_mode.py` 3/3; `Scripts/test-public-release-gate.py` 14/14.
- **PASS — repo/privacy/isolation** : `Scripts/repository-doctor.sh`; `Scripts/check-private-data.sh`; `Scripts/check-test-isolation.sh`; `Scripts/check-licenses.sh` (warning dépendance tests, gate passe); `Scripts/check-media-privacy.sh`; uninstall 7/7 (`Scripts/test-uninstall.sh`).
- **PASS — copy/localisation/version** : copy honesty 8 clés EN/FR; parité 585/585; `Scripts/check-version-consistency.sh` version 1.0.2 cohérente.
- **BLOCKED — release manifest** : `Scripts/test-release-manifest.sh` SKIP sans `Release/latest.json`/`SHA256SUMS`.
- **BLOCKED/non exécutés — distribution** : `Scripts/test-distribution.sh` inspecte vrai store et lance GUI; `Scripts/test-dmg-headless.sh` quitte Finder. Laisser inexécutés.
- **BLOCKED — restantes** : aucun backup/restore utilisateur; mesures startup/RSS absentes; matrice Intel/autres macOS absente. D-06 ouvert; checkout pas qualifié release candidate. Aucun tag, push, sync, release ou publication.

Fichiers locaux non suivis observés : `.mobilebuildmcp/`, `Scripts/site/package.json`, `Scripts/site/package-lock.json`, `passation.md`. Conserver tels quels. Dernier commit `ec12219`.

## Reprise — gate site fermé, 2026-09-26

- `Scripts/check-website.sh` passe désormais ses 32 contrôles navigateur. Premier passage a révélé un lien local `/SHA256SUMS` cassé lorsque release n’est pas vérifiée, et une FAQ qui promettait checksum/signature publiés. `Website/build.py` pointe alors vers GitHub Releases et affiche copie honnête; branche release vérifiée garde le lien checksum local.
- Tests `Scripts/site/test-site.mjs` alignés sur statut vérifié/inconnu, route générique `/download` et titres EN/FR actuels. Tests de rendu ajoutent preuve pour les deux états; mode non vérifié interdit lien/checksum local et allégation de fichier publié.
- Validations : `python3 Tests/ScriptTests/test_website_release_mode.py` (3/3), `Scripts/check-website.sh` (32/32), `Scripts/repository-doctor.sh`, `python3 -m py_compile Website/build.py`, `git diff --check`.
- Rapport `Documentation/HARDENING_PROGRAMME5.md` mis à jour. Restent : XCTest GUI natif, package/distribution GUI, workflow backup/restore, mesures startup/RSS, matrice Intel/macOS. Release candidate toujours non qualifiée; aucun sync, release, tag, push, publication.
- `passation.md`, `.mobilebuildmcp/`, `Scripts/site/package.json` et lockfile restent non suivis et préservés.

## Reprise — mesure startup/RSS bloquée, 2026-09-26

`Scripts/measure-stability.sh` requiert `build/CoreTend.app`, absent du checkout. Tentative de préparation via `Scripts/package-local.sh` avec scratch dédié `/private/tmp/coretend-p5-stability-scratch`; SwiftPM a lancé fetch/résolution `swift-syntax` depuis URL distante. Arrêté avant bundle; aucune mesure prise. Pas d’accès au vrai store, Finder, ni changement source/Package.swift. Ne pas relancer avant disponibilité locale des dépendances ou autorisation réseau. Laisser scratch temporaire préservé.

## Reprise — mesures stabilité disponibles, 2026-09-26

- Bundle courant construit avec `Scripts/package-local.sh`, scratch checkout `.build`, `CORETEND_SWIFT_BUILD_FLAGS=--skip-update`. Mesure `Scripts/measure-stability.sh` complète sur macOS 27.0 arm64 et HOME temporaire.
- 10 launches : processus détecté vivant à 25 ms en moyenne (plancher processus, pas fenêtre); idle 8 s : RSS 111 MiB, CPU 0 %, 45 lignes lsof (en-tête compris), 5 threads; 60 s : RSS 107 MiB et 45 lignes lsof; 100 cycles : RSS 109 → 110 MiB, 0 processus restant, 0 fichiers temporaires.
- Artefacts locaux à préserver : `build/CoreTend.app`, `Release/stability-metrics.txt`, scratch `/private/tmp/coretend-p5-stability-scratch` de tentative interrompue. Aucun vrai store touché.
- D-06 reste ouvert : mesure un seul host, aucune fenêtre visible/usage actif/autre OS ou architecture, pas de budget de performance accepté. Rapport P5 contient limites détaillées.
- Suite Swift relancée offline : `swift test --disable-sandbox --skip-update --no-parallel --skip CoreTendUITests`, sortie 0; 443 tests sur 12 runs. XCTest UI reste exclu car runner natif absent. `PersistenceTests` 57/57; perf fixture 300 fichiers 52 ms.

## Reprise reconstruction totale — 2026-09-26

- Défaut sûreté fermé : `SafetyCenter` supprimait définitivement un fichier si `FileManager.trashItem` échouait sous `/tmp`. Fallback supprimé; échec désormais `.trashFailed`, source conservée, événement `.error`. Test seam interne uniquement; tests utilisent une Corbeille temporaire fixture.
- TDD observé : test rouge (`trashItem` injectable absent), puis vert `SafetyCenterTrashFailureTests` (1/1); SafetyCenter ciblé 14/14. Suite totale `swift test --disable-sandbox --skip-update --no-parallel --skip CoreTendUITests` : **444 tests / 12 runs**, exit 0. Pas de Corbeille réelle touchée.
- Build `CoreTendApp` Release réussi; produit CLI Release réussi. CLI: `--help` exit 0, `--list-rules` 10 lignes tabulées, `--paths` 7 racines, option inconnue exit 1. Format ajouté à `Documentation/COMMANDS.md`; FR-13 passe VERIFIED pour run local/source.
- README, cahier FR-01 et roadmap P3 alignés sur les onze destinations de `ModuleID`; traceabilité mise à jour FR-05/06/13, NFR-01/02. `Safety Model` et revue sécurité décrivent Trash-only.
- Gates fraîches : `Scripts/repository-doctor.sh` PASS; version 1.0.2 cohérente; copy honesty 8 clés EN/FR; parité 585/585; fixtures release-site 3/3; `Scripts/check-website.sh` **32/32**; diff-check final à relancer après docs finales.
- Projet Xcode CoreTend absent. `.mobilebuildmcp/config.yaml` active déjà `swift-package` et `macos`, mais cette session ne présente que workflows simulateur; recharger la session Codex/MobileBuildMCP pour exposer ces outils. UI XCTest/runtime/macOS natif non lancé. Restent: backup/restore utilisateur, QA accessibilité/fenêtre native, distribution GUI, matrice Intel/autres macOS, D-06 budget représentatif. Release publique UNKNOWN; aucun tag/push/publication.
- Commit suivi de continuation : `fb93ad5 fix: preserve files when Trash operation fails`; contient le correctif SafetyCore, son test, l’alignement README/spec/roadmap sur 11 destinations et preuves traceability. Validation après ce commit: full suite 444/12; Release CoreTendApp et CLI; repository-doctor; website 32/32; version/copy/localisation.
- `Resources/DemoFixtures` conserve schéma v2 à 8 anciens IDs. Recherche du dépôt: seul script validator/tests le lisent; aucun consommateur runtime. README le documente comme fixture historique, pas inventaire/nav courant. Pas de schéma v3 inventé sans contrats data des 3 modules manquants.
- Commit doc fixture : `9bd7a5c docs: mark demo fixture as historical schema`. `Scripts/check-demo-fixtures.py` PASS; tests validator 7/7; doctor/diff-check PASS.
- Prochain blocage principal : `.mobilebuildmcp/config.yaml` active déjà `swift-package` et `macos`, mais outils disponibles dans cette session sont simulateur seulement. Recharger session Codex/MobileBuildMCP avant QA XCTest/runtime/accessibilité/distribution macOS. Le reste des gates activables a passé.
- Préserver `.mobilebuildmcp/`, package npm non suivis, `passation.md`, `.build`, `build/CoreTend.app`, mesures stabilité et scratch interrompu.

## Clôture locale de reconstruction — 2026-09-26

- Nouvelle vérification finale : `git diff --check` passe; `Scripts/repository-doctor.sh` passe (227 liens internes / 267 Markdown, 0 cassé; 585/585 clés EN/FR; inventaire 51 fonctionnalités cohérent; aucune donnée privée); version 1.0.2 cohérente; validator fixture passe; `python3 Tests/ScriptTests/test_website_release_mode.py` 3/3.
- Nouvelle gate navigateur `Scripts/check-website.sh` terminée avec **32/32 PASS**, code 0, dont Axe WCAG A/AA, zoom 200 %, clavier, fallback sans JS, routes, viewport, préférences motion et navigation FR/EN.
- Suite Swift relancée après les commits : `swift test --disable-sandbox --skip-update --no-parallel --skip CoreTendUITests`, code 0. Les tests compilent et passent; avertissement SwiftPM: `--skip-update` déprécié. Dernier décompte exhaustif validé avant cette relance : 444 tests/12 runs.
- La session MobileBuildMCP présente encore uniquement outils simulateur (`boot_sim`, `build_sim`, `test_sim`, etc.); aucun workflow macOS/XCTest natif. Le dépôt ne contient aucun `.xcodeproj`/`.xcworkspace` CoreTend. Config locale active déjà `swift-package` + `macos`; pas de modification supplémentaire requise ici.
- Travail source/documentation réalisable finalisé et commité (`fb93ad5`, `9bd7a5c`). Checkout n’est pas une release candidate qualifiée : restent validations externes au checkout pour XCTest/VoiceOver/fenêtre/accessibilité native, distribution Finder/DMG, vrai flux utilisateur sauvegarde-restauration, matrice Intel/autres versions macOS, budget D-06 accepté et identité/signature publique. Aucun de ces points n’a été inventé ni déclaré réussi.
- Aucun accès au vrai store, aucun push/tag/release/publication. Préserver `.mobilebuildmcp/`, `Scripts/site/package.json`, lockfile, ce `passation.md`, `.build`, `build/CoreTend.app`, `Release/stability-metrics.txt` et scratch déjà listés.
- Correction documentaire finale commitée `e488202 docs: reconcile final hardening gate status`: la table P5 reprend désormais website gate PASS 32/32 et suite Swift 444/12; les échecs précédents restent clairement historiques. Doctor et `git diff --check` repassés après correction.
