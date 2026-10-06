# P8 — CoreTend sur le Mac App Store

**Objectif :** distribuer CoreTend 2.0.0 via le Mac App Store. Décision : `Documentation/Decisions/0004-mac-app-store.md`.
**Gate :** G8 — accord explicite du mainteneur avant la soumission à la revue.
**Statut :** Apple a demandé des informations complémentaires au titre de la Guideline 2.1 le 30-09-2026. Invitation TestFlight acceptée selon le mainteneur (02-10) ; vidéo physique et réponse restent à transmettre avant la reprise de la revue.

## Lots

| Lot | Intitulé | Statut |
|---|---|---|
| 8.1 | Variante sandbox : droits, paquet `make package-appstore`, lancement vérifié | Livré |
| 8.2 | Adaptations sandbox : vrai dossier personnel, raccourcis par panneau, accès conservé jusqu'à la Corbeille, fichiers suivis | Livré |
| 8.3 | Revue et polish de l'app entière (8 destinations, accueil, réglages, barre des menus, FR/EN, clair/sombre) | Livré (`cc581f05`) |
| 8.4 | Build App Store : archive, export `app-store-connect` (signature gérée par Xcode), envoi TestFlight | Terminé : build 201 Complete, Ready to Submit |
| 8.5 | Fiche App Store : captures 2880 × 1800, textes EN/FR, confidentialité, catégorie, export | Métadonnées et 8 captures par langue enregistrées |
| 8.6 | Soumission à la revue | Informations complémentaires demandées (Guideline 2.1), 30-09-2026 ; TestFlight accepté ; réponse préparée, non envoyée ; vidéo physique manquante |

## Journal

### 29-09-2026 — 8.1 et 8.2

- `Resources/AppStore/CoreTend.entitlements` : `app-sandbox` + `files.user-selected.read-write`,
  rien d'autre. Info.plist : catégorie Utilitaires, `ITSAppUsesNonExemptEncryption` = false,
  langues en/fr, copyright. `make package-appstore` : build 201 signé avec ces droits.
- `SandboxAccess` : sandbox détectée par `APP_SANDBOX_CONTAINER_ID` ; vrai dossier personnel
  (`getpwuid`) en sandbox, `NSHomeDirectory()` sinon (HOME de fixture respecté).
- Raccourcis (Applications, pépinière d'Intégrité, LaunchAgents) : en sandbox, ils ouvrent le
  panneau système placé sur le dossier ; Nettoyage ouvre le panneau sur l'emplacement attendu.
  Survol d'Intégrité : accès au dossier ouvert pendant la lecture. Fichiers suivis : l'état
  présent/absent n'est plus affirmé en sandbox. L'accès est déjà repris au moment de la Corbeille
  (`actionScopeHeld`), vérifié dans le code.
- Vérifié à l'exécution (identifiant de démo `local.coretend.sandbox`, signature ad hoc) :
  conteneur créé, base locale dans le conteneur, accueil affiché, espace libre mesuré ;
  Performances : charge, mémoire utilisée (`host_statistics64`), cœurs, uptime, thermique OK.
  Aucun refus sandbox dans le journal système.
- Non vérifié encore : parcours avec panneau (choix de dossier, analyse, Corbeille) en sandbox —
  demande une interaction à l'écran.
- `make qualify` : code 0.

### 29-09-2026 — 8.3 (revue et polish) et 8.5 (fiche)

- Captures « en usage » : `python3 Scripts/capture_screens.py --in-use` crée un dossier de
  démonstration (photos, vidéos, projets, téléchargements, 4 paires de copies exactes, faux
  `Library/Caches`) dans le HOME de fixture ; Explorer, Doublons, Nettoyage l'ouvrent seuls,
  Applications et Intégrité lisent `/System/Applications`. Fenêtre à 1440 × 900 points →
  captures 2880 × 1800 (format App Store). Crochets `CORETEND_TEST_SCAN_ROOT`,
  `CORETEND_TEST_CLEANUP_RULE`, `CORETEND_TEST_WINDOW_SIZE` : fixture seulement, testés inactifs
  en lancement normal (`CoreTendPreferencesTests`).
- Polish trouvé en revue et corrigé :
  - panneau des racines tassé (120 → 64 pt) une fois l'analyse finie ; la page défile vers les
    racines et les résultats à la fin de l'analyse (Explorer, Doublons, Nettoyage) — avant, les
    parcelles/groupes restaient sous la ligne de flottaison ;
  - chemins affichés en `~/…` (chemin complet en infobulle) ;
  - « Source de mise à jour inconnue » n'est plus répété sur chaque app (dit une fois dans la note).
- Icône : l'`.icns` d'actool s'arrêtait à 256 px ; l'App Store exige jusqu'à 512@2x →
  `.icns` complet (16–1024) produit depuis le rendu 1024 px ; `Assets.car` Liquid Glass inchangé.
- Aucun lien externe ni mécanisme de mise à jour dans l'app (vérifié) ; textes d'accès des
  Réglages déjà compatibles sandbox.
- Fiche : `Documentation/Release/AppStore-listing.md` (EN/FR, notes de revue, confidentialité
  « Données non collectées ») ; longueurs vérifiées par `Scripts/check_appstore_listing.py`.
- **Bloquant 8.4 :** `xcodebuild -exportArchive` → « No Accounts » : le compte Xcode doit être
  reconnecté (Xcode › Réglages › Comptes). La fiche App Store Connect reste à créer.

### 29-09-2026 — qualification et préparation (historique)

- Demande du mainteneur : « fait tout ce qui est necessaire pour terminer le projet ».
- Objectif du lot 8.4 : requalifier la pointe `next`, valider les ressources App Store,
  puis vérifier l'export signé local. Pas de nouvelle fonction 2.1 ni de promotion G4.
- Dépôt propre au démarrage ; `git pull --ff-only` : déjà à jour.
- Première qualification `make qualify` PASS ; seconde qualification avec `appstore-check`
  intégré PASS, log `/tmp/coretend-final-qualify-green.log`, code 0.
- Défauts reproduits avant correction : reprise du même build bloquée par l'archive existante,
  paramètres invalides détectés trop tard et options temporaires conservées.
- Script corrigé : archive unique par tentative sans écraser les précédentes, numéro de build
  positif et paramètres API complets validés avant packaging, options nettoyées en sortie.
- Six régressions avec faux `make`/`xcodebuild` PASS ; aucun accès à Apple ni clé réelle.
  `make appstore-check traceability` et `git diff --check` PASS après ajustement final.
- Deux exports locaux réels : code 70, `No Accounts`, certificats de distribution et profil
  absents. La reprise atteint Xcode ; elle ne s'arrête plus sur l'archive précédente.
- Paquet sandbox local : `codesign --verify --strict` PASS (signature ad hoc), droits
  `app-sandbox` et `files.user-selected.read-write` présents ; plist valide.
- Les 16 PNG déjà présents : 8 par langue, dimensions 2880 × 1800 PASS. Ce contrôle
  ne remplace pas une revue visuelle nouvelle ni la recette sandbox.
- Modifications non commitées. Aucun upload TestFlight ni soumission App Review.
- Fiche EN/FR : `python3 Scripts/check_appstore_listing.py` PASS.

### 29-09-2026 — compte confirmé et voie Organizer (historique)

- Le mainteneur confirme le compte connecté et demande la clôture sans déclarer validées les
  recettes macOS 14, second Mac, VoiceOver, import réel 1.x et parcours sandbox.
- Nouveau CLI export : code 70, toujours `No Accounts`. En revanche le panneau Apple Accounts
  montre le compte, l'équipe et le rôle Admin ; la liste utilisée par le CLI reste vide.
  Le compte n'est donc pas déclaré absent : divergence entre GUI et CLI constatée.
- Dans Manage Certificates, création de **Apple Distribution** et **Mac Installer Distribution**,
  clés locales disponibles ; aucun certificat existant révoqué ni supprimé.
- Organizer, archive CoreTend 2.0.0 (201), identifiant `com.ahmetbsbnr.coretend` : Custom →
  App Store Connect → Export → équipe → gestion automatique de signature. Version/build
  automatiques et envoi des symboles désactivés ; validation App Store Connect franchie.
- La préparation atteint `codesign`, qui attend le mot de passe du Trousseau dans SecurityAgent.
  Question envoyée au mainteneur ; aucun mot de passe demandé dans la conversation ni lu.
- Source et tests n'ont pas changé dans cette reprise. Les réserves de recette restent ouvertes,
  aucune nouvelle affirmation de validation ni promotion du registre.

### 29-09-2026 — export signé et upload terminés

- Le mainteneur a saisi le mot de passe directement dans le Trousseau ; `codesign` débloqué.
- Export Organizer : `~/Documents/CoreTend-201-AppStore-signed/CoreTend.pkg`, copie conservée
  dans `Artifacts/AppStore/201/CoreTend-201-AppStore-signed/CoreTend.pkg`.
- `pkgutil --check-signature`, extraction temporaire et `codesign --verify --strict --deep` PASS.
  Profil, identifiant, version/build, sandbox, absence get-task-allow vérifiés ; app non installée.
  Rapport : `Documentation/Evidence/AppStore-package-2026-09-29.json`.
- Upload via Organizer Custom → App Store Connect → Upload, équipe du mainteneur,
  gestion automatique de signature, version/build et symboles non gérés automatiquement.
- Confirmation Organizer : **« CoreTend 2.0.0 (201) uploaded »**.
  Delivery UUID `979affff-6f66-41df-86db-2e4bf8a825e2` ; rapport
  `Documentation/Evidence/AppStore-upload-2026-09-29.json`.
- Lien Show in App Store Connect ouvert dans Safari : page de connexion ; demande de connexion
  locale envoyée au mainteneur. Traitement observé après connexion : Complete ; build 201 Ready to Submit, expiration dans 90 jours.
  Cela ne signifie pas que la recette interne a été exécutée.

### 29-09-2026 — fiche et soumission à la revue

- Coordonnées de revue, métadonnées EN/FR, droits de contenu, classification 4+, catégorie
  Utilities, tarif gratuit et confidentialité « Data Not Collected » enregistrés dans ASC.
- Captures EN/FR réimportées et contrôlées : huit images (01–08) par langue, 2880 × 1800.
- Le mainteneur a autorisé la soumission. ASC a confirmé macOS 2.0.0 **Waiting for Review** ;
  aucune publication App Store n'a eu lieu.

### 02-10-2026 — qualification locale et mise à jour TestFlight

- Le mainteneur confirme que l’invitation TestFlight est acceptée ; seule la vidéo physique
  reste à enregistrer avant la réponse à Apple.
- `PATH=/opt/homebrew/bin:$PATH make qualify` : PASS (code 0), log local
  `/tmp/coretend-next-qualify-resume.log`. Le gate couvre notamment 64 tests XCTest,
  les builds reproductibles App/CLI, le runtime empaqueté en fixture et les tests CLI.
- `git diff --check` : PASS. Les recettes UI natives manuelles, VoiceOver et la vidéo sur
  le Mac physique restent non vérifiées.

### 30-09 / 02-10-2026 — demande d’informations (Guideline 2.1)

- Apple demande, pour une nouvelle soumission, une vidéo physique montrant le lancement et le
  parcours typique, ainsi que des précisions sur le but/public, la configuration, les services
  externes, la disponibilité régionale et les secteurs réglementés/contenus tiers.
- Réponse EN préparée dans `Documentation/Release/App-Review-response-2026-09-30.md`, avec les
  Notes App Review à jour dans `Documentation/Release/AppStore-listing.md`.
- La vidéo du build soumis sur un Mac physique (OS courant), commençant au lancement, n’a pas
  été capturée ni jointe. Le texte de réponse comporte un emplacement modèle/version et ne doit
  pas être envoyé avant capture, upload et vérification des affirmations.
- Vérification visuelle de Safari le 30-09 : soumission macOS avec **Unresolved Issues** ; une
  seule entrée, App 2.0.0 (201), **Rejected**, motif affiché « 2.1.0 Performance: App
  Completeness ». Message Apple « Guideline 2.1 - Information Needed - New App Submission ».
  Le bouton « Resubmit to App Review » est désactivé sur cette page tant que l’issue est ouverte.
- Le PKG 201 signé est vérifié et installé sous `/Applications/CoreTend.app` (reçu package
  `com.ahmetbsbnr.coretend`, version 2.0.0). macOS refuse son lancement direct depuis ce PKG
  App Store (`spctl` rejected / LaunchServices launch failed) ; ne pas présenter ce lancement
  comme qualifié.
- TestFlight : groupe interne `CoreTend Internal QA` créé, distribution automatique désactivée,
  build 201 ajouté. Le mainteneur confirme le 02-10 que l’invitation est acceptée. La vidéo
  physique du lancement et du parcours typique reste à enregistrer avant la réponse à Apple.
- Les URL App Store d’assistance et de confidentialité du site public répondent toujours 200
  après la réparation des routes bilingues ; inventaire et contrôles dans
  `Documentation/Evidence/Vercel-audit-2026-09-30.md`.

### 04-10-2026 — lenteurs observées dans l’enregistrement du mainteneur, build 202

- Vidéo du mainteneur (build 201 TestFlight, MacBook Air M1, macOS 27.0.1) : roue d’attente dans
  Doublons après l’analyse, analyse lente de `~/Library/Caches`, fenêtre figée en fin d’analyse.
- Causes mesurées (Time Profiler, fixture 30 000 fichiers, jamais le vrai HOME) :
  - `isUbiquitousItem` par fichier : 73 % du temps d’analyse. Remplacé par un test « dataless »
    (`SF_DATALESS`) et une réponse iCloud par dossier. Moteur : 2,8 s → 0,63 s.
  - `realpath` par fichier remplacé par le chemin canonique du dossier parent (liens jamais suivis).
  - Une mise à jour SwiftUI par fichier : événements regroupés (`batched()`, ~10/s) dans Explorer,
    Nettoyage, Doublons, Applications.
  - Explorer : tri/filtre/plan recalculés à chaque rendu (survol compris) → cache `ExploreDerived`,
    clés de tri précalculées, chemin standardisé une fois par dossier.
  - Doublons : taille lue sur disque à chaque rendu pour chaque groupe → mesurée une fois hors du
    fil principal ; groupes en `LazyVStack` ; 12 copies affichées puis « Afficher les N autres » ;
    progression limitée à ~10/s ; présélection des gros fichiers par leurs 64 premiers Kio.
  - `LayerSway` : `fittingSize` d’une `NSHostingView` imbriquée (moteur Auto Layout à chaque
    mesure) → taille donnée par SwiftUI via une copie masquée du contenu. Animation inchangée.
- Plus long blocage du fil principal (fixture 30 000 fichiers) : Doublons 994 → 90 ms, Nettoyage
  536 → 90 ms, Explorer 919 → 346 ms (un seul calcul en fin d’analyse).
- Tests ajoutés : lots d’événements, groupes de gros fichiers. `make qualify` PASS (66 tests),
  avec la toolchain Xcode : la toolchain swiftly placée en tête du PATH ne compile pas l’app
  (`quickLookPreview` absent).
- Build 202 : `CORETEND_BUILD=202 bash Scripts/appstore_export.sh export` PASS, paquet signé
  vérifié (sandbox, pas de get-task-allow). Upload refusé : « App Store Connect access for
  NSCUV5G738 is required » → reconnecter le compte dans Xcode. Rien envoyé à Apple.
- Vidéo de revue montée depuis l’enregistrement 201 (cartons de réponses EN, passage où la
  Corbeille est vidée dans le Finder retiré) : `Artifacts/AppReview/CoreTend-AppReview-2.1.mp4`.

## Point d'arrêt

- Apple a demandé les informations de Guideline 2.1 le 30-09-2026. Le build 201 et son upload
  restent documentés dans `Documentation/Evidence/AppStore-upload-2026-09-29.json`.
- Prochaine action : enregistrer sur le Mac physique une vidéo dès le lancement de TestFlight,
  montrant le parcours typique ; joindre la vidéo, puis transmettre la réponse EN à la revue et
  les mêmes informations dans Notes. Compléter modèle/OS après observation réelle.
- La release GitHub/site/Homebrew 2.0.0 existe déjà (P7) ; la pointe actuelle de `next` n'est
  pas encore intégrée dans `main`.

## Problèmes ouverts

- Réponse et vidéo demandées sous Guideline 2.1 restent à transmettre. Le mainteneur confirme
  l’invitation TestFlight acceptée le 02-10. Aucun message App Review ni Notes ASC modifiés.
- Les preuves de qualification restées ouvertes dans P4 et le registre restent inchangées.
