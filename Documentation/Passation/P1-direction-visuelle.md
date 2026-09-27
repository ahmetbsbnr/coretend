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
| 1.2b | Exploration : trois directions artistiques animées (thème, motion, logo, recherche, navigation), prototype hors app | En cours |
| 1.3 | Guide UI + décision 0002, sur la direction choisie en 1.2b | À faire |

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

## Problèmes ouverts

_(aucun)_
