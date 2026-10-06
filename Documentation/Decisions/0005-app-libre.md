# 0005 — CoreTend libre : hors App Store, sans sandbox

**Date :** 06-10-2026 · **Statut :** acceptée par le mainteneur · **Remplace :** 0004

## Décision

CoreTend quitte le Mac App Store. Une seule édition, complète, signée Developer ID et notarisée,
distribuée par le site, GitHub, Homebrew et npm (CLI et serveur MCP seulement). Version 2.1.
Plan détaillé : document « CoreTend Libre — plan complet ».

## Ce qui reste

- Tout déplacement passe par `SafetyCore` et va à la Corbeille ; jamais d'effacement définitif.
- Revue et confirmation avant tout déplacement ; aucune action destructive automatique.
- Aucune télémétrie, aucun compte, aucun cloud.

## Ce qui change

- Plus d'App Sandbox : l'analyse peut couvrir le dossier personnel entier ; l'accès complet au
  disque est proposé (jamais exigé).
- Réseau : seulement la vérification de mise à jour (Sparkle), visible et désactivable.
- Interface en 4 espaces (Accueil, Espace, Nettoyer, Apps).
- Langue : français si macOS préfère le français, anglais sinon ; plus de choix dans les Réglages.
