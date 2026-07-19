# CHANGELOG

## 0.1.0 — 2026-07-19
- SwiftPM foundation, SafetyCore, ScanCore, FileRules (4 user cleanup rules),
  DesignSystem tokens, SwiftUI shell with working Cleanup module
  (scan → review → dry-run/Trash), 24 tests green, packaging script.

## 0.2.0 — 2026-07-19
- Persistence SQLite (actor, migrations), My Activity, Settings (+exclusions honorées par les scans).
- Smart Care orchestrateur dry-run; Cleanup regroupé par règle, 3 nouvelles règles.
- My Clutter: Large & Old, Doublons (hachage étagé, hard links, gardien suggéré,
  garantie de survivant), Images similaires (Vision, vignettes à la demande).
- Space Lens (treemap + liste), Applications (inventaire, désinstallation Corbeille,
  leftovers conservateurs), Performance (métriques live + LaunchAgents),
  Protection (ClamAV + quarantaine, état honnête), Cloud Cleanup (empreinte locale),
  barre de menus, onboarding avec sonde FDA réelle.
- 46 tests verts, 0 warning, paquet Release arm64.

## 0.3.0 — 2026-07-19
- Protection: onglet Privacy (profils navigateurs, nettoyage caches uniquement,
  avertissement navigateur ouvert; historique/cookies affichés mais non modifiés).
- Applications: onglet Updates (canal de mise à jour par app, aucun téléchargement).
- Accessibilité: labels VoiceOver sur les cases de sélection.
- Script create-test-volume.sh (image APFS isolée pour tests destructifs).
