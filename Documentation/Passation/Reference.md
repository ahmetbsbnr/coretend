# Référence de reprise

Ce qui ne change pas d’un lot à l’autre. `passation.md` et les fichiers de phase y renvoient.

## Lieux

- Dépôt `ahmetbsbnr/coretend`. Développement : `~/Developer/projects/coretend-next`, branche
  `next`, commits directs (pas de branche de lot).
- `~/Developer/projects/coretend` : maintenance 1.x, branche `fix/1.x-trash-sqlite`. Aucun
  travail produit.
- `main` porte la 1.x publiée (1.0.2). Branches supprimées archivées sous
  `refs/archive/<date>/` (voir `Documentation/Project/Branch-cleanup.md`).

## Commandes

```sh
export PATH=/opt/homebrew/bin:$PATH     # sur cet hôte : python3 ≥ 3.10 requis par les scripts
make qualify                             # gate complet, obligatoire avant commit de code
python3 Scripts/check_traceability.py && python3 Scripts/test_traceability.py
make build-site site-check               # site
make app-runtime-smoke                   # app Release isolée
swift test --filter <Suite>              # DesignSystemTests, PersistenceTests, DomainTests,
                                         # ScanCoreTests, AppShellTests, CoreTendPreferencesTests
git diff --check
```

CI GitHub : check `qualify` sur `next` (requis ; l’admin peut le contourner au push, le
résultat arrive ensuite). Sans `gh` authentifié, lire l’état par l’API publique :
`curl -s https://api.github.com/repos/ahmetbsbnr/coretend/commits/<sha>/check-runs`.

## Lancer l’app en fixture isolée

```sh
make package-local
R=$(realpath "$(mktemp -d "$(getconf DARWIN_USER_TEMP_DIR)coretend-qual-XXXX")")
mkdir -p "$R/home" "$R/store" "$R/tmp" && cp -R Artifacts/CoreTend.app "$R/"
env -i PATH=/usr/bin:/bin HOME="$R/home" CFFIXED_USER_HOME="$R/home" TMPDIR="$R/tmp/" \
  CORETEND_TEST_MODE=1 CORETEND_TEST_STORE_DIR="$R/store" CORETEND_TEST_ONBOARDING_COMPLETED=1 \
  CORETEND_TEST_LANGUAGE=fr CORETEND_TEST_APPEARANCE=dark \
  "$R/CoreTend.app/Contents/MacOS/CoreTendApp" &
# fin : pkill -f "$R/CoreTend.app"; rm -rf "$R"
```

Chemins sans lien symbolique (`realpath`), sinon l’override de store est refusé. Autres
overrides : `CORETEND_TEST_LAST_DESTINATION`, `CORETEND_TEST_RECENT_FILES_ENABLED`,
`CORETEND_TEST_MENU_BAR_ENABLED`, `CORETEND_TEST_APPEARANCE=light|dark`.

## Invariants

- Aucun test sur le vrai HOME, le vrai store CoreTend ou la vraie Corbeille ; mutation
  seulement sous fixture temporaire avec fausse Corbeille. Dans l’app packagée, ne jamais
  confirmer un déplacement (elle utilise la vraie Corbeille).
- Ne pas demander Full Disk Access, sudo, suppression permanente, réseau silencieux,
  télémétrie, mise à jour installante, migration destructive ; ne pas modifier les réglages
  système de l’hôte.
- Erreur, inconnu, absence et échec restent distincts. Ne pas affirmer propriété, sûreté,
  malware, espace récupéré, statut de release ou accessibilité sans preuve.
- Apparence : seulement ce que couvre une décision acceptée (`Documentation/Decisions/`).
  Animations par `MotionToken`, Reduce Motion respecté ; couleur jamais seule porteuse de sens.
- Site : pas de JavaScript (CSP `script-src 'none'`), contenu jamais conditionné à une animation.

## Particularités de l’hôte actuel (Mac arm64, macOS 27)

- `python3` système = 3.9 : `make` s’arrête sur `python-version` avec un message. Mettre `/opt/homebrew/bin` en tête.
- Échap n’atteint pas CoreTend (probable raccourci global d’un utilitaire tiers) : fermeture
  par Échap non qualifiable ici tant que l’utilitaire n’est pas identifié.
- Clics souris dans la fenêtre refusés à l’automatisation (overlay Centre de notifications) :
  utiliser clavier ou actions AX.
- Sandbox de l’agent : `make qualify`, `swift test`, `git push` et le lancement GUI peuvent
  exiger une exécution hors sandbox.
- Après un déplacement du dossier, un `.build/` existant peut casser la compilation
  (`_TestingInternals` introuvable) : reconstruire ou utiliser `--scratch-path`.
- La sélection de la sidebar suit l’accent système macOS (vert sur cet hôte) ; `.tint` ne la change pas.

## Pièces Serre à réutiliser (P3)

- `DesignSystem` : `ScanRoots` (racines pilotées par de vrais événements, floraison, retrait),
  `FallingLeaf`, `SerreCheck`, `SerreRiskBadge`, `SerreSignalTag` (étiquette de plant),
  `serreRise`, `serrePress`, `traceReveal`, `OncePulse`, `SoilBand`, `CoreTendTypography.figure`.
- `CoreTendApp/SerreActionKit.swift` : `PageNotice` + `PageNoticeBanner` (bandeaux avec
  « Choisir à nouveau » / « Réessayer »), `LeafFlight` + `.leafFlightLayer/Row/Anchor`,
  `TrashIndicator`, `executeShowingEachItem` (déplacement élément par élément,
  `FileActionService.execute(_:onItem:)`), `PageNotice.moveOutcome`.
- `Domain` : `DuplicateKeepers` (exemplaire gardé jamais déplaçable), `ApplicationFolders`,
  `LaunchAgentFolders` (dossiers proposés en un clic, rien lu avant le choix ; HOME via
  `NSHomeDirectory()`, jamais `homeDirectoryForCurrentUser`, refusé par `audit_safety.py`).
- `AppShell` : `ProductFormat.bytes/count/items/frenchPlural/memory/filesExamined` — toujours dans
  la langue de l’app, jamais `ByteCountFormatter` ni format système.

## Règles apprises en P3

- **Toute confirmation destructive** met un bouton non destructif en défaut de Retour
  (`.keyboardShortcut(.defaultAction)` sur Annuler) ; `check_architecture.py` le vérifie.
  Origine : incident du 28-09 où une confirmation a été validée sans clic de l’agent.
- Un mouvement doit avoir une cause réelle (guide § 8) : pas de racines pour Applications
  (aucun événement de progression), pas de boucle au repos.
- `.position` en dernier sur une vue interactive : sinon elle capte survol et clics de tout
  son conteneur (bug de la carte Explorer).
- Pas de `if let x` qui masque un `@State x` réaffecté dans la même portée (plantage du
  compilateur, RecordView).
- Rendu d’image (`ImageRenderer`) : passer une vue nommée, pas une chaîne de modificateurs
  (avertissement d’isolation, fatal pour la porte « zéro avertissement »).

## Démos en fixture (vérification visuelle)

- Nettoyage : créer `$R/home/Library/Logs/DiagnosticReports` rempli de faux `.ips`/`.crash`
  (la règle compare la fin du chemin), `CORETEND_TEST_LAST_DESTINATION=cleanup`.
- Explorer : dossier varié sous `$R/home/…` ; Doublons : `cp` de fichiers identiques.
- Applications : proposer `/Applications` (lecture seule). Intégrité :
  `/System/Applications/Calculator.app` + `$R/home/Library/LaunchAgents` avec un plist valide
  et un cassé. Historique : insérer des lignes dans `$R/store/…/records.sqlite`
  (`activity_events(id, occurred_at, kind, detail, failure_code)`), jamais dans le vrai store.
- Pilotage à l’écran par computer-use : le Terminal peut repasser devant l’app et bloquer un
  clic ; ne **jamais** ouvrir la confirmation de déplacement dans l’app packagée (vraie
  Corbeille). Pour voir une animation de déplacement, faire un build de diagnostic temporaire
  qui la déclenche sans fichier (ex. à la sélection d’une ligne), puis le retirer.
