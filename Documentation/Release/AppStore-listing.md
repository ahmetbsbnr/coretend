# Fiche App Store — CoreTend 2.0

À coller dans App Store Connect. Longueurs vérifiées par `Scripts/check_appstore_listing.py`
(nom et sous-titre ≤ 30, texte promotionnel ≤ 170, mots-clés ≤ 100, description ≤ 4000).

## Informations générales

- **Nom :** CoreTend
- **Catégorie principale :** Utilitaires · **secondaire :** Productivité
- **Prix :** gratuit · **Disponibilité :** tous les pays
- **Classification :** 4+ (aucun contenu à déclarer)
- **Copyright :** © 2026 Ahmet Basbunar
- **URL d'assistance :** https://coretend.ahmetbsbnr.com/en/support
- **URL marketing :** https://coretend.ahmetbsbnr.com/
- **URL de confidentialité :** https://coretend.ahmetbsbnr.com/en/privacy
- **Chiffrement (export) :** n'utilise pas de chiffrement (`ITSAppUsesNonExemptEncryption` = NO)
- **Confidentialité de l'app :** Données non collectées (aucun réseau, aucun compte, aucune analyse)

<!-- listing:en -->
## English (U.S.)

**Subtitle:** Your Mac, tended like a garden

**Promotional text:** A living greenhouse for your Mac: see what takes space, understand it, and prune only what you choose. Every move goes to the Trash. Nothing leaves your Mac.

**Keywords:** disk space,storage,duplicates,cache,files,trash,cleanup,analyzer,apps,privacy,local,folders

**Description:**

CoreTend looks after your Mac like a greenhouse. It observes, explains what it finds, and prunes only what you choose — every move goes to the macOS Trash, and nothing leaves your Mac.

EIGHT TOOLS, ONE GREENHOUSE
• Overview — free space as macOS measures it, and the last things CoreTend did and why.
• Explore — choose a folder: every file and subfolder becomes a plot sized by what it takes. Walk into folders, search, sort, preview.
• Cleanup — seven rules for known places (caches, logs, crash reports, Xcode data, unfinished downloads, iOS backups), each with its risk said plainly. Nothing is selected for you.
• Duplicates — exact copies found by content, with the space keeping one would free. You choose the copy that stays; it can never be moved.
• Applications — the apps of a folder with their icon, version and real size; files around an app are matched by name, never claimed as proof.
• Integrity — what macOS records about an app: signature and quarantine marker, for one app or a whole folder. Signals, never a verdict.
• Performance — load, memory in use, thermal state and free space, each with its source, read only when you look.
• Record — a herbarium of everything observed and moved, one page per day. Export it or clear it.

YOU ALWAYS CHOOSE
CoreTend reads only the folders you pick. Scans change nothing. Any move takes your selection, a review and a confirmation — Return cancels — and CoreTend checks each file again just before moving it to the Trash, where you can put it back.

A GREENHOUSE THAT LIVES
Roots grow as files are read, a moved file falls as a leaf, and the greenhouse sways gently while the window is in front — for almost no energy. Reduce Motion, Low Power Mode or one switch in Settings keeps it still.

PRIVATE BY DESIGN
No network, no account, no telemetry. Your paths and your history stay on your Mac.

English and French, light and dark, ⌘K search and an optional menu bar extra.
<!-- /listing:en -->

<!-- listing:fr -->
## Français

**Sous-titre :** Votre Mac, comme une serre

**Texte promotionnel :** Une serre vivante pour votre Mac : voyez ce qui prend de la place, comprenez-le et ne taillez que ce que vous choisissez. Tout va à la Corbeille.

**Mots-clés :** espace disque,stockage,doublons,cache,fichiers,corbeille,nettoyage,analyse,apps,confidentialité

**Description :**

CoreTend entretient votre Mac comme une serre. Elle observe, explique ce qu’elle trouve et ne taille que ce que vous choisissez — tout déplacement va dans la Corbeille de macOS, et rien ne quitte votre Mac.

HUIT OUTILS, UNE SERRE
• Vue d’ensemble — l’espace libre mesuré par macOS, et les dernières actions de CoreTend avec leur raison.
• Explorer — choisissez un dossier : chaque fichier et sous-dossier devient une parcelle à sa taille. Entrez dans les dossiers, cherchez, triez, prévisualisez.
• Nettoyage — sept règles pour des lieux connus (caches, journaux, rapports de crash, données Xcode, téléchargements inachevés, sauvegardes iOS), chacune avec son risque dit clairement. Rien n’est sélectionné à votre place.
• Doublons — les copies exactes trouvées par leur contenu, avec l’espace qu’en garder une seule libérerait. Vous choisissez l’exemplaire gardé ; il ne peut jamais être déplacé.
• Applications — les apps d’un dossier avec leur icône, leur version et leur taille réelle ; les fichiers autour d’une app sont rapprochés par leur nom, jamais présentés comme une preuve.
• Intégrité — ce que macOS enregistre d’une app : signature et marqueur de quarantaine, pour une app ou tout un dossier. Des signaux, jamais un verdict.
• Performances — charge, mémoire utilisée, état thermique et espace libre, chacun avec sa source, relevés seulement quand vous regardez.
• Historique — un herbier de tout ce qui a été observé et déplacé, jour par jour. Exportez-le ou effacez-le.

VOUS CHOISISSEZ TOUJOURS
CoreTend ne lit que les dossiers que vous désignez. Les analyses ne changent rien. Tout déplacement demande votre sélection, une revue et une confirmation — Entrée annule — et CoreTend revérifie chaque fichier juste avant de le mettre dans la Corbeille, d’où vous pouvez le remettre en place.

UNE SERRE QUI VIT
Les racines poussent au rythme des fichiers lus, un fichier déplacé tombe en feuille, et la serre se balance doucement quand la fenêtre est devant — pour presque aucune énergie. « Réduire les animations », le mode économie d’énergie ou un interrupteur dans Réglages la gardent immobile.

PRIVÉE PAR CONCEPTION
Ni réseau, ni compte, ni télémétrie. Vos chemins et votre historique restent sur votre Mac.

Français et anglais, clair et sombre, recherche ⌘K et barre des menus en option.
<!-- /listing:fr -->

## Notes pour la revue (App Review Information)

> CoreTend is a local, read-only-by-default disk and app inspector. It needs no account and makes no
> network connection. To try it: open Explore and choose any folder (for example Downloads) — the
> scan only reads. Moving an item requires selecting it, reviewing it and confirming; items go to
> the macOS Trash, never deleted permanently. Under the App Sandbox, every folder is chosen by the
> user in the system panel; suggested folders (Applications, ~/Library/Caches) open that panel on
> them. Integrity reads code signatures with the Security framework; Performance reads load and
> memory statistics with public APIs.

## Captures (2880 × 1800)

Produites par `python3 Scripts/capture_screens.py --in-use` (dossier de démonstration dans un HOME
temporaire ; Applications et Intégrité lisent `/System/Applications`). Ordre proposé : Vue
d'ensemble, Explorer, Doublons, Nettoyage, Applications, Intégrité, Performances, Accueil — en
anglais pour la fiche EN, en français pour la fiche FR, en sombre.
