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

### 27-09-2026 — lot 3.2, Nettoyage (en cours, arrêt demandé par le mainteneur)

- **Fait :** `a76d15b7` — règles en lignes Serre + badges de risque, texte « .crash et .ips » corrigé ;
  `ScanRoots` (racines au rythme des vrais événements, compteur Iowan, floraison en fin, retrait à
  l’annulation) ; résultats triés par taille connue ; bandeaux refus/partiel/erreur/vide ;
  `FileActionService.execute(_:onItem:)` rapporte chaque élément dès son issue finale ; feuille qui
  tombe vers l’indicateur Corbeille, ligne restée en place avec contour `danger` et raison
  (`ActionItemResult.failureKey`) ; défilement sur toute la largeur de la fenêtre.
- **Vérifié :** tests Domain/DesignSystem/AppShell ajoutés et passés ; `make qualify` PASS avant les
  deux derniers ajustements (zone de défilement, hauteur de liste) ; app fixture observée : règles,
  mauvais dossier (bandeau + Choisir à nouveau), analyse, résultats, sélection, dialogue de revue,
  annulation journalisée.
- **Non vérifié :** `make qualify` après les deux derniers ajustements (interrompu à la demande du
  mainteneur) ; déplacement réel vers la Corbeille et chute de feuille (jamais confirmés par
  l’agent) ; position du bandeau d’action sous la barre Corbeille ; VoiceOver.

## Point d’arrêt

- Lot **3.2 — Nettoyage** en cours, code commité (`a76d15b7`). Reprendre par : `make qualify` ; vérifier
  en app fixture le bandeau d’action sous la barre Corbeille (sélection → Examiner → Annuler) ;
  puis livrer pour recette. La recette inclut le vrai passage par la Corbeille sur un dossier
  jetable, fait par le mainteneur (vérifier la chute de feuille et les lignes restées en place).
- Fixture pratique : dossier `…/home/Library/Logs/DiagnosticReports` rempli de faux `.ips`/`.crash`
  (la règle compare la fin du chemin).
- Non fait dans 3.2 : « nœud qui gonfle aux gros dossiers » (ScanCore ne remonte pas de taille par
  dossier pendant l’analyse).

## Problèmes ouverts

_(aucun)_
