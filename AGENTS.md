# CoreTend Next — règles pour les agents

CoreTend est un utilitaire macOS natif (SwiftUI, SwiftPM, macOS 14+) qui analyse le
stockage en lecture seule et déplace vers la Corbeille, après revue et confirmation,
ce que la personne a choisi. Ce dossier (`coretend-next`, branche `next`) porte le
développement ; `main` suit `next` à chaque release publiée. Le dossier `../coretend`
(branche `fix/1.x-trash-sqlite`) porte la 1.x, en maintenance seulement.

## Avant toute action

1. `git status --short --branch` : vérifier que l’on est sur `next` dans ce dossier. Tout développement se fait directement sur `next` ; ne pas créer de branche de travail.
2. Lire `passation.md` (où on en est, prochaine action), le journal de la phase courante
   dans `Documentation/Passation/`, puis `Documentation/Project/Pilotage.md` (phases, gates,
   lots). Si le lot courant est « En cours », reprendre à son « Point d’arrêt ». Le produit est défini par
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
- Règle du mainteneur (02-10-2026) : ne jamais placer de libellé eyebrow/overline au-dessus
  d’un titre de page ou de section, dans l’app ni sur le site. Le titre ouvre directement
  l’en-tête ; un sous-titre reste possible.
- Gate avant commit : `make qualify`, puis `git diff --check`. Tests ciblés :
  `swift test --filter <Suite>`.
- Changement visible : lancer l’app en fixture isolée (protocole dans `Documentation/Passation/Reference.md`)
  et relire soi-même les captures avant d’affirmer un rendu.
- Tenir la passation à jour au début, à chaque arrêt et à la fin d’un lot
  (`Documentation/Passation/README.md`) ; une session coupée doit pouvoir reprendre au point
  d’arrêt écrit, sans rien deviner.
- Pas de push, fusion, tag, signature ou publication sans demande explicite.

## Invariants de sûreté

- Tout scan est en lecture seule. Tout déplacement passe par `SafetyCore` :
  sélection, revue, confirmation, revalidation, API Trash macOS. Échec de Trash :
  la source reste, l’échec est enregistré ; jamais de suppression permanente.
- Tests et captures uniquement sur fixtures temporaires et fausse Corbeille ; jamais
  le vrai HOME, le vrai store CoreTend ni la vraie Corbeille. Dans l’app packagée,
  ne jamais confirmer un déplacement.
- Aucune télémétrie, aucun réseau silencieux (seule la mise à jour Sparkle parle au réseau, désactivable).
  Toute dépendance runtime est justifiée dans le README.
- Décision 0005 (06-10-2026) : plus d'App Store ni de sandbox ; langue = système (français sinon anglais).
- Ne pas affirmer espace libéré, absence de malware, propriété d’un fichier, statut
  de release ou accessibilité sans preuve.

## Outils

Avant d’appeler les outils XcodeBuildMCP, charger la skill XcodeBuildMCP si la
session en propose une.
