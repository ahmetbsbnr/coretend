# P4 — Qualification transverse

**Objectif :** preuves d’accessibilité, compatibilité, performance, revue indépendante, site et import 1.x.
**Gate :** G4 — preuves consignées pour chaque NFR concerné.
**Statut de la phase :** En cours — G3 acceptée par le mainteneur le 28-09-2026.
**Plan :** `Documentation/Project/Implementation-plan.md` § Programme 2.0.

## Lots

| Lot | Intitulé | Statut |
|---|---|---|
| 4.1 | Accessibilité (mainteneur) : VoiceOver, Dynamic Type/zoom, contraste, Reduce Motion/Transparency | Accepté 28-09-2026 — détail des observations non fourni |
| 4.2 | Compatibilité : hôte macOS 14 et second Mac | Livré — recette limitée en attente ; macOS 14 et second Mac non testés |
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
- **Acceptation :** reçue le 28-09-2026 ; détail des observations non fourni. NFR-07 reste PARTIEL.

### 28-09-2026 — acceptation 4.1 et lot 4.2

- **Mainteneur :** « validé, continue chaque lot/phase/recette une par une » : lot 4.1
  accepté, poursuite limitée à 4.2. Aucun détail d’observation ajouté : NFR-07 reste PARTIEL.
- **Objectif 4.2 :** vérifier le paquet sur les hôtes disponibles et borner NFR-08.
- **Disponibilité mainteneur :** « non que cette mac air m1 sous os27. » Aucun hôte macOS 14
  ou second Mac disponible ; ces deux critères ne peuvent pas être exécutés actuellement.
- **Fait :** paquet local unsigned préparé depuis `cc23a81c`, structure et métadonnées
  contrôlées, lancement isolé sur arm64/macOS 27 PASS. Preuves dans `ReleaseEvidence.md`.
- **Vérifié :** `make qualify` PASS (code 0, `/tmp/coretend-p4-42-qualify.log`),
  `make traceability` et `git diff --check` PASS.
- **Recette :** accepter ou corriger le résultat limité et la réserve d’hôtes. Cela ne
  qualifie ni macOS 14 ni un second Mac ; NFR-08 reste PARTIEL, G4 non passée.

## Point d’arrêt

**Lot 4.2 : contrôles locaux réalisés ; résultat limité à présenter au mainteneur.**

Attendre l’acceptation de ce résultat limité avant 4.3. Les essais macOS 14 et second Mac
restent ouverts jusqu’à disponibilité d’hôtes ; ne pas présenter la matrice comme complète.

## Problèmes ouverts

- NFR-07 : VoiceOver, zoom/texte agrandi, contraste de tous les états et comportement réel
  Reduce Motion/Transparency non qualifiés.
- Escape n’atteignait pas l’app sur cet hôte lors des essais précédents (Reference) ;
  ne pas modifier les raccourcis ou préférences système pour contourner ce problème.

- NFR-08 : seul MacBook Air M1/macOS 27 disponible (confirmation mainteneur) ;
  macOS 14 et second Mac NON LANCÉS.
