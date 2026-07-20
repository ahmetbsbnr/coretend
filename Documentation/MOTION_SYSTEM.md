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
- OrbitalProgressView: arcs indéterminés statiques (pas de rotation).
- HeroCore: changements d'état instantanés, halo statique.
- Aucun PhaseAnimator/TimelineView actif sous Reduce Motion.

## Implémentations
- **Hero Smart Care**: OrbitalProgressView — TimelineView(.animation 30 fps max)
  actif *uniquement* pendant scanning/running. Arcs déterminés = trim animé par
  vraie progression; indéterminés = arc court orbitant (vitesses ±28–55°/s).
- **Succès**: halo bref (opacité 0.22, spring settle) puis retour au calme.
- **Cartes/États**: Animation SwiftUI standard, snappy spring.

## Budget de performance (M1 8 Go)
- TimelineView plafonné à 30 fps, un seul simultané.
- Aucun timer global haute fréquence; métriques échantillonnées à 2 s.
- Fenêtre cachée/menu fermé: tasks annulées (onDisappear / task lifecycle).
- Pas de Metal. Canvas uniquement pour les graphes (buffer 60 points).

## À venir (hors 0.4.0)
matchedGeometryEffect Cleanup (regroupement de résultats), maille Protection,
construction progressive Space Lens.
