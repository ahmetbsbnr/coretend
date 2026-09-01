# Ahmet Design System

Version **1.1.0** — langage visuel canonique des produits d'Ahmet Basbunar
(CoreTend, StagePilot, portfolio).

Ce dossier formalise le système graphique déjà utilisé par le site produit
CoreTend (`Website/index.html`, styles et scripts inline). Il n'altère en rien
le site existant : le build public (`build.py`) n'inclut que l'allow-list
`PUBLIC_ASSET_PATTERNS` et ce dossier n'y figure pas.

## Structure

```
build.mjs            assemble dist/ depuis src/ (node build.mjs [--check])
src/                 sources authorem, une responsabilité par fichier
  tokens.css           01 — tokens clair/sombre
  reset.css            02 — reset + base + View Transitions de thème
  themes.css           contrat de thèmes (documentation, aucune règle)
  typography.css       03 — typographie
  layout.css           04 + 05 — layout + couches ambiantes
  motion.css           06 + 20 — reveal/animations + reduced motion
  components.css       07,08,09,11,12,13,15,17,18,19 — composants
  surfaces.css         10,14,16 — surfaces instrumentales
  responsive.css       21 — breakpoints
  core-bloom.js        primitives motion (ESM)
dist/                sortie compilée, consommée par les produits
  ahmet-design.css
  ahmet-design-motion.js
assets/
  fonts/               Archivo + IBM Plex Mono (woff2, OFL-1.1)
  marks/               Core Bloom (favicon, mark-light, mark-dark)
  icons/               (réservé — icônes inline dans les composants)
VERSION  CHANGELOG.md  PROVENANCE.md  README.md
```

## Consommation par les produits

Les produits **embarquent** `dist/` (vendoring). Aucun chargement distant,
aucun CDN, aucune dépendance runtime entre domaines. Voir
`scripts/sync-design-system.mjs` dans StagePilot pour un exemple de
synchronisation pinnée sur un commit.

## Règles d'évolution

- Peuvent changer par produit : contenu, icône produit, libellés, données,
  structure métier, accent sémantique.
- Ne doivent PAS changer sans décision du design system : typographie, grille,
  boutons, navigation, footer, rayons, animations fondamentales, surfaces,
  espacements principaux, règles de thème.

## Licences

Code et CSS : Apache-2.0. Polices : OFL-1.1 (Archivo, IBM Plex Mono).
Marque « Core Bloom » : marque personnelle d'Ahmet Basbunar, réutilisable dans
ses produits uniquement. Voir `PROVENANCE.md`.
