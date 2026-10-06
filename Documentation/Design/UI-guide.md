# Guide UI — CoreTend « Serre »

**Statut :** accepté par le mainteneur le 27-09-2026 (gate G1, décision
`Documentation/Decisions/0002-direction-serre.md`). S’applique à l’app **et** au site.
Référence animée : `Documentation/Design/Directions/index.html` (direction A). Là où le
prototype et ce guide diffèrent, **le guide gagne** (il corrige et prolonge le prototype).

---

## 1. Le thème

CoreTend entretient un Mac comme on entretient une serre. On **observe** l’état de la serre, on
**analyse jusqu’aux racines**, on **taille** ce qui doit l’être, on tient un **herbier** de tout ce
qui a été fait. Rien n’est arraché sans accord, rien ne sort de la serre.

Le thème gouverne tout : couleurs, formes, typographie, icônes, illustrations, vocabulaire des
textes d’accompagnement et motion. Un élément qui n’a pas de place dans la serre n’a pas de
place dans CoreTend.

### Règle d’honnêteté

La métaphore habille, elle ne remplace jamais le fait :

- Les **libellés de navigation et d’action restent littéraux** : « Nettoyage », « Déplacer vers la
  Corbeille », « Annuler ». La métaphore vit dans les sous-titres, les illustrations et le motion.
- Une action irréversible ou destructive est toujours nommée en clair, jamais « taillée » ou
  « cueillie » dans le bouton qui l’exécute.
- Une visualisation ne montre que ce qui a été mesuré. Pas de couche, racine ou fleur inventée
  pour faire joli : une strate du sol = une quantité mesurée.

### Les destinations dans la serre

| Destination (libellé) | Image | Sous-titre type | Visualisation signature |
|---|---|---|---|
| Vue d’ensemble | l’état de la serre | « L’état de la serre, mesuré à l’instant. » | strates du sol (volume occupé / libre, et catégories seulement si mesurées) |
| Explorer | les parcelles | « Choisissez une parcelle : CoreTend en relève chaque couche. » | carte proportionnelle en parcelles plantées |
| Nettoyage | la taille | « Des tailles connues et sûres. Rien n’est coupé sans votre accord. » | outils de taille par règle, risque en couleur de feuille + libellé |
| Doublons | les pousses jumelles | « Des pousses identiques. Vous choisissez celle qu’on garde. » | paires de pousses, étiquette « gardée » |
| Applications | les plantations | « Les plantes installées et ce qu’elles laissent autour. » | rangs de plantation |
| Intégrité | les étiquettes | « Ce que macOS sait de chaque plant : signature, provenance. » | étiquettes de plant (signal par signal) |
| Performances | la sève | « La respiration de la machine, point par point. » | courbe de sève sur axe temporel réel |
| Historique | l’herbier | « L’herbier : tout ce qui a été observé et taillé. » | pages d’herbier par jour |

---

## 2. Couleurs

Deux ambiances : **Nuit de serre** (sombre) et **Serre de jour** (clair, verre dépoli vert, pas
crème). L’app suit le réglage système ou le choix de l’utilisateur. Contrastes WCAG calculés le
27-09-2026 ; `DesignSystemTests` les imposera en P2.

| Rôle (`Palette`) | Nuit | Jour | Usage |
|---|---|---|---|
| `canvas` | `#0F2019` | `#E7EFE4` | fond du contenu |
| `sidebar` *(nouveau)* | `#0B1913` | `#DCE7D8` | barre latérale, barre de titre |
| `surface` | `#14291F` | `#F4F8F1` | parcelles (cartes), listes |
| `raisedSurface` | `#183126` | `#FFFFFF` | feuilles modales, recherche, popovers |
| `deep` *(nouveau)* | `#0A1510` | `#D3E0CF` | sol : zones de visualisation (racines, strates) |
| `ink` | `#EEF1E6` | `#10261C` | texte principal (≥ 12:1) |
| `secondaryInk` | `#C3CDB9` | `#35503F` | texte secondaire (≥ 6,9:1) |
| `tertiaryInk` *(nouveau)* | `#8FA088` | `#4F6557` | légendes, sources (≥ 4,9:1 partout) |
| `separator` | `#2C4A37` | `#BFD0C1` | filets décoratifs uniquement |
| `strongSeparator` *(nouveau)* | `#5F8A6C` | `#65826D` | contour des contrôles (≥ 3:1 partout) |
| `accent` — chlorophylle | `#9BE36D` | `#2C6E35` | action principale, sélection, progression |
| `onAccent` | `#0B1913` | `#F4F8F1` | texte sur accent (11,7:1 / 5,8:1) |
| `caution` — pollen | `#E8B64A` | `#8A5A00` | risque moyen, avertissement |
| `danger` — terre cuite | `#E98A63` | `#A9431C` | risque élevé, erreur, action irréversible |
| `focus` | = `accent` | = `accent` | anneau de focus |

Règles :

- **Un seul accent**, la chlorophylle. Aucune icône ou élément en bleu système : tout contrôle
  natif reçoit `.tint(accent)` ; la sélection de la barre latérale est dessinée par CoreTend
  (feuille, § 7), pas laissée à l’accent macOS.
- La couleur n’est jamais seule porteuse de sens : risque = couleur **et** libellé **et** forme de
  feuille (§ 5).
- Aucune couleur littérale hors `DesignSystem` (gate en P2). Le site reçoit ces mêmes valeurs par
  export.
- Pas de dégradé décoratif. Seul dégradé admis : la lumière douce en haut du « sol » des
  visualisations (`deep` → `canvas`, 8 % d’opacité).

---

## 3. Typographie

Les titres de page et de section commencent directement par le titre. Ne pas ajouter de
libellé eyebrow/overline au-dessus ; un sous-titre peut suivre le titre de page.

Deux familles livrées avec macOS : aucune police embarquée, aucune licence à gérer.

| Rôle | Police | Taille / graisse | Usage |
|---|---|---|---|
| Titre de page | Iowan Old Style | 44 pt, bold (Iowan n’a pas de semibold) | titre de destination |
| Chiffre héros | Iowan Old Style | 40 pt, regular | la mesure principale d’une vue |
| Titre de section | Avenir Next | 13 pt, demibold, +0,04 em | titres de parcelles |
| Corps | Avenir Next | 14 pt, regular | texte courant, listes |
| Sous-titre | Avenir Next | 16 pt, regular, `secondaryInk` | phrase sous le titre de page |
| Légende | Avenir Next | 12 pt, regular, `tertiaryInk` | sources, heures de mesure |
| Chiffres de tableau | Avenir Next | 14 pt, `monospacedDigit()` | tailles, compteurs, dates |

Pas d’italique décoratif, pas de chasse fixe pour les libellés, pas de capitales forcées. Dynamic
Type : les tailles suivent l’échelle système (`relativeTo:`).

---

## 4. Formes et espace

- **Coin feuille** : rayons asymétriques, pointe en haut à droite et en bas à gauche
  (`UnevenRoundedRectangle`, macOS 14+).
  - contrôles (boutons, sélection) : 16 / 5 / 16 / 5 pt ;
  - parcelles (cartes) : 20 / 7 / 20 / 7 pt ;
  - modales et recherche : 22 / 8 / 22 / 8 pt.
- Grille de 8 pt ; marges de page 40 pt ; espacement entre parcelles 16 pt.
- Cibles cliquables ≥ 44 × 32 pt, **zone cliquable = toute la forme** (`contentShape`).
- Parcelles : pas de carte dans une carte ; un filet `separator` suffit pour subdiviser.
- Ombres : seulement sous `raisedSurface` (modales), jamais sur les parcelles.

---

## 5. Iconographie

- Un **jeu d’icônes Serre** dessiné pour CoreTend (tracés SwiftUI, trait 1,6 pt, terminaisons
  arrondies, une petite courbe organique par icône) pour les 8 destinations, Réglages et
  Recherche. Référence de dessin : icônes du prototype, redessinées en P2.
- SF Symbols seulement pour les actions standard (partager, révéler dans le Finder, fermer),
  teintés `accent` ou `ink`, jamais en couleur système.
- **Feuilles de risque** : faible = feuille pleine `accent`, moyen = feuille entamée `caution`,
  élevé = feuille fendue `danger`, toujours avec le libellé.

---

## 6. Logo

Une **graine** (disque `accent`) d’où sort une **tige** (`ink`) portant **deux feuilles** (`accent`),
la seconde plus haute. Lisible à 16 px : graine + tige + une feuille.

Animation « germination » (1,3 s, une fois, au lancement et dans « À propos ») :

1. la graine tombe de 6 pt et se pose (160 ms, `chute`) ;
2. elle se gonfle légèrement (scale 1 → 1,08 → 1, 180 ms, `pousse`) ;
3. la tige se dessine vers le haut (tracé, 420 ms, `sève`) ;
4. la première feuille se déplie (tracé + rotation 18° → 0°, 360 ms, `pousse`), la seconde 90 ms
   plus tard ;
5. repos, **immobile**. Au survol du logo : les feuilles frémissent une fois (±4°, 400 ms).

Pas de balancement en boucle (le prototype en a un : il est retiré).

---

## 7. Composants et états

Chaque composant existe **une fois** dans `DesignSystem` (P2) et définit tous ses états : repos,
survol, pressé, focus, désactivé, sélectionné (si pertinent), chargement (si pertinent).

| Composant | Repos | Survol | Pressé | Focus | Désactivé |
|---|---|---|---|---|---|
| Bouton principal | fond `accent`, texte `onAccent`, coin feuille | luminosité +8 %, feuille d’icône inclinée −6° | scale 0,97 (90 ms) | anneau `focus` 2 pt, forme feuille | opacité 40 %, pas de survol |
| Bouton secondaire | contour `strongSeparator`, texte `ink` | contour `accent` | scale 0,97 | anneau | opacité 40 % |
| Bouton destructif | fond `danger`, texte clair, libellé littéral | +8 % | scale 0,97 | anneau | opacité 40 % |
| Ligne de barre latérale | icône + libellé `secondaryInk` | fond `hover` (accent 8 %), icône −6° | — | anneau | — |
| Ligne sélectionnée | **marqueur feuille** `sel` (accent 16 %) glissant, texte `ink`, icône `accent` | — | — | anneau | — |
| Ligne de liste | fond transparent | **nervure** : filet `accent` qui se trace de gauche à droite sous la ligne (160 ms) | fond accent 12 % | anneau | `tertiaryInk` |
| Case / sélection | cercle contour `strongSeparator` | contour `accent` | — | anneau | — |
| Champ de recherche | `surface`, contour `strongSeparator`, loupe | contour `accent` | — | contour `accent` 2 pt | — |
| Parcelle (carte) | `surface`, coin feuille | — (non interactive) | — | — | — |
| Badge de risque | feuille + libellé, fond couleur 14 % | — | — | — | — |

États de vue (tous les écrans) : **initial** (graine + phrase d’invitation + action), **en cours**
(racines, § 8), **résultats**, **vide** (graine qui ne germe pas : « rien trouvé ici »), **partiel**
(bandeau `caution` : ce qui n’a pas pu être lu, et que l’absence n’est pas une preuve),
**refus d’accès** (bandeau `caution` + action « Choisir à nouveau »), **erreur** (feuille fanée
`danger`, message factuel, action de reprise).

---

## 8. Motion

### Principes

1. Chaque mouvement a un rôle : **orienter** (où je suis), **relier** (d’où vient ce qui apparaît),
   **confirmer** (mon action a eu lieu), **expliquer un état** (l’analyse progresse). Sinon, rien.
2. **La nature bouge avec une cause** : pousser (apparition), s’étendre (progression),
   tomber (retrait), faner (échec). Jamais de mouvement sans cause.
3. **Aucune animation continue au repos** (NFR-09). Les boucles n’existent que pendant une
   activité réelle (analyse) et s’arrêtent avec elle ; tout est suspendu quand la fenêtre est
   cachée.
4. **Interruptible** : une nouvelle action prend la main immédiatement, sans file d’attente.
5. **Reduce Motion** : chaque mouvement a un équivalent immédiat (tableau plus bas) ; le contenu
   ne dépend jamais d’une animation.
6. Seulement `transform`, `opacity`, tracés et masques : pas d’animation de mise en page.

### Jetons (`MotionToken`, mis à jour en P2)

| Jeton | Durée | Courbe | Usage |
|---|---|---|---|
| `press` | 90 ms | `sève` | pression d’un contrôle |
| `quick` | 160 ms | `sève` | survol, focus, nervure |
| `standard` | 280 ms | `sève` | ouverture de recherche, panneaux, bandeaux |
| `grow` | 480 ms | `sève` | changement de destination, révélation d’une vue |
| `bloom` | 900–1 300 ms | composée | logo, fin d’analyse (floraison) |
| `stagger` | 35 ms par élément, 240 ms max | — | éclosion des listes (8 premiers éléments) |

Courbes :

- **`sève`** `cubic-bezier(.2, .8, .2, 1)` — défaut, départ vif, arrivée douce.
- **`pousse`** ressort (réponse 0,45 s, amortissement 0,72) — **petits éléments seulement**
  (marqueur, feuilles, badges), jamais une vue entière.
- **`chute`** `cubic-bezier(.55, 0, .8, .4)` — ce qui tombe (feuille vers la Corbeille).
- **`retrait`** `cubic-bezier(.4, 0, 1, 1)` — ce qui disparaît ou se rétracte.

### Catalogue

| Moment | Mouvement | Rôle | Reduce Motion |
|---|---|---|---|
| Lancement | germination du logo (§ 6) | identité | logo final immédiat |
| Changement de destination | le **marqueur feuille** glisse vers la ligne cliquée (`pousse`, 380 ms) ; une **vrille** se trace du marqueur au bord du contenu (160 ms) ; la vue **pousse** depuis ce point (masque qui s’ouvre en ellipse, `grow`) ; ses blocs montent de 12 pt en `stagger`. L’ancienne vue se pose de 6 pt et s’efface (180 ms, `retrait`) | relier la ligne cliquée au contenu | fondu 120 ms |
| Recherche ⌘K | le champ **naît du bouton Rechercher** (morphing de forme, `standard`) ; une **racine** se trace sous le champ, sa longueur suit la saisie ; les résultats **éclosent** en `stagger` ; les lettres trouvées passent en `accent` ; aucun résultat : une pousse **fane** (−12°, 300 ms) | relier, confirmer | apparition immédiate |
| Analyse en cours | des **racines** descendent au rythme des vrais événements de progression (profondeur atteinte, fichiers lus) ; un **nœud** gonfle aux gros dossiers ; le compteur défile en chiffres Iowan | expliquer l’état | barre de progression immobile + compteur |
| Annulation d’analyse | les racines se **rétractent** (400 ms, `retrait`) | confirmer | disparition immédiate |
| Fin d’analyse | une **floraison** unique en haut du sol (`bloom`), puis les résultats éclosent | confirmer | message « Analyse terminée » |
| Résultats Explorer | les parcelles apparaissent par taille décroissante (`stagger`) | hiérarchie | immédiat |
| Déplacement vers la Corbeille | chaque ligne confirmée se **replie en feuille** qui **tombe** en courbe vers l’indicateur Corbeille (500 ms, `chute`) ; le compteur décroît ; échec : la feuille **reste**, la ligne prend un contour `danger` et un message | confirmer, honnêteté | ligne retirée + message |
| Doublons | changer l’exemplaire gardé : l’étiquette « gardé » saute d’une pousse à l’autre (`pousse`) | confirmer | immédiat |
| Performances | la courbe de **sève** se trace de gauche à droite à l’apparition ; un nouveau point pulse une fois | orienter | tracé immédiat |
| Historique | les entrées se **pressent** en place (scale 1,02 → 1, 200 ms) groupées en pages par jour | orienter | immédiat |
| Survol | nervure sous la ligne, icône inclinée −6° (`quick`) | affordance | couleur seule |
| Bandeau / erreur | glisse depuis le haut du contenu (`standard`) ; erreur : feuille fanée, **aucun rebond** | alerter | immédiat |
| État vide | la graine illustrée **germe une fois** à l’apparition de la vue | invitation | image finale |

---

## 9. Site

Même serre, mêmes jetons (export depuis `DesignSystem`), mêmes polices (pile système : Iowan Old
Style / Avenir Next, repli `ui-serif` / `system-ui`), **sans JavaScript** (CSP `script-src 'none'`).

- **Accueil** : logo qui germe (CSS, une fois), titre Iowan, une vraie capture de l’app dans un
  cadre « vitrine de serre ». Une **racine décorative** longe la page et **pousse avec le
  défilement** (`animation-timeline: scroll()` sous `@supports`, `aria-hidden`) ; les sections
  **poussent** à leur entrée dans l’écran (`animation-timeline: view()`). Sans support ou avec
  `prefers-reduced-motion` : tout est visible, immobile.
- **Navigation** : liens avec nervure au survol ; sur mobile, liste empilée (pas de bouton menu
  sans décision contraire, voir P4.5).
- **Pages** (Fonctionnalités, Confidentialité, Développeur, Assistance) : chaque section porte
  l’image de sa destination (§ 1), avec captures réelles et limites dites en clair.
- Aucun contenu conditionné à une animation ; aucun traqueur ; aucune police distante.

---

## 10. Interdits

- Une app Apple générique : `List`/`Form`/barre latérale système laissées telles quelles, bleu
  système, `.buttonStyle(.plain)` sans état.
- Crème, italiques d’accent, étiquettes numérotées « 01 / 02 », étiquettes en chasse fixe,
  boutons pilule, verre dépoli généralisé, dégradés décoratifs.
- Une animation en boucle au repos ; un rebond sur une erreur ; une animation qui bloque une
  action.
- Une métaphore qui adoucit une action destructive ou invente une mesure.
- Une couleur, une durée ou une courbe qui n’est pas un jeton.

---

## 11. Vérification (à mettre en place en P2)

- `DesignSystemTests` : contrastes du § 2 dans les deux ambiances ; durées du § 8.
- `check_architecture.py` : aucun `.buttonStyle(.plain)`, `Color(red:…)`, `Color.blue` ou hex hors
  `DesignSystem` ; aucune `repeatForever` hors composant d’analyse.
- `make capture-screens` : planche relue à chaque lot visible ; captures clair/sombre, FR/EN.
- Site : `check_site.py` (pas de script), contrat `prefers-reduced-motion` existant, et contrôle
  que les jetons CSS viennent de l’export.
