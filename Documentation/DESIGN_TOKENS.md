# DESIGN TOKENS (Sources/DesignSystem)

## Couleurs — `MCColor` (Colors.swift)
Adaptatives light/dark via NSColor dynamic provider.
- Marque: coreMint, ionViolet, solarAmber, pulseCoral.
- Rôles: storage, protection, performance, destructive, attention, success.
- Graphiques: chartSeries[4], graphGrid.
- Surfaces: background, elevatedBackground, separator (couleurs système),
  primaryText/secondaryText (system primary/secondary).
Règle: couleurs système dès que l'adaptativité prime sur la marque.

## Espacements — `MCSpacing`
xxs 4 · xs 8 · sm 12 · md 16 · lg 24 · xl 32 · xxl 48 · page 24.

## Rayons — `MCRadius`
small 6 · card 12 · hero 20 · capsule 999.

## Dimensions — `MCSize`
sidebarMin 190 · sidebarIdeal 220 · windowMin 860×580 · heroCore 200 ·
metricRing 76 · chartHeight 140 · moduleIcon 30.

## Mouvement — `MCMotion`
quick 0.15 s · standard 0.3 s · gentle 0.55 s.
Springs: snappy (0.3/0.85), settle (0.55/0.9). `MCMotion.animation(_:reduce:)`
retourne nil sous Reduce Motion — point de passage unique.

## Opacités — `MCOpacity`
hover 0.08 · pressed 0.14 · disabled 0.4 · orbitTrack 0.14 · halo 0.22.

## Typographie — `MCFont` (Typography.swift)
displayMetric, heroTitle, pageTitle, sectionTitle, cardTitle, body,
secondaryBody, caption, metric, monospacedMetric, badge, button(=body), tableHeader.

## Compat
`MCTheme` = alias vers les nouveaux tokens (vues legacy). À résorber.

## Composants (Components.swift, CoreBloom.swift, HeroCore.swift)
MCCard, MCSectionHeader, MCStatusBadge, MCMetricCard, MCEmptyState, MCErrorState,
MCModuleIdentity, CoreBloomMark, MCArc, OrbitalProgressView, MCHeroCoreView.
Tests: Tests/DesignSystemTests.
