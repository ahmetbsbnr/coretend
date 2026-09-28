# 0003 — La serre vivante : mouvement ambiant encadré

- **Date :** 28-09-2026
- **Statut :** Acceptée par le mainteneur (« Vivante, encadrée »).
- **Amende :** décision 0002 et `Documentation/Design/UI-guide.md` § 8, principe 3
  (« aucune animation continue au repos »).

## Contexte

Après le test sur MacBook Air M5, le mainteneur demande « meilleures motions, meilleures
animations, l'app est une serre vivante en elle-même, va sur ce thème en entier ».

## Décision

Un mouvement ambiant (balancement lent des feuilles, lumière qui suit l'heure) est autorisé,
seulement quand **toutes** ces conditions sont vraies :

1. la fenêtre est active et au premier plan (pas cachée, pas en arrière-plan) ;
2. le Mac n'est pas en mode économie d'énergie (`ProcessInfo.isLowPowerModeEnabled`) ;
3. « Réduire les animations » est désactivé ;
4. le réglage « Serre vivante » (Réglages, activé par défaut) est activé.

Sinon tout est immobile, dans son état final. Cadence basse (≤ 15 images/s, `TimelineView`
en pause quand une condition tombe). Le mouvement ambiant ne porte jamais d'information :
toute information reste visible sans lui. Les mouvements causés par une action (analyse,
déplacement, navigation) gardent leurs règles.

## Conséquences

- Le composant de gate vit dans `DesignSystem` (`AmbientLife`) ; aucune boucle hors de lui.
- NFR-09 : mesure CPU au repos avant/après, fenêtre active, consignée dans les preuves.
