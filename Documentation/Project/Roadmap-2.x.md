# Feuille de route après la 2.0.0 (28-09-2026)

État : CoreTend 2.0.0 publiée (release GitHub, site, tap Homebrew). Tests visuels validés par le
mainteneur le 28-09-2026 (VineSweep, ouverture Gatekeeper comprises). Méthode inchangée : un lot
à la fois, `make qualify`, journal de passation, accord explicite avant toute étape publique.

## Q0 — DMG notarisé (bloqué : identifiant Apple du mainteneur)

Le DMG signé n'est pas notarisé : notariser une image disque exige `notarytool`, qui ne peut pas
utiliser le compte connecté dans Xcode. Le profil de la 1.x (`CORETEND_NOTARY_PROFILE`, runner
`coretend-signing`) n'existe plus sur ce Mac.

1. **Mainteneur** : créer une clé API App Store Connect (Users and Access › Integrations ›
   Team Keys, rôle *Developer*), télécharger le `.p8`, puis lancer lui-même :
   `xcrun notarytool store-credentials coretend-notary --key <AuthKey.p8> --key-id <ID> --issuer <Issuer ID>`.
   Aucun mot de passe d'app ; l'agent ne voit ni ne saisit la clé.
2. **Agent** : `bash Scripts/make_release_dmg.sh --app ~/Documents/CoreTend-2.0.0/CoreTend.app
   --identity 02A57D6E5EA4245B8BEE9622C774136C5C79FAAB --notary-profile coretend-notary
   --output <dossier vide>` (signature, notarisation, agrafage, `spctl`, `SHA256SUMS`).
3. Sur accord : `gh release upload v2.0.0` du DMG + `SHA256SUMS` à deux lignes ; page
   Télécharger : DMG proposé à côté du ZIP. Le ZIP reste la source du cask.
4. Ensuite, le même profil permet de notariser toute la release en ligne de commande
   (plus besoin de l'archive manuelle).

## Q1 — 2.0.1, dette de release (petits lots, sans nouvelle fonction)

- **Protection de `main`** : elle attend encore 3 vérifications de la 1.x ; la remplacer par
  `qualify` (réglage du dépôt : accord requis). Les pushes n'auront plus à contourner la règle.
- **Restes 1.x** : runner `coretend-signing-MacBook-de-Ahmet` hors ligne, secrets
  `MINISIGN_*` et `CORETEND_*` inutilisés par la 2.0 → proposer leur retrait (accord requis).
- **Logotype web** : texte vectorisé (aujourd'hui Iowan Old Style par nom de police).
- **Script de release unique** : `make release VERSION=…` enchaînant package, signature,
  notarisation (profil Q0), ZIP, DMG, `SHA256SUMS`, `release.json` et le cask du tap, sans
  publier ; la publication reste une commande séparée.
- **Réserves G4** : test sur un vrai macOS 14 (machine virtuelle Apple silicon ou Mac prêté),
  passage VoiceOver complet des 8 destinations ; corriger ce qui en sort.

## Q2 — 2.1, fonctions (issues du programme Upgrade, non livrées)

- **Doublons** : comparaison côte à côte de deux exemplaires (aperçu, dates, emplacements).
- **Applications** : regroupement App Store / autres / système, panneau de détail unique au lieu
  des actions par ligne.
- **Performances** : pression mémoire quand macOS l'expose (sinon ne rien afficher).
- **Historique** : filtre par objet (dossier, app, règle).
- Chaque fonction : copie EN/FR + tests, captures, entrée du registre de traçabilité.

## Q3 — plus tard, à décider

- Cask officiel `Homebrew/homebrew-cask` quand le dépôt atteint les critères de notoriété.
- Branche 1.x (`../coretend`, `fix/1.x-trash-sqlite`) : la 2.0 la remplace ; décider de
  l'archiver ou de publier le correctif Corbeille/SQLite en 1.x finale.
- Mac App Store : exige le bac à sable (accès aux dossiers par signets de sécurité) ; étude
  de faisabilité avant tout engagement.

## Ordre proposé

Q0 dès que la clé existe → Q1 (2.0.1) → Q2 (2.1) → Q3 selon décisions.
