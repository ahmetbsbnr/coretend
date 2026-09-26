# Programme 5 — hardening and candidate evidence

Date: 2026-09-26. Base before P5 design: `45fa2ef2efce2ffecdfcc818338362d4e8bdd97f`.
Design: `2d32f0a`; plan: `45fa2ef`.

## Host and boundaries

- macOS 27.0 (`26A428`), arm64, Apple Swift 6.4.
- Before test attempts, no `build/` or `dist/` directory and no generated DMG/ZIP
  in `Release/`; only historical inventory/launch docs, release notes and
  manifest template existed there.
- SwiftPM created ignored `.build/` intermediates. `Package.swift` was briefly
  changed only to exclude the incompatible `CoreTendUITests` target during a
  focused attempt, then restored byte-for-byte (`cmp` passed). No production
  target, real CoreTend store, installed app or `/Applications` path was
  modified.
- `test-distribution.sh` was not run because it fingerprints the real user
  store and launches a packaged GUI app. `test-dmg-headless.sh` was not run
  because it explicitly quits Finder. No tag, release, sync, network fetch or
  deployment occurred.

## Security and privacy review

Source inspection found one production `URLSession` client, in `UpdateChecker`,
called from the explicit Updates screen button. It requests the fixed HTTPS
public manifest, uses an ephemeral session, disables cookies, adds no custom
identifying headers, and has a 15-second timeout. The app does not attach scan
results/paths or fetch/install binaries. The host can observe ordinary request
metadata. No production `Process` use, account client, analytics or remote crash
reporter was found by the reviewed searches.

Updated [PRIVACY.md](PRIVACY.md), [PRIVACY_AUDIT_CURRENT.md](PRIVACY_AUDIT_CURRENT.md),
[SECURITY_AUDIT_CURRENT.md](SECURITY_AUDIT_CURRENT.md), the README, FAQ and threat
model to state this boundary accurately. `Scripts/check-private-data.sh`,
`Scripts/check-test-isolation.sh`, `Scripts/check-licenses.sh` and
`Scripts/check-media-privacy.sh` passed. License gate reported one documented
test-only `swift-testing` dependency as a warning. No packet capture or external
security/privacy audit was performed.

## Persistence and installation

`LegacyDataMigration` has per-item rollback coverage in the existing test
source; Programme 5 could not execute Swift suites in this runner. CoreTend has
no complete user-facing database backup/restore workflow. FR-11/NFR-04 remain
partial; no backup feature was added.

`Scripts/test-uninstall.sh` passed all seven synthetic-HOME scenarios: default
dry-run, allowlisted removal, keep-data, symlink refusal, legacy preservation,
explicit legacy removal, and dry-run legacy exclusion. This proves the script
contract only; it is not clean-install, upgrade, downgrade or GUI evidence.

## Performance and compatibility

Current supported declaration remains arm64/macOS 14+. Only arm64/macOS
27.0/Swift 6.4 host identity was measured; no other supported OS or hardware
was tested.

The 300-file deterministic scan test was not executed, so there are no timing or
memory results. Attempts and blockers:

1. A filtered CoreTend app run stalled at SwiftPM planning (`1 / 1496` deferred
tasks) and was interrupted.
2. The performance filter reached compilation, then Swift failed to resolve
   `_TestingInternals` in `CoreTendUITests`.
3. Temporarily excluding that test target first failed writing the user clang
   module cache (outside workspace permissions).
4. With isolated HOME, sandbox setup failed: `sandbox-exec: sandbox_apply:
   Operation not permitted`.

No workaround crossed the sandbox. D-06 remains open; no arbitrary performance
budget was added.

## Gates

Passed on 2026-09-26:

- `Scripts/repository-doctor.sh`
- `Scripts/test-uninstall.sh` (7 scenarios)
- `Scripts/check-private-data.sh`
- `Scripts/check-test-isolation.sh`
- `Scripts/check-licenses.sh` (pass, one dependency warning)
- `Scripts/check-media-privacy.sh`
- `Scripts/check-copy-honesty.py` (8 critical keys in EN and FR)
- `Scripts/check-localization-parity.py` (585/585; 4 parser fixtures)
- `Scripts/test-release-sync.sh` (8 offline fixtures; GitHub comparison skipped)
- `Tests/ScriptTests/test_published_release.py` (8 fixtures)
- `Tests/ScriptTests/test_website_release_mode.py` (3 fixtures)
- `Scripts/test-public-release-gate.py` (14 fixtures)
- `Scripts/check-version-consistency.sh` (1.0.2 source consistency)
- design tokens, first paint, retired redirects, Markdown links (227 links / 267
  tracked Markdown files), Python compilation, Bash syntax, `git diff --check`

Blocked/not run:

- Full Swift suite, focused persistence/performance suite and Release build: SwiftPM
  toolchain/sandbox blockers above; tests did not execute.
- `Scripts/check-website.sh`: Playwright package absent (`Cannot find package
  'playwright'`). Static site build and non-browser site gates passed in P4.
- Distribution DMG/ZIP/launch gate: intentionally not run due Finder/real-store
  effects described above.
- `Scripts/test-release-manifest.sh` exited 0 with SKIP because generated Release/latest.json and SHA256SUMS were absent.
- Compatibility matrix, measured startup/memory, database backup/restore, clean
  install/upgrade/uninstall GUI cycle and independent security audit: not proven.
- Current public version and artifact identity remain UNKNOWN; remote GitHub
  comparison was skipped because `gh` was unavailable or unauthenticated.

## Readiness

P5 evidence collection is recorded, but this checkout is **not qualified as a
release candidate**: Swift tests/build, browser gate, packaging/launch, backup and
restore behavior, performance baseline, and cross-version compatibility remain
unproven. Continue only with environment support for those gates; publication
still requires separate authorization.

### Reprise après installation MobileBuildMCP

- L’utilisateur a installé `mobilebuildmcp 2.7.1` via Homebrew. Le binaire et les workflows `macos`/`swift-package` sont présents sur l’hôte, mais aucun outil XcodeBuildMCP n’est exposé dans cette session. Le setup interactif ne peut générer ses defaults : dépôt SwiftPM sans `.xcodeproj`/`.xcworkspace`.
- Tentative de test filtré par `mobilebuildmcp swift-package test` avec HOME isolé atteint SwiftPM puis échoue `sandbox-exec: sandbox_apply: Operation not permitted`. Aucun test ne s’est exécuté.
- Installation isolée des dépendances de site (`playwright`, `pngjs`, `@axe-core/playwright`) depuis npm n’a produit aucune sortie pendant 40 s et a été interrompue. Réseau/package fetch indisponible dans ce runner; aucun fichier du dépôt n’a été ajouté par cette tentative. Chromium donc absent.
- Étape concrète restante : session relancée avec workflow MCP `swift-package`/`macos` actif et environnement autorisant SwiftPM sandbox; installer les modules npm et Chromium dans environnement connecté, puis relancer `Scripts/check-website.sh`, tests/build Swift et mesures perf.

## Reprise P5 — Toolchain Swift Testing, 2026-09-26

### Diagnostic `_TestingInternals`

- Toolchain vérifié : `xcode-select -p` → `/Applications/Xcode.app/Contents/Developer`; `xcodebuild -version` → Xcode 27.0, build 27A266a; `swift --version` → Swift 6.4, clang 2100.3.34.1, arm64/macOS 27.0.
- Avant nettoyage, `.build` contenait les dossiers `ExplicitPrecompiledModules` et `SwiftExplicitPrecompiledModules`, ainsi que produits/intermediates Xcode. `swift package clean` les a supprimés; seuls checkout et dépôts SwiftPM ont persisté. `Package.swift` est resté inchangé.
- `CoreTendUITests.swift` importe XCTest seulement. `CoreTendUITests` est déclaré sans dépendances dans `Package.swift`. Aucune mention/configuration `SWIFT_ENABLE_EXPLICIT_MODULES`, `SWIFT_USE_EXPLICIT_MODULES` ou `-explicit-module-build` dans les sources/configs suivies. Le backend Xcode SwiftPM génère néanmoins des dossiers de modules explicites.
- Build graph propre contient les cibles `Testing`, `_TestingInternals` et `TestingMacros` depuis le package Swift Testing; `_TestingInternals` résout bien dans `target-graph.txt`. Build propre complet termine sans erreur de module. Avertissement de scan résiduel : `CoreTendUITests-product` est signalé comme découvrant `Testing` sans dépendance, alors que sa source importe XCTest; le graphe final du produit UI n’a aucune dépendance explicite. Aucun ajout de dépendance/architecture effectué.
- Conclusion : erreur `_TestingInternals` non reproduite après clean et compilation complète. Éléments compatibles avec état de module/build cache incohérent sous Xcode 27/Swift 6.4; cause initiale exacte non prouvable sans log original de l’échec. Le warning de dépréciation indique aussi que ce toolchain fournit déjà Swift Testing; aucune migration de dépendance entreprise dans cette reprise.

### Résultats gates (commande, statut, preuve)

| Gate | Statut | Commande et preuve |
|---|---|---|
| Xcode/Swift toolchain | PASS | `xcode-select -p; xcodebuild -version; swift --version` — Xcode 27.0, Swift 6.4, arm64. |
| Nettoyage `.build` et résolution module | PASS | `swift package clean`; puis suite Swift propre — build complet réussi; target graph propre résout `_TestingInternals`. |
| Tests SwiftPM | PASS | `swift test --package-path /private/tmp/coretend-reconstruction --disable-sandbox --no-parallel --skip CoreTendUITests` — 443 tests passés sur 12 produits, code 0. `CoreTendUITests` exclu : cible XCTest UI, pas exécutable par Swift Testing/SwiftPM comme UI native. |
| Test performance 300 fichiers | PASS | `swift test --package-path /private/tmp/coretend-reconstruction --disable-sandbox --filter smallDeterministicScanCompletesWithinBudget` — 1/1; 0,193 s en filtre isolé (0,169 s dans la suite complète), seuil du test <5 s. |
| Build Release `CoreTendApp` | PASS | `swift build --package-path /private/tmp/coretend-reconstruction --disable-sandbox --configuration release --target CoreTendApp` — build complete, 35,20 s. |
| SwiftPM via MobileBuildMCP | BLOCKED | `mobilebuildmcp swift-package test ... --test-product CoreTendUITests` — `sandbox-exec: sandbox_apply: Operation not permitted` à la compilation manifest. Le runner direct a réussi avec `--disable-sandbox`; sandbox externe workspace-write reste actif. |
| UI XCTest / lancement GUI | BLOCKED | `swift test ... --filter CoreTendUITests` — compilation/discovery 8 tests, mais Swift Testing exécute 0; XCUIApplication exige target XCTest natif et app empaquetée. Pas de GUI gate lancée. |
| Website browser gate | PASS (revalidation finale) | `Scripts/check-website.sh` — 32/32 contrôles, exit 0. L’échec `listen EPERM` ci-dessous est historique; gate désormais exécutée avec succès. |
| Website static fixtures | PASS | `python3 Tests/ScriptTests/test_website_release_mode.py` — 3/3; `Scripts/test-public-release-gate.py` — 14/14. |
| Repo/privacy/isolation/uninstall | PASS | `Scripts/repository-doctor.sh` — toutes vérifications; `Scripts/check-private-data.sh`, `Scripts/check-test-isolation.sh`, `Scripts/check-licenses.sh`, `Scripts/check-media-privacy.sh`; `Scripts/test-uninstall.sh` — 7/7. Licences: warning sur une dépendance de tests, gate passe. |
| Copy/localization/version | PASS | `python3 Scripts/check-copy-honesty.py` — 8 clés EN/FR; `python3 Scripts/check-localization-parity.py` — 585/585; `Scripts/check-version-consistency.sh` — 1.0.2 cohérent. |
| Manifest d’artefact release | BLOCKED | `Scripts/test-release-manifest.sh` — SKIP, aucun `Release/latest.json` ou `SHA256SUMS` généré. |
| Packaging/distribution GUI | BLOCKED | `Scripts/test-distribution.sh` non lancé (empreinte du vrai store et lancement GUI); `Scripts/test-dmg-headless.sh` non lancé (quitte Finder). |
| Performance startup/mémoire | PARTIAL | Fixture 300 fichiers 52 ms; process-live 25 ms; RSS idle 111→107 MiB/60 s et +1 MiB/100 cycles sur arm64/macOS 27.0. Aucun autre host, première fenêtre ou budget D-06. |
| Sauvegarde/restauration | BLOCKED | Aucun workflow utilisateur complet de backup/restore; non prouvé, aucun ajout produit dans P5. |
| Compatibilité autres OS/Intel | BLOCKED | Seulement arm64/macOS 27.0 observé; matrice non exécutée. |

Suite parallèle initiale `swift test --parallel` a été interrompue après stagnation sur les stress tests et message `sysmond service not found`; rerun séquentiel complet a passé. Aucun test/UI/Disk image n’a touché le vrai store. Aucun changement à `Package.swift`, aucune nouvelle dépendance `_TestingInternals`, aucun tag/push/publication.

Readiness reste **non qualifiée release candidate** : GUI/distribution, sauvegarde/restauration, qualification startup/mémoire et matrice restent ouverts. La gate navigateur est fermée (32/32); les 444 tests et build Release lèvent le précédent blocage compilation/tests Swift, sans clore les autres risques.

### Reprise navigateur — 2026-09-26

`Scripts/check-website.sh` a ensuite pu lier son serveur local et finir : **32/32 contrôles navigateur passés**, build isolé et fixture de routes inclus. Le premier passage a mis au jour un vrai défaut de copie en mode release non vérifiée : le lien `/SHA256SUMS` restait local alors que le build excluait ce fichier, et la FAQ affirmait qu’un checksum publié était disponible. Le site envoie maintenant vers la page GitHub Releases et explique que les preuves ne sont pas vérifiées; mode release vérifiée conserve le lien local. Tests navigateur ajustés aux slogans actuels et aux deux états de provenance de release.

Preuves après correction : `python3 Tests/ScriptTests/test_website_release_mode.py` 3/3; `Scripts/check-website.sh` 32/32; `Scripts/repository-doctor.sh`; `python3 -m py_compile Website/build.py`; `git diff --check`. Cela ferme uniquement le gate navigateur. UI XCTest, packaging/distribution GUI, sauvegarde/restauration, mesures startup/RSS et matrice Intel/autres OS restent ouverts; checkout non qualifié release candidate.

### Reprise — tentative mesure startup/RSS

`Scripts/measure-stability.sh` is available and runs under temporary HOME, but requires a packaged `build/CoreTend.app`. `Scripts/package-local.sh` was attempted with isolated scratch `/private/tmp/coretend-p5-stability-scratch`; SwiftPM began resolving `swift-syntax` from its remote URL. The command was interrupted before packaging completed. No app bundle or performance measurement was produced; no real user store or Finder action occurred. Do not rerun until dependency resolution is available locally or network access is explicitly restored. Repository source and `Package.swift` unchanged.

### Mesures startup/RSS — 2026-09-26

Le bundle courant a été construit avec `Scripts/package-local.sh`, scratch existant `.build` et `CORETEND_SWIFT_BUILD_FLAGS=--skip-update`; SwiftPM n’a pas tenté de fetch durant ce build. `Scripts/measure-stability.sh` a fini sous HOME temporaire sur macOS 27.0 arm64. Sortie locale : `Release/stability-metrics.txt`.

- 10 démarrages froids : processus vivant en moyenne après 25 ms. C’est un plancher de disponibilité du processus, pas le temps de première fenêtre.
- Idle après 8 s : RSS 111 MiB, CPU 0,0 %, 45 lignes `lsof` (en-tête inclus), 5 threads.
- Après 60 s idle : RSS 107 MiB (delta −3 MiB), 45 lignes `lsof` (delta 0).
- 100 cycles avec HOME réutilisé : RSS 109 → 110 MiB (delta +1 MiB); 0 processus restant et 0 fichier temporaire dans sandbox.

Mesures limitées à un hôte arm64/macOS 27.0; répétabilité statistique, fenêtre visible, usage actif, autres OS/architectures et seuil D-06 restent non prouvés. Cette collecte fournit baseline, pas qualification performance. Une tentative précédente avec scratch vide fut interrompue quand SwiftPM déclencha une résolution distante; aucun bundle n’en résulta. Build/mesures finaux réutilisent checkout `.build` et `--skip-update`.

### Finalisation — statut courant, 2026-09-26

- **PASS** : rerun `swift test --disable-sandbox --skip-update --no-parallel --skip CoreTendUITests` — 444 tests/12 runs, exit 0; persistence ciblé 57/57; fixture scan 300 fichiers 52 ms; build bundle Release offline; mesures stabilité ci-dessus; repository-doctor; website navigateur 32/32; release-mode fixtures 3/3; localisation/copy/version gates. XCTest UI demeure exclu.
- **GAP explicite** : FR-11/NFR-04 reste PARTIAL. Migration rollback et idempotency tests passent, mais aucun workflow utilisateur de sauvegarde/restauration n’existe; plan P5 interdit d’inventer cette fonctionnalité pendant hardening.
- **BLOCKED / non exécuté** : XCTest UI natif, packaging/distribution GUI (effets Finder/store), manifest local (artefacts signés absents), matrice Intel/autres versions macOS, mesures fenêtre visible/usage actif. DMG layout non construit : `dmgbuild` absent du venv et provisionnement aurait besoin d’une dépendance externe.
- D-06 reste ouvert : un host ne fixe pas budget représentatif. Release publique reste UNKNOWN; aucune sync, tag, push ou publication. Checkout **non qualifié release candidate**.

### Complément — reprise reconstruction, 2026-09-26

- Revue finale a trouvé un ancien secours dans `SafetyCenter`: si `trashItem` échouait sous `/tmp`, le fichier était supprimé définitivement. Secours retiré; l’échec renvoie maintenant `trashFailed`, garde le fichier intact et émet un événement `.error`. Le seam d’injection est interne; tests déplacent vers une Corbeille de fixture, jamais la Corbeille utilisateur.
- TDD : test rouge sur l’API d’injection absente; test vert `failedTrashRequestLeavesTemporaryFileUntouched`. Test ciblé SafetyCenter: 14/14. Suite rerun: **444 tests / 12 runs**, exit 0, `CoreTendUITests` exclu.
- CLI Release vérifié localement: `--help` exit 0; `--list-rules` 10 lignes tabulées; `--paths` 7 racines absolues; option inconnue exit 1. Format documenté dans `Documentation/COMMANDS.md`.
- README, cahier FR-01 et roadmap Programme 3 alignés sur les 11 destinations actuelles. Repository-doctor passe; localisation 585/585; copy honesty 8×2; version cohérente; website gate rerun **32/32**.
- Restent non prouvés : UI XCTest/runtime/accessibilité native, installation/distribution GUI, backup/restore utilisateur, première fenêtre/usage actif, matrice Intel/macOS; release publique inconnue. D-06 ouvert; candidate non qualifiée.
