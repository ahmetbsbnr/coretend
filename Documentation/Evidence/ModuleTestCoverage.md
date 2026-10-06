# Couverture des modules — 2026-10-02

## Tests automatisés

| Module visible | Couverture des comportements |
|---|---|
| Vue d’ensemble | `AppShellTests`: routes, commandes, libellés FR/EN, mesures et fractions; `SystemMetricsTests`; recette native: titre de l’écran et contrôles AX |
| Explorer | `ScanCoreTests`: recherche, catégories, filtres, carte, annulation; `DomainTests`: actions, favoris/récents; recette native: sélection de ligne et annulation de confirmation |
| Nettoyage | `ScanCoreTests`: règles et périmètres; `SafetyCoreTests`/`DomainTests`: revue et refus; recette native: choix de règle, scan, sélection, revue et annulation |
| Doublons | `ScanCoreTests`: copies exactes/proches, keeper, liens; `DomainTests`: action avec fausse Corbeille; recette native: groupe, sélection et annulation |
| Applications | `AppDiscoveryTests`/`DomainTests`: inventaire, tri, métadonnées et revue; recette native: inventaire et contrôles de module |
| Intégrité | `DomainTests`: signature, quarantaine, LaunchAgents, liens et limites de lecture; recette native: rapport et ouverture/annulation des sélecteurs |
| Performances | `SystemMetricsTests`, `DomainTests`, `PersistenceTests`: mesures, sélection, historique et purge; recette native: rafraîchissement et annulation de purge |
| Historique | `DomainTests`/`PersistenceTests`: filtres, périodes, groupement, export JSON/CSV et effacement; recette native: état vide désactive l’effacement et exporteur s’ouvre puis s’annule |
| Réglages, navigation, palette | `AppShellTests`/`CoreTendPreferencesTests`; recette native: clic des huit destinations, onglets, interrupteurs, panneau d’accès, aperçu privé, champ de recherche et ouverture |
| Composants visuels | `DesignSystemTests`: contraste, jetons, formes, icônes, motion et Reduce Motion |

Lancer les contrôles de fonctions avec `swift test`. Lancer les parcours SwiftUI du bureau avec
`make test-native-ui`; l’hôte doit autoriser l’accès Accessibilité. Le banc installe un paquet local
dans un HOME et un store temporaires, crée les données d’essai sous ce HOME, et annule les
confirmations destructives. La fausse Corbeille est limitée au store temporaire et sa validation
de chemin est couverte par `TestStoreOverrideTests`.

La recette vérifie les surfaces et interactions représentatives par l’API Accessibilité native;
elle ne garantit pas chaque combinaison d’état, de taille ou de système. Les sélecteurs système
sont ouverts puis annulés. Les captures visuelles relèvent de `make capture-screens` et de leur
inspection séparée.
