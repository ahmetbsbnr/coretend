# CoreTend Next — plan d’exécution

> Pour le travail initial démarré dans le dépôt indépendant `rebuild/`, consulter `Documentation/Archive/Greenfield-Implementation-plan.md`. Le présent plan régit la branche `next` du dépôt public historique.

**Objectif :** satisfaire le cahier des charges sans dégrader la sûreté des fichiers ni affirmer des fonctions non prouvées.

**Architecture :** SwiftPM/macOS 14+, modules séparés pour contrats, scan en lecture seule, sûreté, persistance, domaine, app SwiftUI et CLI. La branche `next` descend de `origin/main`; aucune réécriture de l’historique public.

**Référence :** `Documentation/Project/Cahier-des-charges.md`, `Documentation/Traceability.csv`, `Documentation/Project/Repository-strategy.md`.

## 1. Base de dépôt et preuves

- [x] Copier passation historique et documents cités dans `Documentation/Archive/Legacy-Reconstruction/`; créer `passation.md` courant.
- [x] Conserver Apache-2.0 pour code, CC-BY-4.0 pour documentation, attribution et règles de contribution/sécurité.
- [x] Créer `next` depuis `origin/main` et y intégrer la reconstruction avec un commit local; `make qualify` passe sur ce worktree.
- [x] Archiver les pointes des branches puis réduire les branches locales à `main` et `next`; supprimer les branches distantes anciennes, sans toucher aux tags.
- [x] CI GitHub Actions de `next` vérifiée : run 36264106677 (`f7d7d73`, macos-latest) passe build/fixtures/site/contracts + whitespace.
- [x] Protéger `next` : check `qualify` strict requis, force-push/suppression interdits. Pas d’approbation PR obligatoire pour préserver le flux full-auto; les commits suivants utiliseront branche PR et merge après check vert. Revue avant fusion vers `main` reste exigée par politique produit.

## 2. Fonctions Must à compléter

- [x] **Applications — comportement borné** : bundles inventoriés séparément des candidats de fichiers associés. Correspondance d’identifiant ne vaut jamais preuve; UI expose « candidats possibles, attribution non confirmée » et ne propose aucune action sur données associées/partagées. Revue nominative et Corbeille concernent uniquement bundle .app choisi. Fixtures Domain couvrent découverte et échec audit/Trash. Attribution positive et action sur données associées restent explicitement indisponibles; FR-26 demeure PARTIEL.
- [x] **Performance — implémentation** : mesures locales horodatées, inconnues explicites, historique SQLite 30 jours/500 entrées, graphique sur points mesurés et effacement borné. Fixtures couvrent mesures, rétention, sélection et effacement. FR-03/perf.metrics restent PARTIEL jusqu’à parcours natif/accessibilité.
- [x] **Integrity — signaux limités** : signature/quarantaine locales avec états indisponibles et limites; inspection LaunchAgents consultative sous dossier choisi, bornée et sans verdict malware. Fixtures couvrent états et plist. Qualification native et couverture des services macOS restent ouvertes.
- [x] **Explore et navigation — implémentation** : Quick Look valide les candidats au moment de l’aperçu; favoris/récents locaux; palette bilingue; filtres/presets taille, âge et catégorie; MenuBarExtra facultatif, ses mesures restent actives seulement pendant présentation. Fixtures et qualification Release isolée documentées. Navigation, aperçu, menu et accessibilité natifs restent à qualifier.
- [x] **Données — implémentation** : rétention, effacement, diagnostic opt-in avec allowlist, backup/restauration fixture et import historique allowlisté/copie seule/transactionnel. Fixtures synthétiques couvrent migration, rollback, reprise et isolation; aucune vraie base utilisateur lue. Parcours natif et récupération réelle restent à qualifier.

Les cases ci-dessus suivent la livraison du code et des fixtures, pas la clôture des exigences. Le statut contractuel reste celui de `Documentation/Traceability.csv`; Musts encore PARTIEL ne deviennent pas VÉRIFIÉ sans preuve native, hôte ou humaine requise.

## 3. Qualification

- [x] Fixtures couvrent règles de chemin/symlink, similarité consultative, données d’app non attribuées, annulation déterministe et échecs/rollback de persistance. `make qualify` passe sur le worktree local; `git diff --check` passe.
- [ ] Compléter qualification native clavier/sidebar/Quick Look/menu, VoiceOver parlé, zoom/Dynamic Type, contraste, Reduce Motion/Transparency et états d’accès refusé. Tests Release isolés couvrent fenêtre, huit routes, une route palette, menu inséré sans interaction et store fixture; ne remplacent pas critères restants. Noter hôte et limites dans les preuves.
- [x] Installer/lancer/désinstaller app Release dans HOME fixture; tests préservent store fixture et refusent chemins invalides. [ ] Signature/notarisation, hôte macOS minimum, autre machine et artefacts publics avant tag restent non qualifiés ou hors mandat; ne pas fabriquer de preuve.
- [x] Garder `Documentation/Traceability.csv` relié au code/tests/preuves datées par le gate. Tant qu’un Must reste PARTIEL/À_CONSTRUIRE, conserver l’étiquette aperçu.

## 4. Should et preuves externes

- [x] Catégories Explore, Quick Look borné, favoris/récents, palette bilingue et menu-bar (accès + mesures visibles) ont une implémentation locale et fixtures; leurs interactions natives restent PARTIEL.
- [ ] Cask uniquement après artefact de release authentique et checksum vérifié; cette reconstruction n’est ni publiée ni candidate de release.
- [ ] Capture UI automatisée, profiling multi-macOS, audit ergonomie externe et compatibilité seconde machine exigent cadrage/outillage/hôtes/relecteur non présents. Ne pas déclarer ces preuves réalisées.
