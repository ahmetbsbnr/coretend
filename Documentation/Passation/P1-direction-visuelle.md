# P1 — Direction visuelle et guide UI

**Objectif :** une direction visuelle acceptée par le mainteneur sur l’app lancée, et un guide UI qui devient la seule référence d’apparence.
**Gate :** G1 — décision `Documentation/Decisions/0002-direction-visuelle.md` acceptée ; `Documentation/Design/UI-guide.md` rédigé.
**Statut de la phase :** En cours depuis le 27-09-2026.
**Plan :** `Documentation/Project/Implementation-plan.md` § Programme 2.0.

## Lots

| Lot | Intitulé | Statut |
|---|---|---|
| 1.1 | Kit de captures (8 destinations, Réglages, ⌘K, onboarding ; clair/sombre ; FR/EN ; planche HTML) | Livré — recette en attente (`3098745`) |
| 1.2 | Séance G1 avec le mainteneur (~45 min) | À faire — prochaine étape |
| 1.3 | Guide UI + décision 0002 | À faire |

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
