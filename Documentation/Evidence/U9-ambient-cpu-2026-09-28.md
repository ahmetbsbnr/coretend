# U9 — coût processeur de la serre vivante (28-09-2026)

Hôte : MacBook Air M1, macOS 27. App fixture (Release, `make package-local`), Vue d'ensemble
avec `GreenhouseScene`, sombre. Mesure `ps -o %cpu` chaque seconde.

| Situation | Cadence | %CPU observé |
|---|---|---|
| « Réduire les animations » activé (réglage du mainteneur) | — | 0,0–0,1 (scène immobile, conforme à 0003) |
| Fenêtre active, ambiance vivante | 15 i/s | 7,7–9,3 |
| Fenêtre active, ambiance vivante | **10 i/s (retenu)** | 5,3–9,8 (médiane ≈ 6,1) |
| Fenêtre en arrière-plan (Xcode devant) | 10 i/s | 0,0 (six relevés) |

Deux captures de la fenêtre à 1 s d'écart diffèrent fenêtre active (balancement observé),
identiques quand une condition tombe. Limite : un seul hôte ; coût à réduire (dessin de la
scène entière à chaque image) — piste : couche statique + seules les feuilles animées.

## Révision — Core Animation (28-09-2026, 17:55)

- Balancement SwiftUI par image : 3 éléments ≈ 11 % ; `repeatForever` SwiftUI ≈ 19 % (recalculé
  par SwiftUI à chaque image). Abandonnés.
- **Retenu :** `LayerSway` (contenu hébergé dans un calque, `CABasicAnimation` sur
  `transform.rotation.z`) et `PollenField` (`CAEmitterLayer`) : animés par le serveur de rendu.
  Scène (13 pousses, pollen), plante de destination, logo et 8 icônes de barre latérale animés :
  **0,0–0,7 % CPU** fenêtre active (six relevés), images différentes à 1 s d'écart.
