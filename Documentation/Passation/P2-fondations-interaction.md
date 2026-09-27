# P2 — Fondations Serre

**Objectif :** l’app et le site en direction Serre : jetons, logo, icônes, composants avec tous leurs états, coquille de l’app et motion du guide.
**Gate :** G2 — recette survol/clic/clavier sur chaque écran, clair et sombre.
**Statut de la phase :** En cours depuis le 27-09-2026.
**Plan :** `Documentation/Project/Implementation-plan.md` § Programme 2.0.

## Lots

| Lot | Intitulé | Statut |
|---|---|---|
| 2.1 | Jetons Serre (couleurs Nuit/Jour, typographie, motion, formes) + tests | Accepté (27-09) |
| 2.2 | Logo Serre et germination ; jeu d’icônes ; feuilles de risque | Livré — recette en attente (`9d75517`) |
| 2.3 | Composants et états (guide § 7) + gate `check_architecture.py` | À faire |
| 2.4 | Coquille de l’app : barre latérale, transition « pousse », recherche ⌘K, clavier/focus | À faire |
| 2.5 | Site en Serre : jetons exportés, logo, navigation, racine au défilement (CSS seul) | À faire |

## Journal

### 27-09-2026 — lot 2.1, jetons Serre

- **Fait :** `8635253` — `Palette` aux valeurs Serre + rôles `sidebar`, `deep`, `tertiaryInk`,
  `strongSeparator` ; `CoreTendTypography` en Iowan Old Style (titres, `hero`) et Avenir Next
  (`lede`, `sectionTitle`, `body`, `secondary`, `caption`, `measurement`) ; `MotionToken`
  `press/quick/standard/grow/bloom` et `MotionCurve` `sap/sprout/fall/retreat` ; `LeafCorner`
  (`Sources/DesignSystem/LeafShape.swift`). `gentle` → `standard` (même durée) à 5 endroits.
  Export site : 4 rôles ajoutés, `Website/design-tokens.css` régénéré.
  `b542d87` — l’outil de capture trouve aussi les fenêtres ouvertes sur un autre Space.
- **Vérifié :** `DesignSystemTests` 9/9 (valeurs du guide, contraste de chaque rôle texte ≥ 4,5
  et des contours ≥ 3 sur les 4 fonds, polices installées, coins feuille) ; un `tertiaryInk`
  volontairement faux a fait échouer les tests guide et contraste. `make qualify` PASS.
  Captures Vue d’ensemble et Nettoyage FR/EN clair/sombre relues : couleurs et typo Serre.
- **Reste visible en générique (lots suivants) :** barre latérale grise système et sélection
  système (2.4), boutons et badges système (2.3), icônes SF Symbols (2.2).
- **Recette 2.1 (mainteneur) :** lancer l’app ou regarder `make capture-screens`, dire si
  couleurs et typographie Serre conviennent.
- **Recette 2.1 — acceptée (27-09) :** « il a l'aire d'etre bien […] le style generale est bien
  mieux que tout les design proposé depuis le debut de coretend. » Question du mainteneur sur
  les animations : elles arrivent en 2.2 (logo), 2.3 (survol), 2.4 (navigation, recherche),
  2.5 (site) et P3 (analyse, Corbeille, floraison).

### 27-09-2026 — lot 2.2, logo et icônes

- **Fait :** `9d75517` — `SerreLogo` (germination ≈ 1,2 s une fois, puis immobile ; frémissement au
  survol ; logo final sous Reduce Motion), `SerreGlyph`/`SerreIcon` (10 icônes), `RiskLeaf`
  (pleine / moitié / fendue). Branchés : barre latérale, barre d’outils, ligne Réglages, palette
  ⌘K, recherche Applications, écran de bienvenue (logo à la place du bouclier bleu), badges de
  risque du Nettoyage. Toutes les feuilles modales reçoivent la teinte chlorophylle (elles ne
  l’héritaient pas : icônes, curseur et bouton bleus). Contenu des feuilles extrait dans
  `sheetContent(_:)` (le compilateur ne typait plus le `switch` en ligne).
- **Vérifié :** `SerreDrawingTests` 4/4 + `DesignSystemTests` 9/9. Planche
  `CORETEND_RENDER_DIR=<dossier> swift test --filter SerreRenderSheet` rendue et relue en clair et
  en sombre (icônes lisibles à 18 et 36 pt, feuilles de risque, étapes de germination). `make
  qualify` PASS. Captures palette, bienvenue, Nettoyage FR/EN clair/sombre relues.
- **Non vérifié :** la germination en mouvement réel (captures fixes, état final) ; à regarder
  en lançant l’app (premier lancement).
- **Encore générique :** bouton « Commencer » et boutons de l’app (2.3), barre latérale et
  sélection système (2.4). Défaut de contenu noté : le texte « Uniquement les rapports .crash »
  est faux (la règle retient aussi `.ips`) — à corriger en 3.2.
- **Recette 2.2 (mainteneur) :** lancer l’app (premier lancement : le logo germe), regarder
  icônes et feuilles de risque.

## Point d’arrêt

- 2.2 livré, recette du mainteneur en attente.
- Prochain lot **2.3 — composants** (guide § 7) dans `DesignSystem` : `SerreButtonStyle`
  (principal, secondaire, destructif : coin feuille, survol +8 % et icône −6°, pressé 0,97 `press`,
  focus anneau feuille, désactivé 40 %), ligne de liste avec **nervure** au survol (filet `accent`
  tracé de gauche à droite, `quick`), case, champ de recherche, parcelle (`LeafCorner.parcel`,
  `surface`), badge de risque, bandeaux (partiel / refus / erreur), états de vue. Remplacer les
  six `.buttonStyle(.plain)` et les `RoundedRectangle` ad hoc des vues. Gate
  `Scripts/check_architecture.py` : pas de `.buttonStyle(.plain)`, `Color(red:…)`, `Color.blue` ni
  `repeatForever` hors `DesignSystem` (le faire échouer d’abord sur le code actuel).

## Problèmes ouverts

_(aucun)_
