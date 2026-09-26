# Stratégie du dépôt public CoreTend

**Décision :** conserver `ahmetbsbnr/coretend` comme dépôt public canonique. Son historique, ses tags et la ligne 1.x restent consultables. Intégrer la reconstruction dans une branche `next` issue de `origin/main`, puis fusionner par pull request lorsque les critères de qualité sont remplis. Ne pas réécrire `main` ni réutiliser un numéro de version déjà publié.

## Branches et versions

| Référence | Rôle | Règle |
| --- | --- | --- |
| `main` | Version publique stable et documentation correspondante | CI requise, aucun push forcé/suppression; revue PR non imposée par règle d’hébergement observée |
| `next` | Intégration temporaire de la reconstruction complète | Check `qualify` strict requis, aucun push forcé/suppression; pas de promesse publique |
| `feature/<sujet>` ou `fix/<sujet>` | Travail bref issu de `next` ou `main` selon cible | Pull request, suppression après fusion |
| `maintenance/1.x` | Correctifs 1.x seulement si une maintenance réelle reprend | Pas de développement parallèle permanent |
| `vX.Y.Z` | Version immuable | Créé après preuves de build, signature, notarisation et distribution |

La branche `develop/v2` et les branches de session anciennes ne sont pas des lignes de produit. Préserver leurs pointes dans `refs/archive/branches/*` avant nettoyage local; ne conserver sur `origin` que les branches ayant une fonction active. Ne pas supprimer de tag de release.

## Projet, code et documentation

- SwiftPM est source de vérité du code. L’application macOS et le CLI vivent dans un même dépôt avec modules `Sources/`, tests `Tests/`, site statique `Website/`, scripts `Scripts/` et documents `Documentation/`.
- `Documentation/Project/Cahier-des-charges.md` définit le produit; `Documentation/Traceability.csv` relie exigences, code et preuves. `Documentation/Progress.md` décrit l’état observé. Une capacité partielle ne devient pas « terminée » grâce à une seule compilation.
- L’ancienne passation et les documents qu’elle cite sont archivés sous `Documentation/Archive/Legacy-Reconstruction/`. Ils sont historiques, avec anciens chemins, architecture et résultats de tests. Le fichier racine `passation.md` est la passation courante.
- Licence Apache-2.0 conservée pour code et documentation. `NOTICE` conservé pour attribution historique; nouvelles dépendances et médias exigent provenance/licence explicites avant intégration.
- Les contributions passent par `CONTRIBUTING.md`; signalements de vulnérabilité suivent `SECURITY.md` sans divulgation publique initiale.

## CI et publication

1. Pull request : compilation app/CLI, tests isolés, contrôle du site, traçabilité, sûreté et `git diff --check` sur macOS compatible. Les contrôles ne lisent ni vrai store utilisateur ni vraie Corbeille.
2. Préversion : exécution native macOS, accessibilité clavier/VoiceOver, tests d’installation et de désinstallation sur compte ou HOME isolé, mesures de performance et vérification sur les versions/architectures annoncées. Archiver sorties, environnement, limites et sommes SHA-256.
3. Release publique : identité Developer ID contrôlée hors dépôt, signature, notarisation, vérification du ticket, ZIP/DMG et provenance. Publication GitHub Releases puis mise à jour du site et du canal Homebrew seulement après vérification des artefacts publiés. Aucun secret de signature dans Git.
4. Mises à jour : annoncer source et version vérifiées; jamais installer silencieusement. Conserver une page de confidentialité honnête sur scans locaux, diagnostics et accès réseau.

`main` continue de représenter la version publique 1.x tant que `next` ne satisfait pas les critères de remplacement. L’aperçu `next` n’est ni signé, ni notarisé, ni qualifié comme release.

## Transition locale du 26-09-2026

La reconstruction a commencé dans `rebuild/`, dépôt Git indépendant. Son arbre a été intégré sur `next` par un commit issu du `main` public. Cette forme garde l’ascendance publique et évite un push forcé. Le dépôt `rebuild/` reste une copie locale de provenance; les tags et branches historiques restent accessibles par l’historique et les références d’archive locales. Voir `Documentation/Project/Branch-cleanup.md`.

Vérification hébergement le 26-09-2026 : `next` requiert le status check `qualify` strict (GitHub Actions), bloque force-push et suppression, sans exiger d’approbation PR. L’acteur admin a droit de bypass; push `c7ea517` avant résultat distant a retourné l’avertissement GitHub de bypass car `qualify` était encore attendu. Gate local `make qualify` avait passé; CI distante du commit antérieur `f7d7d73` a réussi. Pour les prochains jalons, travailler sur branche dédiée et fusionner vers `next` seulement après check PR vert. `main` reste protégée par checks historiques (`build-and-test`, `distribution-check`, `checks`), force-push/suppression bloqués, sans exigence d’approbation observée. Ces réglages décrivent l’état actuel, distinct de la politique souhaitée de revue avant fusion vers `main`.
