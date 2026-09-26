# Release evidence ledger

État courant : reconstruction locale non publiée. Aucun artefact candidat n’a été signé, notarisé, envoyé ou annoncé. Aucune URL publique de téléchargement, version publiée ou somme de contrôle de release ne doit être présentée comme réelle.

La qualification locale doit consigner commit, hôte/OS, commandes, sorties, provenance du paquet local, audits, tests, accessibilité, limites et écarts Must. Toute version publiée ou action de distribution exige une décision distincte, hors mandat courant.

## Build local du 26-09-2026

- Source compilée : `d53e71888d83d30d9defe395e4e851a5c2e04061` (`next`). Hôte : macOS 27.0 (26A428), arm64, Apple Swift 6.4.
- `make package-local` : réussi. Application locale `Artifacts/CoreTend.app`; ZIP local non signé `Artifacts/CoreTend-local-unsigned.zip` (634 Kio affichés par `ls -lh`). `Info.plist` passe `plutil -lint` pendant le packaging.
- SHA-256 du ZIP local : `8783aa498e4eb8958e758c9a6eac32f800397c3def3e4376e1ef6d3e78a0ab9f`.
- `swift build --product CoreTendApp` et `swift build --product CoreTendCLI` : réussis avant packaging. Tests, lancement natif, installation, signature, notarisation et publication non exécutés pour cette tranche. Le ZIP reste ignoré par Git et n’est pas une release.

## Build local après données et états de scan — 26-09-2026

- Source compilée : `c90cd1e` (`next`, incluant `0807db8`). Même hôte macOS 27.0 arm64 et Swift 6.4.
- `swift build --product CoreTendApp` et `make package-local` : réussis. `Info.plist` passe `plutil -lint` pendant le packaging.
- ZIP local non signé `Artifacts/CoreTend-local-unsigned.zip` : SHA-256 `876a8ad83fd30741ab378416e0ac4e2dc208544cb9f6b874879ecacb53f7bf93`. Il remplace le ZIP local précédent; aucun artefact publié.
- Tests, lancement natif, vérification d’annulation par interaction, installation, signature et notarisation non exécutés pour ces changements. Les statuts NFR-05 et NFR-06 restent PARTIELS.

## Build local après navigation et packaging — 26-09-2026

- Source compilée : `894c107` (`next`, incluant `9ad2417`). Même hôte macOS 27.0 arm64 et Swift 6.4.
- `swift build --product CoreTendApp` et `make package-local` : réussis. Le nouveau script prépare un bundle propre dans `Artifacts/` avant remplacement; `Info.plist` passe `plutil -lint`.
- ZIP local non signé actuel : SHA-256 `e1e87a2a611d4793b2043c396ea2d957b34fe9205e73434fa3ce51620c3473fa`. Cette somme identifie seulement cet artefact local; le ZIP est régénéré avec des métadonnées d’horodatage, donc une reconstruction peut produire une autre somme.
- Relancement natif pour prouver la restauration, inspection du contenu ZIP, tests, installation, signature, notarisation et publication non exécutés pour cette tranche.

## Build Quick Look — 26-09-2026

- Source compilée : commit source à relever après commit de cette tranche (`next`). Hôte : même Mac arm64 / macOS 27.0 / Swift 6.4.
- `swift build --product CoreTendApp`, `swift build -c release --product CoreTendApp`, `make package-local` et `make verify-package` : réussis. Vérification porte sur compilation, Info.plist, intégrité ZIP et structure Mach-O arm64.
- Quick Look est disponible pour fichiers choisis dans Explorer, Doublons et Images similaires; portée dossier maintenue pendant aperçu. Compilation prouve les API, pas le comportement natif en exécution.
- SHA-256 du ZIP local non signé : `7d885f8fa0bac32487205e5faa435e05fd16ed2e096a64dbc21fb50758070fee`. Artefact ignoré par Git, local et non publié.
- Lancement, parcours Quick Look, accessibilité, signature, notarisation et publication non vérifiés. FR-23 / quicklook.extended restent PARTIELS.

## Aide accès dossiers — 26-09-2026

- Source compilée : commit de fonctionnalité précédant la mise à jour documentaire de cette tranche (`next`). `swift build --product CoreTendApp`, `make traceability`, `make safety-audit`, `make package-local`, `make verify-package` réussis.
- ZIP local unsigned SHA-256 : `d11cd103e63c58affe766535c49938f3521e51e6f45fafde66b2a097664acb4c`. Vérification porte sur structure/plist/ZIP/Mach-O; pas sur lancement ou parcours natif. Aucun artefact publié.
- FR-10 reste PARTIEL et aucun état de sécurité ou permission exhaustive n’est inféré.

## Qualification intégrée sur 4f98f5a — 26-09-2026

- `make qualify` passe : site, inventaire, traceability, audit sécurité, `swift test`, builds debug `CoreTendApp` et `CoreTendCLI`.
- Les tests utilisent fixtures / stockages temporaires et adaptateurs Trash factices selon l’audit. Aucun essai sur données personnelles, vraie Corbeille ou compte HOME temporaire pour installation.
- Écarts restant : UI native, installation/lancement, VoiceOver/clavier, deuxième version macOS/hôte, signature/notarisation, statut Must partiel/incomplet. Qualification code ≠ release publiable.

## CLI partial-scan contract — 26-09-2026

- Source compilée : `6dfb493` (`next`). `make qualify`, `make package-local`, `make verify-package` réussis; tests CLI ciblés 5/5.
- Le ZIP unsigned local courant est arm64; SHA-256 `835917d81e62930c77208c44d58357e6be9db4c7f1be250e7681eab3c7317c60`. Vérification confirme uniquement plist, structure ZIP et Mach-O; aucun lancement UI/signature/notarisation/publication.
- Résultat CLI n’améliore pas le scan sur fichiers protégés lui-même; issues et codes sortie empêchent de traiter un résultat incomplet comme succès.

## Quick Look accessibility labels — 26-09-2026

- Source compilée : `cdb3870` (`next`). `make qualify`, `make package-local` et `make verify-package` réussis; gate inclut XCTest complet et builds debug App/CLI.
- ZIP arm64 non signé SHA-256 : `721cc3311c1ee8c986ca324e534e830be5b2c73b7f2b59acd80f6466b8e0740d`. Vérification limitée à Info.plist, archive et architecture Mach-O. Aucun lancement, VoiceOver, installation, signature ou notarisation.
- Libellés/hints fichier Quick Look améliorés. NFR-07 reste PARTIEL jusqu’à qualification manuelle clavier, focus, VoiceOver, zoom, contraste et réductions de mouvement/transparence.

## Explore explicit presets — 26-09-2026

- Source compilée : `664dbf6` (`next`). `make qualify`, `make package-local`, `make verify-package` réussis. Deux tests ExplorePreset (seuil Gio inclusif/inconnu, date limite 365 jours) passent; suite complète comprise dans gate.
- ZIP arm64 non signé : SHA-256 `072ff474f4eae77109dd312b342e125c2b1c30d8275afeb0cc3f8a573d522c48`. Verification limitée à Info.plist, archive et Mach-O; aucune exécution UI, install, signature, notarisation ou publication.

## Diagnostic exact preview — 26-09-2026

- Source compilée : `5fc9563` (`next`). La feuille Réglages présente le JSON expurgé exact, avant sélection de destination. La feuille se ferme avant que l’exporteur soit ouvert.
- `make qualify`, `make package-local`, `make verify-package` réussis; test ciblé redaction sur fixture réussi. Qualification ne couvre pas la feuille native ni annulation par interaction.
- ZIP arm64 unsigned SHA-256 `63b28f04d3382fed0ded640538e99a801ed0cb7ec676074718218e5525bf3bfb`. Aucun lancement, installation, signature/notarisation ou publication.

## Audit statique réseau — 26-09-2026

- `make qualify` passe avec audit étendu : aucun import/API réseau standard, socket/processus d’exécution, SDK analytics connu ou dépendance SwiftPM URL détecté sous runtime.
- Aucun changement binaire après artefact `5fc9563` (ZIP `63b28f04d3382fed0ded640538e99a801ed0cb7ec676074718218e5525bf3bfb`). Vérification ne vaut pas capture runtime; NFR-04 demeure PARTIEL.

## Local installer — 26-09-2026

- Bundle arm64 source Swift release `5fc9563`, emballé avec installateur actuel. ZIP unsigned SHA-256 `795eab7dbeb13d0d0b241f0a018fb58645c8bfc0c2ebb6d0e4af3622777c0898`.
- `make verify-install-package`: bundle release réellement copié vers `CoreTend.app` sous HOME temporaire; doublon et source/destination symlink refusés. `make qualify` inclut smoke synthetic, suite XCTest complète, builds debug, audit réseau/sûreté et site; `make verify-package` vérifie archive/plist/Mach-O.
- Test ne lance pas l’app et ne touche pas installation réelle, données CoreTend, Finder ou Trash. FR-14 demeure PARTIEL : parcours GUI, désinstallation utilisateur, signature, notarisation, OS minimum non qualifiés.
- CI distante du commit `f7d7d73` : [Actions run 36264106677](https://github.com/ahmetbsbnr/coretend/actions/runs/36264106677), macos-latest, conclusion `success` le 2026-09-26 18:54:30 UTC; tous les steps réussis.
- Protection GitHub activée/vérifiée pour `next` : status check `qualify` (GitHub Actions, app 15368), strict, force-push/suppression interdits, aucune revue PR requise. Protection `main` inspectée mais inchangée; checks historiques y restent configurés sans approbation PR obligatoire.

## Repository protection checkpoint — 26-09-2026

- CI distante de `bea69a3` réussie : [Actions run 36264445630](https://github.com/ahmetbsbnr/coretend/actions/runs/36264445630), `qualify` + whitespace, macos-latest, 18:59:56Z.
- Run `36264363517` de `c7ea517` a aussi réussi après push; serveur avait signalé bypass admin car check distant était encore en attente au push. La protection conserve status check strict pour merge; privilégier branches de travail + PR pour éviter bypass direct.

## Branch-policy documentation checkpoint — 26-09-2026

- CI `ed437b1` réussie : [Actions run 36264534176](https://github.com/ahmetbsbnr/coretend/actions/runs/36264534176), macos-latest, build/fixtures/site/contracts + whitespace, 19:01:42Z.
