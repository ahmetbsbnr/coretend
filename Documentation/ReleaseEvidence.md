# Release evidence ledger

État courant : reconstruction locale non publiée. Aucun artefact candidat n’a été signé, notarisé, envoyé ou annoncé. Aucune URL publique de téléchargement, version publiée ou somme de contrôle de release ne doit être présentée comme réelle.

La qualification locale doit consigner commit, hôte/OS, commandes, sorties, provenance du paquet local, audits, tests, accessibilité, limites et écarts Must. Toute version publiée ou action de distribution exige une décision distincte, hors mandat courant.

## Build local du 26-09-2026

- Source compilée : `d53e71888d83d30d9defe395e4e851a5c2e04061` (`next`). Hôte : macOS 27.0 (26A428), arm64, Apple Swift 6.4.
- `make package-local` : réussi. Application locale `Artifacts/CoreTend.app`; ZIP local non signé `Artifacts/CoreTend-local-unsigned.zip` (634 Kio affichés par `ls -lh`). `Info.plist` passe `plutil -lint` pendant le packaging.
- SHA-256 du ZIP local : `8783aa498e4eb8958e758c9a6eac32f800397c3def3e4376e1ef6d3e78a0ab9f`.
- `swift build --product CoreTendApp` et `swift build --product CoreTendCLI` : réussis avant packaging. Tests, lancement natif, installation, signature, notarisation et publication non exécutés pour cette tranche. Le ZIP reste ignoré par Git et n’est pas une release.
