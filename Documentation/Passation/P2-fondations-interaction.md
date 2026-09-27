# P2 — Fondations Serre

**Objectif :** l’app et le site en direction Serre : jetons, logo, icônes, composants avec tous leurs états, coquille de l’app et motion du guide.
**Gate :** G2 — recette survol/clic/clavier sur chaque écran, clair et sombre.
**Statut de la phase :** En cours depuis le 27-09-2026.
**Plan :** `Documentation/Project/Implementation-plan.md` § Programme 2.0.

## Lots

| Lot | Intitulé | Statut |
|---|---|---|
| 2.1 | Jetons Serre (couleurs Nuit/Jour, typographie, motion, formes) + tests | Accepté (27-09) |
| 2.2 | Logo Serre et germination ; jeu d’icônes ; feuilles de risque | Accepté (27-09) |
| 2.3 | Composants et états (guide § 7) + gate `check_architecture.py` | Livré — recette en attente (`6050d7e`) |
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
- **Recette 2.2 — acceptée (27-09) :** « validé continue ».

### 27-09-2026 — lot 2.3, composants

- **Fait :** `6050d7e` — `SerreButtonStyle` (`.serre(.primary|.secondary|.destructive|.row(selected:)|.icon|.tile)`,
  tous les états, nervure animée sous les lignes, icône inclinée au survol, dessin dans
  `SerreButtonChrome`) ; `SerreParcel`, `SerreBanner`, `SerreEmptyState`. Style secondaire Serre par
  défaut dans le contenu et les feuilles ; « Commencer » et « Terminé » en principal ; les six
  `.buttonStyle(.plain)` remplacés ; `ObservatoryCard` → `SerreParcel`.
  `check_architecture.py` : règles de design (bouton plain, couleur littérale ou système,
  `repeatForever` hors `DesignSystem`) + 2 tests.
- **Vérifié :** gate de design rouge sur les 6 boutons avant, vert après. Planche de rendu
  (toutes variantes × repos/survol/pressé/focus/désactivé, bandeaux, parcelle) relue clair/sombre ;
  survol du bouton principal qui assombrissait → corrigé. `make qualify` PASS. Captures Nettoyage,
  Applications, palette, Vue d’ensemble relues.
- **Pas encore adopté partout (P3, écran par écran) :** bandeaux et états vides Serre à la place
  des `ContentUnavailableView` et textes d’état actuels ; nombreuses cartes encore en
  `RoundedRectangle` ; 5 boutons `.borderless` dans les listes.
- **Vu sur capture :** la sélection de la barre latérale est **bleue** (accent système) quand la
  fenêtre est active → traité en 2.4 (marqueur feuille dessiné par CoreTend).
- **Recette 2.3 (mainteneur) :** survoler et cliquer les boutons et lignes (nervure), clavier
  (anneau de focus), clair/sombre.

## Point d’arrêt

- 2.3 livré, recette du mainteneur en attente.
- Prochain lot **2.4 — coquille de l’app** (guide § 8, catalogue) : barre latérale dessinée par
  CoreTend (plus de sélection système bleue) avec logo en tête et **marqueur feuille** qui glisse
  (`sprout`) ; **vrille** du marqueur vers le contenu ; la vue **pousse** depuis ce point (masque
  ellipse, `grow`) et ses blocs montent en `stagger` ; l’ancienne vue se pose et s’efface
  (`retreat`) ; interruptible. Recherche ⌘K qui **naît du bouton Rechercher**, **racine** sous le
  champ qui suit la saisie, résultats qui **éclosent**, pousse qui fane sans résultat. Barre
  d’outils en `.serre(.icon)`. Clavier : focus visible, ⌘1…⌘8, Échap (à re-tester, voir
  Reference.md). Reduce Motion : fondu 120 ms ou immédiat.

## Problèmes ouverts

_(aucun)_
