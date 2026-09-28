# Programme « Upgrade » — retour du test sur MacBook Air M5 (28-09-2026)

Source : test du mainteneur sur un MacBook Air M5, macOS 27, build notarisé `0.1.0-local`
(captures : `Documentation/Evidence/Captures/2026-09-28-M5/`). Demande : « meilleur menu, meilleure
gestion de l'espace, meilleure gestion des apps, de chaque module, beaucoup de fonctionnalités à
envisager, dont certaines à améliorer, meilleure application, meilleur message de bienvenue,
upgrade l'app ».

Placement : avant P5 (la release 2.0 embarque ces améliorations). Méthode inchangée : un lot à la
fois, `make qualify` + vérification à l'écran, journal dans `P6-upgrade.md`. Aucune règle de
sûreté assouplie (lecture seule par défaut, Corbeille après revue et confirmation, pas de FDA).

## Constats (captures M5)

| # | Constat | Lot |
|---|---|---|
| 1 | Contenu bridé à 960 pt : grande bande vide sur écran large | U1 |
| 2 | Menu de barre des menus en clair quand l'app est en sombre ; texte tronqué | U2 |
| 3 | Vue d'ensemble : « Dernière activité : Échec » sans contexte ; peu d'aide à décider | U3 |
| 4 | Applications : liste longue, sans taille ni tri ; actions répétées sur chaque ligne | U4 |
| 5 | Échec Corbeille sur une app de `/Applications` (« Windows App ») sans explication ni issue | U4 |
| 6 | « Fichiers autour » : aucun candidat pour Chrome (recherche par identifiant seulement) | U4 |
| 7 | Premier lancement : message d'accueil jugé pauvre | U5 |
| 8 | Réglages : feuille étroite, longue colonne à défiler | U6 |
| 9 | Chaque module : fonctions à enrichir (voir U7) | U7 |

## Lots

- **U1 — Espace.** Largeur de lecture adaptative (jusqu'à ~1 280 pt), grilles à deux colonnes
  quand la fenêtre le permet (Vue d'ensemble, Performances, Réglages), listes pleine largeur.
- **U2 — Menu de la barre des menus.** Même apparence que l'app, textes non tronqués,
  compact : 3 mesures, dernière activité lisible, raccourcis vers les destinations.
- **U3 — Vue d'ensemble « tableau de serre ».** Dernière activité avec son objet et sa raison ;
  raccourcis vers les règles de Nettoyage disponibles ; accès direct aux dossiers habituels.
- **U4 — Applications.** Taille de chaque app (lecture seule), tri (nom, taille, version),
  recherche, regroupement (App Store / autres / système), panneau de détail au lieu d'actions
  sur chaque ligne ; échec Corbeille expliqué (app protégée ou appartenant à un administrateur :
  utiliser le Finder) ; « Fichiers autour » élargi au nom de l'app en plus de l'identifiant,
  toujours marqué « correspondance de nom, non prouvée ».
- **U5 — Accueil.** Premier lancement en 3 pages animées (Serre), ce que fait CoreTend, ce qu'il
  ne fait jamais, par où commencer ; message de bienvenue sur la Vue d'ensemble au premier jour.
- **U6 — Réglages.** Fenêtre de réglages macOS dédiée (Settings scene) avec onglets
  (Général, Confidentialité, Données, Avancé) au lieu d'une feuille.
- **U7 — Modules.** Par destination, lot par lot : Nettoyage (taille totale par règle avant
  analyse, sélection par groupe explicite), Explorer (navigation dans les sous-dossiers,
  fil d'Ariane), Doublons (taille récupérable par groupe, comparaison côte à côte),
  Intégrité (lecture de toutes les apps d'un dossier en une passe), Performances (mémoire
  utilisée et pression si mesurable), Historique (filtre par objet).
- **U8 — Qualification.** `make qualify`, captures FR/EN clair/sombre, retest sur le M5 avec un
  nouveau build notarisé.

- **U9 — La serre vivante (demande du 28-09 : « meilleures motions, meilleures animations, l'app
  est une serre vivante en elle-même, va sur ce thème en entier »).** Toute l'app devient une serre :
  - une **scène de serre** en tête de la Vue d'ensemble dont les plantes reflètent l'état mesuré
    (espace libre = sol et pousses, derniers échecs = feuille fanée, analyses récentes = racines) ;
  - chaque destination a sa **plante-signature** qui réagit aux vraies actions (pousse à
    l'analyse, taille au nettoyage, fleurit à la fin) ;
  - **lumière du jour** : l'ambiance suit l'heure locale et l'apparence (aube, midi, soir) ;
  - transitions entre destinations en **croissance organique** (tiges, vrilles), survols qui font
    frémir les feuilles, pluie légère de particules lors d'un déplacement vers la Corbeille ;
  - **respiration ambiante** (balancement lent des feuilles) : proposition de révision de la
    règle « aucune animation au repos » → autorisée seulement fenêtre active et au premier plan,
    à basse cadence, suspendue fenêtre cachée ou inactive, sur batterie faible et sous « Réduire
    les animations », désactivable dans Réglages ; mesure CPU avant/après (NFR-09). **À valider
    par le mainteneur** (amendement de la décision 0002 et du guide § 8).

## Hors périmètre

Accès complet au disque, suppression définitive, désinstallation « totale » des données
associées sans preuve d'appartenance, réseau, télémétrie.
