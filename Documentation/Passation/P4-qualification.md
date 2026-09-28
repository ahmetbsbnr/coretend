# P4 — Qualification transverse

**Objectif :** preuves d’accessibilité, compatibilité, performance, revue indépendante, site et import 1.x.
**Gate :** G4 — preuves consignées pour chaque NFR concerné.
**Statut de la phase :** Travaux disponibles 4.1–4.6 livrés ; preuves externes ouvertes, G4 non passée.
**Plan :** `Documentation/Project/Implementation-plan.md` § Programme 2.0.

## Lots

| Lot | Intitulé | Statut |
|---|---|---|
| 4.1 | Accessibilité (mainteneur) : VoiceOver, Dynamic Type/zoom, contraste, Reduce Motion/Transparency | Accepté 28-09-2026 — détail des observations non fourni |
| 4.2 | Compatibilité : hôte macOS 14 et second Mac | Accepté avec réserve 28-09-2026 ; macOS 14 et second Mac non testés |
| 4.3 | Performance : corpus, mesures, budgets | Accepté 28-09-2026 — budgets locaux validés, réserves NFR-09 conservées |
| 4.4 | Revue indépendante architecture/sûreté | Livré — revue indépendante et correctifs qualifiés |
| 4.5 | Site : zoom, VoiceOver, en-têtes déployés, navigateurs ; bouton menu mobile sans JS ? | Livré — contrôles locaux et headers antérieurs, VoiceOver/déploiement ouverts |
| 4.6 | Import 1.x sur copie d’un vrai store 1.x | Lecteur et fixtures livrés — copie réelle non fournie |

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

### 28-09-2026 — lot 4.3, livraison

- **Décision :** « continue » : résultat limité de 4.2 accepté, réserves NFR-08 conservées.
- **Objectif :** NFR-09, mesures reproductibles et budgets proposés sur l’hôte disponible.
- **Fait :** profil mixed/export JSON ajoutés au benchmark CLI ; sonde app isolée reproductible
  `Scripts/benchmark_app_fixture.py`, trois rapports bruts dans Evidence et PerformanceBaseline.
- **Mesures :** uniform 0,873 s / mixed 1,069 s (médianes chaudes) ; fenêtre app 0,469 s
  médiane. Cinq seuils locaux de non-régression proposés, fondés sur 2× les références.
- **Limite :** essai Explorer jusqu’à 9 875 fichiers puis erreur AX -10000 ; fin non observée.
  Second essai de sélection non confirmé. Aucun budget scan natif/UI déduit de ces essais.
- **Qualification :** `make qualify` PASS (code 0, `/tmp/coretend-p4-43-final-qualify.log`) ;
  benchmarks exécutés après les builds, sans compilation concurrente pour la série finale.
- **Vérification finale :** `make traceability` et `git diff --check` PASS.
- **Recette :** examiner corpus, mesures, limites et budgets avant acceptation ; pas de 4.4 avant recette.

### 28-09-2026 — poursuite de P4 autorisée

- **Mainteneur :** « tout est validé, finit tout 4 en entier. » : 4.3 et budgets locaux
  acceptés ; autorisation d’enchaîner 4.4–4.6 sans arrêt intermédiaire pour recette.
- **4.4 ouvert :** revue par agent distinct sans contexte d’implémentation, lecture seule.
  Absence de second relecteur humain explicitement conservée. Corriger les constats confirmés
  avant livraison et qualification ; NFR-10/NFR-12 concernés.
- **4.5/4.6 :** à effectuer après 4.4. Demande de copie réelle 1.x envoyée au mainteneur ;
  ne pas lire ni copier le store original depuis le HOME réel.

### 28-09-2026 — 4.4 livré, 4.5 ouvert

- **Revue :** agent distinct, contexte neuf, pas de second humain ; trois constats corrigés.
  Preuve : `Documentation/Evidence/P4-44-review-2026-09-28.md`.
- **Correctifs :** doublons liés aux snapshots hashés, identité regularfile taille/mtime/ctime,
  keepers attendus à la revue/exécution ; JSON présent mal typé refusé ; références FR-07 et
  clutter.duplicates complétées. Régressions sur fixtures/fausse Corbeille PASS.
- **Vérifié :** tests ciblés PASS ; `make qualify` PASS code 0, `git diff --check` PASS.
- **4.5 :** NFR-11, zoom navigateur/second moteur/headers publics, preuves site existantes.
  Menu mobile reste visible sans JavaScript selon livraison Serre acceptée ; aucun redesign.

### 28-09-2026 — 4.5, contrôles réalisés

- Chrome zoom navigateur 200 % : 20 PASS ; WebKit non persistant 100/200 % : 40 PASS,
  FR/EN clair/sombre, images lazy chargées après scroll, pas de débordement ni scripts.
  Skip-link/focus Chrome observés ; quatre captures ouvertes et relues. Menu visible sans JS conservé.
- Headers publics de l’ancienne livraison présents ; aucune preuve de déploiement Next,
  aucun déploiement entrepris. VoiceOver parlé/Safari complet NON LANCÉS.
- Preuve `SiteAccessibilitySmoke.md`, deux rapports JSON datés ; NFR-11 PARTIEL.
- `make qualify` PASS code 0, `git diff --check` PASS.

### 28-09-2026 — 4.6 livré, bilan P4

- **Réalisation :** lecture d’une copie SQLite 1.x autonome, versions 1–4 reconnues d’après
  le code publié ; exclusions uniquement. Pas de lecture UserDefaults/historique personnel.
  JSON v1 conservé ; aperçu hors MainActor, accès security-scoped jusqu’à la fin de lecture.
- **Sûreté :** descripteur read-only/NOFOLLOW, double fstat, snapshot privé immutable,
  quick_check, allowlist, bornes 64 MiB/1 000 exclusions, refus WAL/journal et entrées invalides.
  Nettoyage limité au snapshot créé ; exception textuelle étroite audit relue indépendamment.
- **Preuves :** `Documentation/Evidence/P4-46-import-2026-09-28.md` ; tests Persistence
  ciblés PASS (39 tests), conservation source/rollback/reprise/idempotence ; quatre captures
  Réglages FR/EN clair/sombre ouvertes et relues, sans déplacement confirmé dans l’app packagée.
- **Copie réelle :** demandée, non fournie ; recette réelle NON LANCÉE. FR-20 PARTIEL.
- **Qualification finale :** `make qualify` PASS code 0
  (`/tmp/coretend-p4-passation-qualify.log`, code 0 sur HEAD `ac27e45b`) ;
  `make traceability` et `git diff --check` PASS. Registre 3/78 Must et 0/11 Should
  VÉRIFIÉ, aucun statut promu sans observation détaillée du mainteneur.

## Point d’arrêt

- Dernier commit P4 de code et preuve : `ac27e45b432b72df30bdc6c487df8e8b337093cd`.
  Six commits P4 locaux depuis la pointe distante observée, puis deux commits de clôture
  documentaire. Qualification locale code 0 sur `ac27e45b`. Aucun push. CI `qualify` de
  `1f62627e0c0733d285258466559dc7c7344eb0d8` SUCCESS (GitHub, terminé 09:16:57 UTC) ;
  cette exécution CI ne couvre pas les commits locaux. Requalification locale complète
  en cours pour cette reprise documentaire.

**4.1–4.6 : travaux réalisables livrés ; G4 non passée faute de preuves restantes.**

Aucun lot de code ouvert. Fournir les observations/copies/hôtes manquants pour compléter
les preuves ci-dessous, puis décider G4. Aucun push/P5 autorisé.

## Problèmes ouverts — preuves restantes pour G4

| Lot | Limite conservée | Reprise |
|---|---|---|
| 4.1 | VoiceOver parlé, agrandissement, contraste de tous états, réglages réels Reduce Motion/Transparency non observés | Recette destination par destination dans Accessibility.md |
| 4.2 | Seul MacBook Air M1/macOS 27 ; macOS 14 et second Mac indisponibles | Qualification isolée sur ces hôtes quand disponibles |
| 4.3 | Corpus réel, latence UI, fin scan natif, CPU instantanée au repos non qualifiés | Mesurer avec protocole identique ; budgets locaux acceptés conservés |
| 4.4 | Agent indépendant, aucun second humain ; race résiduelle validation/API Trash | Preuve limitée explicite dans P4-44-review ; aucune mutation réelle à tenter pour la revue |
| 4.5 | VoiceOver/Safari complet, headers de la livraison Next déployée non qualifiés | Observation humaine et contrôle après déploiement explicitement autorisé |
| 4.6 | Copie réelle 1.x non fournie, parcours natif complet non qualifié | Copie déjà créée et autorisée, import uniquement dans fixture temporaire |

Escape n’atteignait pas l’app sur cet hôte lors d’essais précédents (Reference) ; aucun
raccourci ou réglage système modifié pour contourner ce problème.
