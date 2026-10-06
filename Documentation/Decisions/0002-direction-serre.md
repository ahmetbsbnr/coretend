# Décision 0002 — Direction artistique « Serre »

**Date :** 27-09-2026. **Décideur :** le mainteneur. **Statut :** acceptée, guide compris (gate G1 passée le 27-09-2026).

## Contexte

Toutes les directions visuelles précédentes (MC*, Instrument, Porcelain, Observatoire) ont été
refusées : génériques, trop proches d’une app Apple standard, sans thème ni motion. Le
27-09-2026, trois directions animées ont été présentées (`Documentation/Design/Directions/`) :
A · Serre, B · Sonar, C · Atelier.

## Décision

Le mainteneur choisit **A · Serre**, pour l’app **et** pour le site :

> j'obte pour la premiere, j'adore cette theme d'analyse en profondeur dans les racines etc ce
> systeme de plantes, applique cette vision de serre puis aussi dan sle site evidement, en
> améliorant les motions qui sont deja a un niveau supérieur.

CoreTend entretient un Mac comme on entretient une serre : on observe, on analyse jusqu’aux
racines, on taille ce qui doit l’être, rien n’est arraché sans accord. Le motion, déjà jugé au
bon niveau dans le prototype, doit être porté plus loin.

## Conséquences

- Règle du mainteneur (02-10-2026) : ne jamais placer de libellé eyebrow/overline au-dessus
  d’un titre de page ou de section, dans l’app ni sur le site. Les titres commencent
  directement l’en-tête ; un sous-titre reste possible.


- `Documentation/Design/UI-guide.md` devient la seule référence d’apparence et de motion pour
  l’app et le site. Toute évolution passe par une nouvelle décision.
- Les jetons de `Sources/DesignSystem/` prennent les valeurs Serre ; le site les reçoit par
  `Scripts/export_design_tokens.py`, sans valeur saisie à la main.
- Les directions B et C, et les valeurs Observatoire/Porcelain, ne sont plus des références.
- Contraintes inchangées : sûreté et textes honnêtes (la métaphore n’adoucit jamais une action
  irréversible), Reduce Motion, aucune animation continue au repos (NFR-09), pas de
  dépendance runtime, site sans JavaScript.
