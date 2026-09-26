# Guide utilisateur — aperçu local

CoreTend n’est pas distribué. Pour essayer l’aperçu depuis le code, construisez `CoreTendApp`, ouvrez l’app locale, puis sélectionnez un dossier explicite dans Explorer, Doublons ou Nettoyage.

Les scans sont en lecture seule. Explorer propose recherche, tri et carte proportionnelle basée uniquement sur octets locaux connus; valeurs inconnues restent exclues de la carte. Les exclusions choisies dans Réglages s’appliquent à Explorer, Doublons et Nettoyage. Le scan exact des doublons lit le contenu pour calculer SHA-256; les résultats proposent un exemplaire à garder, jamais sélectionné pour déplacement. Explorer, Doublons et Nettoyage permettent de sélectionner des candidats. Toute action exige une revue des noms, une confirmation explicite, un événement « proposé » enregistré avant confirmation, une nouvelle validation du chemin et un déplacement vers la Corbeille macOS. Une annulation est journalisée. Aucune suppression permanente n’est disponible. Historique permet de consulter, filtrer, exporter ou effacer après confirmation les événements locaux. Réglages permet l’import opt-in du seul format de préférences v1 reconnu et l’export d’un diagnostic sans chemin personnel ni détail d’événement, après aperçu. L’accueil explique le choix explicite de dossiers et l’absence de demande d’accès intégral au disque.

Le CLI exige `--root` pour scanner et `--store` pour consulter un historique local. Ne partagez pas sa sortie sans vérifier les noms et chemins qu’elle contient. Aucune fonction de nettoyage automatique ou de suppression permanente n’existe.

Dans Applications, **Rechercher des fichiers associés** demande un dossier explicite. CoreTend ne retient que les noms contenant un composant exactement égal à l’identifiant de bundle. Ce signal ne prouve pas l’appartenance; les candidats restent consultatifs et aucune action n’est proposée.
# Images similaires

Dans **Doublons**, choisissez **Images similaires**, puis sélectionnez un dossier. CoreTend calcule localement une empreinte visuelle réduite pour les fichiers image pris en charge et présente les paires candidates. Cette comparaison heuristique peut manquer des ressemblances ou rapprocher des images distinctes. Elle ne supprime rien; examinez les deux fichiers vous-même.

Dans **Performances**, chaque ouverture ou clic sur **Actualiser** ajoute un relevé local daté. La charge système sur une minute provient de macOS; ce nombre n’est pas un pourcentage CPU. Le graphique montre les relevés connus sous forme de points. Les valeurs indisponibles restent inconnues. L’historique conserve 30 jours et au plus 500 relevés; aucun échantillonnage continu en arrière-plan.
