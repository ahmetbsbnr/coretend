# Preuve de qualification accessibilité

## Essai de lancement isolé — 26-09-2026

- Hôte : macOS 27.0 (26A428), arm64.
- Artefact : `Artifacts/CoreTend.app`, copie locale du ZIP unsigned SHA-256 `94503244830030785388e6ea2359dc844af22d719d5e82729f14408f1697a299`.
- Isolation : bundle copié dans `/private/tmp/coretend-ui-qual.rIdehA/home/Applications`; lancement avec ce chemin comme `HOME`.
- `/usr/bin/env HOME=/private/tmp/coretend-ui-qual.rIdehA/home open -n /private/tmp/coretend-ui-qual.rIdehA/home/Applications/CoreTend.app` : code retour 0. System Events a retourné le nom de fenêtre `CoreTend`.
- Lecture des propriétés détaillées de la fenêtre et de ses éléments via System Events : échec, erreur AppleScript `-10827`.
- Non vérifiés : parcours des huit destinations, clavier/focus, VoiceOver, zoom, contraste, Reduce Motion/Transparency, Quick Look, graphique, états vide/erreur/annulation.
- Résultat : lancement et présence d’une fenêtre observés; qualification d’accessibilité non réalisée. NFR-07 reste PARTIEL.

## P4 — lot 4.1, préparation du 28-09-2026

### Périmètre et preuves agent

- Base : `fa9132ed`, macOS 27 arm64 ; G3 acceptée par le mainteneur (« validé,
  continue »). Cette acceptation ne décrit pas de nouvelles observations d’accessibilité.
- Revue de `Palette.swift`, `Typography.swift`, `Motion.swift`, `SerreButtonStyle.swift`,
  `SerreSidebar.swift`, `SerreSurfaces.swift`, `SerreControls.swift`, `SerreLogo.swift`
  et `SerreActionKit.swift`. Aucun changement de code.
- Calcul WCAG indépendant exécuté en Python à partir des valeurs RGB du dépôt : minima
  sur canvas/sidebar/surface/raisedSurface, colonnes clair/sombre :

| Rôle | Clair | Sombre |
|---|---:|---:|
| ink | 12,51 | 12,19 |
| secondaryInk | 6,95 | 8,47 |
| tertiaryInk | 4,94 | 5,01 |
| accent / focus | 4,86 | 9,03 |
| caution | 4,65 | 7,45 |
| danger | 4,70 | 5,50 |
| strongSeparator | 3,31 | 3,54 |
| onAccent sur accent | 5,77 | 11,70 |
| onAccent sur danger | 5,57 | 7,12 |

Ces calculs couvrent les couleurs opaques au repos, pas les compositions alpha,
le survol (`brightness`), les contrôles désactivés, graphiques et captures réelles.
Les textes désactivés ont une opacité de 0,4 ; ne pas extrapoler les ratios ci-dessus.

- Toutes les polices partagées utilisent `relativeTo`; cela ne prouve pas l’agrandissement
  effectif ni l’absence de troncature sous macOS.
- Aucun `repeatForever`, matériau SwiftUI ou appel `.blur(` trouvé dans `Sources`.
  Les fonds principaux sont opaques ; scrim et certaines teintes décoratives utilisent
  des opacités. Reduce Transparency réel et matériaux des contrôles système restent à observer.
- Les principaux effets Serre lisent `accessibilityReduceMotion`. `FallingLeaf` dépend
  de la garde de `LeafFlight.send`; aucune animation de déplacement n’a été exercée ici.
- **Point à observer, pas défaut confirmé :** Rechercher et Réglages dans la sidebar
  désactivent `serreFocusRing`, tandis que l’indicateur du conteneur est sur la destination
  sélectionnée. Vérifier que le focus individuel de ces deux boutons est visible et fidèle.
- Les observations clavier antérieures sont conservées dans le registre NFR-07 ;
  elles ne constituent pas un nouveau parcours runtime sur ce lot.

### Recette mainteneur — résultats à consigner

Lancer uniquement une **copie en fixture isolée**, selon
`Documentation/Passation/Reference.md` (HOME, CFFIXED_USER_HOME, store et TMPDIR temporaires).
Ne pas scanner un dossier personnel ; utiliser un corpus jetable explicitement choisi.
**Ne jamais confirmer un déplacement vers la Corbeille dans l’app packagée.**
L’agent ne modifie pas les préférences système et n’active pas VoiceOver sur l’hôte.
Le mainteneur choisit les réglages d’assistance sur son environnement de recette.

Noter : build/commit, version macOS, langue, apparence, réglages d’assistance, résultat
PASS/FAIL et description précise du défaut (contrôle, phrase prononcée, touche, capture).
Un seul « validé » ne documente pas chaque critère NFR-07.

Pour **chaque ligne** ci-dessous, vérifier :

1. Clavier : Tab/Maj-Tab, activation par clavier, focus visible sans souris ; destinations
   par ⌘1…⌘8, flèches sidebar, retour après palette/Réglages. Aucun piège de focus.
2. VoiceOver : noms et rôles des commandes, titre, ordre de lecture ; décoration ignorée,
   risque/état exprimés en mots ; chiffres, sources et dates compréhensibles.
3. Texte agrandi et zoom 200 % disponibles sur l’hôte : noter séparément le mécanisme utilisé
   (zoom d’écran ne prouve pas le reflow du texte). À fenêtre étroite, tous les contrôles
   restent atteignables et aucun texte indispensable n’est tronqué.
4. Clair/sombre, FR/EN : lisibilité au repos/survol/focus/sélection, états distincts sans couleur.
5. Reduce Motion : changement de destination, palette, logo et progrès sans déplacement
   animé ; aucun mouvement au repos. Reduce Transparency : contenu et focus lisibles.

| Surface | Complément propre à la surface | Résultat humain |
|---|---|---|
| Vue d’ensemble | Valeurs mesurées, chemins vers Explorer/Historique | À observer |
| Nettoyage | Risque, sélection, revue ; Annuler par défaut, quitter sans confirmer | À observer |
| Explorer | Racine, progression, résultats, équivalent liste de la carte | À observer |
| Doublons | Groupe, exemplaire conservé, sélection et comparaison ; aucun déplacement | À observer |
| Applications | Recherche/effacement, inventaire et détail ; aucun déplacement | À observer |
| Intégrité | Choix du fichier jetable, signaux textuels et limites d’interprétation | À observer |
| Performances | Valeurs/sources/dates, points réellement mesurés et lecture du graphe | À observer |
| Historique | Recherche, filtres, pagination, vide ; quitter toute confirmation | À observer |
| Réglages | FR/EN, focus de chaque contrôle, défilement, Terminé/Done | À observer |
| Palette ⌘K | Focus initial, flèches/Retour, recherche vide, fermeture et retour de focus | À observer |
| Barre des menus | Ouverture, valeurs, destinations, fermeture et focus | À observer |
| Premier lancement | Lecture des trois étapes, focus et Commencer | À observer |

Escape n’atteignait pas l’app lors des essais précédents sur cet hôte : noter le résultat
sans modifier les raccourcis système. En cas de défaut, préciser une reproduction sur
fixture ; corriger avant de clore 4.1. **NFR-07 reste PARTIEL ; G4 non passée.**

### Vérification automatique de préparation

`export PATH=/opt/homebrew/bin:$PATH; make qualify` : PASS, code 0 le 28-09-2026.
Journal local : `/tmp/coretend-qualify-p4-41.log`. `git diff --check` : PASS.
Ces commandes n’activent pas VoiceOver et ne qualifient pas les observations humaines ci-dessus.

DesignSystemTests : 17 tests exécutés, 0 échec, 1 ignoré (`testRenderSheet`).
Les tests de contraste, de tokens Reduce Motion et de formes de risque passent ;
la feuille de rendu ignorée ne constitue pas une preuve visuelle nouvelle.
