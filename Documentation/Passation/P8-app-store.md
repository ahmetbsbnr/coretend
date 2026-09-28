# P8 — CoreTend sur le Mac App Store (TestFlight puis revue)

**Objectif :** une version TestFlight de CoreTend 2.0 le 29-09-2026 au matin, puis une soumission
à la revue d'Apple. Décision : `Documentation/Decisions/0004-mac-app-store.md`.
**Gate :** G8 — accord explicite du mainteneur avant la soumission à la revue.
**Statut :** En cours depuis le 29-09-2026.

## Prérequis mainteneur

- [ ] Fiche App Store Connect : Apps › + › New App, macOS, nom **CoreTend**, SKU `coretend`,
      Bundle ID `com.ahmetbsbnr.coretend` (l'enregistrer sur developer.apple.com s'il manque).
      Sans cette fiche, l'envoi TestFlight est refusé.

## Lots

| Lot | Intitulé | Statut |
|---|---|---|
| 8.1 | Variante sandbox : droits, paquet `make package-appstore`, lancement vérifié | Livré |
| 8.2 | Adaptations sandbox : vrai dossier personnel, raccourcis par panneau, accès conservé jusqu'à la Corbeille, fichiers suivis | Livré |
| 8.3 | Revue et polish de l'app entière (8 destinations, accueil, réglages, barre des menus, FR/EN, clair/sombre) | À faire |
| 8.4 | Build App Store : archive, export `app-store-connect` (signature gérée par Xcode), envoi TestFlight | À faire |
| 8.5 | Fiche App Store : captures 2880 × 1800, textes EN/FR, confidentialité, catégorie, export | À faire |
| 8.6 | Soumission à la revue — sur accord | À faire |

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

## Point d'arrêt

- Démarrage : audit sandbox fait (aucun sous-processus ; dossiers choisis par `fileImporter` ;
  `NSHomeDirectory()` et accès limité à l'analyse à corriger).
