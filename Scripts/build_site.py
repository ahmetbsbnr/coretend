#!/usr/bin/env python3
"""Generate the CoreTend 2.0 website: bilingual, static, no script, a living greenhouse in CSS.

Pages: index, features, download, privacy, support, developer (EN and FR) and a language chooser.
Release facts (version, date, download URL, SHA-256) come from Website/release.json; while it
says the release is not published, every page says so and no download link is shown.
"""

from html import escape
import json
from pathlib import Path
import shutil

from export_design_tokens import export_tokens

ROOT = Path(__file__).resolve().parents[1]
SITE = ROOT / "Website"
LANGUAGES = ("en", "fr")
ROUTES = ("index", "features", "download", "privacy", "support", "developer")
REPO = "https://github.com/ahmetbsbnr/coretend"


def release() -> dict:
    return json.loads((SITE / "release.json").read_text())


# ---------------------------------------------------------------------------------------------
# Copy

DESTINATIONS = {
    "en": [
        ("overview", "Overview", "The greenhouse at a glance",
         "Free space measured by macOS, the soil band of your volume, the last things CoreTend did and why, and paths into every tool."),
        ("explore", "Explore", "Plots in proportion",
         "Choose a folder: CoreTend reads it without touching it, then shows every file and subfolder as a plot sized by what it takes. Walk into subfolders, search, sort, preview."),
        ("cleanup", "Cleanup", "Known, safe pruning",
         "Seven rules for known places — caches, logs, crash reports, Xcode data, unfinished downloads, iOS backups — each with its risk said plainly. Nothing is selected for you."),
        ("duplicates", "Duplicates", "Twin shoots",
         "Exact copies found by content, with the space keeping one would free. You choose which copy stays; that one can never be moved. Similar images are shown as pairs, for you to judge."),
        ("applications", "Applications", "The plantings",
         "Every app of a folder with its icon, version and real size; sort by size; files around an app matched by name, never claimed as proof. Move one app bundle to the Trash after review."),
        ("integrity", "Integrity", "Plant labels",
         "What macOS records about an app — signature, quarantine marker — one label per signal, or a whole folder in one pass. Signals, never a verdict on safety."),
        ("performance", "Performance", "The sap",
         "System load, memory in use, thermal state and more, each with its source, and the load drawn over time. Readings are taken when you look, never in the background."),
        ("record", "Record", "The herbarium",
         "Everything observed and moved, one page per day. Search it, export it to CSV or JSON, or clear it — it stays on your Mac."),
    ],
    "fr": [
        ("overview", "Vue d’ensemble", "La serre d’un coup d’œil",
         "L’espace libre mesuré par macOS, la bande de sol du volume, les dernières actions de CoreTend et leur raison, et des chemins vers chaque outil."),
        ("explore", "Explorer", "Les parcelles en proportion",
         "Choisissez un dossier : CoreTend le lit sans y toucher, puis montre chaque fichier et sous-dossier comme une parcelle à sa taille. Entrez dans les sous-dossiers, cherchez, triez, prévisualisez."),
        ("cleanup", "Nettoyage", "Une taille connue et sûre",
         "Sept règles pour des lieux connus — caches, journaux, rapports de crash, données Xcode, téléchargements inachevés, sauvegardes iOS — chacune avec son risque dit clairement. Rien n’est sélectionné à votre place."),
        ("duplicates", "Doublons", "Les pousses jumelles",
         "Copies exactes trouvées par leur contenu, avec l’espace qu’en garder une seule libérerait. Vous choisissez l’exemplaire gardé, qui ne peut jamais être déplacé. Les images proches sont montrées par paires, à vous d’en juger."),
        ("applications", "Applications", "Les plantations",
         "Chaque app d’un dossier avec son icône, sa version et sa taille réelle ; tri par taille ; fichiers autour d’une app par correspondance de nom, jamais présentés comme une preuve. Déplacez un bundle vers la Corbeille après revue."),
        ("integrity", "Intégrité", "Les étiquettes de plant",
         "Ce que macOS enregistre d’une app — signature, marqueur de quarantaine — une étiquette par signal, ou tout un dossier en une passe. Des signaux, jamais un verdict de sûreté."),
        ("performance", "Performances", "La sève",
         "Charge système, mémoire utilisée, état thermique et plus, chacun avec sa source, et la charge tracée dans le temps. Les relevés se font quand vous regardez, jamais en arrière-plan."),
        ("record", "Historique", "L’herbier",
         "Tout ce qui a été observé et déplacé, une page par jour. Cherchez, exportez en CSV ou JSON, ou effacez — il reste sur votre Mac."),
    ],
}

COPY = {
    "en": {
        "skip": "Skip to content", "nav_label": "Main navigation", "other": "Français", "note": "local care",
        "nav": {"index": "Home", "features": "Features", "download": "Download", "privacy": "Privacy",
                "support": "Support", "developer": "Developers"},
        "footer": "A living greenhouse for your Mac. Local, open source, Apache 2.0.",
        "footer_links": "Explore",
        "unpublished": "CoreTend 2.0 is ready and will be published soon. The download appears here on release day.",
        "cta_download": "Download CoreTend 2.0", "cta_features": "See what it does",
        "requirements": "macOS 14 Sonoma or later · Apple silicon · English and French",
        "home": {
            "title": "Tend your Mac like a greenhouse.",
            "description": "CoreTend 2.0: a living, local greenhouse for your Mac. See what takes space, understand it, and prune only what you choose — every move goes to the Trash.",
            "kicker": "CoreTend 2.0",
            "lead": "CoreTend observes your Mac, explains what it finds and prunes only what you choose. Nothing leaves your Mac; nothing is erased for good.",
            "tools_title": "Eight tools, one greenhouse",
            "tools_lead": "Each part of your Mac has its place in the greenhouse, and its own way of showing what matters.",
            "alive_title": "A greenhouse that lives",
            "alive": [
                ("Motion with a cause", "Roots descend as files are read. A moved file falls as a leaf into the Trash. A file that stays says why."),
                ("Alive, never busy", "Leaves sway and pollen drifts while the window is in front — drawn by macOS itself, for almost no energy — and everything rests the moment you look away."),
                ("Calm on request", "Reduce Motion, Low Power Mode or one switch in Settings: the greenhouse stands still, every piece of information still in place."),
            ],
            "never_title": "What CoreTend will never do",
            "never": [
                ("Erase for good", "Every move goes to the macOS Trash, after your review and confirmation. You can put it back."),
                ("Ask for full disk access", "You choose each folder CoreTend may read. No password, no system extension."),
                ("Phone home", "No network, no account, no telemetry. Your paths and your history stay on your Mac."),
            ],
            "final_title": "Bring your Mac back to life.",
        },
        "features": {
            "title": "Everything in the greenhouse",
            "description": "The eight tools of CoreTend 2.0 — Overview, Explore, Cleanup, Duplicates, Applications, Integrity, Performance and Record — and how each keeps you in charge.",
            "kicker": "Features",
            "lead": "Every tool reads first and explains what it measured. Moving anything takes your selection, a review and a confirmation.",
            "also_title": "Across the app",
            "also": [
                ("⌘K search", "Jump to any tool or setting from a field that grows out of the sidebar."),
                ("Menu bar", "Optional: free space, memory and load at a glance, and every tool one click away."),
                ("From CoreTend 1.x", "Import recognised preferences and exclusions from a 1.x copy; the source stays intact."),
                ("Command line", "A read-only command-line tool scans a folder you name and reads the history."),
            ],
        },
        "download": {
            "title": "Get CoreTend 2.0",
            "description": "Download CoreTend 2.0 for macOS 14 or later on Apple silicon: signed and notarized by Apple, free and open source.",
            "kicker": "Download",
            "lead": "CoreTend 2.0 is a free update to CoreTend. It is signed with a Developer ID and notarized by Apple.",
            "install_title": "Install",
            "install": [
                ("Direct download", "Unzip the notarized archive and move CoreTend into Applications."),
                ("Homebrew", "brew install --cask ahmetbsbnr/coretend/coretend"),
                ("Check the file", "Compare the SHA-256 of what you downloaded with the one shown here."),
            ],
            "new_title": "New in 2.0",
            "new": "A complete rebuild: the living greenhouse design, eight tools, a three-page welcome, Applications with sizes and sorting, Explore that walks into folders, Integrity for a whole folder at once, recoverable space in Duplicates, memory in use, and a Settings window in four tabs.",
            "from1": "Coming from 1.x? 2.0 replaces it. Your 1.x data are not touched; you can import its preferences and exclusions from Settings.",
            "sha": "SHA-256",
            "version": "Version",
        },
        "privacy": {
            "title": "Your files stay yours",
            "description": "How CoreTend 2.0 handles your files: chosen folders only, read-only scans, every move to the Trash after review, no network and no telemetry.",
            "kicker": "Privacy and safety",
            "lead": "CoreTend works on your Mac and nowhere else. It reads the folders you choose and changes nothing until you decide.",
            "sections": [
                ("Only the folders you choose", "Each tool reads the folder you pick. Usual folders like Applications are offered in one click, never read before you choose. CoreTend never asks for Full Disk Access."),
                ("Reading is not changing", "Scans read names, sizes and dates; file contents are read only to compare copies. Nothing is written into what is scanned."),
                ("Every move is yours", "You select, review and confirm. CoreTend checks each file again just before moving it to the macOS Trash; a file that changed stays where it is."),
                ("Nothing leaves your Mac", "No network requests, no account, no analytics. History, favorites and readings live in a local database you can export or clear."),
            ],
        },
        "support": {
            "title": "Help in the greenhouse",
            "description": "Help for CoreTend 2.0: first launch, folder access, moving files to the Trash, removing CoreTend and reporting a problem.",
            "kicker": "Support",
            "lead": "Answers to the usual questions. For anything else, open an issue on GitHub — without personal paths.",
            "sections": [
                ("First launch", "A short welcome explains what CoreTend does and never does. You can begin right away; no extra access is needed."),
                ("A folder cannot be read", "macOS decides which folders an app may read. If a result is partial or refused, CoreTend says so — choose the folder again or pick another one."),
                ("Getting a file back", "Everything CoreTend moves goes to the macOS Trash. Open the Trash and choose Put Back."),
                ("An app will not move", "Some apps belong to the system or to an administrator. CoreTend leaves them in place and says so; remove them in the Finder if you are sure."),
                ("Removing CoreTend", "Quit it and move it to the Trash. Its local data live in ~/Library/Application Support/CoreTend-Reconstruction."),
                ("Reporting a problem", "Open a GitHub issue with your macOS version and what you saw. Leave out personal file names and paths."),
            ],
        },
        "developer": {
            "title": "Open source, built in the open",
            "description": "Build CoreTend 2.0 from source: a Swift 6 package with no runtime dependency, its design system, safety rules and contribution guide.",
            "kicker": "Developers",
            "lead": "CoreTend is a Swift 6 package: a SwiftUI app and a read-only command-line tool, with no runtime dependency. Apache 2.0.",
            "sections": [
                ("Build", "Clone the repository and build with Swift Package Manager on macOS 14 or later.", ["swift build --product CoreTendApp", "make qualify"]),
                ("Design system", "The Serre design system — palette, type, leaf shapes, motion tokens, the living greenhouse — lives in one module and is checked in tests."),
                ("Safety rules", "One module may move files, only to the Trash, after revalidation. The build checks that no other code can remove or rename a file."),
                ("Contribute", "Read CONTRIBUTING.md, open an issue first for larger changes, and keep every claim tied to something measured."),
            ],
        },
    },
    "fr": {
        "skip": "Aller au contenu", "nav_label": "Navigation principale", "other": "English", "note": "entretien local",
        "nav": {"index": "Accueil", "features": "Fonctionnalités", "download": "Télécharger", "privacy": "Confidentialité",
                "support": "Assistance", "developer": "Développeurs"},
        "footer": "Une serre vivante pour votre Mac. Locale, open source, Apache 2.0.",
        "footer_links": "Explorer",
        "unpublished": "CoreTend 2.0 est prête et sera publiée très bientôt. Le téléchargement apparaîtra ici le jour de la sortie.",
        "cta_download": "Télécharger CoreTend 2.0", "cta_features": "Voir ce qu’elle fait",
        "requirements": "macOS 14 Sonoma ou plus récent · Apple silicon · français et anglais",
        "home": {
            "title": "Entretenez votre Mac comme une serre.",
            "description": "CoreTend 2.0 : une serre vivante et locale pour votre Mac. Voyez ce qui prend de la place, comprenez-le, et ne taillez que ce que vous choisissez — tout déplacement va à la Corbeille.",
            "kicker": "CoreTend 2.0",
            "lead": "CoreTend observe votre Mac, explique ce qu’il trouve et ne taille que ce que vous choisissez. Rien ne quitte votre Mac ; rien n’est effacé définitivement.",
            "tools_title": "Huit outils, une serre",
            "tools_lead": "Chaque partie de votre Mac a sa place dans la serre, et sa façon de montrer ce qui compte.",
            "alive_title": "Une serre qui vit",
            "alive": [
                ("Des mouvements qui ont une cause", "Les racines descendent au rythme des fichiers lus. Un fichier déplacé tombe en feuille dans la Corbeille. Un fichier resté en place dit pourquoi."),
                ("Vivante, jamais agitée", "Les feuilles se balancent et le pollen flotte quand la fenêtre est devant — dessinés par macOS lui-même, pour presque aucune énergie — et tout se repose dès que vous regardez ailleurs."),
                ("Calme sur demande", "« Réduire les animations », le mode économie d’énergie ou un interrupteur dans Réglages : la serre s’immobilise, toute l’information reste en place."),
            ],
            "never_title": "Ce que CoreTend ne fera jamais",
            "never": [
                ("Effacer définitivement", "Tout déplacement va dans la Corbeille de macOS, après votre revue et votre confirmation. Vous pouvez le remettre en place."),
                ("Demander l’accès complet au disque", "Vous choisissez chaque dossier que CoreTend peut lire. Ni mot de passe, ni extension système."),
                ("Envoyer quoi que ce soit", "Ni réseau, ni compte, ni télémétrie. Vos chemins et votre historique restent sur votre Mac."),
            ],
            "final_title": "Redonnez vie à votre Mac.",
        },
        "features": {
            "title": "Tout ce que contient la serre",
            "description": "Les huit outils de CoreTend 2.0 — Vue d’ensemble, Explorer, Nettoyage, Doublons, Applications, Intégrité, Performances et Historique — et comment chacun vous laisse décider.",
            "kicker": "Fonctionnalités",
            "lead": "Chaque outil lit d’abord et explique ce qu’il a mesuré. Déplacer quoi que ce soit demande votre sélection, une revue et une confirmation.",
            "also_title": "Dans toute l’app",
            "also": [
                ("Recherche ⌘K", "Allez à n’importe quel outil ou réglage depuis un champ qui naît de la barre latérale."),
                ("Barre des menus", "En option : espace libre, mémoire et charge d’un coup d’œil, et chaque outil à un clic."),
                ("Depuis CoreTend 1.x", "Importez les préférences et exclusions reconnues d’une copie 1.x ; la source reste intacte."),
                ("Ligne de commande", "Un outil en ligne de commande, en lecture seule, analyse le dossier indiqué et lit l’historique."),
            ],
        },
        "download": {
            "title": "Obtenir CoreTend 2.0",
            "description": "Téléchargez CoreTend 2.0 pour macOS 14 ou plus récent sur Apple silicon : signée et notarisée par Apple, gratuite et open source.",
            "kicker": "Télécharger",
            "lead": "CoreTend 2.0 est une mise à jour gratuite de CoreTend. Elle est signée avec un Developer ID et notarisée par Apple.",
            "install_title": "Installer",
            "install": [
                ("Téléchargement direct", "Décompressez l’archive notarisée et placez CoreTend dans Applications."),
                ("Homebrew", "brew install --cask ahmetbsbnr/coretend/coretend"),
                ("Vérifier le fichier", "Comparez l’empreinte SHA-256 du fichier téléchargé avec celle affichée ici."),
            ],
            "new_title": "Nouveautés de la 2.0",
            "new": "Une reconstruction complète : la serre vivante, huit outils, un accueil en trois pages, Applications avec tailles et tri, Explorer qui entre dans les dossiers, Intégrité pour tout un dossier, espace récupérable dans Doublons, mémoire utilisée, et des Réglages en quatre onglets.",
            "from1": "Vous venez de la 1.x ? La 2.0 la remplace. Vos données 1.x ne sont pas touchées ; importez ses préférences et exclusions depuis les Réglages.",
            "sha": "SHA-256",
            "version": "Version",
        },
        "privacy": {
            "title": "Vos fichiers restent à vous",
            "description": "Comment CoreTend 2.0 traite vos fichiers : seulement les dossiers choisis, analyses en lecture seule, déplacements vers la Corbeille après revue, ni réseau ni télémétrie.",
            "kicker": "Confidentialité et sûreté",
            "lead": "CoreTend travaille sur votre Mac et nulle part ailleurs. Il lit les dossiers que vous choisissez et ne change rien avant votre décision.",
            "sections": [
                ("Seulement les dossiers choisis", "Chaque outil lit le dossier que vous désignez. Les dossiers habituels comme Applications sont proposés en un clic, jamais lus avant votre choix. CoreTend ne demande jamais l’accès complet au disque."),
                ("Lire n’est pas modifier", "Les analyses lisent noms, tailles et dates ; le contenu n’est lu que pour comparer des copies. Rien n’est écrit dans ce qui est analysé."),
                ("Chaque déplacement vous appartient", "Vous sélectionnez, revoyez et confirmez. CoreTend revérifie chaque fichier juste avant de le déplacer dans la Corbeille ; un fichier qui a changé reste en place."),
                ("Rien ne quitte votre Mac", "Aucune requête réseau, aucun compte, aucune statistique. Historique, favoris et relevés vivent dans une base locale que vous pouvez exporter ou effacer."),
            ],
        },
        "support": {
            "title": "De l’aide dans la serre",
            "description": "Aide pour CoreTend 2.0 : premier lancement, accès aux dossiers, fichiers dans la Corbeille, désinstallation et signalement d’un problème.",
            "kicker": "Assistance",
            "lead": "Les réponses aux questions courantes. Pour le reste, ouvrez une issue sur GitHub — sans chemins personnels.",
            "sections": [
                ("Premier lancement", "Un court accueil explique ce que CoreTend fait et ne fait jamais. Vous pouvez commencer tout de suite ; aucun accès supplémentaire n’est nécessaire."),
                ("Un dossier ne peut pas être lu", "macOS décide des dossiers qu’une app peut lire. Si un résultat est partiel ou refusé, CoreTend le dit — choisissez à nouveau le dossier ou un autre."),
                ("Récupérer un fichier", "Tout ce que CoreTend déplace va dans la Corbeille de macOS. Ouvrez la Corbeille et choisissez Remettre en place."),
                ("Une app ne se déplace pas", "Certaines apps appartiennent au système ou à un administrateur. CoreTend les laisse en place et le dit ; retirez-les dans le Finder si vous en êtes sûr."),
                ("Retirer CoreTend", "Quittez-la et placez-la dans la Corbeille. Ses données locales sont dans ~/Library/Application Support/CoreTend-Reconstruction."),
                ("Signaler un problème", "Ouvrez une issue GitHub avec votre version de macOS et ce que vous avez vu. Laissez de côté noms de fichiers et chemins personnels."),
            ],
        },
        "developer": {
            "title": "Open source, construit au grand jour",
            "description": "Construire CoreTend 2.0 depuis les sources : un paquet Swift 6 sans dépendance, son système de design, ses règles de sûreté et son guide de contribution.",
            "kicker": "Développeurs",
            "lead": "CoreTend est un paquet Swift 6 : une app SwiftUI et un outil en ligne de commande en lecture seule, sans dépendance à l’exécution. Apache 2.0.",
            "sections": [
                ("Construire", "Clonez le dépôt et construisez avec Swift Package Manager sur macOS 14 ou plus récent.", ["swift build --product CoreTendApp", "make qualify"]),
                ("Système de design", "Le système Serre — palette, typographie, formes de feuille, jetons de mouvement, la serre vivante — vit dans un module et est vérifié par des tests."),
                ("Règles de sûreté", "Un seul module peut déplacer des fichiers, seulement vers la Corbeille, après revalidation. La construction vérifie qu’aucun autre code ne peut supprimer ou renommer un fichier."),
                ("Contribuer", "Lisez CONTRIBUTING.md, ouvrez d’abord une issue pour les changements importants, et reliez chaque affirmation à une mesure."),
            ],
        },
    },
}

# ---------------------------------------------------------------------------------------------
# Living pieces (all decorative; the content never depends on them)

MARK = (
    '<svg class="mark" viewBox="200 180 624 680" aria-hidden="true" focusable="false">'
    '<path class="mark-stem" pathLength="1" d="M512 780 C 512 640, 506 520, 520 400"/>'
    '<path class="mark-leaf mark-leaf-1" d="M518 470 C 430 470, 330 420, 300 300 C 410 290, 500 350, 518 470 Z"/>'
    '<path class="mark-leaf mark-leaf-2" d="M524 400 C 560 290, 660 220, 770 230 C 760 350, 660 420, 524 400 Z"/>'
    '<path class="mark-soil" d="M250 800 Q 512 730 774 800"/>'
    '</svg>'
)


def sprout(x: float, height: float, index: int, wilted: bool = False) -> str:
    top = 300 - height
    return (f'<g class="shoot{" shoot-wilted" if wilted else ""}" style="--i:{index}" transform="translate({x} 0)">'
            f'<g class="shoot-sway">'
            f'<path class="shoot-stem" pathLength="1" d="M0 300 C 0 {300 - height * 0.5}, -4 {top + 20}, 2 {top}"/>'
            f'<path class="shoot-leaf" d="M1 {top + height * 0.35} C -18 {top + height * 0.35}, -34 {top + height * 0.2}, -38 {top} C -20 {top - 2}, -4 {top + 10}, 1 {top + height * 0.35} Z"/>'
            f'<path class="shoot-leaf" d="M2 {top + 8} C 10 {top - 14}, 28 {top - 26}, 44 {top - 24} C 42 {top - 4}, 24 {top + 10}, 2 {top + 8} Z"/>'
            f'</g></g>')


def greenhouse() -> str:
    heights = [120, 170, 90, 200, 150, 230, 110, 185, 140, 210, 100, 160, 130]
    shoots = "".join(sprout(60 + i * 72, h, i, wilted=(i == 11)) for i, h in enumerate(heights))
    arches = "".join(f'<path class="glass" d="M{x} 300 Q {x + 150} {-20} {x + 300} 300"/><path class="mullion" d="M{x + 150} 300 V 140"/>'
                     for x in (20, 330, 640))
    pollen = "".join(f'<span style="--x:{(i * 37) % 100}%;--d:{7 + (i * 3) % 7}s;--delay:{-(i * 1.3):.1f}s"></span>' for i in range(22))
    return (f'<div class="greenhouse" aria-hidden="true"><svg viewBox="0 0 960 330" preserveAspectRatio="xMidYMax meet" focusable="false">'
            f'{arches}{shoots}</svg>'
            f'<div class="pollen">{pollen}</div></div>')


VINE = ('<svg class="vine" viewBox="0 0 1200 40" preserveAspectRatio="none" aria-hidden="true" focusable="false">'
        '<path pathLength="1" d="M0 20 C 100 0, 200 40, 300 20 S 500 0, 600 20 S 800 40, 900 20 S 1100 0, 1200 20"/></svg>')


# ---------------------------------------------------------------------------------------------
# Page pieces

def file_name(route: str) -> str:
    return "index.html" if route == "index" else f"{route}.html"


def header(lang: str, route: str) -> str:
    c = COPY[lang]
    links = "".join(f'<a href="{file_name(r)}"{" aria-current=\"page\"" if r == route else ""}>{escape(c["nav"][r])}</a>'
                    for r in ROUTES if r != "index")
    other = "fr" if lang == "en" else "en"
    return f"""<a class="skip-link" href="#main">{escape(c['skip'])}</a>
<header class="site-header">
  <a class="brand" href="index.html" aria-label="CoreTend — {escape(c['nav']['index'])}">{MARK}<span>CoreTend<small>{escape(c['note'])}</small></span></a>
  <nav class="primary-nav" aria-label="{escape(c['nav_label'])}">{links}</nav>
  <a class="lang" href="../{other}/{file_name(route)}" lang="{other}" hreflang="{other}">{escape(c['other'])}</a>
</header>"""


def footer(lang: str) -> str:
    c = COPY[lang]
    links = "".join(f'<a href="{file_name(r)}">{escape(c["nav"][r])}</a>' for r in ROUTES if r != "index")
    return f"""<footer class="site-footer">
  {VINE}
  <div class="footer-brand"><a class="brand" href="index.html">{MARK}<span>CoreTend<small>{escape(c['note'])}</small></span></a><p>{escape(c['footer'])}</p></div>
  <nav aria-label="{escape(c['footer_links'])}">{links}</nav>
  <p class="footer-meta">© 2026 CoreTend · Apache 2.0</p>
</footer>"""


def download_button(lang: str, rel: dict, *, large: bool = False) -> str:
    c = COPY[lang]
    if rel.get("published") and rel.get("url"):
        return (f'<a class="button button-primary{" button-large" if large else ""}" href="{escape(rel["url"], quote=True)}">'
                f'{escape(c["cta_download"])}<span aria-hidden="true"> ↓</span></a>')
    return f'<p class="unpublished">{escape(c["unpublished"])}</p>'


def capture(lang: str, surface: str, title: str, *, hero: bool = False) -> str:
    image = f"../screenshots/{surface}-{lang}"
    return (f'<figure class="capture reveal{" capture-hero" if hero else ""}">'
            f'<picture><source media="(prefers-color-scheme: light)" srcset="{image}-light.png">'
            f'<img src="{image}-dark.png" alt="CoreTend — {escape(title, quote=True)}" width="2240" height="1520" loading="{"eager" if hero else "lazy"}"></picture>'
            f'<figcaption>{escape(title)}</figcaption></figure>')


def cards(items, css: str = "card") -> str:
    out = []
    for n, item in enumerate(items):
        title, body, *extra = item
        detail = f"<p>{escape(body)}</p>"
        if extra:
            detail += "".join(f"<code>{escape(line)}</code>" for line in extra[0])
        out.append(f'<article class="{css} reveal" style="--n:{n}"><span class="card-leaf" aria-hidden="true"></span><h3>{escape(title)}</h3>{detail}</article>')
    return "".join(out)


SURFACE = {key: key for key in ("overview", "explore", "cleanup", "duplicates", "applications", "integrity", "performance", "record")}


def home(lang: str, rel: dict) -> str:
    c, p = COPY[lang], COPY[lang]["home"]
    tools = "".join(
        f'<a class="tool reveal" style="--n:{n}" href="features.html#{key}"><span class="tool-name">{escape(name)}</span>'
        f'<strong>{escape(tag)}</strong><span class="tool-body">{escape(body)}</span></a>'
        for n, (key, name, tag, body) in enumerate(DESTINATIONS[lang]))
    return f"""<main id="main">
  <section class="hero">
    <div class="hero-copy">
      <p class="eyebrow"><span class="dot" aria-hidden="true"></span>{escape(p['kicker'])}</p>
      <h1>{escape(p['title'])}</h1>
      <p class="lead">{escape(p['lead'])}</p>
      <div class="actions">{download_button(lang, rel, large=True)}<a class="button button-secondary" href="features.html">{escape(c['cta_features'])}<span aria-hidden="true"> →</span></a></div>
      <p class="requirements">{escape(c['requirements'])}</p>
    </div>
    {greenhouse()}
  </section>
  {capture(lang, "overview", DESTINATIONS[lang][0][1] + " — " + DESTINATIONS[lang][0][2], hero=True)}
  <section class="band" aria-labelledby="tools-title"><div class="band-head reveal"><h2 id="tools-title">{escape(p['tools_title'])}</h2><p>{escape(p['tools_lead'])}</p></div><div class="tools">{tools}</div></section>
  <section class="band band-alive" aria-labelledby="alive-title"><div class="band-head reveal"><h2 id="alive-title">{escape(p['alive_title'])}</h2></div><div class="cards">{cards(p['alive'])}</div></section>
  <section class="band" aria-labelledby="never-title"><div class="band-head reveal"><h2 id="never-title">{escape(p['never_title'])}</h2></div><div class="cards">{cards(p['never'], "card card-never")}</div></section>
  <section class="final reveal"><div class="final-mark">{MARK}</div><h2>{escape(p['final_title'])}</h2>{download_button(lang, rel, large=True)}<p class="requirements">{escape(c['requirements'])}</p></section>
</main>"""


def features(lang: str) -> str:
    p = COPY[lang]["features"]
    blocks = "".join(
        f'<section class="feature" id="{key}"><div class="feature-copy reveal"><p class="eyebrow">{escape(name)}</p><h2>{escape(tag)}</h2><p>{escape(body)}</p></div>'
        f'{capture(lang, SURFACE[key], name + " — " + tag)}</section>'
        for key, name, tag, body in DESTINATIONS[lang])
    return f"""<main id="main">
  {intro(p)}
  {blocks}
  <section class="band"><div class="band-head reveal"><h2>{escape(p['also_title'])}</h2></div><div class="cards">{cards(p['also'])}</div></section>
</main>"""


def download(lang: str, rel: dict) -> str:
    c, p = COPY[lang], COPY[lang]["download"]
    facts = f'<dl class="facts reveal"><div><dt>{escape(p["version"])}</dt><dd>{escape(rel["version"])}</dd></div>'
    if rel.get("sha256"):
        facts += f'<div><dt>{escape(p["sha"])}</dt><dd><code>{escape(rel["sha256"])}</code></dd></div>'
    facts += f'<div><dt>macOS</dt><dd>{escape(c["requirements"])}</dd></div></dl>'
    return f"""<main id="main">
  {intro(p)}
  <section class="band download-band"><div class="download-box reveal">{MARK}{download_button(lang, rel, large=True)}{facts}</div></section>
  <section class="band"><div class="band-head reveal"><h2>{escape(p['install_title'])}</h2></div><div class="cards">{cards([(t, b) if t != "Homebrew" else (t, "", [b]) for t, b in p['install']])}</div></section>
  <section class="band"><div class="band-head reveal"><h2>{escape(p['new_title'])}</h2><p>{escape(p['new'])}</p><p>{escape(p['from1'])}</p></div></section>
</main>"""


def intro(p: dict) -> str:
    return (f'<section class="intro"><p class="eyebrow"><span class="dot" aria-hidden="true"></span>{escape(p["kicker"])}</p>'
            f'<h1>{escape(p["title"])}</h1><p class="lead">{escape(p["lead"])}</p>{VINE}</section>')


def simple(lang: str, route: str) -> str:
    p = COPY[lang][route]
    return f"""<main id="main">
  {intro(p)}
  <section class="band"><div class="cards cards-two">{cards(p['sections'])}</div></section>
</main>"""


def document(lang: str, route: str, rel: dict) -> str:
    page = COPY[lang]["home" if route == "index" else route]
    other = "fr" if lang == "en" else "en"
    body = {"index": lambda: home(lang, rel), "features": lambda: features(lang),
            "download": lambda: download(lang, rel)}.get(route, lambda: simple(lang, route))()
    return f"""<!doctype html>
<html lang="{lang}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="{escape(page['description'], quote=True)}">
  <meta name="theme-color" content="#0F2019">
  <link rel="alternate" hreflang="{other}" href="../{other}/{file_name(route)}">
  <link rel="icon" href="../brand/coretend-mark-dark.svg" type="image/svg+xml">
  <link rel="apple-touch-icon" href="../brand/coretend-app-icon-1024.png">
  <meta property="og:type" content="website">
  <meta property="og:title" content="{escape(page['title'], quote=True)} — CoreTend">
  <meta property="og:description" content="{escape(page['description'], quote=True)}">
  <meta property="og:image" content="../brand/coretend-app-icon-1024.png">
  <meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'none'; style-src 'self'; img-src 'self'; font-src 'self'; connect-src 'self'; base-uri 'none'; object-src 'none'; form-action 'self'">
  <title>{escape(page['title'])} — CoreTend</title>
  <link rel="stylesheet" href="../design-tokens.css">
  <link rel="stylesheet" href="../site.css">
</head>
<body class="page-{route}">
  {header(lang, route)}
  {body}
  {footer(lang)}
</body>
</html>
"""


def language_index() -> str:
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="CoreTend 2.0 — a living, local greenhouse for your Mac. Une serre vivante et locale pour votre Mac.">
  <meta name="theme-color" content="#0F2019">
  <link rel="icon" href="brand/coretend-mark-dark.svg" type="image/svg+xml">
  <meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'none'; style-src 'self'; img-src 'self'; font-src 'self'; connect-src 'self'; base-uri 'none'; object-src 'none'; form-action 'self'">
  <title>CoreTend — choose your language / choisir la langue</title>
  <link rel="stylesheet" href="design-tokens.css">
  <link rel="stylesheet" href="site.css">
</head>
<body class="page-language">
  <a class="skip-link" href="#main">Skip / Aller au contenu</a>
  <main id="main" class="language">
    {greenhouse()}
    <div class="language-card">
      <a class="brand brand-large" href="en/index.html">{MARK}<span>CoreTend<small>2.0</small></span></a>
      <h1>A living greenhouse for your Mac.<span lang="fr">Une serre vivante pour votre Mac.</span></h1>
      <nav class="actions" aria-label="Language / Langue"><a class="button button-primary" href="en/index.html" lang="en">English <span aria-hidden="true">→</span></a><a class="button button-secondary" href="fr/index.html" lang="fr">Français <span aria-hidden="true">→</span></a></nav>
    </div>
  </main>
</body>
</html>
"""


def main() -> None:
    export_tokens()
    rel = release()
    brand = SITE / "brand"
    brand.mkdir(exist_ok=True)
    for name in ("coretend-mark-dark.svg", "coretend-mark-light.svg", "coretend-logotype-dark.svg",
                 "coretend-logotype-light.svg", "coretend-app-icon-1024.png"):
        shutil.copyfile(ROOT / "Resources/Brand/Logo" / name, brand / name)
    for lang in LANGUAGES:
        (SITE / lang).mkdir(exist_ok=True)
        for route in ROUTES:
            (SITE / lang / file_name(route)).write_text(document(lang, route, rel), encoding="utf-8")
    (SITE / "index.html").write_text(language_index(), encoding="utf-8")


if __name__ == "__main__":
    main()
