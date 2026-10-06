# Feuille de route après la 2.0.0 (mise à jour 29-09-2026)

État : CoreTend 2.0.0 publiée (release GitHub, site, tap Homebrew). Tests visuels validés par le
mainteneur le 28-09-2026 (VineSweep, ouverture Gatekeeper comprises). Méthode inchangée : un lot
à la fois, `make qualify`, journal de passation, accord explicite avant toute étape publique.

## Q0 — DMG notarisé — terminé, revalidé le 29-09-2026

Le DMG public est désormais signé, notarisé et agrafé : SHA-256 conforme au manifeste,
`codesign`, `stapler` et `spctl` PASS le 29-09-2026. Voir `Documentation/ReleaseEvidence.md`.
La procédure de notarisation de DMG décrite dans l’historique de P7 est terminée. Les SHA-256 et vérifications actuels sont consignés dans `Documentation/ReleaseEvidence.md`.

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
- Mac App Store : build 201 soumis à la revue ; dernier état observé le 29-09-2026 : Waiting for Review. Consulter `Documentation/Passation/P8-app-store.md`.

Cette feuille de route est prospective ; les points de phase terminés et le statut du dépôt
sont suivis dans `passation.md`. La pointe actuelle de `next` n’est pas intégrée dans `main`.

## Ordre proposé

Q0 terminé → décision App Store à suivre → Q1 (2.0.1) → Q2 (2.1) → Q3 selon décisions.
