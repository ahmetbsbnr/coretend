# Passation courante — CoreTend Next

**Date :** 26-09-2026. **État :** reconstruction en cours, sans release. Dépôt actif : worktree `next/`, branche `next` publiée sur `ahmetbsbnr/coretend` et issue de `main`. L’ancien dépôt indépendant `rebuild/` reste une copie locale de provenance.

## Lire d’abord

1. [`Documentation/Project/Cahier-des-charges.md`](Documentation/Project/Cahier-des-charges.md) : QQOQCCP, MoSCoW, RACI, exigences, huit destinations.
2. [`Documentation/Project/Repository-strategy.md`](Documentation/Project/Repository-strategy.md) : politique de branches, contribution et release.
3. [`Documentation/Progress.md`](Documentation/Progress.md) et [`Documentation/Traceability.csv`](Documentation/Traceability.csv) : état et preuves par capacité.
4. [`Documentation/Archive/Legacy-Reconstruction/passation.md`](Documentation/Archive/Legacy-Reconstruction/passation.md) : passation historique complète et sa famille documentaire. Ne pas confondre ses résultats 1.x avec la reconstruction neuve.

## État de travail

- Application SwiftUI, huit destinations, CLI, modules de scan/sûreté/persistance, site EN/FR et paquet local unsigned existent. Les parcours restent partiels selon la traçabilité.
- Dernière tranche : images similaires consultatives et recherche de fichiers associés aux apps par identifiant bundle dans un dossier choisi. Compilation `swift build` réussie; tests ciblés sur images synthétiques, symlink, limite de candidats et correspondance exacte réussis. Couverture produit encore partielle.
- Aucun accès aux données réelles CoreTend ni à la vraie Corbeille pendant les tests. Aucune publication, signature, notarisation ou mise à jour distante.
- Les documents anciens ont été copiés dans `Documentation/Archive/Legacy-Reconstruction/` sans modifier le worktree historique.
- `next` a intégré l’arbre de reconstruction sur l’historique public. `make qualify` passe dans `next/`. Branches locales réduites à `main` et `next`; trois anciennes branches `origin` supprimées après archivage de leurs pointes. Détails : `Documentation/Project/Branch-cleanup.md`.
- Développement après intégration : charge système sur une minute et historique Performance SQLite v3 (30 jours/500 entrées, points mesurés). Tests Persistence ciblés 14/14 et `make qualify` passent; qualification UI native encore ouverte.
- Intégrité ajoute lecture du marqueur de quarantaine macOS sur l’app choisie; états présent/absent/indisponible et test fixture. La provenance réelle reste non vérifiée.
- Applications propose désormais le déplacement du seul bundle `.app` choisi vers la Corbeille, avec proposition journalisée, revue nominative et confirmation. L’identité du répertoire est comparée à l’inventaire, à la revue et à l’exécution; tests sur Corbeille fixture et remplacement de répertoire. Données associées/héritées inchangées; FR-26 reste PARTIEL.

## Suite prioritaire

1. Finir les fonctions Must encore partielles ou absentes; prioriser attribution des fichiers liés aux apps, sources de mise à jour, états d’accès, favoris et accessibilité selon `Documentation/Project/Implementation-plan.md`.
2. Vérifier chaque capacité avec fixtures isolées et tests utiles, puis parcours macOS natifs. Corriger la documentation quand la preuve change.
3. Vérifier CI distante de `next` et régler la protection des branches dans l’hébergement. Ne pas déplacer la version publique `main` avant qualification.
4. Préparer une version publique uniquement après matrice de compatibilité, signature/notarisation et vérification des artefacts.
