# 0004 — CoreTend sur le Mac App Store

**Date :** 29-09-2026 · **Statut :** remplacée par 0005 (06-10-2026)

## Contexte

Le cahier des charges classait l'App Store en *Could* (« après redesign ciblé sandbox ») et en
*Won't* pour le livrable d'alors. La 2.0.0 est sortie en Developer ID (GitHub, site, tap
Homebrew). Le 29-09-2026, le mainteneur demande une version TestFlight puis une soumission à
Apple : l'App Store « était prévu depuis le début du projet ».

## Décision

CoreTend est distribuée **aussi** sur le Mac App Store, sous le même identifiant
`com.ahmetbsbnr.coretend`, gratuite. Le canal Developer ID (ZIP/DMG notarisés, Homebrew) reste.

## Conséquences

- L'app de l'App Store tourne dans l'**App Sandbox** : elle ne lit que ce que l'utilisateur
  choisit dans le panneau système (droit `files.user-selected.read-write`). C'est déjà le principe
  du produit (« vous choisissez chaque dossier ») ; les raccourcis de dossiers habituels ouvrent
  donc le panneau déjà placé sur ce dossier au lieu de le lire directement.
- Le dossier personnel réel remplace `NSHomeDirectory()` (qui désigne le conteneur en sandbox).
- L'accès à un dossier choisi dure jusqu'à la fin de l'action (analyse **et** déplacement vers la
  Corbeille), pas seulement de l'analyse.
- L'outil en ligne de commande n'est pas livré dans la version App Store.
- Les données de la version App Store vivent dans son conteneur : l'historique de la version
  Developer ID n'y est pas repris automatiquement.
- Aucune règle de sûreté n'est assouplie : lecture seule par défaut, Corbeille après revue et
  confirmation, pas de réseau, pas de télémétrie (« Données non collectées »).
- La soumission à la revue d'Apple est une étape publique : accord explicite du mainteneur.
