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
| 2.3 | Composants et états (guide § 7) + gate `check_architecture.py` | Accepté (27-09) |
| 2.4a | Coquille : barre latérale Serre, logo, marqueur feuille, vrille, transition « pousse », clavier | Accepté (27-09) |
| 2.4b | Recherche ⌘K qui naît du bouton : racine sous le champ, résultats qui éclosent, pousse fanée ; fermeture au clic hors de la recherche | Accepté (27-09) |
| 2.5 | Site en Serre : jetons exportés, logo, navigation, racine au défilement (CSS seul) | Livré — recette en attente (`97e43d3`) |

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
- **Recette 2.3 — acceptée (27-09) :** « ca a la'air d'etre pas mal, continue ainsu ». 2.4 découpé
  en 2.4a (coquille/navigation) et 2.4b (recherche), un lot = une intention.

### 27-09-2026 — lot 2.4a, barre latérale et navigation

- **Fait :** `8a3fb5f` — `SerreSidebar` (logo qui germe, nom, bouton Rechercher ⌘K, sections, Réglages)
  à la place de la liste système : plus de sélection bleue. Marqueur feuille partagé
  (`matchedGeometryEffect`, `sprout` 380 ms) quelle que soit la source du changement ; vrille qui se
  trace puis s’efface ; anneau de focus porté par le marqueur (les lignes, lues comme focalisées
  par le conteneur, dessinaient toutes un anneau : `serreFocusRing` les coupe). Transition
  `.grow(from:)` (`GrowMask`, ellipse depuis la hauteur de la ligne, `grow` ; sortie `retreat` ;
  fondu 120 ms sous Reduce Motion). `Destination.sidebarOrder/step/shortcutNumber` : même ordre
  pour barre latérale, palette (Historique n’est plus 2ᵉ) et ⌘1…⌘8 ; ↑/↓ après un clic. Barre de
  titre : fond `canvas`, titre masqué (macOS 15+), plus d’icônes (recherche et réglages dans la
  barre latérale).
- **Vérifié :** tests ordre/pas/raccourcis/ordre de la palette (vu échouer avec l’ancien ordre) et
  rayon du masque. Quatre tests d’abord insérés dans un acteur utilitaire, jamais exécutés par
  XCTest : déplacés et vus s’exécuter. `make qualify` PASS (le build Release zéro-avertissement a
  attrapé un avertissement d’isolation Swift 6 dans `GrowMask`, corrigé). Transition ⌘4 capturée
  image par image : vue qui pousse depuis la ligne, ancienne vue qui se retire, marqueur entre
  deux lignes, vrille. Captures barre latérale, palette, Vue d’ensemble FR/EN clair/sombre.
- **Limites :** les blocs de chaque vue ne montent pas encore un par un (`stagger`) : la vue monte
  d’un bloc ; l’échelonnement se fera écran par écran en P3. ↑/↓ demande un clic préalable dans
  la barre latérale. Échap non qualifiable sur cet hôte.
- **Recette 2.4a (mainteneur) :** changer de destination (clic, ⌘1…⌘8, ↑/↓, palette), regarder
  marqueur, vrille et vue qui pousse ; clair/sombre ; Réduire les animations.
- **Recette 2.4a — acceptée (27-09) :** « validé, aussi ajoute le fait de sortir de la recherche
  commandK avec un clique de souris hors fenetre de recherche etc ». Exigence ajoutée à 2.4b.

### 27-09-2026 — lot 2.4b, recherche ⌘K

- **Fait :** `05f810a` — la palette n’est plus une feuille modale : `SearchLayer` la dessine au-dessus
  de la fenêtre sur un `SerreScrim` ; **clic sur le fond**, Échap, ⌘K ou choix d’un résultat la
  ferment (exigence du mainteneur à la recette 2.4a). La boîte naît du bouton Rechercher
  (`matchedGeometryEffect`, `standard`), son contenu apparaît ensuite ; `SearchRoot` sous le
  champ (longueur liée à la saisie, pleine à 14 caractères, radicelles) ; résultats qui éclosent
  (35 ms, 8 premiers) ; pousse fanée sans résultat. Logique clavier inchangée ; `close` remplace
  `dismiss` ; `RootSheet.commands` supprimé.
- **Vérifié :** test `SearchRoot` (monotone, vide sans saisie, pleine à longueur). App packagée en
  fixture pilotée : ⌘K capturé image par image (boîte en vol depuis le bouton, résultats qui
  éclosent), « per » filtre et fait pousser la racine, « perzzz » montre la pousse fanée, **clic
  souris synthétique hors de la boîte → fermée**. `make qualify` PASS. Captures palette FR/EN
  clair/sombre.
- **Limites :** la bande de la barre de titre n’est pas assombrie ; un clic à cet endroit déplace
  la fenêtre au lieu de fermer. Échap non qualifiable sur cet hôte. Le focus clavier n’est pas
  rendu explicitement au bouton Rechercher à la fermeture.
- **Recette 2.4b (mainteneur) :** ⌘K ou bouton Rechercher, taper, choisir, fermer au clic dehors.
- **Recette 2.4b — acceptée (27-09) :** « validé continue ».

### 27-09-2026 — lot 2.5, site en Serre

- **Fait :** `97e43d3` — `Website/site.css` et `Scripts/build_site.py` : jetons Serre, Iowan Old Style /
  Avenir Next, coins feuille (plus de pilules), plus de dégradé ni de capitales/chasse fixe sur
  les étiquettes ; logo Serre en SVG (en-tête, pied, page de langue) qui germe une fois dans
  l’en-tête ; nervure au survol des liens ; racine décorative qui pousse au défilement
  (`animation-timeline: scroll()` sous `@supports`, masquée sous 1200 px) ; sections et étapes
  qui poussent à l’entrée (`view()`) ; « CORETEND / 01 » → mots simples, numéros d’étape dans des
  feuilles. Tout sous `prefers-reduced-motion: no-preference` ; le contrat reduced-motion arrête
  aussi la racine. Toujours sans JavaScript.
- **Défaut attrapé :** l’entrée de l’accueil partait d’un masque fermé et a laissé le titre
  invisible sur une capture (même défaut que `b8e2769`) ; l’accueil ne fait plus que glisser.
- **Vérifié :** `make build-site site-check`, `make qualify` PASS. Chrome sans interface : accueil
  1280 px clair et sombre ; mobile dans des cadres de **vraie** largeur 390 et 320 px, sans
  débordement (une fenêtre sans interface de 390 px déborde aussi avec l’ancien site : largeur
  minimale de Chrome, pas un défaut du site).
- **Non vérifié :** racine au défilement en navigateur réel (captures fixes), Safari, zoom réel.
- **Recette 2.5 (mainteneur) :** ouvrir `Website/fr/index.html` dans Chrome ou Safari, faire
  défiler, survoler le menu, tester clair/sombre.

## Point d’arrêt

- Tous les lots de P2 sont livrés ; 2.5 attend sa recette.
- **Gate G2** : recette de toute la phase par le mainteneur — app (survol, clic, clavier, focus,
  navigation, recherche, clair/sombre, Réduire les animations) et site. À l’acceptation : clore P2,
  ouvrir P3 au lot 3.1 (Vue d’ensemble + premier lancement) dans `P3-destinations.md`.

## Problèmes ouverts

_(aucun)_
