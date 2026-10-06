# Release evidence ledger

État courant vérifié le 29-09-2026 : CoreTend 2.0.0 est distribuée en ZIP et DMG
signés, notarisés et agrafés. Les artefacts publics ont été retéléchargés dans une fixture,
leurs SHA-256 correspondent à `Website/release.json`. `codesign --verify --strict`,
`xcrun stapler validate` et `spctl` retournent 0 pour l'app du ZIP et pour le DMG.
Aucune installation, ouverture du DMG ni publication effectuée pendant cette vérification.

La variante App Store 2.0.0 (201) a été exportée signée depuis l'Organizer après validation
locale du Trousseau par le mainteneur. Signature, profil et entitlements vérifiés ; envoi confirmé par Organizer.
Traitement Apple Complete ; build 201 associé à la version 2.0.0. La soumission a été
confirmée dans App Store Connect avec le statut **Waiting for Review**. La décision Apple est en attente.
Le CLI retourne encore `No Accounts`, ce qui ne décrit pas l'état du compte visible dans Xcode. Les preuves de compatibilité macOS 14, VoiceOver et
parcours sandbox restent ouvertes. Les entrées datées ci-dessous sont historiques.

## Paquet App Store signé — 29-09-2026

- Export Organizer Custom → App Store Connect → Export, équipe du mainteneur, signature automatique.
- Paquet conservé : `Artifacts/AppStore/201/CoreTend-201-AppStore-signed/CoreTend.pkg`.
- SHA-256 `9d137c333b02793427af209bb60a56e66130a863acb9cced5ebf7f6aed309a65`.
- `pkgutil --check-signature` : certificat Apple `3rd Party Mac Developer Installer` valide.
- Extraction temporaire via `pkgutil --expand-full`, app non installée/non lancée ;
  `codesign --verify --strict --deep` PASS.
- Identifiant `com.ahmetbsbnr.coretend`, version 2.0.0, build 201 ; profil embarqué conforme,
  expiration 29-09-2027, sandbox et accès utilisateur read-write vrais, get-task-allow absent.
- Rapport : `Documentation/Evidence/AppStore-package-2026-09-29.json`.
- Le paquet est associé au build 201 soumis à la revue ; App Store Connect confirme Waiting for Review.

## Revalidation des artefacts publics — 29-09-2026

- ZIP : SHA-256 `3fd2548cf988fdecc0749f0c170764cccaf3541aa02c840c4e5c58adafcfefef`.
- DMG : SHA-256 `47b37c3846b4f7efc1fe1ec7ec6724ad8b33a1547aa6e756330188f886c71e98`.
- App extraite par `ditto` ; signature profonde stricte, ticket et Gatekeeper PASS.
- DMG non monté ; signature stricte, ticket et Gatekeeper contexte primary-signature PASS.
- Rapport nettoyé des chemins temporaires :
  `Documentation/Evidence/Release-validation-2026-09-29.json`.
- Ces contrôles concernent les octets publiés, pas les modifications locales de cette session.

## Paquet local installé et lancé en fixture — 2026-09-27

- `make app-runtime-smoke` construit le Release `.app` et le ZIP dans un répertoire temporaire dédié, valide structure/plist/Mach-O, installe le bundle dans HOME fixture, lance l’exécutable installé et le désinstalle en préservant la base fixture.
- ZIP temporaire observé : SHA-256 `5904b8efb73fac47054153a2ca578204b7399c30b0e09cd62824112f4b388868`. Runtime isolé: 14 échantillons sans socket Internet et aucun fichier SQLite/sidecar hors store déclaré.
- L’artefact temporaire a été supprimé à la fin du test. Ce hash prouve uniquement les octets testés; il ne désigne pas un artefact distribué/candidat. Signature, notarisation, Finder/Launch Services et hôte minimum non vérifiés.

## Distinction des erreurs d’accès Applications — 26-09-2026

- Source : commit `87edd45` (`feat/access-diagnostics`), basé sur `55e8628`. Hôte macOS 27.0 (26A428), arm64, Swift 6.4.
- `make qualify` et `git diff --check` passent : site, traçabilité, audit de sûreté, installation fixture, suite XCTest, builds App/CLI et whitespace.
- `make package-local` et `make verify-package` passent. ZIP arm64 unsigned SHA-256 `20a72cf36d3327018b8c78fef76e2f8aab835629b0558345f2b99749693c6024`. Vérification limitée à Info.plist, intégrité ZIP et architecture Mach-O.
- Tests Domain sur fixtures distinguent racine absente, mauvais type, symlink, EACCES/EPERM et erreur Cocoa d’accès refusé. La vue Applications affiche causes localisées EN/FR pour le dossier choisi; aucune sonde TCC/Full Disk Access. FR-10 reste PARTIEL.
- Artefact local uniquement : non lancé depuis cette tranche, non signé, non notarié, non publié.

## Essai UI/accessibilité isolé — 26-09-2026

- macOS 27.0 (26A428), arm64. Le bundle arm64 déjà présent sous `Artifacts/` a été copié dans un HOME temporaire et ouvert avec `open -n`; commande terminée avec code 0 et System Events a retourné le nom de fenêtre `CoreTend`.
- ZIP local unsigned : SHA-256 `94503244830030785388e6ea2359dc844af22d719d5e82729f14408f1697a299`. `make verify-package` passe; contrôle limité à plist, ZIP et Mach-O.
- Lecture des détails d’éléments UI via System Events échoue avec erreur AppleScript `-10827`. Aucun parcours clavier/VoiceOver ou contrôle visuel d’accessibilité effectué; NFR-07 reste PARTIEL. Détails : `Documentation/Evidence/Accessibility.md`.

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

## SQLite v4 — favoris/récents — 26-09-2026

- `make qualify` passe : génération/site statique, traçabilité (40 exigences + 51 capacités), audit sécurité, smoke install en HOME temporaire, suite Swift complète, build app et CLI, whitespace.
- Tests Persistence ciblés : 17/17. Fixtures v1/v2/v3, préservation du contenu v3, idempotence, rétention 100 récents, favoris et mesures inconnues; aucun store utilisateur lu.
- `make package-local` et `make verify-package` réussis. ZIP arm64 unsigned SHA-256 `9b5a340e2513e7f1a9a16a0c0b252a72d8f0eecff6bca62668135019e815b091`. Vérification limitée à Info.plist, archive et Mach-O. App non lancée, non signée, non notarisée, non publiée.
- FR-24/favrec.module en cours; VoiceOver/UI native, palette de commandes et reprise de contenu après re-sélection du dossier restent ouvertes.

## Palette clavier bilingue — 26-09-2026

- Catalogue AppShell couvre huit destinations + Réglages, termes associés FR/EN et recherche insensible à la casse/diacritiques. SwiftUI ouvre par ⌘K, filtre dans une feuille, Retour choisit premier résultat, Échap ferme; sélection réutilise binding du `NavigationSplitView` existant.
- `make qualify` passe après changement; tests AppShell 4/4; builds debug App/CLI inclus. `make package-local`, `make verify-package`, `git diff --check` passent.
- ZIP arm64 unsigned SHA-256 `fbb8a3d042b89f26a37972930553a9b4b218516c357964ea58be9d198942390b`. Contrôle structure seulement. Aucun lancement runtime, contrôle VoiceOver, signature, notarisation ou publication.

## Palette — sélection par flèches — 26-09-2026

- ↑/↓ change sélection de commande avec limites aux extrémités; Retour ouvre commande sélectionnée; une recherche qui change réinitialise sélection si nécessaire. Tests AppShell 5/5 dont liste vide et bornes.
- `make qualify`, `make package-local`, `make verify-package`, `git diff --check` passent. ZIP arm64 unsigned SHA-256 `4c63d81a3b25f4c79b26017760fae0ec632ee93c5d8eb2d1dba5abb2316096bd`; structure seulement, aucun lancement UI, test VoiceOver ou signature.

## Recent files batch transaction — 26-09-2026

- `SQLiteStore.recordRecentFiles` valide le lot complet puis réutilise une requête préparée sous une transaction unique; quota appliqué une fois. Erreurs SQL annulent le lot. Explorer remplace jusqu’à 100 appels individuels par un appel batch.
- `make qualify`, Persistence ciblé 18/18, `git diff --check`, `make package-local` et `make verify-package` réussis.
- ZIP arm64 unsigned SHA-256 `45b8c102247d1656171db8e14349498cfd027083c42fac45e7c976f08c10465e`. Structure seulement; app non lancée, non signée, non notariée, non publiée.

## Performance chart selection — 26-09-2026

- Code source app : `b0287bf` (PR #50, `next`). Build de production puis `make package-local verify-package` réussis après interaction graphique sur point connu le plus proche.
- ZIP local arm64 non signé SHA-256 `94503244830030785388e6ea2359dc844af22d719d5e82729f14408f1697a299` (`Artifacts/CoreTend-local-unsigned.zip`). Verification du plist, archive et Mach-O arm64 seulement.
- Aucun lancement GUI, VoiceOver, signature, notarisation ou publication. Utiliser `make package-local verify-package` pour reproduire depuis `next`.

## Lancement runtime isolé — 27-09-2026

- Hôte : macOS 27.0 arm64, Swift 6.4; exécutable `.build/debug/CoreTendApp` produit par la qualification locale de la branche de reconstruction.
- Lancement avec `HOME`, `CFFIXED_USER_HOME` et `TMPDIR` pointant vers un profil/temporaire unique. Processus resté actif après 8 secondes; `records.sqlite` créé sous `<temporary HOME>/Library/Application Support/CoreTend-Reconstruction/` uniquement. Processus terminé explicitement après observation; profil temporaire nettoyé.
- Cette preuve couvre démarrage du binaire et isolation du store. Fenêtre réellement visible, parcours GUI/a11y et lancement du bundle empaqueté restent non qualifiés. Aucune ouverture via profil utilisateur réel.


## P4 — lot 4.2, compatibilité limitée — 28-09-2026

### Hôtes et portée

Le mainteneur confirme : seul son **MacBook Air M1 sous macOS 27** est disponible.
L’agent observe `sw_vers` : 27.0, build 26A428 ; `uname -m` : arm64.
Swift : Apple Swift 6.4. Aucun second Mac ou hôte macOS 14 n’a été testé.
`tart` et `prlctl` absents du PATH ; le lanceur `VBoxManage` présent échoue car
l’application VirtualBox est absente (code 126). Aucune VM provisionnée ou installation entreprise.

| Hôte | Contrôle | Résultat |
|---|---|---|
| MacBook Air M1, macOS 27.0 (26A428) | Paquet et lancement en fixture isolée | PASS |
| arm64, macOS 14 | Exécution sur OS minimum | NON LANCÉ — hôte indisponible |
| Second Mac | Exécution sur autre machine | NON LANCÉ — hôte indisponible |

### Artefact et commandes exécutées

- Source : `cc23a81c` (dernières modifications de code livrées en P3).
- `make package-local verify-package` : PASS. ZIP non signé local :
  `Artifacts/CoreTend-local-unsigned.zip`, SHA-256
  `224deb78e5f0647b7ed9f8e9b64dfd8a8e51a062b0bda9182665bdc21c6e8944`.
- `file`, plist et `xcrun vtool -show-build` : exécutable arm64, minimum déclaré
  14.0 dans le plist et Mach-O. `otool -L` examiné : dépendances système Apple/SQLite/Swift.
  Ces métadonnées ne prouvent pas l’exécution sous macOS 14.
- `python3 Scripts/test_app_runtime_isolation.py Artifacts/CoreTend.app` : PASS.
  Installation temporaire, HOME/CFFIXED_USER_HOME/TMPDIR/store isolés ; processus actif
  pendant huit secondes, SQLite sous le store prévu, aucun socket Internet dans 14 relevés.
  Processus terminé et copie installée retirée par le script. Aucun déplacement confirmé.
- Mesure indicative de ce smoke : création du store à 0,626 s ; RSS médiane 99,7 MiB,
  maximum 107,0 MiB. Ce n’est pas la preuve de performance représentative du lot 4.3.
- Journaux locaux : `/tmp/coretend-p4-42-package.log`, `/tmp/coretend-p4-42-runtime.log`.

### Recette et réserve

Accepter ou corriger les preuves et la portée ci-dessus. La recette des hôtes manquants
reste à réaliser : même ZIP identifié par SHA-256, copie installée en fixture selon
`Documentation/Passation/Reference.md`, démarrage, huit destinations, Réglages, palette,
FR/EN clair/sombre, scan d’un corpus jetable et fermeture. Consigner OS/build, architecture,
identifiant non sensible de machine, résultat et défauts. Ne jamais confirmer un déplacement
vers la Corbeille dans l’app packagée.

**NFR-08 reste PARTIEL. Cible déclarée macOS 14+ ; exécution observée seulement sur
arm64/macOS 27.0, un seul Mac. Signature/notarisation/publication non réalisées.**

- Qualification finale du lot local : `make qualify` PASS (code 0), `make traceability`
  et `git diff --check` PASS. Journal `/tmp/coretend-p4-42-qualify.log`.
