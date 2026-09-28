# Système de passation

Objectif : un agent (ou une personne) qui arrive sans contexte reprend **exactement** au
point où le précédent s’est arrêté, même si la session a été coupée au milieu d’un lot.

## Les fichiers

| Fichier | Rôle | Quand l’écrire |
|---|---|---|
| `passation.md` (racine) | point d’entrée : phase et lot courants, **prochaine action exacte**, ce qui attend le mainteneur | au début d’un lot, à chaque arrêt, à la fin d’un lot |
| `Documentation/Passation/P0-…P5-*.md` | journal d’une phase : lots, statuts, commits, vérifications, recettes, problèmes ouverts | à chaque changement de statut d’un lot |
| `Documentation/Passation/Reference.md` | commandes, lancement en fixture, invariants, particularités de l’hôte | quand une commande ou une particularité change |
| `Documentation/Project/Implementation-plan.md` | le programme (quoi, dans quel ordre) | quand le mainteneur change le programme |
| `Documentation/Traceability.csv`, `Documentation/Progress.md` | statut des exigences et preuves datées | quand une recette ou une preuve change un statut |

`Documentation/Passation/P4-qualification.md` peut terminer les lots réalisables tout en
laissant G4 explicitement ouverte. Il distingue les contrôles exécutés des observations
humaines, copies ou hôtes manquants. `passation.md` renvoie vers ce tableau des réserves :
« livré » ne signifie ni « accepté » ni gate passée. À chaque fin de session, confirmer
que les commandes en cours ont réellement terminé, noter leur code de sortie et supprimer
les formulations « en cours » si elles ont fini.

Il n’existe pas d’autre passation, TODO ou roadmap. Une ancienne passation va dans
`Documentation/Archive/`.

## Statuts d’un lot

`À faire` → `En cours` → `Livré — recette en attente` → `Accepté` (ou `Accepté avec
corrections`, ou `Refusé`). Un lot `Refusé` redevient `En cours` ; on ne passe pas au suivant.

## Protocole de session

**Démarrer**

1. `cd ~/Developer/projects/coretend-next && git status --short --branch` : on doit être sur
   `next`, sans modification non commitée inattendue. `git pull --ff-only`.
2. Lire `passation.md`, puis le fichier de la phase courante.
3. Si le lot courant est `En cours`, lire sa section « Point d’arrêt » : c’est là qu’on reprend.
   Si des fichiers sont modifiés sans commit, les inspecter avant toute action ; ne jamais les
   jeter.

**Pendant**

- En commençant un lot : le passer `En cours` dans le fichier de phase et dans
  `passation.md`, avec objectif, fichiers prévus, lignes du registre et recette prévue.
- À chaque étape significative (commit, test rouge/vert, blocage) : mettre à jour le
  « Point d’arrêt » du lot. Une session coupée ne doit rien perdre d’autre que le travail non
  commité depuis ce point.

**S’arrêter** (fin de lot, fin de session ou blocage)

1. `make qualify` si du code a changé ; `git diff --check`.
2. Fichier de phase : statut du lot, commits, vérifications (PASS / FAIL / NON LANCÉ),
   point d’arrêt, problèmes ouverts.
3. `passation.md` : sections « Où on en est », « Prochaine action » et « En attente du
   mainteneur ».
4. Commit sur `next` (documentation comprise). Push seulement sur demande du mainteneur.
5. Dire au mainteneur ce qui est livré, ce qu’il doit regarder, et s’arrêter.

Après toute modification scriptée d’un fichier de passation, vérifier que ses sections
« Lots », « Journal », « Point d’arrêt » et « Problèmes ouverts » sont toutes présentes.

## Écrire un point d’arrêt utile

Une personne sans contexte doit pouvoir agir sans rien deviner :

- **Fait** : commits (hash + sujet), fichiers touchés.
- **Vérifié** : commande exacte et résultat.
- **Reste** : prochaine étape concrète (fichier, fonction, test à écrire).
- **Piège** : ce qui a surpris (hôte, outil, comportement).
