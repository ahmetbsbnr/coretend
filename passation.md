# Passation — CoreTend `next`

## Remise à plat — 27-09-2026 au soir (à lire en premier)

- **Phase : P0 → P1** de [`Documentation/Project/Pilotage.md`](Documentation/Project/Pilotage.md). Prochaine étape : **G1**, validation de la direction visuelle Observatoire par le mainteneur sur l’app lancée. Aucun nouvel écran ni changement d’apparence avant G1.
- Diagnostic complet (historique v1/v2/v3/Next, causes d’échec, besoins) : [`Documentation/Project/Audit-2026-09-27.md`](Documentation/Project/Audit-2026-09-27.md). Règles d’agent : `AGENTS.md` (importé par `CLAUDE.md`).
- **Dossier de travail : `~/Developer/projects/coretend-next`** (worktree recréé après le déplacement de `~/Developer/Website`). `../coretend` est la maintenance 1.x (`fix/1.x-trash-sqlite`), pas un lieu de travail produit.
- La refonte **Observatoire** (commits `23b3f32` → `4451f8b`) a remplacé Porcelain/Slate/Teal dans l’app et le site, sans relecture de sa spec. Elle est l’état actuel, **pas une direction validée**.
- **10 commits de cette branche ne sont pas sur GitHub** (`5f44839..4451f8b`). Les pousser est une décision du mainteneur.
- **Bloquant : `make qualify` échoue sur `4451f8b`.** `Scripts/audit_safety.py` refuse `homeDirectoryForCurrentUser` dans `Sources/CoreTendApp/CleanupView.swift:171` (commit `6d744ea`). Premier lot à faire, avant tout push ou G1. Sur cet hôte, lancer les scripts avec `/opt/homebrew/bin/python3` : le `python3` système (3.9) casse `Scripts/test_traceability.py`.
- Perdus au déplacement (non suivis par Git) : `Documentation/Project/Remaining-musts-plan.md` et `design-preview/`.
- Défaut signalé par le mainteneur : pas de retour au survol (aucun `onHover` dans l’app) et zone cliquable du bouton Réglages de la sidebar limitée au texte (`.buttonStyle(.plain)`, fond hors du bouton, `CoreTendApp.swift`). À traiter en P2 par des composants communs.

Les sections suivantes datent du relevé de midi ; elles restent exactes sauf là où la remise à plat ci-dessus les corrige.

**État relevé : 27 septembre 2026, après requalification NFR-11.** Reconstruction en cours, non finalisée; aucune release publique. Cette passation remplace la précédente. Historique détaillé : `Documentation/Progress.md` et l’historique Git.

## État courant

- Dépôt canonique : `ahmetbsbnr/coretend`, worktree `~/Developer/projects/coretend-next`.
- Branche : `feat/reconstruction-open-musts`; dernier commit fonctionnel `b8e2769` (`fix: keep site content visible during entrance and qualify dark appearance`), suivi des mises à jour de passation/preuves `f745e95`, `8e1319b` et `512ff78`. Base de PR : `next` (`origin/next` à `55e8628`).
- PR brouillon [#55](https://github.com/ahmetbsbnr/coretend/pull/55) vers `next`.
- CI GitHub `qualify` passe sur `8e1319b` (run [36311612004](https://github.com/ahmetbsbnr/coretend/actions/runs/36311612004)) et sur la mise à jour de passation `512ff78` (run [36311782272](https://github.com/ahmetbsbnr/coretend/actions/runs/36311782272)). Sur `512ff78`, Vercel `app` et `coretend` sont bloqués par quota (« retry in 24 hours »); l’agrégat reste en attente.
- `git status` : seuls fichiers non suivis `Documentation/Project/Remaining-musts-plan.md` (**garder local, ne jamais ajouter**), `Scripts/__pycache__/` (généré par `make qualify`) et `.impeccable/` (configuration locale du hook design, contient une exception `overused-font=helvetica`).
- Aucun merge, tag, signature, notarisation, publication ni déploiement CoreTend effectué.

## Travail de cette session (commits `e1fbdf6` → `b8e2769`)

- **FR-26 tranché par l’utilisateur : retrait du bundle seul.** Aucune source de preuve d’appartenance approuvée; fichiers associés trouvés par bundle ID restent consultatifs, sans action. Consigné dans Traceability et Progress. Ne pas coder d’action sur données associées sans nouveau contrat approuvé.
- **Smoke runtime :** `Scripts/runtime_metrics.py` lance `ps` en locale `C`; la locale française (`68,8`) cassait `make app-runtime-smoke`. Tests de régression ajoutés.
- **Site :** meta description par page, vérifiée par `check_site.py`.
- **NFR-11, après refonte :** Lighthouse mobile relancé sur les 11 routes; Accessibilité/Bonnes pratiques/Agentic Browsing 100 partout, SEO 60. Dix routes EN/FR contrôlées en viewport émulé 640 × 900 et 320 × 800 : pas d’overflow, `lang`/meta description corrects; à 320, premier Tab atteint le skip-link traduit, contour 3 px. `SiteAccessibilitySmoke.md`, Traceability et Progress actualisés. Zoom navigateur réel et accessibilité humaine restent ouverts.
- **Clavier natif (app Release en fixture) :** barre latérale ↑/↓ observée sur les huit destinations. Corrigés : flèches ignorées dans la palette ⌘K (champ focalisé), ligne sélectionnée hors vue, feuille Réglages sans sortie et textes tronqués (bouton Terminé/Done, formulaire groupé, hauteur bornée). `⌘,` ouvre Réglages. Barre latérale élargie (libellé FR tronqué corrigé).
- **Direction artistique appliquée à midi : Porcelain / Slate / Teal**, remplacée l’après-midi par Observatoire (voir la remise à plat). Source d’origine : le `DESIGN.md` de la ligne 1.x, valeurs réécrites, aucun fichier importé conformément à la Décision 0001.
  - Nouveau module `DesignSystem` (architecture §9) : palette clair/sombre, contraste WCAG testé (textes ≥ 4,5:1 sur fond et sur accent), jetons de mouvement 150/300/550 ms, animation nulle sous Reduce Motion.
  - App : teinte teal, fond porcelaine/ardoise, risques Nettoyage ambre/corail en plus du libellé, carte proportionnelle en tons de teal, transitions entre destinations, transition numérique de l’espace libre, surlignage animé de la palette. Observée en clair et en sombre.
  - Site : `site.css` refait (couleurs, rayons 9/14 px, apparition par translation, survol des cartes, halo teal borné), contrat reduced-motion renforcé. Observé à 500 px et en sombre. Pas d’Archivo ni d’arcs Core Bloom (fichiers de l’ancien dépôt interdits); police système.
  - Override fixture `CORETEND_TEST_APPEARANCE=light|dark`, actif seulement en profil de test.

Détails, hôte et limites : `Documentation/Evidence/AppWindowRuntimeQualification.md`, `Documentation/Evidence/SiteAccessibilitySmoke.md`, `Documentation/Progress.md`.

## Mesure de couverture du registre

Source de vérité : `Documentation/Traceability.csv`, 91 lignes. Aucun statut n’a changé dans cette session.

| Priorité | PARTIEL | VÉRIFIÉ | À_CONSTRUIRE | Couverture indicative* |
| --- | ---: | ---: | ---: | ---: |
| Must (78) | 76 | 2 | 0 | 51,3 % |
| Should (11) | 10 | 0 | 1 | 45,5 % |
| Conseil (1) | 0 | 0 | 1 | — |
| Won’t (1) | 0 | 0 | 1 | — |
| Total (91) | 86 | 2 | 3 | 49,5 % |

\* `VÉRIFIÉ=100 %`, `PARTIEL=50 %`, `EN_COURS=25 %`, `À_CONSTRUIRE=0 %`. Indice de preuves, pas un pourcentage officiel de produit recréé. Aucun Must ne passe `VÉRIFIÉ` sur la seule base de tests unitaires ou d’une compilation.

## Ce qui reste — aucun gap « code seul » identifié

Relecture des 89 lignes non vérifiées : tous les gaps restants demandent une observation native, une condition externe ou une revue.

- **Observations natives réalisables en fixture :** parcours Historique (filtres, export), Explorer, Doublons, Applications, Intégrité avec dossiers de test; Quick Look; MenuBarExtra; confirmations jusqu’à l’annulation seulement (l’app utilise la vraie Corbeille via `MacOSTrashClient` : ne jamais confirmer).
- **Nécessitent l’utilisateur :** VoiceOver parlé, Dynamic Type/zoom, contraste tous états, Reduce Motion/Transparency réels (réglages système, ne pas les modifier soi-même); vraie Corbeille.
- **Conditions externes :** hôte macOS 14 minimum, second hôte/version, revues indépendantes (NFR-10, NFR-12), signature/notarisation/release (FR-17, NFR-14), ergonomie externe.
- **Différés par périmètre :** FR-18, FR-19.
- **Site :** 640/320 CSS px vérifiés par émulation; pas de test sur appareil mobile physique ni de vrai zoom navigateur. Lighthouse mobile post-refonte : SEO 60; autres catégories mesurées 100. NFR-11 reste PARTIEL pour zoom réel, VoiceOver, réglages OS, reduced-motion à l’exécution et qualification multi-navigateur/déployée.

## Limites d’environnement constatées sur cet hôte

- **Échap n’atteint pas CoreTend** (ni automatisation ni clavier réel) : un moniteur `NSEvent` temporaire voyait ⌘K et ↓, jamais keyCode 53. Probable raccourci global d’un autre utilitaire. Fermeture par Échap non qualifiée; retester après avoir identifié l’utilitaire.
- **Clics souris dans la fenêtre refusés** par l’automatisation (overlay « Centre de notifications »); utiliser clavier ou actions AX via System Events.
- **Sandbox :** `make qualify`, `swift test`, `gh`, `git push` et le lancement GUI de l’app exigent l’exécution hors sandbox (`sandbox-exec` imbriqué SwiftPM, certificat TLS de `gh`).
- La sélection de la barre latérale suit l’accent système macOS de l’utilisateur (vert sur cet hôte); `.tint` ne la modifie pas, choix natif conservé.

## Ordre de reprise

0. Corriger l’échec de `audit_safety.py` ci-dessus et repasser `make qualify`. Puis suivre la phase courante de `Pilotage.md` : préparer G1 (captures de l’app lancée, 8 destinations, Réglages, ⌘K, clair/sombre) puis s’arrêter pour la décision du mainteneur. Les étapes ci-dessous ne reprennent qu’après G1, un lot à la fois.
1. Vérifier CI `qualify` de PR #55 sur HEAD courant.
2. Poursuivre les qualifications natives réalisables (liste ci-dessus), une par une, en fixture; corriger les défauts trouvés avec test quand possible; inscrire seulement ce qui a été observé, avec hôte et limites.
3. Lighthouse post-refonte et viewport EN/FR 640/320 sont faits et consignés; relancer après prochain changement de contenu ou de style.
4. Réconcilier `Traceability.csv`, puis `Progress.md`, preuves dédiées, guide et cette passation. Garder `PARTIEL` si un seul critère manque.
5. Avant commit : `make qualify`, `python3 Scripts/check_traceability.py`, `python3 Scripts/test_traceability.py`, `git diff --check`, `git status --short --branch`. Ne pas stager `Remaining-musts-plan.md`, `Scripts/__pycache__/`, `.impeccable/`.
6. Commit sur la branche du lot; push seulement sur demande du mainteneur. Vercel peut rester rouge pour quota. Aucun merge/tag/release/publication sans conditions formelles. Must avant Should; pas de Cask sans release publiée/checksum.

## Lancer l’app en fixture isolée (protocole utilisé)

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

Chemins sans lien symbolique requis (`realpath`), sinon l’override de store est refusé. Autres overrides : `CORETEND_TEST_LAST_DESTINATION`, `CORETEND_TEST_RECENT_FILES_ENABLED`, `CORETEND_TEST_MENU_BAR_ENABLED`.

## Commandes et sources

- Gate complet : `make qualify`
- Traceabilité : `python3 Scripts/check_traceability.py` et `python3 Scripts/test_traceability.py`
- Site : `make build-site site-check`
- Smoke app Release isolé : `make app-runtime-smoke`
- Tests ciblés : `swift test --filter DesignSystemTests`, `--filter CoreTendPreferencesTests`, `--filter PersistenceTests`, `--filter DomainTests`, `--filter ScanCoreTests`, `--filter AppShellTests`
- Références normatives : `Documentation/Project/Cahier-des-charges.md`, `Documentation/Project/Implementation-plan.md`, `Documentation/Traceability.csv`, `Documentation/Project/Repository-strategy.md`, `Documentation/Decisions/0001-greenfield.md`; direction visuelle `../app/DESIGN.md`.
- Références de preuve : `Documentation/Progress.md`, `Documentation/ReleaseEvidence.md`, `Documentation/Evidence/*.md`.

## Invariants de reprise

- Aucun test sur vrai HOME/store CoreTend/Corbeille ou données privées; mutation seulement sous fixture temporaire avec Fake Trash. Dans l’app packagée, ne jamais confirmer un déplacement.
- Ne pas solliciter FDA, sudo, effacement permanent, accès réseau silencieux, télémétrie, mise à jour installante, migration destructive, ni modifier les réglages système de l’hôte.
- Erreur, inconnue, absence et échec restent distincts. Ne pas affirmer propriété, sûreté, malware, espace récupéré, statut release ou accessibilité sans preuve.
- Direction visuelle : un seul accent teal; couleur jamais seule porteuse de sens; toute animation passe par les jetons `MotionToken` et respecte Reduce Motion; contenu du site jamais conditionné à une animation.
