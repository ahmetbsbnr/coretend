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

- [ ] **Applications** : `Sources/Domain/ApplicationDiscovery.swift`, `Sources/Domain/ApplicationAssociationMatcher.swift`, `Sources/CoreTendApp/ApplicationsView.swift`. Remplacer la simple correspondance de nom par provenance attribuable ou état inconnu; distinguer app et données associées; ajouter revue nominative avant tout déplacement Trash, avec exclusions des fichiers partagés. Tester sur bundles et dossiers synthétiques.
- [ ] **Performance** : `Sources/Domain/SystemSnapshot.swift`, `Sources/Persistence/SQLiteStore.swift`, `Sources/CoreTendApp/SystemSnapshotView.swift`. Persister échantillons datés minimaux, durée de rétention définie, graphique des mesures connues, états inconnus explicites. Tester migrations/retention sur store temporaire.
- [ ] **Integrity** : `Sources/Domain/CodeSignatureInspection.swift`, `Sources/CoreTendApp/IntegrityView.swift`. Ajouter signaux locaux disponibles et leurs limites, état de permission, provenance de chaque observation. Aucun verdict malware.
- [ ] **Explore et navigation** : `Sources/CoreTendApp/ExploreScanView.swift`, `Sources/CoreTendApp/CoreTendApp.swift`, `Sources/AppShell/Destination.swift`. Quick Look sur sélection explicite, favoris/récents locaux, palette clavier et statut menu bar seulement si leur périmètre de confidentialité est documenté.
- [ ] **Données** : `Sources/Persistence/SQLiteStore.swift`, `Sources/CoreTendApp/SettingsView.swift`. Politique de rétention, effacement et sauvegarde/restauration sur HOME fixture; importer uniquement formats hérités reconnus et vérifiés.

## 3. Qualification

- [ ] Couvrir chaque comportement critique avec fixtures dédiées, particulièrement races chemin/symlink, images similaires, app associés, annulation et échecs de persistance. Exécuter `make qualify` et `git diff --check` après changement.
- [ ] Tester app lancée en environnement isolé, clavier/VoiceOver, zoom, Reduce Motion et états accès refusé. Noter version macOS, architecture et limites dans `Documentation/ReleaseEvidence.md`.
- [ ] Valider package installé/désinstallé en compte de test, signature/notarisation et artefacts publiés avant tag. Aucun script de build ne touche au vrai store ni à la vraie Corbeille.
- [ ] Mettre à jour `Documentation/Traceability.csv` seulement avec code, tests et preuve réelle. Tant qu’un Must reste PARTIEL/À_CONSTRUIRE, conserver l’étiquette aperçu.
