# TODO — CoreTend (post-refonte site monopage)

Statut : la refonte du site monopage est **validée**. Ne plus modifier son architecture
sauf pour corriger un défaut réel. Le bouton direct, la simplicité, la DA, les
redirections et la synchronisation de version correspondent à la demande.

Le projet complet n'est **pas** terminé. Problèmes critiques non résolus :

1. l'application n'a pas fonctionné lors d'un test sur un autre Mac ;
2. le DMG drag-and-drop est visuellement mauvais ;
3. le parcours d'installation client complet n'a pas été validé ;
4. les crash tests complets n'ont pas été exécutés ;
5. l'attestation GitHub n'a pas été vérifiée ;
6. le workflow planifié de synchronisation du portfolio n'a jamais été exécuté automatiquement.

---

## 1. Reproduire le problème de lancement sur un Mac propre

Blocage prioritaire absolu. Ne pas supposer que la cause est uniquement Gatekeeper.

Tester l'artefact public exact téléchargé depuis <https://coretend.ahmetbsbnr.com/download>.

Conditions les plus proches d'un nouveau client :

- [ ] nouveau compte utilisateur macOS
- [ ] HOME vierge
- [ ] aucun cache CoreTend
- [ ] aucune préférence existante
- [ ] aucun outil de développement supposé installé
- [ ] ancien scanner externe absent
- [ ] application téléchargée depuis la release publique
- [ ] attribut de quarantaine présent
- [ ] copie depuis le DMG vers Applications
- [ ] premier lancement depuis Finder
- [ ] lancement par clic droit → Ouvrir
- [ ] lancement depuis Réglages Système → Confidentialité et sécurité → Ouvrir quand même
- [ ] lancement hors ligne
- [ ] second lancement
- [ ] lancement après redémarrage
- [ ] lancement en français et en anglais

Matrices à couvrir autant que possible :

- [ ] une autre version compatible de macOS
- [ ] Apple Silicon
- [ ] Intel (uniquement si le projet affirme une compatibilité Intel)
- [ ] environnement virtualisé propre lorsque disponible

## 2. Obtenir la cause exacte

Collecter et analyser les preuves réelles :

- [ ] Console macOS
- [ ] rapports de crash
- [ ] rapports de diagnostic
- [ ] `log show` filtré sur CoreTend
- [ ] `open -a CoreTend`
- [ ] lancement direct du binaire dans `Contents/MacOS`
- [ ] `codesign -dvvv`
- [ ] `codesign --verify --deep --strict --verbose=4`
- [ ] `spctl --assess --type execute --verbose=4`
- [ ] `xattr -lr`
- [ ] `otool -L`
- [ ] `file`
- [ ] `lipo -info`
- [ ] contenu et permissions du bundle
- [ ] ressources réellement embarquées
- [ ] Info.plist
- [ ] entitlements
- [ ] chemins absolus codés en dur
- [ ] dépendances dynamiques manquantes
- [ ] erreurs liées aux préférences, dossiers ou permissions

Déterminer factuellement si l'échec vient de : Gatekeeper, absence de signature, crash
applicatif, dépendance manquante, ressource absente, incompatibilité macOS,
incompatibilité d'architecture, erreur de première initialisation, ancien scanner externe, un chemin
local présent uniquement sur la machine de développement, ou plusieurs causes combinées.

**Ne pas conclure sans preuve.**

## 3. Corriger le lancement

Corriger toute cause applicative ou de distribution reproductible. L'application doit
démarrer proprement même lorsque :

- [ ] ancien scanner externe est absent
- [ ] le réseau est indisponible
- [ ] les préférences n'existent pas
- [ ] les dossiers de travail n'existent pas
- [ ] une permission est refusée
- [ ] une base locale est vide ou corrompue
- [ ] la vérification de mise à jour échoue

Aucune dépendance optionnelle ne doit empêcher l'ouverture de l'interface. En cas
d'erreur récupérable, afficher une interface compréhensible au lieu de quitter ou rester
invisible.

- [ ] ajouter les tests de non-régression nécessaires

## 4. Refaire entièrement le DMG

Le DMG actuel est refusé visuellement. Le recréer depuis zéro avec exactement la même
direction artistique que l'application CoreTend, le nouveau site monopage et le portfolio.

Composition premium et minimaliste :

- [ ] fond personnalisé en haute résolution
- [ ] palette paper / ink / cobalt du projet
- [ ] grain ou texture discrète
- [ ] logo CoreTend correctement dimensionné
- [ ] icône CoreTend à gauche
- [ ] dossier Applications à droite
- [ ] indication visuelle élégante entre les deux
- [ ] texte minimal
- [ ] aucune décoration générique macOS
- [ ] aucun élément technique visible
- [ ] aucun fichier inutile

Le fond ne doit pas être une couleur unie ni un gradient improvisé. Vraie composition
graphique cohérente avec le hero du site :

- [ ] symbole CoreTend
- [ ] halo cobalt subtil
- [ ] ligne ou mouvement visuel dirigeant vers Applications
- [ ] hiérarchie claire
- [ ] beaucoup d'espace maîtrisé
- [ ] rendu Retina net

## 5. Dimensions et disposition du DMG

Calculer et vérifier précisément :

- [ ] dimensions de la fenêtre
- [ ] ratio du fond
- [ ] position initiale
- [ ] taille des icônes
- [ ] coordonnées des icônes
- [ ] espacement entre CoreTend et Applications
- [ ] visibilité des libellés
- [ ] contraste
- [ ] marges
- [ ] rendu sur écrans Retina et non-Retina
- [ ] absence de scroll
- [ ] absence de barre latérale Finder
- [ ] vue en icônes
- [ ] ordre visuel
- [ ] image de fond correctement embarquée

Contenu du volume, strictement :

- [ ] `CoreTend.app`
- [ ] alias vers `/Applications`
- [ ] ressources invisibles indispensables au fond

Aucun README, fichier caché parasite, archive ou script visible.

## 6. Tester réellement le DMG

Comme un client :

1. [ ] téléchargement depuis GitHub
2. [ ] vérification SHA-256
3. [ ] montage
4. [ ] affichage correct du fond
5. [ ] alignement des icônes
6. [ ] glisser-déposer
7. [ ] remplacement d'une ancienne version
8. [ ] démontage
9. [ ] lancement depuis Applications
10. [ ] relance après redémarrage
11. [ ] suppression et réinstallation
12. [ ] test avec attribut de quarantaine
13. [ ] vérification de l'absence de dépendances au volume monté

Captures du DMG final (à inspecter réellement avant publication) :

- [ ] fenêtre complète
- [ ] Retina
- [ ] taille normale
- [ ] icône en cours de déplacement vers Applications

## 7. Parcours client complet

Test de bout en bout depuis zéro :

1. [ ] arrivée sur le site
2. [ ] clic sur Télécharger
3. [ ] téléchargement direct
4. [ ] ouverture du DMG
5. [ ] copie dans Applications
6. [ ] premier lancement
7. [ ] traitement de l'avertissement macOS officiel
8. [ ] ouverture de CoreTend
9. [ ] onboarding
10. [ ] ancien scanner externe absent
11. [ ] installation ou guidance ancien scanner externe
12. [ ] première analyse
13. [ ] affichage des résultats
14. [ ] erreur et récupération
15. [ ] fermeture
16. [ ] relance
17. [ ] recherche de mise à jour
18. [ ] désinstallation
19. [ ] réinstallation

Pour chaque étape vérifier : compréhension, cohérence visuelle, absence d'ambiguïté,
absence de crash, absence de blocage, messages professionnels, français et anglais,
navigation clavier, VoiceOver lorsque testable.

## 8. Crash tests complets

Ajouter et exécuter au minimum :

- [ ] 50 lancements à froid successifs
- [ ] fermeture forcée au démarrage
- [ ] fermeture pendant une analyse
- [ ] fermeture pendant la détection de ancien scanner externe
- [ ] fermeture pendant une vérification de mise à jour
- [ ] préférences invalides
- [ ] préférences tronquées
- [ ] fichiers de cache corrompus
- [ ] dossiers inexistants
- [ ] dossiers inaccessibles
- [ ] permissions refusées
- [ ] fichiers vides
- [ ] fichiers corrompus
- [ ] fichiers très volumineux
- [ ] plusieurs milliers de fichiers
- [ ] noms Unicode
- [ ] emojis
- [ ] espaces
- [ ] caractères spéciaux
- [ ] chemins très longs
- [ ] liens symboliques
- [ ] liens symboliques cycliques
- [ ] fichiers supprimés pendant l'analyse
- [ ] volume externe démonté pendant l'analyse
- [ ] disque presque plein, simulé sans danger
- [ ] mémoire sous pression
- [ ] CPU sous charge
- [ ] ancien scanner externe absent
- [ ] ancien scanner externe incomplet
- [ ] binaire ancien scanner externe invalide
- [ ] base antivirus absente
- [ ] base antivirus obsolète
- [ ] base antivirus corrompue
- [ ] réseau absent
- [ ] manifeste de mise à jour inaccessible
- [ ] manifeste invalide
- [ ] réponse HTTP inattendue
- [ ] timeout
- [ ] annulation utilisateur
- [ ] relance après crash
- [ ] veille et réveil pendant une opération
- [ ] changement de langue
- [ ] redimensionnement extrême
- [ ] plusieurs fenêtres ou commandes répétées rapidement

Aucun test ne doit supprimer ou modifier des données réelles de l'utilisateur.
Utiliser des dossiers temporaires et un HOME isolé.

## 9. Mesures de stabilité

- [ ] temps de lancement à froid
- [ ] temps jusqu'à la première fenêtre
- [ ] mémoire au repos
- [ ] mémoire durant une analyse
- [ ] CPU au repos
- [ ] CPU durant une analyse
- [ ] croissance mémoire sur une session prolongée
- [ ] comportement après 100 opérations répétées
- [ ] éventuelles fuites ou handles non libérés
- [ ] corriger les anomalies reproductibles

## 10. Nouvelle release

Si le code de l'application, le bundle ou le DMG change : publier une nouvelle release
candidate. Ne pas remplacer silencieusement les artefacts de `v0.9.1-rc.2`. Utiliser la
prochaine version cohérente, par exemple `v0.9.1-rc.3`.

- [ ] pointer sur le commit corrigé
- [ ] contenir le nouveau DMG
- [ ] contenir le ZIP correspondant
- [ ] contenir les checksums
- [ ] contenir les signatures Minisign
- [ ] contenir le SBOM
- [ ] contenir l'attestation
- [ ] contenir les notes de correction
- [ ] mettre à jour le site
- [ ] mettre à jour le portfolio
- [ ] être détectée par l'updater

## 11. Vérifier réellement l'attestation

Non terminée tant qu'aucune sortie vérifiable n'existe. Après publication de la nouvelle RC :

- [ ] télécharger l'artefact public
- [ ] utiliser la commande GitHub officielle de vérification
- [ ] indiquer explicitement le dépôt attendu
- [ ] vérifier que l'attestation correspond au workflow et au commit du tag
- [ ] conserver la sortie de vérification
- [ ] corriger le workflow en cas d'échec

## 12. Vérifier la synchronisation automatique du portfolio

Le workflow planifié doit être exécuté réellement au moins une fois. Déclencher via
`workflow_dispatch`, puis vérifier :

- [ ] récupération du manifeste public
- [ ] absence de modification lorsqu'il est déjà synchronisé
- [ ] mise à jour correcte avec une version de test contrôlée lorsque simulable
- [ ] typecheck
- [ ] build
- [ ] commit automatique uniquement lorsqu'un changement existe
- [ ] absence de boucle de commits
- [ ] déploiement Vercel
- [ ] version correcte en production

Un workflow seulement planifié ne constitue pas une validation.

## 13. Site et documentation

Le site monopage doit rester simple. N'ajouter aucune nouvelle section technique.
Corriger seulement si nécessaire :

- [ ] la version
- [ ] la cible du téléchargement
- [ ] les notes concernant l'ouverture sur macOS
- [ ] le lien vers la nouvelle release
- [ ] le statut de signature
- [ ] les médias liés au nouveau DMG

Les détails techniques restent sur GitHub.

## 14. Conditions de fin

Le travail est terminé uniquement lorsque :

- [ ] la cause de l'échec sur l'autre Mac est identifiée
- [ ] toute cause corrigible est corrigée
- [ ] le premier lancement fonctionne dans un environnement propre
- [ ] le DMG est entièrement redessiné
- [ ] le DMG reprend exactement la DA CoreTend
- [ ] le glisser-déposer est fonctionnel
- [ ] les crash tests sont exécutés
- [ ] les défauts reproductibles sont corrigés
- [ ] le parcours client complet est validé
- [ ] une nouvelle RC est publiée si les artefacts ont changé
- [ ] le site télécharge cette nouvelle RC
- [ ] le portfolio affiche cette nouvelle RC
- [ ] l'updater détecte cette nouvelle RC
- [ ] l'attestation est réellement vérifiée
- [ ] la synchronisation automatique du portfolio est réellement exécutée
- [ ] les CI sont vertes
- [ ] les productions sont vérifiées

## 15. Rapport final uniquement

Aucun plan ni checkpoint. Le rapport final doit contenir :

- cause exacte du lancement défaillant
- logs ou preuves utilisés
- correction appliquée
- commit final
- tag final
- URL de la nouvelle release
- captures du nouveau DMG
- dimensions et coordonnées du DMG
- résultat du parcours client
- liste complète des crash tests
- défauts trouvés
- défauts corrigés
- mesures de stabilité
- SHA-256 des artefacts publics
- résultat Minisign
- résultat de l'attestation GitHub
- résultat du workflow de synchronisation
- versions affichées par l'app, GitHub, le site et le portfolio
- preuve que le téléchargement public fonctionne sur un environnement propre
- seules limites réellement impossibles

**Ordre d'attaque :** reproduire le lancement défaillant avec le DMG public → corriger
l'application → reconstruire entièrement le DMG → publier.
