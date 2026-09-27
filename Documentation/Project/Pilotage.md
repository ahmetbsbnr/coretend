# Pilotage de CoreTend Next

Ce document dit **comment le projet avance** : qui décide, dans quel ordre, et quand
on s’arrête. Il répond aux causes d’échec de v2 et v3 relevées dans
[l’audit du 27-09-2026](Audit-2026-09-27.md) : décisions visuelles prises sans le
mainteneur, directions changées en cours de route, vitesse sans point d’arrêt,
plusieurs vérités à la fois.

## 1. Rôles

| Qui | Décide | Ne décide pas |
|---|---|---|
| **Mainteneur** (Ahmet) | direction visuelle, périmètre et MoSCoW, acceptation d’un lot, fusion vers `next`/`main`, push, release, publication | — |
| **Agent** (Claude ou autre) | comment implémenter un lot déjà cadré, quels tests écrire | tout ce qui est dans la colonne de gauche |

La RACI du cahier (§ 8) reste la référence ; ce tableau en est la lecture opérationnelle.

## 2. Une seule vérité par sujet

| Sujet | Source unique | Règle |
|---|---|---|
| Où travailler | dossier `~/Developer/projects/coretend-next`, branche `next` directement | jamais dans le dossier 1.x pour du travail produit |
| État courant et reprise | `passation.md` (point d’entrée) et `Documentation/Passation/` (un journal par phase, référence) | mis à jour au début, à chaque arrêt et à la fin de chaque lot, selon `Documentation/Passation/README.md` ; pas d’autre passation |
| Exigences et statut | `Documentation/Traceability.csv` | `VÉRIFIÉ` seulement après recette (§ 5) |
| Historique des preuves | `Documentation/Progress.md` | ajout daté, jamais réécrit |
| Décisions | `Documentation/Decisions/NNNN-*.md` | une décision = un fichier daté, approuvé par le mainteneur |
| Plan | `Documentation/Project/Implementation-plan.md` | tout autre plan ou spec doit y être lié, sinon il n’existe pas |
| Règles d’agent | `AGENTS.md` (lu aussi par `CLAUDE.md`) | aucun autre fichier d’instructions dans le dépôt |

Un document remplacé part dans `Documentation/Archive/` avec une ligne qui dit par quoi
il est remplacé. On ne crée pas de nouvelle passation, TODO ou roadmap à côté.

## 3. Phases

| Phase | Objectif | Sortie (gate) |
|---|---|---|
| **P0 — Remise à plat** | un dossier, une branche active, documents cohérents, commits locaux sauvegardés | `make qualify` vert sur la pointe ; audit accepté par le mainteneur ; branche poussée si le mainteneur le décide |
| **P1 — Direction visuelle** | montrer l’app **lancée** en Observatoire : 8 destinations, Réglages, palette ⌘K, clair et sombre | **G1** : décision `0002-direction-visuelle.md` acceptée, avec la liste des changements demandés |
| **P2 — Fondations d’interaction** | composants communs dans `DesignSystem` : bouton, ligne de sidebar, ligne de liste, avec survol, zone cliquable pleine, focus, état pressé/désactivé ; appliqués partout | **G2** : recette survol/clic/clavier sur toutes les destinations |
| **P3 — Destinations, une par une** | Vue d’ensemble → Nettoyage → Explorer → Doublons → Applications → Intégrité → Performances → Historique | **G3.x** : recette de la destination ; ses lignes Must passent `VÉRIFIÉ` |
| **P4 — Qualification transverse** | VoiceOver, Dynamic Type, Reduce Motion, hôte macOS 14, performance | **G4** : preuves consignées pour chaque NFR concerné |
| **P5 — Release 2.0** | signature, notarisation, fusion `next` → `main`, tag, site, cask | **G5** : autorisation explicite à chaque étape |

On ne commence pas une phase avant que la gate précédente soit passée. Aucun nouvel
écran ni changement de palette, typographie ou mise en page avant G1.

## 4. Un lot de travail

Un lot = une intention, au plus une journée, commité directement sur `next`
(décision du mainteneur du 27-09 : plus de branche de lot). **Un seul lot ouvert
à la fois** ; un lot non accepté est corrigé sur `next`, pas mis de côté.

**Avant de coder**, l’agent écrit dans la conversation :
objectif, fichiers touchés, lignes de `Traceability.csv` concernées, ce que le
mainteneur regardera à la recette. Si le lot touche l’apparence et que ce n’est pas
couvert par une décision acceptée, il s’arrête et demande.

**Pour finir**, l’agent :
1. lance `make qualify` et `git diff --check` ;
2. pour tout changement visible, lance l’app en fixture (protocole dans `Documentation/Passation/Reference.md`)
   et joint des captures clair/sombre qu’il a ouvertes et relues ;
3. met à jour `passation.md`, le journal de la phase (`Documentation/Passation/`) et, si un statut change, `Progress.md`/`Traceability.csv` ;
4. **s’arrête** et présente la recette. Le lot suivant attend le résultat.

## 5. Recette

Le mainteneur lance l’app (ou regarde les captures, pour un lot sans interaction) et
parcourt la liste de recette du lot. Résultat possible : accepté, accepté avec
corrections (nouvelles lignes au lot suivant), refusé (le lot est repris, pas empilé).
L’agent consigne le résultat daté dans `Progress.md`. Une exigence n’est `VÉRIFIÉ`
qu’avec une recette acceptée ou une preuve automatique qui couvre tout son critère.

## 6. Ce qui est interdit, parce que c’est ce qui a fait échouer v2 et v3

- Enchaîner les lots sans recette, ou interdire à l’agent de s’arrêter.
- Implémenter une spec visuelle marquée « à relire ».
- Changer de direction visuelle sans nouvelle décision acceptée.
- Créer un nouveau plan, une nouvelle passation ou un nouveau système de design
  « à côté » de ceux du § 2.
- Travailler dans un autre dossier ou une autre branche que ceux du § 2 sans le dire.
- Pousser, fusionner, tagger ou publier sans demande explicite.
