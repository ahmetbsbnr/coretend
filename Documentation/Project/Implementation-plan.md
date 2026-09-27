# CoreTend Next — plan d’exécution

> Pour le travail initial démarré dans le dépôt indépendant `rebuild/`, consulter `Documentation/Archive/Greenfield-Implementation-plan.md`. Le présent plan régit la branche `next` du dépôt public historique.

**Objectif :** satisfaire le cahier des charges sans dégrader la sûreté des fichiers ni affirmer des fonctions non prouvées.

**Architecture :** SwiftPM/macOS 14+, modules séparés pour contrats, scan en lecture seule, sûreté, persistance, domaine, app SwiftUI et CLI. La branche `next` descend de `origin/main`; aucune réécriture de l’historique public.

**Référence :** `Documentation/Project/Cahier-des-charges.md`, `Documentation/Traceability.csv`, `Documentation/Project/Repository-strategy.md`.

**Pilotage :** phases, gates et lots dans `Documentation/Project/Pilotage.md`. Plans et specs sous `docs/superpowers/` ne s’appliquent que s’ils sont liés ici : [refonte Observatoire](../../docs/superpowers/plans/2026-09-27-coretend-observatoire.md) — implémentée, en attente de G1.

## Programme 2.0 — à partir du 28-09-2026

### Point de départ

Relevé du register au 27-09 : 78 Must, dont 2 `VÉRIFIÉ` ; 11 Should, aucun vérifié. Les moteurs
(scan, sûreté, persistance, doublons, CLI) sont couverts par fixtures et `make qualify` passe.
Presque toutes les lignes ouvertes portent la même lacune : **« parcours natif non qualifié »**.
Le produit n’a pas été utilisé et accepté par son mainteneur. Le programme porte donc sur
l’expérience et la recette, pas sur du moteur supplémentaire. Défaut connu : aucun retour au
survol dans l’app, six `.buttonStyle(.plain)` avec zones cliquables incomplètes.

Chaque lot suit `Pilotage.md` § 4–5 : cadré avant de coder, commité sur `next`, `make qualify`
vert, captures relues si visible, puis **arrêt et recette du mainteneur**. Un lot à la fois.
Les durées sont des estimations pour un lot par jour de travail, recette comprise.

### P0 — Clôture de la remise à plat (0,5 j)

- [x] **0.1** CI `qualify` verte sur `origin/next` (`5b589b0`, `3d8c4b1`, 27-09).
- [x] **0.2** (`e3d80a8`) Le `Makefile` vérifie Python ≥ 3.10 et échoue avec un message clair (le `python3`
  système 3.9 casse `test_traceability.py` sans erreur lisible).
- **Recette :** aucune. **Sortie :** gate P0.

### P1 — Direction visuelle et guide UI (2 j) — gate G1

- [x] **1.1 Kit de captures** (`3098745`, recette en attente). Script qui lance l’app en fixture et capture 8 destinations,
  Réglages, ⌘K, onboarding et barre de menus, clair/sombre, FR/EN, avec données synthétiques,
  puis une planche HTML locale. Prérequis mainteneur : autoriser l’enregistrement d’écran.
- [x] **1.2 Séance G1** (27-09) : Observatoire refusé ; brief consigné. **1.2b** trois directions animées (`15056a4`) ; **Serre choisie** (décision 0002).
- [x] **1.3 Guide UI** (rédigé le 27-09, acceptation G1 en attente) `Documentation/Design/UI-guide.md`, rédigé depuis la séance : palette et
  rôles, typographie, grille et densité, composants et **leurs états (repos, survol, pressé,
  focus, désactivé, sélectionné)**, sidebar, cartes (quand en mettre, quand non), icônes,
  mouvement, textes. Décision `0002-direction-serre.md`. Plus aucun choix
  visuel hors de ce guide.
- **Sortie :** G1 accepté. Si la direction est refusée, on refait P1 ; rien de P2 ne commence.

### P2 — Fondations Serre (4–5 j) — gate G2

Référence : `Documentation/Design/UI-guide.md` (direction « Serre », décision 0002).

- [x] **2.1 Jetons Serre** (`8635253`) : `Palette` (Nuit/Jour, rôles `sidebar`, `deep`, `tertiaryInk`,
  `strongSeparator`), `CoreTendTypography` (Iowan Old Style / Avenir Next), `MotionToken`
  (`press`, `quick`, `standard`, `grow`, `bloom`, courbes `sève`, `pousse`, `chute`, `retrait`),
  formes « coin feuille ». Tests de contraste et de durées mis à jour.
- [x] **2.2 Logo et icônes** (`9d75517`) : logo Serre en tracés SwiftUI avec la germination ; jeu d’icônes
  Serre des 8 destinations, Réglages, Recherche ; feuilles de risque.
- [x] **2.3 Composants** (`6050d7e`) : boutons (principal, secondaire, destructif), ligne de barre latérale
  et **marqueur feuille** dessinés par CoreTend, ligne de liste avec nervure, case, champ de
  recherche, parcelle, badge de risque, bandeaux, états de vue. Tous les états du guide § 7.
  Gate `check_architecture.py` : pas de `.buttonStyle(.plain)`, couleur littérale ou
  `repeatForever` hors `DesignSystem`.
- [ ] **2.4 Coquille de l’app** (découpé en 2.4a navigation, 2.4b recherche) : barre latérale Serre, transition « pousse » entre destinations,
  recherche ⌘K qui naît du bouton, remplacement de tous les styles ad hoc, clavier et focus.
- [ ] **2.5 Site en Serre** : export des jetons, polices système, logo qui germe en CSS, en-tête
  et navigation, racine qui pousse au défilement (CSS seul, `@supports`), contrat reduced-motion.
- **Recette G2 :** l’app et le site en Serre, survol/clic/clavier sur chaque écran, clair/sombre.

### P3 — Destinations, une par une (9 lots, ~2 semaines) — gates G3.1 → G3.9

Chaque lot : états initial, en cours, résultats, vide, partiel, refus d’accès, erreur ;
FR/EN ; clair/sombre ; clavier ; captures ; recette ; puis passage des lignes listées à
`VÉRIFIÉ` pour leur part native lorsque la recette couvre tout le critère.

| Lot | Destination | Lignes principales du registre |
|---|---|---|
| 3.1 | Vue d’ensemble + premier lancement | FR-01, FR-03, shell.launch, shell.onboarding, shell.nav |
| 3.2 | Nettoyage (chemin destructif) | FR-05, FR-06, cleanup.* (7), safety.*, NFR-01, NFR-02 |
| 3.3 | Explorer | FR-08, FR-16, scan.spacelens, spacelens.view, spacelens.delete, clutter.largeold, cloud.detect, FR-23 |
| 3.4 | Doublons et images proches | FR-07, scan.duplicates, scan.similarimages, clutter.duplicates, clutter.similarimages |
| 3.5 | Applications | apps.*, FR-25, FR-26 (bundle seul), FR-10 |
| 3.6 | Intégrité | FR-09, integrity.* |
| 3.7 | Performances | perf.metrics, NFR-09 (mesure seulement) |
| 3.8 | Historique | activity.*, FR-06, FR-24, favrec.module |
| 3.9 | Réglages, palette ⌘K, barre de menus, langue, import ancien | settings.*, ui.commandpalette, shell.menubar, FR-21, FR-22, l10n.languagepicker, migration.* |
| 3.10 | Site : pages Fonctionnalités, Confidentialité, Développeur, Assistance en Serre, captures réelles | FR-15, NFR-11 |

Ordre : ce que l’on voit d’abord (3.1), puis la valeur centrale et le chemin le plus risqué
(3.2), puis le reste par usage. Pour 3.2, la recette inclut **un vrai passage par la Corbeille
macOS sur un dossier jetable créé pour l’occasion**, fait par le mainteneur.

### P4 — Qualification transverse (1–2 semaines, dépend d’hôtes) — gate G4

- [ ] **4.1 Accessibilité (mainteneur)** : VoiceOver parlé, Dynamic Type/zoom, contraste,
  Reduce Motion, Reduce Transparency, destination par destination (NFR-07).
- [ ] **4.2 Compatibilité** : un hôte macOS 14 (machine ou VM) et un second Mac (NFR-08).
- [ ] **4.3 Performance** : corpus représentatif documenté, mesures démarrage/scan/RSS, puis
  budgets fixés (NFR-09).
- [ ] **4.4 Revue indépendante** architecture et sûreté, dans un contexte neuf, consignée ;
  absence de second relecteur humain déclarée (NFR-10, NFR-12).
- [ ] **4.5 Site** : zoom réel, VoiceOver, en-têtes déployés, navigateurs (NFR-11) ; décider
  si le site garde un bouton de menu mobile (sans JavaScript).
- [ ] **4.6 Import de données 1.x** sur une copie réelle d’un store 1.x, jamais l’original (FR-20).

### P5 — Release 2.0 (1 semaine) — gate G5, chaque étape sur autorisation

- [ ] Identité Developer ID et profil de notarisation (hors dépôt), build signé, notarisé,
  agrafé ; ZIP/DMG, SHA-256, provenance (NFR-14, FR-14).
- [ ] Notes de version FR/EN, site sorti de `noindex`, lien de téléchargement réel (FR-15).
- [ ] PR `next` → `main` avec revue, tag `v2.0.0`, release GitHub, cask Homebrew généré depuis
  l’artefact publié (FR-17).
- **Piste 1.x, optionnelle avant 2.0 :** publier 1.0.3 depuis `fix/1.x-trash-sqlite` (correctif
  du fallback de suppression) si des utilisateurs 1.x doivent être protégés d’ici là.

### Suivi

Indicateur unique : **Must `VÉRIFIÉ` / 78** (2 au départ). Visée : ≥ 40 après P3, 78 avant G5.
`passation.md` et le journal de phase (`Documentation/Passation/`) sont tenus à jour au début, à chaque arrêt et à la fin de chaque lot ; `Progress.md` reçoit le résultat daté de
chaque recette. Un point hebdomadaire compare l’indicateur, les gates passées et les lots refusés.

### Risques

| Risque | Parade |
|---|---|
| Direction visuelle encore refusée | P1 bouclé tant que G1 n’est pas accepté ; aucun écran construit avant |
| Recettes qui s’accumulent | un lot à la fois ; pas de lot suivant sans résultat de recette |
| Hôtes manquants (macOS 14, second Mac) | P4.2 planifiée tôt ; sans hôte, la matrice de support annoncée reste réduite |
| Mainteneur seul relecteur | déclaré dans les preuves ; revue d’agent en contexte neuf en complément, pas en remplacement |
| Échap bloqué sur l’hôte | identifier l’utilitaire tiers avant 2.3 |

## Historique — plan d’amorçage (26–27-09-2026, livré)

### 1. Base de dépôt et preuves

- [x] Copier passation historique et documents cités dans `Documentation/Archive/Legacy-Reconstruction/`; créer `passation.md` courant.
- [x] Conserver Apache-2.0 pour code, CC-BY-4.0 pour documentation, attribution et règles de contribution/sécurité.
- [x] Créer `next` depuis `origin/main` et y intégrer la reconstruction avec un commit local; `make qualify` passe sur ce worktree.
- [x] Archiver les pointes des branches puis réduire les branches locales à `main` et `next`; supprimer les branches distantes anciennes, sans toucher aux tags.
- [x] CI GitHub Actions de `next` vérifiée : run 36264106677 (`f7d7d73`, macos-latest) passe build/fixtures/site/contracts + whitespace.
- [x] Protéger `next` : check `qualify` strict requis, force-push/suppression interdits. Pas d’approbation PR imposée par l’hébergement; depuis le 27-09, chaque lot se termine par la recette du mainteneur avant fusion (`Pilotage.md`). Revue avant fusion vers `main` reste exigée par politique produit.

### 2. Fonctions Must à compléter

- [x] **Applications — comportement borné** : bundles inventoriés séparément des candidats de fichiers associés. Correspondance d’identifiant ne vaut jamais preuve; UI expose « candidats possibles, attribution non confirmée » et ne propose aucune action sur données associées/partagées. Revue nominative et Corbeille concernent uniquement bundle .app choisi. Fixtures Domain couvrent découverte et échec audit/Trash. Attribution positive et action sur données associées restent explicitement indisponibles; FR-26 demeure PARTIEL.
- [x] **Performance — implémentation** : mesures locales horodatées, inconnues explicites, historique SQLite 30 jours/500 entrées, graphique sur points mesurés et effacement borné. Fixtures couvrent mesures, rétention, sélection et effacement. FR-03/perf.metrics restent PARTIEL jusqu’à parcours natif/accessibilité.
- [x] **Integrity — signaux limités** : signature/quarantaine locales avec états indisponibles et limites; inspection LaunchAgents consultative sous dossier choisi, bornée et sans verdict malware. Fixtures couvrent états et plist. Qualification native et couverture des services macOS restent ouvertes.
- [x] **Explore et navigation — implémentation** : Quick Look valide les candidats au moment de l’aperçu; favoris/récents locaux; palette bilingue; filtres/presets taille, âge et catégorie; MenuBarExtra facultatif, ses mesures restent actives seulement pendant présentation. Fixtures et qualification Release isolée documentées. Navigation, aperçu, menu et accessibilité natifs restent à qualifier.
- [x] **Données — implémentation** : rétention, effacement, diagnostic opt-in avec allowlist, backup/restauration fixture et import historique allowlisté/copie seule/transactionnel. Fixtures synthétiques couvrent migration, rollback, reprise et isolation; aucune vraie base utilisateur lue. Parcours natif et récupération réelle restent à qualifier.

Les cases ci-dessus suivent la livraison du code et des fixtures, pas la clôture des exigences. Le statut contractuel reste celui de `Documentation/Traceability.csv`; Musts encore PARTIEL ne deviennent pas VÉRIFIÉ sans preuve native, hôte ou humaine requise.

### 3. Qualification

- [x] Fixtures couvrent règles de chemin/symlink, similarité consultative, données d’app non attribuées, annulation déterministe et échecs/rollback de persistance. `make qualify` passe sur le worktree local; `git diff --check` passe.
- [ ] Compléter qualification native clavier/sidebar/Quick Look/menu, VoiceOver parlé, zoom/Dynamic Type, contraste, Reduce Motion/Transparency et états d’accès refusé. Tests Release isolés couvrent fenêtre, huit routes, une route palette, menu inséré sans interaction et store fixture; ne remplacent pas critères restants. Noter hôte et limites dans les preuves.
- [x] Installer/lancer/désinstaller app Release dans HOME fixture; tests préservent store fixture et refusent chemins invalides. [ ] Signature/notarisation, hôte macOS minimum, autre machine et artefacts publics avant tag restent non qualifiés ou hors mandat; ne pas fabriquer de preuve.
- [x] Garder `Documentation/Traceability.csv` relié au code/tests/preuves datées par le gate. Tant qu’un Must reste PARTIEL/À_CONSTRUIRE, conserver l’étiquette aperçu.

### 4. Should et preuves externes

- [x] Catégories Explore, Quick Look borné, favoris/récents, palette bilingue et menu-bar (accès + mesures visibles) ont une implémentation locale et fixtures; leurs interactions natives restent PARTIEL.
- [ ] Cask uniquement après artefact de release authentique et checksum vérifié; cette reconstruction n’est ni publiée ni candidate de release.
- [ ] Capture UI automatisée, profiling multi-macOS, audit ergonomie externe et compatibilité seconde machine exigent cadrage/outillage/hôtes/relecteur non présents. Ne pas déclarer ces preuves réalisées.
