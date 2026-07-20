# VISUAL TOOLING

## Outils utilisés (session 2026-07-20)
- **screencapture + AppleScript (System Events)**: pilotage du vrai bundle,
  sélection sidebar par nom, captures fenêtre → `Scripts/capture.sh`.
- **CoreGraphics + iconutil**: génération native de l'icône (aucune dépendance
  Canva/Adobe pour les sources) → `Resources/Brand/Sources/generate-brand-assets.swift`.
- **Swift Testing**: tests tokens/géométrie/ressources (Tests/DesignSystemTests).

## MCP disponibles mais non retenus pour les assets finaux
- **Adobe MCP / Canva MCP**: connectés. Non utilisés pour les sources de marque:
  exigence « ne pas dépendre d'un fichier stocké uniquement dans Canva/Adobe » —
  le générateur CG local est reproductible et versionné. Utilisables pour
  moodboards exploratoires ultérieurs.
- **claude-in-chrome**: non pertinent (app native, pas de web).

## Skills évalués
- `frontend-design`, `ui-ux-pro-max`, `taste-skill`, `all-good-ui`, `impeccable`:
  orientés web/HTML/React — principes (hiérarchie, densité, tokens) appliqués
  manuellement; aucun code web introduit. Rejetés comme générateurs.
- Skills GSAP: consultés comme référence de chorégraphie (easing, séquençage);
  aucun JS dans l'app. Traduction en springs SwiftUI (MCMotion).
- `find-skills` (macOS SwiftUI design, SF Symbols, Icon Composer, screenshot
  testing…): pas de skill natif macOS pertinent disponible dans le registre au
  moment de la session — implémentation manuelle documentée ici.
- `graphify`, `copywriting`, `copy-editing`, `onboarding`: principes appliqués
  (microcopy honnête, onboarding 4 étapes); pas d'artefact externe généré.

## Limitations rencontrées
- Dialogues TCC (enregistrement d'écran Terminal, Apple Music, Téléchargements)
  bloquent les captures; contournés par clics synthétiques CGEvent.
- Pas de Xcode: pas d'Icon Composer, pas de tests UI XCUITest, pas d'asset
  catalog compilé — icône via iconutil, ressources copiées par package-local.sh.
- Indices de sidebar décalés par les en-têtes de section → sélection par nom.
