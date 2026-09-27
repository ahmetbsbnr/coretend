# Nettoyage des branches — 26-09-2026

Le dépôt public `ahmetbsbnr/coretend` conserve son historique et ses tags. Avant suppression, chaque pointe locale et chaque branche `origin` connue a été copiée dans `refs/archive/2026-09-26/` dans le dépôt Git local. Les références d’archive ne sont pas des branches de travail et ne sont pas publiées.

| Ancienne référence | Pointe archivée | Suite |
| --- | --- | --- |
| `claude/keen-gates-6dtpoi` locale | `0c5732e` | supprimée localement |
| `develop/v2` locale | `5c21035` | supprimée localement |
| `feature/app-store-migration` locale | `3733cd7` | supprimée localement |
| `maintenance/1.x` locale | `14d2daa` | supprimée localement |
| `reconstruction/baseline` locale | `e488202` | supprimée localement; worktree historique détaché, fichiers non suivis conservés |
| `main` locale avant mise à jour | `39bdbfa` | avancée à `origin/main` (`14d2daa`) |
| `origin/claude/keen-gates-6dtpoi` | `2382421` | supprimée du serveur |
| `origin/develop/v2` | `065b5fa` | supprimée du serveur |
| `origin/maintenance/1.x` | `14d2daa` | supprimée du serveur |
| `origin/main` | `14d2daa` | conservée |

Après nettoyage, branches locales actives : `main` et `next`. Branches `origin` actives : `main` et `next`. `next` provient de `origin/main` et intègre la reconstruction par commit de remplacement d’arbre; elle a été poussée sans force. Aucun tag créé. Les références `archive/tags/...` préexistantes restent intactes.

Pour restaurer une ancienne pointe locale, créer une branche depuis sa référence archivée, par exemple `git branch recover-v2 refs/archive/2026-09-26/heads/develop/v2`. Une branche distante supprimée peut être republiée depuis `refs/archive/2026-09-26/remotes/origin/<nom>` si nécessaire.

## Nettoyage du 27-09-2026

Après le déplacement du workspace vers `~/Developer/projects`. Chaque pointe supprimée est conservée sous `refs/archive/2026-09-27/` (locale, non publiée).

| Référence | Raison | Suite |
| --- | --- | --- |
| `docs/handoff-after-batch`, `docs/handoff-chart-selection-merged`, `docs/package-evidence-chart-50`, `docs/passation-full-refresh`, `docs/site-capability-refresh`, `feat/legacy-import-performance-graph`, `feat/performance-chart-selection`, `fix/performance-chart-date-axis`, `fix/persistence-timestamp-validation` | Fusionnées par squash dans `next` (PR #45–#53) ; `git cherry next` ne trouve aucun patch absent ; branches distantes déjà supprimées | supprimées localement |
| stash « Phase 6 material » sur `develop/v2` | Matériel v2 abandonné | archivé en `refs/archive/2026-09-27/stash/develop-v2-phase6`, stash supprimé |
| worktrees `next` et `coretend-reconstruction` | Dossiers disparus au déplacement | métadonnées élaguées ; `feat/reconstruction-open-musts` recréé dans `~/Developer/projects/coretend-next` |

Branches restantes et rôle :

| Branche | Rôle |
| --- | --- |
| `main` | 1.x publiée (1.0.2) |
| `next` | intégration de la reconstruction |
| `feat/reconstruction-open-musts` | lot courant, PR #55 vers `next` |
| `fix/1.x-trash-sqlite` (locale) | correctifs de sûreté 1.x, dossier `../coretend` ; release 1.0.3 à décider |
| `feat/access-diagnostics` | fonction non intégrée (signalement des erreurs d’accès aux dossiers dans Applications, 2 commits au-dessus de `next`) ; à intégrer ou fermer par décision du mainteneur |

Restaurer : `git branch <nom> refs/archive/2026-09-27/heads/<nom>`.
