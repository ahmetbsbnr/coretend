# P1 — Direction visuelle et guide UI

**Objectif :** une direction visuelle acceptée par le mainteneur sur l’app lancée, et un guide UI qui devient la seule référence d’apparence.
**Gate :** G1 — décision `Documentation/Decisions/0002-direction-visuelle.md` acceptée ; `Documentation/Design/UI-guide.md` rédigé.
**Statut de la phase :** En cours depuis le 27-09-2026.
**Plan :** `Documentation/Project/Implementation-plan.md` § Programme 2.0.

## Lots

| Lot | Intitulé | Statut |
|---|---|---|
| 1.1 | Kit de captures (8 destinations, Réglages, ⌘K, onboarding ; clair/sombre ; FR/EN ; planche HTML) | Livré — recette en attente (`3098745`) |
| 1.2 | Séance G1 avec le mainteneur (~45 min) | Fait — **Observatoire refusé** (27-09) |
| 1.2b | Exploration : trois directions artistiques animées (thème, motion, logo, recherche, navigation), prototype hors app | Accepté — **Serre choisie** (27-09) |
| 1.3 | Guide UI + décision 0002, sur la direction choisie en 1.2b | Livré — acceptation G1 en attente |

## Journal

### 27-09-2026 — lot 1.1, kit de captures

- **Fait :** `3098745` — `make capture-screens` (`Scripts/capture_screens.py` + `Scripts/capture_window_helper.swift`) :
  paquet local installé dans un HOME/store temporaires, une ouverture par écran × langue ×
  apparence via `CORETEND_TEST_*`, Réglages et ⌘K par raccourci clavier, capture de la seule
  fenêtre, planche `index.html`. Sortie : `Artifacts/Captures/<date>/` (ignoré par Git, local).
  `make capture-kit-check` (dans `qualify`) teste le plan de capture et la planche.
- **Vérifié :** 44/44 captures (`Artifacts/Captures/2026-09-27/`). Captures ouvertes et relues :
  Vue d’ensemble (FR clair, EN sombre), Réglages FR sombre, palette EN clair, onboarding FR
  clair, Nettoyage FR clair, Explorer EN sombre, Historique FR sombre — bon écran, langue et
  apparence à chaque fois. Tests du kit vus en échec sur une copie cassée. `make qualify` PASS.
- **Limites :** états initiaux seulement (aucun dossier choisi, aucune donnée) ; barre de
  menus non capturée ; Vue d’ensemble montre l’espace libre réel de l’hôte (mesure système,
  aucun fichier lu) — les captures restent locales.
- **Recette 1.1 (mainteneur) :** ouvrir la planche et dire si elle suffit pour la séance G1.

### 27-09-2026 — séance G1 (1.2) : retour du mainteneur

Mots du mainteneur (verbatim) :

> je n'aime pas le visuel de l'app en effet tout les design proposé depuis le debut de coretend
> ne me contente pas, je ne vois pas de design qui sort de l'ordinaire, la gestion de l'app, les
> modules d'app qui sont tres generique d'apple, je veux juste un logiciel moche, je veux que tu
> ajoute du motion, une vrai d/a basé sur un theme basé en générale et que tout se suit, des
> annimation de logo , de recherche, du motion quand on chage de menu, je veux un truc complet

Lecture de l’agent (à confirmer par le mainteneur) : « un logiciel moche » est lu comme « pas un
logiciel moche / pas générique ».

**Décision G1 :** direction Observatoire **refusée**, comme toutes les directions précédentes
(MC*, Instrument, Porcelain). Le brief pour la suite :

1. **Une vraie direction artistique**, construite sur **un thème** qui gouverne tout : couleurs,
   formes, typographie, vocabulaire, icônes, motion. Tout doit se suivre.
2. **Sortir de l’ordinaire** : ne plus ressembler à une app Apple générique (List/Form/sidebar
   système telles quelles).
3. **Motion partout où il a un sens** : animation du logo, animation de la recherche (⌘K),
   transition au changement de menu ; « un truc complet ».
4. Contraintes inchangées : Reduce Motion respecté (le contenu ne dépend jamais d’une
   animation), sûreté et textes honnêtes, pas de dépendance runtime (polices et assets
   embarqués avec licence documentée).

Conséquence (Pilotage § 3) : P1 est refaite. Aucune ligne de SwiftUI tant qu’une direction n’est
pas choisie sur prototype animé (1.2b), puis écrite en guide (1.3) et acceptée (G1).

### 27-09-2026 — lot 1.2b, trois directions animées

- **Fait :** `15056a4` — `Documentation/Design/Directions/index.html`, prototype autonome (HTML/CSS/SVG,
  sans dépendance, polices livrées avec macOS) : **A · Serre** (jardin, croissance, Iowan Old Style,
  vert chlorophylle), **B · Sonar** (sondage, échos, DIN Condensed, ambre), **C · Atelier**
  (horlogerie, loupe, Didot, laiton et rubis). Chacune : logo animé, transition au changement de
  menu, recherche ⌘K animée, analyse de démonstration animée, survol, vues Vue d’ensemble,
  Nettoyage et états vides. Paramètres d’URL `dir`, `view`, `search`, `scan`.
- **Vérifié :** Chrome sans interface, captures ouvertes et relues : les trois vues d’ensemble,
  recherche Sonar ouverte, Nettoyage Serre, analyses Serre/Sonar/Atelier. Corrigés en cours de
  route : marqueur de sélection décalé d’une ligne, cadran Atelier qui dépassait. Mouvement
  réduit respecté (`prefers-reduced-motion`) et simulable par une case à cocher.
- **Non vérifié :** transitions de menu en interaction réelle (captures statiques seulement).
- **Incident de passation :** la mise à jour du lot 1.1 avait supprimé la section « Point
  d’arrêt » de ce fichier sans erreur ; rétablie ici. Les scripts de mise à jour doivent
  vérifier chaque remplacement.

### 27-09-2026 — choix du mainteneur et lot 1.3

- **Mainteneur :** « j'obte pour la premiere, j'adore cette theme d'analyse en profondeur dans les
  racines etc ce systeme de plantes, applique cette vision de serre puis aussi dan sle site
  evidement, en améliorant les motions qui sont deja a un niveau supérieur. »
- **Fait :** décision `Documentation/Decisions/0002-direction-serre.md` ; guide
  `Documentation/Design/UI-guide.md` (thème et règle d’honnêteté, couleurs Nuit/Jour, typographie,
  coin feuille, icônes, logo et germination, composants et états, système de motion avec
  jetons/courbes/catalogue et équivalents Reduce Motion, site, interdits, vérification).
  Programme : P2 devient « Fondations Serre » (2.1–2.5, site inclus), P3 gagne 3.10 (pages du site).
- **Vérifié :** contrastes WCAG calculés pour chaque jeton texte sur `canvas`, `surface`,
  `raisedSurface`, `sidebar` dans les deux ambiances : tous ≥ 4,5:1 ; contours de contrôle
  (`strongSeparator`) ≥ 3:1. Deux valeurs ajustées pour y arriver (`tertiaryInk` Jour,
  `strongSeparator` Jour).
- **Écart assumé avec le prototype :** le balancement en boucle du logo et des états vides est
  retiré (NFR-09 : aucune animation continue au repos).

## Ordre du jour proposé pour la séance G1 (constats de l’agent, à confirmer)

Constats relevés en relisant les captures ; ce ne sont pas des décisions.

1. **Deux gris différents en sombre :** sidebar et barre de titre gris système, contenu bleu
   ardoise. Harmoniser ou assumer ?
2. **Accent :** icônes de la palette ⌘K et du bouclier d’onboarding en bleu système, alors que
   la règle est un seul accent teal ; sélection de la sidebar = accent système macOS.
3. **Historique :** bouton « Exporter… » étiré sur presque toute la largeur ; champ de
   recherche et menus de largeurs sans rapport ; « 0 événement(s) » au lieu d’un vrai pluriel.
4. **Explorer (état initial) :** un bouton seul sur un grand vide ; rien n’explique ce qu’on
   obtiendra.
5. **Vue d’ensemble :** contenu coupé en bas à la taille par défaut (« Favoris et récents ») ;
   nombres FR au format anglais (« 60.62 GB » au lieu de « 60,62 Go »).
6. **Nettoyage :** le texte « Uniquement les rapports .crash » est faux, la règle retient aussi
   `.ips` (défaut de contenu, pas de style).
7. **Ordre :** la palette ⌘K liste Historique en 2ᵉ, la sidebar en dernier.
8. **Survol :** aucun retour au survol nulle part (connu, traité en P2 selon le guide).

Pour chaque écran, le mainteneur dit : garder / changer / refaire, et pourquoi.

## Point d’arrêt

- **Attente du mainteneur (gate G1) :** relire `Documentation/Design/UI-guide.md` et dire
  « accepté » ou ce qu’il faut changer. Rien n’est codé en SwiftUI avant.
- Après G1 : clore P1, ouvrir P2 au lot 2.1 (jetons Serre) dans `P2-fondations-interaction.md`.

## Problèmes ouverts

_(aucun)_
