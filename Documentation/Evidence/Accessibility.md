# Preuve de qualification accessibilité

## Essai de lancement isolé — 26-09-2026

- Hôte : macOS 27.0 (26A428), arm64.
- Artefact : `Artifacts/CoreTend.app`, copie locale du ZIP unsigned SHA-256 `94503244830030785388e6ea2359dc844af22d719d5e82729f14408f1697a299`.
- Isolation : bundle copié dans `/private/tmp/coretend-ui-qual.rIdehA/home/Applications`; lancement avec ce chemin comme `HOME`.
- `/usr/bin/env HOME=/private/tmp/coretend-ui-qual.rIdehA/home open -n /private/tmp/coretend-ui-qual.rIdehA/home/Applications/CoreTend.app` : code retour 0. System Events a retourné le nom de fenêtre `CoreTend`.
- Lecture des propriétés détaillées de la fenêtre et de ses éléments via System Events : échec, erreur AppleScript `-10827`.
- Non vérifiés : parcours des huit destinations, clavier/focus, VoiceOver, zoom, contraste, Reduce Motion/Transparency, Quick Look, graphique, états vide/erreur/annulation.
- Résultat : lancement et présence d’une fenêtre observés; qualification d’accessibilité non réalisée. NFR-07 reste PARTIEL.
