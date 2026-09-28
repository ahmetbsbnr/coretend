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
