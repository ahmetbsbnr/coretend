# Acceptation UX — Programme 3

État mesuré : 2026-09-26. Base de travail : `reconstruction/baseline`, HEAD initial `81ef619545ab5884922d573752f658a3613620b1`; code ensuite commité en `b38eb2c`, scripts en `fc521fc`; documentation de preuve à committer. Les tests ont été lancés sur ces mêmes contenus avant commit.

## Résultat

La destination de sidebar est maintenant une préférence stable. Valeur absente/inconnue revient à Dashboard; seules les destinations connues sont persistées. Les onze `ModuleID` conservent leurs identifiants. Chaque titre est lié explicitement à une clé localisée. Les états d’analyse partielle, commandes onboarding et labels de palette ont un contrat EN/FR testé.

Le mode capture isole UserDefaults et Store. Les lecteurs Performance et Cloud Cleanup utilisent le répertoire temporaire validé quand `CORETEND_TEST_MODE=1`; une configuration invalide retourne vide sans consulter le home. Le fixture Cloud Cleanup prouve qu’un Dropbox simulé dans le home reste invisible alors que le provider placé dans le Store temporaire est détecté.

## Vérifications exécutées

- `swift test --disable-sandbox --skip-update --filter CoreTendAppTests`: **196 tests passés**. Seul le target `CoreTendUITests` a été retiré temporairement de `Package.swift` à cause de `_TestingInternals`; le manifeste a été restauré byte-for-byte.
- `swift test --disable-sandbox --skip-update --filter CoreTendAccessibilityTests`: **2 tests passés**, mêmes disposition et restauration du manifeste.
- Tests ciblés preference, navigation localisée, Cloud Cleanup et LaunchAgent: **23 tests passés** dans CoreTendAppTests.
- `swift build --disable-sandbox --skip-update -c release --target CoreTendApp`: passé.
- Build de l’exécutable Release a compilé et lié `CoreTend`; génération dSYM échoue avec `Operation not permitted`.
- `Scripts/repository-doctor.sh`: passé.
- `python3 Scripts/check-copy-honesty.py`: passé, 8 clés critiques en EN et FR.
- Tables de localisation : Base 585, FR 585, aucune clé manquante.
- `zsh -n Scripts/capture-native-matrix.sh Scripts/capture.sh`: passé; aucune terminaison globale `pkill -x CoreTend`.
- `git diff --check`: passé.

Deux exécutions de la suite Swift Testing sans filtre ont terminé la compilation mais n’ont affiché aucun démarrage de tests; elles ont été interrompues. Aucun résultat complet n’est revendiqué. Les cibles touchées ont des résultats frais ci-dessus.

## Preuves natives indisponibles

App candidate assemblée sous `/private/tmp/coretend-p3-20260926.app` depuis le binaire lié. `Scripts/test-app-launch.sh` a constaté une sortie après 1 seconde, code 134; stderr indiquait `nice(5) failed: operation not permitted`. LLDB a rapporté `process exited with status -1 (no such process)`. Cela concorde avec le runner interdisant le démarrage GUI/debugger; cause produit non établie. Le script de matrice 44 captures n’a donc pas été lancé jusqu’au bout et aucun screenshot courant n’est accepté comme preuve. `CoreTendUITests` n’a pas été exécuté comme XCUITest natif.

Pas de revue humaine actuelle sur navigation visuelle, onboarding réel, clavier, VoiceOver, focus, Dynamic Type/zoom, contraste ou mouvement réduit. L’attestation de `Documentation/HUMAN_QA_REPORT.md` porte sur l’artefact 1.0.0 du 2026-09-04 et ne vaut pas pour ce checkout.

## Suite d’acceptation

FR-01 passe à `IMPLEMENTED_UNVERIFIED`: contrat, mapping et tests de préférence sont présents; restauration au runtime reste à prouver sur session macOS GUI native. FR-10 reste `PARTIAL`; NFR-07 et NFR-08 restent `PARTIAL`. Refaire smoke launch et matrice EN/FR claire/sombre sur runner GUI, inspecter les captures, puis contrôler clavier/VoiceOver/Dynamic Type/contraste/mouvement réduit.
