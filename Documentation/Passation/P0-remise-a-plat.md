# P0 — Remise à plat

**Objectif :** un dossier, une branche, des documents cohérents, un gate vert, rien de local seulement.
**Gate :** P0 — `make qualify` vert sur `next` localement et en CI ; audit accepté par le mainteneur.
**Statut de la phase :** En cours (reste 0.2).
**Plan :** `Documentation/Project/Implementation-plan.md` § Programme 2.0 › P0.

## Lots

| Lot | Intitulé | Statut |
|---|---|---|
| — | Remise à plat du 27-09 (audit, pilotage, branches, intégration, correctifs du gate) | Livré |
| 0.1 | CI `qualify` verte sur `origin/next` | Accepté (automatique) |
| 0.2 | `Makefile` vérifie Python ≥ 3.10 avec message clair | À faire |

## Journal

### 27-09-2026 — remise à plat

- **Constat :** voir `Documentation/Project/Audit-2026-09-27.md` (historique v1/v2/v3/Next,
  causes d’échec, besoins). Le workspace a été déplacé de `~/Developer/Website` vers
  `~/Developer/projects` ; le worktree `next/` a été perdu, puis recréé en
  `~/Developer/projects/coretend-next`. Perdus (non suivis) : `Remaining-musts-plan.md`, `design-preview/`.
- **Gouvernance :** `AGENTS.md` (+ `CLAUDE.md` qui l’importe), `Documentation/Project/Pilotage.md`,
  audit ; développement directement sur `next` (décision du mainteneur).
- **Branches :** 9 branches fusionnées supprimées, `feat/reconstruction-open-musts` (PR #55) avancée
  et `feat/access-diagnostics` (PR #54) fusionnée dans `next` (`0acf44d`), toutes archivées sous
  `refs/archive/2026-09-27/`. Restent `main`, `next`, `fix/1.x-trash-sqlite`.
- **Gate :** trois échecs introduits par la refonte Observatoire corrigés — `82c2ed6`
  (`CleanupRuleDescriptor.isExpectedRoot`, plus de lecture de HOME), `0c4728d` (site sans
  JavaScript, CSP `script-src 'none'`), `e47e340` (durées de mouvement du test alignées sur la spec).
- **Vérifié :** `make qualify` PASS local (27-09 20:05). CI `qualify` PASS sur `5b589b0` et
  `3d8c4b1`. `next` poussée (fast-forward), PR #54/#55 marquées fusionnées par GitHub.
- **Programme 2.0** écrit dans `Implementation-plan.md` (`3d8c4b1`).

## Point d’arrêt

- Prochaine étape : lot **0.2**. Dans le `Makefile`, avant les cibles qui lancent `python3`,
  échouer si `python3 -c 'import sys; sys.exit(sys.version_info < (3, 10))'` échoue, avec un
  message qui indique d’utiliser Python ≥ 3.10 (ex. `/opt/homebrew/bin`). Vérifier : `make
  qualify` PASS avec 3.14, et échec lisible avec `PATH=/usr/bin:/bin make traceability`.
- Puis demander au mainteneur d’accepter l’audit et passer à P1.

## Problèmes ouverts

- Échap n’atteint pas l’app sur cet hôte (voir `Reference.md`) — à traiter avant P2.3.
- Mobile : le site affiche la navigation en liste (plus de bouton menu) — décision en P4.5.
