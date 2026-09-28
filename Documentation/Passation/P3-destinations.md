# P3 — Destinations, une par une

**Objectif :** chaque écran complet dans tous ses états, accepté par le mainteneur, avec ses lignes du registre passées à VÉRIFIÉ pour leur part native.
**Gate :** G3.1 → G3.9 — une recette par lot jusqu’à 3.6 ; depuis le 28-09, décision du mainteneur : lots livrés à la suite, recette groupée avant G3.
**Statut de la phase :** En cours depuis le 27-09-2026.
**Plan :** `Documentation/Project/Implementation-plan.md` § Programme 2.0.

## Lots

| Lot | Intitulé | Statut |
|---|---|---|
| 3.1 | Vue d’ensemble + premier lancement | Accepté 27-09-2026 (`6f66447a`) |
| 3.2 | Nettoyage (inclut un vrai passage par la Corbeille sur dossier jetable, fait par le mainteneur) | Livré — le mainteneur a dit « continue » sans recette explicite ; lignes du registre inchangées (`4fd7fd62`) |
| 3.3 | Explorer | Livré — le mainteneur a dit « continue » sans recette explicite (`0e9fc484`) |
| 3.4 | Doublons et images proches | Accepté 28-09-2026 (`7f4b9fd7`) |
| 3.5 | Applications | Accepté 28-09-2026 (`bb66dc75`, `2663f55d`) |
| 3.6 | Intégrité | Accepté 28-09-2026 (`5430106d`) |
| 3.7 | Performances | Livré, vérifié par l’agent (`52d8fd16`) |
| 3.8 | Historique | Livré, vérifié par l’agent (`05f7aa51`) |
| 3.9 | Réglages, ⌘K, barre de menus, langue, import ancien | Livré — recette groupée en attente (limite menu natif) |
| 3.10 | Site : pages publiques en Serre, captures réelles de l’app, contenu pour une sortie publique (correction G2) | Livré — recette groupée en attente |

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

### 28-09-2026 — lot 3.2, fin de livraison

- **Fait :** `a874f4f4` — accords au singulier (« 1 élément sélectionné », « Examiner 1 élément »,
  « 1 déplacé vers la Corbeille »), `ProductFormat.items` / `frenchPlural` testés.
- **Vérifié :** `make qualify` PASS (après les ajustements de défilement et de hauteur de liste, et
  après ce correctif). App fixture : bandeau d’action affiché sous la barre Corbeille après
  Examiner → Annuler ; annulation journalisée.
- **Non vérifié :** déplacement réel vers la Corbeille, chute de feuille, lignes restées en place
  (à faire par le mainteneur) ; VoiceOver.
- **Recette 3.2 (mainteneur) :** sur un dossier jetable `…/Library/Logs/DiagnosticReports` rempli de
  faux `.ips` : choisir la règle, se tromper de dossier (bandeau + Choisir à nouveau), analyser
  (racines, floraison), sélectionner 2–3 fichiers, Examiner, **Déplacer vers la Corbeille** :
  chaque feuille tombe vers la Corbeille, le compteur monte, les fichiers sont dans la Corbeille
  macOS. Optionnel : supprimer un fichier sélectionné dans le Finder avant de confirmer → sa ligne
  reste avec contour rouge et la raison.

### 28-09-2026 — lot 3.2, retour de recette « pas vu d’animation »

- **Constat :** le mainteneur a déplacé 2 fichiers (journal : `movedToTrash`) sans voir de feuille.
  Diagnostic (build temporaire, feuille ralentie, déclenchée par la sélection, aucun fichier
  déplacé) : la feuille existait mais partait du rond de sélection, même vert, bougeait à peine
  pendant la première moitié de la courbe `chute` puis s’effaçait en traversant. Les racines se
  dessinaient sous le bord de la fenêtre et une analyse de 14–17 fichiers finit avant qu’elles
  poussent. Le mainteneur a vu la feuille dans le build de diagnostic : « c’est bon ».
- **Incident :** pendant le diagnostic, la fenêtre de confirmation de l’app de démonstration a été
  validée sans clic de l’agent (le clic « Annuler » était bloqué, le Terminal était passé devant) :
  2 faux fichiers fixture (`Safari-2026-09-23/24-101500.ips`, octets aléatoires) sont allés dans la
  Corbeille du mainteneur. Cause : bouton destructif par défaut (Retour). Corrigé dans `85d93f24`.
- **Fait :** `85d93f24` — Retour annule dans toutes les confirmations destructives (Corbeille ×4,
  effacements d’historique ×2) ; `check_architecture.py` refuse une confirmation destructive sans
  défaut non destructif (testé). `4fd7fd62` — feuille qui s’ouvre depuis le nom du fichier, reste
  opaque en tombant, la Corbeille compte et tressaille à l’arrivée ; ligne qui se replie ; défilement
  vers les racines au lancement ; racines qui atteignent leur profondeur avant la floraison ; tri
  sans animation.
- **Vérifié :** `make qualify` PASS ; app fixture : défilement vers les racines, croissance puis
  floraison.
- **Non vérifié :** chute de feuille à sa vitesse finale (observée seulement ralentie).

### 28-09-2026 — lot 3.3, Explorer

- **3.2 :** le mainteneur a vu la feuille dans le build de diagnostic (« c’est bon ») puis a dit
  « continue » sans recette explicite du parcours complet ; FR-05, FR-06, cleanup.*, safety.* restent
  `PARTIEL` (pas de passage à `VÉRIFIÉ` sans recette).
- **Fait :** `c4e1d97b` — `SerreActionKit` : `PageNotice`/`PageNoticeBanner`, `LeafFlight`
  (feuille vers la Corbeille, comptage à l’arrivée), `TrashIndicator`, `executeShowingEachItem` ;
  Nettoyage passe dessus. `0e9fc484` — Explorer : état initial graine + « Choisir un dossier »,
  parcelle mesurée, racines au lancement (liste masquée jusqu’à la fin de l’analyse), filtres en
  parcelle, carte des parcelles proportionnelles (plus grandes d’abord, survol qui nomme, clic qui
  entoure et amène la ligne), liste Serre (dossier relatif, tailles dans la langue de l’app, favori,
  Quick Look), déplacement comme Nettoyage.
- **Vérifié :** `make qualify` PASS ; test copie Explorer FR/EN ; app fixture (dossier varié de 23
  fichiers) : état initial, analyse, carte, survol, clic → ligne entourée.
- **Non vérifié :** déplacement réel et chute de feuille dans Explorer ; Quick Look ; favoris.
- **Recette 3.3 (mainteneur) :** choisir un dossier, regarder racines et parcelles, survoler et
  cliquer une parcelle, filtrer, trier, aperçu, favori ; optionnel : déplacer un fichier jetable.

### 28-09-2026 — lot 3.4, Doublons et images proches

- **3.3 :** « continue » sans recette explicite ; lignes du registre inchangées.
- **Fait :** `7f4b9fd7` — `DuplicateKeepers` (Domain, 3 tests) : la personne choisit l’exemplaire
  gardé, jamais déplaçable (gardé = retiré de la sélection + passé comme `protectedKeepers` à la
  revue). Modes en lignes Serre, état initial, racines sur le travail réel (lecture, hachage,
  décodage, comparaisons), groupes en parcelles de pousses, étiquette « Gardé » qui saute
  (`matchedGeometryEffect`, `pousse`), images proches en paires de vignettes sans action Corbeille,
  déplacement via `SerreActionKit`.
- **Vérifié :** `make qualify` PASS ; app fixture (3 groupes) : état initial, analyse, groupes,
  ligne gardée lumineuse, cocher puis « Garder celui-ci » → étiquette déplacée et coche retirée.
- **Non vérifié :** déplacement réel ; mode images proches (pas d’images dans la fixture).
- **Recette 3.4 (mainteneur) :** dossier de doublons, changer l’exemplaire gardé, cocher des
  copies, optionnel : déplacer ; mode images proches sur un dossier de photos. **Acceptée le
  28-09-2026** (« validé ») ; registre : preuves datées, lignes `PARTIEL` (déplacement et images
  proches non observés).

### 28-09-2026 — lot 3.5, Applications

- **Fait :** `bb66dc75` — état initial graine, parcelle mesurée avec limites, lecture sans racines
  (aucun événement de progression réel), rangs de plantation avec vraie icône de l’app, version,
  identifiant, adresse de mise à jour déclarée (lien léger), actions « Fichiers autour… » et
  « Corbeille… » en boutons icône Serre, erreurs et anomalies en bandeaux, déplacement d’un bundle
  via `SerreActionKit` (données associées laissées en place).
- **Vérifié :** `make qualify` PASS ; app fixture : état initial ; dossier de bundles illisibles
  (bandeau erreur + 4 anomalies) ; inventaire en lecture de `/Applications` (33 apps, icônes) en
  sombre et clair. Aucun bundle déplacé.
- **Non vérifié :** déplacement d’un bundle ; « Fichiers autour » ; VoiceOver.
- **Recette 3.5 (mainteneur) :** choisir un dossier d’apps, rechercher, ouvrir « Fichiers
  autour… » sur une app ; optionnel : déplacer une app jetable (copie d’une app sans importance).
  **Acceptée le 28-09-2026** avec une demande : détection automatique du dossier Applications.
  Faite dans `2663f55d` sans lecture automatique (le registre exige un dossier explicitement choisi) :
  les dossiers trouvés sont proposés en un clic. Registre : preuves datées, `PARTIEL`.

### 28-09-2026 — lot 3.6, Intégrité

- **Fait :** `5430106d` — `SerreSignalTag` (étiquette de plant : œillet, feuille de ton, détails, se
  balance une fois) ; état initial graine ; étiquette du plant avec vraie icône, une étiquette par
  signal (signature : identifiant, équipe, code ; quarantaine : présence/absence neutre, jamais
  un verdict), source et limites sur chacune ; LaunchAgents : dossiers trouvés proposés en un clic
  (`LaunchAgentFolders`, testé), candidats en lignes, problèmes en bandeaux, accords corrects.
- **Vérifié :** `make qualify` PASS ; app fixture : état initial, Calculatrice étiquetée (signature
  validée, aucun marqueur), vos LaunchAgents (1 plist valide, 1 cassé).
- **Non vérifié :** app non signée / en quarantaine ; VoiceOver.
- **Recette 3.6 (mainteneur) :** étiqueter une app téléchargée (souvent en quarantaine) et une app
  système ; lire vos LaunchAgents. **Acceptée le 28-09-2026** ; registre : preuves datées, `PARTIEL`.

### 28-09-2026 — lot 3.7, Performances

- **Fait :** `52d8fd16` — mesures en parcelles, chiffres Iowan (`CoreTendTypography.figure`), feuille de
  ton pour l’état thermique, valeurs dans la langue de l’app ; « la sève » : courbe de charge
  tracée de gauche à droite à l’apparition (`TraceReveal`), dernier relevé qui pulse une fois
  (`OncePulse`) ; aucune mesure ni animation au repos (NFR-09) ; bandeaux Serre ; copie « / »
  corrigée ; test logo isolé sur le thread principal (avertissements).
- **Vérifié :** `make qualify` PASS ; app fixture : parcelles, courbe après 4 actualisations,
  pulsation vue une fois puis disparue.
- **Non vérifié :** Reduce Motion ; VoiceOver.
- **Recette 3.7 (mainteneur) :** ouvrir Performances, actualiser plusieurs fois, regarder la courbe
  se tracer et le dernier point pulser ; effacer les relevés (Entrée annule).

### 28-09-2026 — décision du mainteneur : fin de P3 sans recette par lot

- « continue chaque recette chaque lot une par une jusqu’à finalisation complète, pas besoin de ma
  validation explicite. puis push next si nécessaire. »
- Conséquence : 3.7 à 3.10 sont livrés à la suite, chacun vérifié par l’agent (`make qualify`, app
  fixture, captures) et journalisé ici. Aucune ligne du registre ne passe `VÉRIFIÉ` sans
  observation du mainteneur ; les preuves datées de l’agent sont ajoutées, statut `PARTIEL`.
  La recette groupée de P3 (et les recettes explicites 3.2, 3.3) restent dues avant la gate G3.
- `next` est poussé à la fin de 3.10 (autorisé).

### 28-09-2026 — lot 3.8, Historique

- **Fait :** `05f7aa51` — herbier : une page par jour (date en Iowan), feuille par type d’événement,
  entrées pressées en place (`SerrePress`) une fois par chargement ; outils en parcelle (recherche,
  type, période, compte accordé, Exporter…, Effacer…) ; états vide / sans résultat / erreur Serre ;
  plus de liste imbriquée.
- **Vérifié :** `make qualify` PASS ; base fixture de 7 événements sur 3 jours : 3 pages, feuilles
  et heures correctes.
- **Non vérifié :** export JSON/CSV via le panneau ; effacement ; VoiceOver.

### 28-09-2026 — lot 3.9, fin de livraison

- **Fait :** WIP `ab0cd928` qualifié ; accords exclusions/événements corrigés et nombres
  `ProductFormat`. Réglages haut/milieu/bas et palette relus FR/EN clair/sombre en fixture.
- **Vérifié :** `make qualify` après corrections PASS, code 0 ; `git diff --check` PASS.
  Bouton Terminé/Done observé via AX ; icône pousse et réglage barre des menus actif visibles.
  FR → EN → FR et palette sans correspondance observés ensuite ; formats menu centralisés dans `53dfac36`.
- **Limites :** ouverture du panneau MenuBarExtra non obtenue par automatisation ; contenu et
  navigation restent à observer par le mainteneur. Import/export natifs,
  VoiceOver/Reduce Motion restent non qualifiés. Preuves : `Documentation/Evidence/P3-39-2026-09-28.md`.
- **Registre :** preuves datées ajoutées, aucun statut promu. Recette groupée avant G3.

### 28-09-2026 — lot 3.10, fin de livraison

- **Fait (`b923f013`) :** site Serre FR/EN, vitrine réelle, 24 captures copiées sans retouche, légendes avec
  provenance/limites ; macOS 14+, langues et statut Next non publié explicites. Captures locales
  contrôlées (fichier + alt), contenu jamais masqué à l’entrée, commandes Développeur groupées.
- **Vérifié :** `make capture-screens` PASS (44/44), `make build-site site-check` PASS,
  Chrome isolé 30 contrôles PASS (10 pages × 1280 clair/sombre et 390 clair), captures relues.
  Reduce Motion émulé : logo `0s`, toutes les images chargées, aucun débordement horizontal.
  `make qualify` sur les dernières modifications PASS (code 0), `git diff --check` PASS.
- **Preuves :** `Documentation/Evidence/P3-310-2026-09-28.md` ; registre et Progress datés,
  aucun statut promu. VoiceOver, zoom réel, second navigateur et headers déployés restent ouverts.
- **Recette :** groupée P3 avant G3, dont Nettoyage/Corbeille réelle sur dossier jetable (mainteneur)
  et Explorer ; ne pas commencer P4 avant cette gate.

## Point d’arrêt

**Lots 3.9 et 3.10 livrés le 28-09-2026 ; recette groupée P3 due avant G3.**

- **Fait :** 3.9 `4e573a1d`, complément formats/observations `53dfac36` ; site `b923f013`, poussé sur `origin/next`.
- **Vérifié :** qualification finale PASS (code 0, `/tmp/coretend-qualify-p3-delivery.exit`) ;
  captures réelles, site-check et contrôles Chrome PASS.
- **CI :** `qualify` sur `b923f013` PASS, terminé le 28-09 à 09:44:37 UTC.
- **Prochaine action agent :** arrêt pour la recette groupée ; ne pas commencer P4.
  Push effectué, pas de gate G3 acceptée.
- **Prochaine action mainteneur :** recette groupée, particulièrement 3.2 avec un vrai passage
  par la Corbeille sur dossier jetable et 3.3 ; contenu/navigation du panneau MenuBarExtra,
  import/export natifs. Aucun déplacement n’a été confirmé par l’agent.

## Problèmes ouverts

- Menu de la barre des menus : ouverture par automatisation non obtenue ; contenu et navigation à observer à la recette groupée.
