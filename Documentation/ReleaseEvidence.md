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
