# Changelog — Ahmet Design System

Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/) et le
versionnement sémantique.

## [1.0.0] - 2026-08-05

### Ajouté

- Extraction initiale depuis le site produit CoreTend
  (ahmetbsbnr/coretend @ 63cd103, `Website/index.html`).
- Tokens complets clair/sombre (paper/ink/line/cobalt/safe/caution/critical/
  panel/shadow/rayons/wrap/gutter/easings/motion).
- Reprise : reset, base, typographie (Archivo + IBM Plex Mono), layout `.wrap`,
  couches ambiantes (field/grain/spot/progress), boutons (pill + reflet),
  chips/pills/tags, header `.bar` sticky blur, hero, fenêtre produit `.app`,
  ticker, steps/timeline, modules `.mod`, slabs/findings/tabs, gauges, facts,
  terminal `.term`, FAQ animée, closing, footer `.foot`, toast, skip, rail,
  empty-state.
- Motion : reveals 850 ms, scramble, compteurs, sparklines, orbites du logo
  (WAAPI 20/15/10 s), magnétique/tilt, View Transitions pour le thème.
- `prefers-reduced-motion` exhaustif.
- Breakpoints : 1180/1000/900/860/640/560/390.
- Module ESM `ahmet-design-motion.js` : initTheme, initField, initLogos,
  initReveals, initScrollSystems, initPointer, splitHeadline, initTicker,
  initFaq, initAnchors, showToast.

### Modifié par rapport à la source CoreTend

- Keyframes préfixées `ads-` (namespace du design system).
- Ajout de `.btn-danger`, `.tag.crit`, `.empty-state`, état actif `.bar-link`
  et `.app-side a` (besoins applicatifs StagePilot).
- Thème : clé localStorage `ahmet-theme` (au lieu de `coretend-theme`) et API
  `window.AhmetTheme` (+ `cycle()`), `window.AhmetLogoState`.
- Fallback `prefers-color-scheme` conservé pour les environnements sans script
  de boot.
- Retrait des comportements spécifiques au produit CoreTend (démo de scan,
  treemap scripté, gatekeeper, terminal de vérification) : ils restent dans le
  site CoreTend et ne font pas partie du système partagé.
