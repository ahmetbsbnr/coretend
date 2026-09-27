# CoreTend « Observatoire » — refonte front-end

**Date:** 2026-09-27  
**État:** direction choisie, spécification à relire  
**Périmètre:** application macOS native et site public français/anglais

## Intention

Donner à CoreTend une identité visuelle lisible et cohérente sur le site et dans l’app, puis réorganiser toute l’interface autour de la compréhension et du contrôle laissé à la personne. La direction retenue est **Observatoire** : ardoise profonde, texte ivoire, cyan minéral pour les actions et données, cuivre réservé aux avertissements. L’app montre un instrument calme, dense sans être serré ; le site raconte ce qu’il permet avec de vrais états et des captures de l’application livrée.

Le serveur local `python3 -m http.server 8765 --bind 127.0.0.1 --directory design-preview` sert une maquette exploratoire des trois pistes. Elle est isolée du produit, n’accède à aucun dossier et n’est pas une implémentation de l’app.

## Principes visuels et motion

- Surfaces en bleu ardoise, panneaux de teintes proches, séparations fines, texte ivoire. Une hiérarchie portée par la typographie, l’espace et des graphiques utiles, sans lueur décorative ni grille répétitive de cartes.
- Un seul accent d’action : cyan minéral. Cuivre pour l’avertissement ; corail pour les erreurs et conséquences destructrices. Chaque état porte également libellé et pictogramme.
- SF dans l’app ; site avec pile système locale et mono pour mesures, versions et commandes. Pas de chargement distant de police.
- Rayon principal autour de 12–16 pt dans l’app ; grille de 8 pt ; cibles interactives d’au moins 44 pt. Réorganisation fluide quand la fenêtre rétrécit ; texte jamais coupé pour gagner de la place.
- App : fondu et translation de 4–8 pt lors d’un changement de vue, transitions interrompables de 180–280 ms ; valeur mesurée anime seulement son tracé/progression après mise à jour. Confirmation et annulation visibles sans animation obligatoire.
- Site : une séquence d’entrée dans le hero, puis un mouvement de données guidé par le défilement dans une section produit. Le texte reste lisible sans script ; pas de défilement capturé, d’autoplay sonore ou de contenu masqué en attente d’un observateur.
- Respect de `prefers-reduced-motion` côté site et de Reduce Motion côté app : transitions coupées ou raccourcies, contenu et contrôles immédiatement accessibles.
- Le prototype utilise des mesures fictives signalées. La production utilise des captures vérifiées de la version de l’app, avec provenance, version, texte alternatif et métadonnées non essentielles retirées. Pas d’interface de produit générée.

## Application macOS

Conserver les destinations et contrats métier actuels ; refaire la composition, la navigation, la densité et les états en SwiftUI. Navigation principale en sidebar native, largeur minimum exploitable, repli possible et sélection persistée. Groupes proposés :

1. **Votre Mac** : Vue d’ensemble, Explorer l’espace, Nettoyage, Doublons.
2. **Comprendre** : Applications, Intégrité, Performances, Historique.
3. **Bas de sidebar** : état « Local et privé » avec explication concise, puis Réglages.

`⌘K` ouvre la palette de commandes et de destinations ; réglages restent dans une fenêtre/presentation macOS native ; menu-bar extra garde ses mesures et raccourcis existants. Menus Fichier, Édition, Présentation, Fenêtre et Aide restent natifs. Sidebar compacte remplace le split view si la fenêtre ne peut plus offrir la largeur utile.

### Écrans et états

- **Vue d’ensemble** : une rangée de mesures macOS avec source et heure, activité récente ou état vide, visualisation de stockage seulement après analyse réelle, rappel de contrôle et action « Analyser un dossier ». Pas de faux score de santé ni de résultat avant mesure.
- **Explorer l’espace** : sélection du dossier, recherche/tri, visualisation proportionnelle au contenu mesuré, liste détaillée et aperçu. Sélection de retrait ouvre revue puis confirmation ; résultat, échec partiel et annulation restent explicites.
- **Nettoyage** : règles connues, séparées par niveau de risque, aucune préselection, dossier exact à choisir, candidats à examiner puis confirmation avant Corbeille.
- **Doublons** : groupes fondés sur comparaison exacte, paire/groupe détaillé, suggestion conservatoire identifiée comme telle, choix explicite par fichier, déplacement seulement après revue et confirmation.
- **Applications** : inventaire du dossier choisi et limites des métadonnées ; examen du déplacement d’un seul bundle choisi, données associées explicitement conservées.
- **Intégrité** : signature, identifiant, équipe, statut et marque de quarantaine comme signaux distincts ; résultats indisponibles et limites formulés près du signal.
- **Performances** : mesures séparées de CPU, mémoire, espace et état thermique selon les capacités réelles ; étiquettes source/heure ; historique borné, état vide et erreur de stockage.
- **Historique** : chronologie locale filtrable, export, effacement confirmé, états vide/indisponible ; avertissement sur noms/chemins dans les exports.
- **Réglages, commande rapide, onboarding et menu-bar** : même palette et typographie ; groupes réglages (apparence/langue, vie privée et accès, options d’historique), état désactivé explicite et aide contextuelle.

Chaque écran fournit états initial, en cours, résultats, vide, partiel, permission refusée, inaccessible et erreur lorsque pertinents. Tout scan reste en lecture seule ; toute action de retrait nécessite choix, revue, confirmation et envoi à la Corbeille. Cette refonte ne modifie ni périmètres d’accès, ni règles métier, ni persistance.

## Site public

Appliquer l’identité à toutes les pages FR et EN existantes : Accueil, Fonctionnalités, Confidentialité, Développeur et Assistance. Navigation persistante : logo, Fonctionnalités, Confidentialité, Développeur, Assistance, choix de langue et bouton Télécharger toujours associé à la version/architecture réellement publiée.

- **Accueil** : proposition directe, vraie capture produit dans un cadre macOS, téléchargements et preuve de confidentialité ; ensuite scènes produit (espace, doublons, contrôle), compatibilité et accès aux aides.
- **Fonctionnalités** : sections par tâche, avec résultat observable, limites et capture réelle pertinente.
- **Confidentialité** : flux local expliqué, autorisations choisies, modèle de menace, limites et contact sécurité.
- **Développeur** : capacités/limites, intégration CLI, commandes, contrats et prérequis, présentés comme documentation lisible.
- **Assistance** : installation/mises à jour, accès dossiers, erreurs courantes, désinstallation et contact.

Desktop : composition éditoriale large, scènes produit immersives et sombres ; mobile : navigation accessible, captures recadrées avec contrôle, pile de sections sans débordement horizontal. Conserver liens bilingues, skip link, focus visible, pied de page licences/sécurité/source, métadonnées SEO et lecture sans JavaScript.

## Architecture d’interface et partage

- SwiftUI reste propriétaire des vues et comportements natifs de l’app ; `DesignSystem` devient propriétaire des rôles et valeurs d’apparence adaptatives consommés par les composants SwiftUI.
- Site statique reste généré/servi par le mécanisme existant. Un export contrôlé de jetons sémantiques du DesignSystem alimente les variables CSS ; aucun hex saisi indépendamment dans une page.
- Composants communs limités aux rôles, échelle, rayons et temporisations ; motifs réellement natifs peuvent différer. Le contenu réel et la logique restent côté app/site comme aujourd’hui.
- Le prototype `design-preview/` reste une référence de discussion et n’est ni inclus dans le build/release, ni chargé par le site public.

## Critères d’acceptation

1. Chaque destination native, Réglages, palette de commandes, menu-bar et chaque page FR/EN présente identité, structure et hiérarchie de la direction Observatoire.
2. Sidebar/site navigation compréhensibles au clavier ; destinations restaurées, langue et apparence respectées.
3. États vide, progression, partiel, refus et erreur relus pour tous les flux concernés ; aucun faux résultat ni perte d’un avertissement de sûreté.
4. Jetons app/site cohérents, contraste corps ≥ 4.5:1 et contrôles essentiels ≥ 3:1 en thèmes clair et sombre ; tailles de fenêtre/mobile et zoom texte réorganisent le contenu sans coupure.
5. Mouvements respectent Reduce Motion et ne conditionnent jamais l’accès au contenu. Site compréhensible sans JavaScript.
6. Captures site vérifiées sur le produit livré ; données fictives de la bêta absentes du site publié.
7. Aucune modification des contrats CLI, du domaine, des accès fichiers et des décisions explicites de suppression.

## Hors périmètre

Reconstruction du moteur d’analyse, nouvelles catégories de scan, synchro/cloud, collecte analytique, authentification, changements au modèle de sécurité ou à la licence, génération d’images de fausse interface, publication et notarisation.
