<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# CoreTend — inventaire total MoSCoW

État audité le 2026-09-04. Source : dépôt `main`, documentation, gates et
tests exécutés. Statuts : **FAIT**, **PARTIEL**, **ABANDONNÉ/ANNULÉ**,
**LAISSÉ EN ATTENTE**, **PAS FAIT**, **À FAIRE**.

## Résumé exécutif

- Version publiée : **1.0.0 stable**, arm64, macOS 14+.
- CoreTend : commit `6a07f86`, arbre propre, poussé sur GitHub.
- Portfolio : commit `b2028e7`, synchronisé avec CoreTend.
- Tests Swift : **342/342 passés**.
- Provenance release : tests **15/15 passés**.
- QA humaine : VoiceOver, clavier, Dynamic Type, contraste, réduction mouvement,
  second Mac/autre macOS et matrice native 44 captures : **FAIT par attestation**.
- Mentions scanner externe retirées du dépôt et des surfaces publiques : **FAIT**.

## Must have — requis pour produit livré

| Sujet | Statut | Preuve / décision |
|---|---|---|
| Application macOS SwiftUI fonctionnelle | FAIT | `CoreTendApp`, SwiftPM, macOS 14+ |
| Dashboard, Cleanup, Integrity, Performance, Applications | FAIT | `Documentation/FEATURE_MATRIX.md` |
| Large/old files, doublons, images similaires, Space Lens | FAIT | moteurs ScanCore testés et intégrés |
| Cloud cleanup local/logical | FAIT | analyse sans téléchargement forcé |
| Privacy Cleaner | FAIT | caches navigateur vers Corbeille ; historique/cookies exclus |
| App updater | FAIT | App Store/Sparkle détectés ; aucune installation automatique |
| Applications + données associées | FAIT | sélection revue, correspondance bundle-id conservatrice |
| Désinstallation sûre | FAIT | déplacement vers Corbeille, validation chemin au moment exécution |
| Journal de sécurité | FAIT | audit SQLite ; résumé exécuté/ignoré-erreur ajouté |
| Persistance/migrations | FAIT | actor SQLite, migrations idempotentes testées |
| Login items / provenance / signature | FAIT | IntegrityCore en lecture seule |
| Menu bar, Settings, Onboarding | FAIT | accès, permissions, exclusions, langue |
| Zéro télémétrie / pas compte / pas cloud | FAIT | `PRIVACY.md`, contrôles secrets |
| FR + EN | FAIT | ressources localisées et parité contrôlée |
| Trash par défaut + restauration documentée | FAIT | `RESTORE.md`, SafetyCore |
| Tests unitaires, intégration, performance | FAIT | 342 tests verts |
| QA humaine accessibilité et multi-machine | FAIT | `HUMAN_QA_REPORT.md`, attestation mainteneur |
| Captures natives FR/EN clair/sombre | FAIT | 44 frames, 11 modules |
| Developer ID, notarisation, stapling, SHA-256, Minisign | FAIT pour v1.0.0 publiée | preuves dans release publiée |
| Workflow prochaine release avec SLSA | FAIT | `.github/workflows/release.yml` |
| Site public et portfolio alignés | FAIT | routes FR/EN, version 1.0.0, crédits Claude supervisé |
| Retrait complet des références scanner historique | FAIT | recherche dépôt/public sans occurrence interdite |

## Should have — qualité importante, reportée ou limitée

| Sujet | Statut | Décision |
|---|---|---|
| SLSA rétroactive pour v1.0.0 | ABANDONNÉ/ANNULÉ | signature finale hors Actions ; attestation rétroactive mensongère |
| CLI | PARTIEL / FAIT lecture seule | `coretend-cli --list-rules`, `--paths`, `--help` ; aucune mutation |
| CLI destructif automatisable | LAISSÉ EN ATTENTE | nécessite confirmation, journal et rollback équivalents UI |
| Caches Xcode DerivedData | FAIT | règle développeur low-risk |
| iOS DeviceSupport / Xcode Archives | FAIT partiel | règles medium-risk, non présélectionnées |
| Caches Simulateurs iOS | PAS FAIT | moteur dédié et validation nécessaires |
| Détection binaires universels | PAS FAIT | analyse seulement puis validation signature/réversible |
| Désinstallation complète app | PARTIEL | support associé allowlist ; pas balayage large automatique |
| EXIF / métadonnées sensibles | PAS FAIT | inspection et suppression opt-in à concevoir |
| Gestion LaunchAgents/Daemons | PARTIEL | inventaire lecture seule ; désactivation/rollback absents |
| Signaux sécurité natifs supplémentaires | PAS FAIT | Integrity reste lecture seule, sans claim malware |
| Contraste, Dynamic Type, Reduce Motion | FAIT | design/accessibility state et QA humaine |
| Provenance build de chaque nouvelle release | À FAIRE | exécuter pipeline signing Mac pour prochaine version |
| Nouveaux locales | PAS FAIT | hors périmètre 1.0 |
| Helper privilégié | PAS FAIT / reporté | aucune nécessité produit actuelle |
| Edition Mac App Store | PAS FAIT / reportée | distribution Developer ID prioritaire |

## Could have — idées possibles, non promises

| Sujet | Statut | Condition avant engagement |
|---|---|---|
| Widget Notification Center | PAS FAIT | nouvelle target WidgetKit, tests macOS et design |
| Actions Shortcuts | PAS FAIT | extension dédiée, permissions, confirmation destructive |
| Nettoyage Corbeille | ABANDONNÉ/ANNULÉ pour 1.0 | moteur sûr dédié, jamais règle aveugle |
| Nettoyage Simulateurs | ABANDONNÉ/ANNULÉ pour 1.0 | même exigence moteur dédié |
| Nettoyage Mail attachments | ABANDONNÉ/ANNULÉ pour 1.0 | données sensibles et restauration à spécifier |
| Réparation LaunchAgents cassés | ABANDONNÉ/ANNULÉ pour 1.0 | risque boot/login ; rollback obligatoire |
| Historique/cookies navigateur | LAISSÉ EN ATTENTE | fermeture browser, schéma reconnu, backup/restore testés |
| Comparaison images Photos Library | LAISSÉ EN ATTENTE | exclusion actuelle volontaire |
| Détection malware/YARA | ABANDONNÉ/ANNULÉ | aucun moteur tiers ; aucune promesse malware |
| Scanner externe historique | ABANDONNÉ/ANNULÉ | retrait complet demandé et effectué |
| Privileged helper | LAISSÉ EN ATTENTE | besoin réel + modèle de sécurité + signature |

## Won’t have — explicitement hors produit actuel

- Compte utilisateur, synchronisation cloud, télémétrie, analytics, crash
  reporter tiers.
- Suppression irréversible par défaut.
- Installation automatique des mises à jour.
- Suppression aveugle de `~/Library`, dossiers système ou données utilisateur.
- Claim « antivirus », détection malware ou quarantaine.
- Attestation SLSA inventée pour v1.0.0.
- Promesse de locales, helper privilégié ou édition App Store.
- Promesse de widget, Shortcuts, CLI destructif, EXIF ou binaires universels
  dans v1.0.0.

## Abandonné / annulé / retiré

- Ancien nom produit et anciennes références de branding : retirés après
  migration CoreTend.
- Ancien panneau menu/vidéo/captures obsolètes : retirés des assets publics.
- Mode Dry Run : retiré du produit et des textes actuels.
- Intégration scanner historique : retirée code, docs, UI, site et tests.
- 4 PR Dependabot anciennes (#1, #2, #14, #16) : décision mainteneur,
  laissées fermées/non réactivées.
- SLSA rétroactive v1.0.0 : refusée volontairement pour exactitude provenance.

## Laissé en attente / bloqué par humain ou environnement

- Nouvelle signature/notarisation : nécessite compte/certificat Apple et Mac
  de signature.
- Publication d’une nouvelle version : nécessite artefacts générés depuis HEAD,
  tag correspondant, ticket staplé et vérification Gatekeeper.
- DNS public : accès registrar nécessaire si contrôle live indisponible.
- QA interactive : déjà attestée par mainteneur ; automatisation ne remplace
  pas observation avec VoiceOver/clavier/Dynamic Type.
- Identité publique locale : secrets et données personnelles ne doivent pas être
  ajoutés automatiquement.

## À faire ensuite — ordre recommandé

1. Préparer prochaine release depuis commit propre ; générer, signer, notariser,
   stapler et attester mêmes octets.
2. Ajouter tests CLI lecture seule dans gate dédié.
3. Concevoir moteur EXIF et moteur Simulator uniquement après modèle de sécurité.
4. Concevoir WidgetKit/Shortcuts dans targets macOS séparées.
5. Réévaluer CLI destructif, binaires universels et désinstallation étendue avec
   rollback et journal.

## Références d’autorité

- `TODO.md`
- `Documentation/FEATURE_MATRIX.md`
- `Documentation/PROJECT_STATE.md`
- `Documentation/RELEASE_STATE.md`
- `Documentation/HUMAN_QA_REPORT.md`
- `Documentation/RELEASE_PROVENANCE.md`
- `Documentation/SAFETY_MODEL.md`
- `Documentation/PRIVACY.md`
- `Documentation/DEPENDABOT_PR_DECISION.md`
