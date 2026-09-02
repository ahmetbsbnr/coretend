# DESIGN SYSTEM
Identité « Porcelaine » : accent unique teal océanique (`#0B6E6C` clair /
`#5FD3C6` sombre) sur base porcelaine (`#F6F4EF`) / ardoise (`#1B1E22`).
Amber = caution fonctionnelle, coral = erreur/destructif, graphite =
secondaire (pas une seconde teinte). Storage/protection/performance se
distinguent par icône + libellé, pas par couleur. Surfaces solides
`MCColor.elevatedBackground`, cartes MCCard rayon 8, SF Symbols, mode
clair/sombre automatique. Tokens dans `Sources/DesignSystem` ; contraste
vérifié par `PaletteContrastTests`.
États standard par module: idle / scanning / review-results / executing /
done / empty / failed, tous représentés dans les vues.
