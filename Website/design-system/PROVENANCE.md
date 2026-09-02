# Provenance — Ahmet Design System 1.1.0

## Source

- Dépôt : [ahmetbsbnr/coretend](https://github.com/ahmetbsbnr/coretend)
  (licence Apache-2.0), site produit `Website/`.
- Commit source : `63cd103` (branche `main`, 2026-08-04).
- Fichiers sources : `Website/index.html` (CSS inline lignes 16–620, JS inline
  lignes 1013–1807), `Website/assets/tokens/design-tokens.css`,
  `Website/assets/shell/boot.js`.

## Licence

Ce package est une œuvre dérivée du site CoreTend, distribué sous
**Apache-2.0** conformément à la licence du dépôt source
(https://github.com/ahmetbsbnr/coretend/blob/main/LICENSE).

Attribution : © Contributeurs CoreTend / Ahmet Basbunar.

## Modifications apportées (article 4 Apache-2.0)

1. Extraction du CSS inline en feuilles autonomes ; keyframes préfixées `ads-`.
2. Extraction du JS inline en module ESM ; API renommées
   (`CoreTendTheme` → `AhmetTheme`, `CoreTendLogoState` → `AhmetLogoState`),
   clé localStorage `coretend-theme` → `ahmet-theme`.
3. Retrait des contenus et comportements spécifiques au produit CoreTend
   (démo de scan, vues Storage/Space Lens/Duplicates/Applications/Integrity/
   Activity, trouvailles, terminal d'audit, scène Gatekeeper, ticker de
   promesses, i18n EN/FR embarquée).
4. Ajouts pour les besoins applicatifs : `.btn-danger`, `.tag.crit`,
   `.empty-state`, états de navigation actifs (`.bar-link[aria-current]`,
   `.app-side a`), fallback `prefers-color-scheme` sans script de boot.
5. Aucune modification des valeurs de tokens, de la typographie, des rayons,
   des easings ni des durées fondamentales.

## Polices

- **Archivo** — Omnibus-Type, SIL Open Font License 1.1.
  Fichiers : `archivo-latin.woff2`, `archivo-latin-ext.woff2` (copiés depuis
  `Website/assets/fonts/`).
- **IBM Plex Mono** — IBM, SIL Open Font License 1.1.
  Fichiers : `plexmono-{400,500,600}-{latin,latin-ext}.woff2`.

## Marque

Le logo « Core Bloom » (trois arcs + cœur) est la marque personnelle d'Ahmet
Basbunar. Sa réutilisation est autorisée dans les produits appartenant à
Ahmet Basbunar (CoreTend, StagePilot, portfolio). Tout autre usage requiert
une autorisation explicite.

## Données personnelles

Aucune donnée personnelle n'est incluse dans ce package. Les chemins, noms et
valeurs présents dans les sources CoreTend auditées étaient des données
d'exemple (`/Users/demo`, « DemoApp »…) et n'ont pas été repris ici.
