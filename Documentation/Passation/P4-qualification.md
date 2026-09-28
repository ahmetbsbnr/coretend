# P4 — Qualification transverse

**Objectif :** preuves d’accessibilité, compatibilité, performance, revue indépendante, site et import 1.x.
**Gate :** G4 — preuves consignées pour chaque NFR concerné.
**Statut de la phase :** En cours — G3 acceptée par le mainteneur le 28-09-2026.
**Plan :** `Documentation/Project/Implementation-plan.md` § Programme 2.0.

## Lots

| Lot | Intitulé | Statut |
|---|---|---|
| 4.1 | Accessibilité (mainteneur) : VoiceOver, Dynamic Type/zoom, contraste, Reduce Motion/Transparency | En cours — recette humaine préparée |
| 4.2 | Compatibilité : hôte macOS 14 et second Mac | À faire |
| 4.3 | Performance : corpus, mesures, budgets | À faire |
| 4.4 | Revue indépendante architecture/sûreté | À faire |
| 4.5 | Site : zoom, VoiceOver, en-têtes déployés, navigateurs ; bouton menu mobile sans JS ? | À faire |
| 4.6 | Import 1.x sur copie d’un vrai store 1.x | À faire |

## Journal

### 28-09-2026 — lot 4.1, préparation de qualification

- **Objectif :** compléter NFR-07 par observation humaine, sans changer les réglages de
  l’hôte ni toucher au HOME/store/Corbeille réels.
- **Fichiers :** `Documentation/Evidence/Accessibility.md`, `Documentation/Accessibility.md`,
  passation, Progress et registre ; aucun changement de code ou de direction visuelle.
- **Fait :** revue des tokens, couleurs, polices, sidebar et surfaces ; matrice de recette
  destination par destination préparée dans la preuve existante.
- **Limites :** VoiceOver parlé, agrandissement réel et préférences d’accessibilité système
  NON LANCÉS par l’agent. Focus Rechercher/Réglages à observer avant toute correction.
- **Recette :** voir `Documentation/Evidence/Accessibility.md`, section lot 4.1.
- **Vérifié :** `make qualify` PASS (code 0, `/tmp/coretend-qualify-p4-41.log`) ;
  `git diff --check` PASS.
- **Acceptation :** en attente. NFR-07 reste PARTIEL.

## Point d’arrêt

**Lot 4.1 ouvert : protocole prêt, observations du mainteneur requises.**

Reprendre avec les résultats de la matrice dans `Documentation/Evidence/Accessibility.md` ;
reproduire en fixture tout défaut signalé, corriger et qualifier avant acceptation de 4.1.
Ne pas commencer 4.2 avant cette acceptation. Prévoir ensuite un hôte macOS 14 et un second
Mac : aucun hôte supplémentaire n’est actuellement qualifié.

## Problèmes ouverts

- NFR-07 : VoiceOver, zoom/texte agrandi, contraste de tous les états et comportement réel
  Reduce Motion/Transparency non qualifiés.
- Escape n’atteignait pas l’app sur cet hôte lors des essais précédents (Reference) ;
  ne pas modifier les raccourcis ou préférences système pour contourner ce problème.
