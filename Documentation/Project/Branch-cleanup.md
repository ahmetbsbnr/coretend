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
