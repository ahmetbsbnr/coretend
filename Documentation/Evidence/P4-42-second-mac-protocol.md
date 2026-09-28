# P4 · 4.2 — Protocole « second Mac » (MacBook M5, macOS 27)

Objectif : une preuve de compatibilité sur un second hôte, observée par le mainteneur. Ne
remplace pas l'hôte macOS 14, qui reste manquant.

## Paquet

- Fichier : `Artifacts/CoreTend-local-unsigned.zip`, construit par `make package-local` depuis
  `next` au commit `b5598788` (28-09-2026).
- SHA-256 : `e64eb42d1cd0d3cbbdd4ffcf988191ed4652e431b095685c61193166553c9dde`.
- Non signé, non notarisé : TestFlight et la notarisation demandent une identité Apple
  Developer, absente de l'hôte de développement (`security find-identity` : 0 identité).

## Installation sur le Mac M5

1. Transférer le ZIP (AirDrop), vérifier l'empreinte : `shasum -a 256 CoreTend-local-unsigned.zip`.
2. Décompresser, placer `CoreTend.app` dans `~/Applications` (pas besoin de droits admin).
3. Premier lancement : clic droit › Ouvrir, puis confirmer (ou Réglages Système ›
   Confidentialité et sécurité › « Ouvrir quand même »). Aucun autre réglage à modifier.

## À observer (noter OUI / NON / remarque)

1. Premier lancement : logo qui germe, trois étapes, bouton Commencer.
2. Chaque destination de la barre latérale s'ouvre (⌘1…⌘8) ; la vue pousse depuis la ligne.
3. ⌘K ouvre la recherche depuis le bouton ; un clic hors de la boîte la ferme.
4. Vue d'ensemble : chiffre d'espace libre et bande de sol cohérents avec « À propos de ce Mac ».
5. Explorer sur un dossier choisi (ex. Téléchargements) : racines, parcelles, liste.
6. Performances : Actualiser plusieurs fois, la courbe se trace.
7. Clair / sombre (Réglages › Apparence) et FR / EN (Réglages › Langue).
8. Aucune alerte de plantage ; aucune demande d'accès complet au disque.

**Ne confirmer aucun déplacement vers la Corbeille** sur de vrais fichiers pendant ce test.

## Retour

Envoyer : modèle et version de macOS exacts (menu Pomme › À propos de ce Mac), la liste
ci-dessus remplie, et toute capture d'écran utile. L'agent l'ajoute au registre (NFR-08, 4.2)
avec la date ; statut `VÉRIFIÉ` seulement pour la part observée.
