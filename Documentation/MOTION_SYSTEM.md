# MOTION SYSTEM

## Principes
1. Le mouvement encode un état réel (scan, exécution, succès) — jamais décoratif.
2. Continuité spatiale: un élément se transforme, il ne clignote pas.
3. Interruption propre: tout est annulable (Cancel) sans saut visuel.
4. Erreur = mouvement local discret; jamais de flash plein écran ni de secousse.
5. Repos = zéro moteur d'animation actif.

## Tokens
Durées et springs: `MCMotion` (voir DESIGN_TOKENS.md).
- quick 0.15 s: hover, pressed, focus.
- standard 0.3 s: changements d'état de composants.
- gentle 0.55 s / settle spring: transitions de phase (idle→scanning→review).

## Reduce Motion
Point unique: `MCMotion.animation(_:reduce:)` + `@Environment(\.accessibilityReduceMotion)`.
- MCScanStage: sweep radar, pings, pulse et motes arrêtés; un seul anneau calme
  est affiché à la place.
- Aucun PhaseAnimator/TimelineView actif sous Reduce Motion.

## Implémentations
- **MCScanStage** (`Sources/DesignSystem/ScanStage.swift`) — le motif de scan
  unique, câblé dans les 6 modules d'analyse (Cleanup, Duplicates, Space Lens,
  Privacy Cleaner, Similar Images, Cloud Cleanup). `TimelineView(.animation)`
  plafonné à 30 fps, actif *uniquement* pendant `isScanning`; anneau de
  progression qui se remplit vers `fraction` quand l'analyse est bornée; arcs
  Core Bloom au repos. Les motifs par module antérieurs (`MCFragmentView`
  Cleanup, `MCMeshView` Protection, `MCHeroCoreView` Smart Care +
  `OrbitalProgressView`) ont été retirés — superposés par `MCScanStage`.
- **Succès**: halo bref (spring settle) puis retour au calme.
- **Cartes/États**: Animation SwiftUI standard, snappy spring.

## Budget de performance (M1 8 Go)
- TimelineView plafonné à 30 fps, un seul simultané.
- Aucun timer global haute fréquence; métriques échantillonnées à 2 s.
- Fenêtre cachée/menu fermé: tasks annulées (onDisappear / task lifecycle).
- Pas de Metal. Canvas uniquement pour les graphes (buffer 60 points).

## À venir (post-1.0)
Un motif d'état dédié pour Protection (l'ancien `MCMeshView` a été retiré sans
être livré). `matchedGeometryEffect` (regroupement Cleanup, zoom Space Lens)
est déjà câblé dans les vues.
