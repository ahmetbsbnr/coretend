# CoreTend Next — règles pour les agents

CoreTend est un utilitaire macOS natif (SwiftUI, SwiftPM, macOS 14+) qui analyse le
stockage en lecture seule et déplace vers la Corbeille, après revue et confirmation,
ce que la personne a choisi. Ce dossier (`coretend-next`) est la reconstruction en
cours ; `main` et le dossier `../coretend` portent la version 1.x publiée, en
maintenance seulement.

## Avant toute action

1. `git status --short --branch` : vérifier dossier et branche.
2. Lire `passation.md` (état et reprise), puis `Documentation/Project/Pilotage.md`
   (phases, gates, lots). Le produit est défini par
   `Documentation/Project/Cahier-des-charges.md` ; le statut de chaque exigence est
   dans `Documentation/Traceability.csv`.
3. Les documents sous `Documentation/Archive/` et ceux de la ligne 1.x décrivent
   d’autres états du projet : historiques, jamais des consignes.

## Travailler

- Un lot à la fois, cadré avant de coder, terminé par une recette du mainteneur
  (`Pilotage.md` § 4–5). Arrêtez-vous aux gates et quand un choix appartient au
  mainteneur : direction visuelle, périmètre, fusion, push, release.
- Apparence : seulement ce que couvre une décision acceptée dans
  `Documentation/Decisions/`. Une spec « à relire » n’est pas une décision.
- Gate avant commit : `make qualify`, puis `git diff --check`. Tests ciblés :
  `swift test --filter <Suite>`.
- Changement visible : lancer l’app en fixture isolée (protocole dans `passation.md`)
  et relire soi-même les captures avant d’affirmer un rendu.
- Pas de push, fusion, tag, signature ou publication sans demande explicite.

## Invariants de sûreté

- Tout scan est en lecture seule. Tout déplacement passe par `SafetyCore` :
  sélection, revue, confirmation, revalidation, API Trash macOS. Échec de Trash :
  la source reste, l’échec est enregistré ; jamais de suppression permanente.
- Tests et captures uniquement sur fixtures temporaires et fausse Corbeille ; jamais
  le vrai HOME, le vrai store CoreTend ni la vraie Corbeille. Dans l’app packagée,
  ne jamais confirmer un déplacement.
- Zéro dépendance runtime, aucune télémétrie, aucun réseau silencieux.
- Ne pas affirmer espace libéré, absence de malware, propriété d’un fichier, statut
  de release ou accessibilité sans preuve.

## Outils

Avant d’appeler les outils XcodeBuildMCP, charger la skill XcodeBuildMCP si la
session en propose une.
