# BRAND SYSTEM — CoreTend

## Mission visuelle
Un soin système crédible, calme et local. L'identité doit dire: précision
d'instrument, pas de peur, rien de caché.

## Personnalité
Posée, factuelle, bienveillante. Jamais marketing, jamais infantilisante.

## Symbole — Core Bloom
- Noyau central plein (fraction 0.24 du côté).
- Trois arcs orbitaux asymétriques: (start −30°, span 150°, r 0.94) stockage;
  (105°, 115°, 0.72) protection; (250°, 80°, 0.50) performances.
- Traits arrondis (lineCap round), largeur 7 % du côté (12 % sous 64 px).
- Silhouette reconnaissable à 16 px (validée dans AppIcon.iconset/icon_16x16.png).

### Construction & variantes
- Source unique: `Resources/Brand/Sources/generate-brand-assets.swift`
  (CoreGraphics pur, régénérable: `swift <script>` puis `iconutil`).
- Couleur: arcs mint/violet/ambre + noyau mint dégradé.
- Monochrome: `CoreBloomMark(tint: nil)` — trait primaire uni.
- Barre des menus: template noir 18/36 px, `isTemplate = true` (s'adapte clair/sombre).
- Petites tailles: traits épaissis, aucun détail supplémentaire.

### Zones de protection / tailles minimales
- Zone libre = ½ diamètre du noyau tout autour.
- Taille minimale: 16 px (menu bar 18 px). Pas de texte intégré au symbole.

## Palette
| Nom | Light | Dark | Rôle |
|---|---|---|---|
| Core Mint | 0.043 0.51 0.46 | 0.30 0.83 0.75 | accent, stockage |
| Ion Violet | 0.36 0.33 0.80 | 0.60 0.57 0.96 | protection |
| Solar Amber | 0.72 0.46 0.07 | 0.95 0.68 0.26 | performances, attention |
| Pulse Coral | 0.75 0.25 0.23 | 0.95 0.47 0.43 | destructif |
| Graphite/Mist | système (windowBackground / controlBackground) | surfaces |

## Typographie
San Francisco uniquement. Styles sémantiques dans `MCFont` (Typography.swift).
Chiffres: design rounded + monospacedDigit pour les métriques.

## Iconographie
SF Symbols pour tout le standard. Identités de module centralisées dans
`MCModuleIdentity`. Custom symbols réservés à Core Bloom et aux états produit.

## Illustration
Aucune illustration raster. Formes SwiftUI/Canvas/CG uniquement.

## Animation
Voir MOTION_SYSTEM.md. Le symbole s'anime uniquement pendant une activité réelle.

## Ton rédactionnel
Factuel, rassurant, honnête sur les limites (ClamAV, FDA, cloud). Interdits:
« parfait », « magie », « turbo », « 100 % protégé », « votre Mac est malade ».

## Usages interdits
- Pas de rotation du logo au repos.
- Pas de recoloration hors palette.
- Pas d'étirement, pas d'ombre portée dure, pas de contour ajouté.
- Pas de lettre M/C stylisée en guise de logo.
