# P3 — Destinations, une par une

**Objectif :** chaque écran complet dans tous ses états, accepté par le mainteneur, avec ses lignes du registre passées à VÉRIFIÉ pour leur part native.
**Gate :** G3.1 → G3.9 — une recette par lot.
**Statut de la phase :** En cours depuis le 27-09-2026.
**Plan :** `Documentation/Project/Implementation-plan.md` § Programme 2.0.

## Lots

| Lot | Intitulé | Statut |
|---|---|---|
| 3.1 | Vue d’ensemble + premier lancement | Accepté 27-09-2026 (`6f66447a`) |
| 3.2 | Nettoyage (inclut un vrai passage par la Corbeille sur dossier jetable, fait par le mainteneur) | En cours |
| 3.3 | Explorer | À faire |
| 3.4 | Doublons et images proches | À faire |
| 3.5 | Applications | À faire |
| 3.6 | Intégrité | À faire |
| 3.7 | Performances | À faire |
| 3.8 | Historique | À faire |
| 3.9 | Réglages, ⌘K, barre de menus, langue, import ancien | À faire |
| 3.10 | Site : pages publiques en Serre, captures réelles de l’app, contenu pour une sortie publique (correction G2) | À faire |

## Journal

### 27-09-2026 — lot 3.1, Vue d’ensemble et premier lancement

- **Fait :** `6f66447a` — en-tête commun à toutes les destinations (titre + phrase Serre `<destination>.lede`,
  FR/EN), avertissement de sûreté en `SerreBanner(.note)`, blocs qui montent (`serreRise`). Vue
  d’ensemble : chiffre héros Iowan dans la langue de l’app (`ProductFormat.bytes`), bande de sol
  `SoilBand` construite seulement depuis des valeurs mesurées cohérentes (`SoilFractions`), légende
  occupé/libre/capacité, parcelle « herbier » pour la dernière activité, deux chemins vers Explorer
  et Historique (navigation passée par l’environnement), bandeau d’erreur avec Actualiser.
  Favoris et récents : état vide et bandeaux Serre, parcelles feuille. Premier lancement : trois
  étapes en feuilles.
- **Vérifié :** 4 tests AppShell (phrases FR/EN, tailles dans la langue de l’app, sol mesuré
  seulement, étapes FR/EN). `make qualify` PASS. Captures Vue d’ensemble, bienvenue, Performances
  FR/EN clair/sombre relues (« 58,05 Go » en français).
- **Lignes du registre visées :** FR-01, FR-03, shell.launch, shell.onboarding, shell.nav — elles ne
  passent `VÉRIFIÉ` qu’après la recette du mainteneur, en notant ce qui a été observé.
- **Non vérifié :** montée des blocs en mouvement réel ; clic sur les deux chemins (observé en code,
  pas en capture) ; VoiceOver.
- **Recette 3.1 (mainteneur) :** premier lancement (logo, étapes, Commencer), Vue d’ensemble (chiffre,
  bande de sol, chemins cliquables), clair/sombre, FR/EN. **Acceptée le 27-09-2026** (« validé ») ;
  registre : shell.onboarding `VÉRIFIÉ`, FR-01/FR-03/shell.launch/shell.nav preuves datées, `PARTIEL`.

## Point d’arrêt

- 3.1 accepté. Lot en cours : **3.2 — Nettoyage**.
- Lot **3.2 — Nettoyage** (chemin destructif) : règles en lignes Serre avec feuilles de
  risque, texte « .crash » corrigé (la règle retient aussi `.ips`), analyse avec **racines** qui
  suivent la vraie progression, revue en parcelles, confirmation, **feuille qui tombe vers la
  Corbeille** à chaque élément déplacé, échec visible (bandeau, la ligne reste). La recette inclut
  un vrai passage par la Corbeille sur un dossier jetable, fait par le mainteneur.

## Problèmes ouverts

_(aucun)_
