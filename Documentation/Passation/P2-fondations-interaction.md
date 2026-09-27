# P2 — Fondations Serre

**Objectif :** l’app et le site en direction Serre : jetons, logo, icônes, composants avec tous leurs états, coquille de l’app et motion du guide.
**Gate :** G2 — recette survol/clic/clavier sur chaque écran, clair et sombre.
**Statut de la phase :** En cours depuis le 27-09-2026.
**Plan :** `Documentation/Project/Implementation-plan.md` § Programme 2.0.

## Lots

| Lot | Intitulé | Statut |
|---|---|---|
| 2.1 | Jetons Serre (couleurs Nuit/Jour, typographie, motion, formes) + tests | Livré — recette en attente (`8635253`) |
| 2.2 | Logo Serre et germination ; jeu d’icônes ; feuilles de risque | À faire |
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

## Point d’arrêt

- 2.1 livré, recette du mainteneur en attente.
- Prochain lot **2.2 — logo et icônes** : logo Serre en `Shape`/`Path` SwiftUI dans
  `DesignSystem` (graine, tige, deux feuilles) avec la germination du guide § 6 (tracé via
  `trim`, jetons `bloom`/`sprout`, aucune boucle au repos, image finale sous Reduce Motion) ;
  icônes des 8 destinations + Réglages + Recherche en tracés 1,6 pt ; feuilles de risque
  (pleine / entamée / fendue). Les brancher dans la barre latérale et le Nettoyage sans changer
  la mise en page (celle-ci est le lot 2.4).

## Problèmes ouverts

_(aucun)_
