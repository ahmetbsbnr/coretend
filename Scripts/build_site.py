#!/usr/bin/env python3
"""Generate the CoreTend website: bilingual, static, no script, a living greenhouse in CSS.

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
NPM = "https://www.npmjs.com/package/coretend"
TAP = "https://github.com/ahmetbsbnr/homebrew-coretend"


def channels(lang: str) -> str:
    """Where else CoreTend is published: Homebrew, npm (command line and MCP), GitHub."""
    label = "Aussi sur" if lang == "fr" else "Also on"
    links = [("Homebrew", TAP), ("npm", NPM), ("GitHub", REPO)]
    items = " · ".join(f'<a href="{url}">{name}</a>' for name, url in links)
    return f'<p class="requirements channels">{label} {items}</p>'


def release() -> dict:
    return json.loads((SITE / "release.json").read_text())


# ---------------------------------------------------------------------------------------------
# Copy

DESTINATIONS = {
    "en": [
        ("home", "Home", "Your Mac in one sentence",
         "How much space CoreTend can give back, with the one button that leads to it. Free space as macOS measures it, and what happened lately."),
        ("space", "Space", "See what takes the space",
         "Scan your home folder in one click: every folder becomes a block as large as what it takes. Walk in, search, sort, preview — and find exact duplicates in the same place."),
        ("clean", "Clean", "Clear it safely",
         "Caches, logs, Xcode and simulator files, npm, pnpm, Gradle and Cargo caches, Mail attachments: read at once, grouped, each with its risk. Safe items are ticked; one review, one click, and Undo puts everything back."),
        ("apps", "Apps", "Uninstall completely",
         "Every app with its size. Uninstall moves the app and the files it left in your Library — support files, caches, preferences, containers — to the Trash, after you see the list."),
    ],
    "fr": [
        ("home", "Accueil", "Votre Mac en une phrase",
         "L’espace que CoreTend peut récupérer, avec le seul bouton qui y mène. L’espace libre mesuré par macOS, et ce qui s’est passé récemment."),
        ("space", "Espace", "Voyez ce qui prend la place",
         "Analysez votre dossier personnel en un clic : chaque dossier devient un bloc aussi grand que ce qu’il occupe. Entrez, cherchez, triez, prévisualisez — et trouvez les doublons exacts au même endroit."),
        ("clean", "Nettoyer", "Libérez-le sans risque",
         "Caches, journaux, fichiers Xcode et des simulateurs, caches npm, pnpm, Gradle et Cargo, pièces jointes de Mail : tout est lu d’un coup, regroupé, chacun avec son risque. Les éléments sûrs sont cochés ; une revue, un clic, et Annuler remet tout en place."),
        ("apps", "Apps", "Désinstallez complètement",
         "Chaque app avec sa taille. Désinstaller place l’app et les fichiers qu’elle a laissés dans votre Bibliothèque — fichiers de support, caches, préférences, conteneurs — à la Corbeille, après vous avoir montré la liste."),
    ],
}

COPY = {
    "en": {
        "skip": "Skip to content", "nav_label": "Main navigation", "other": "Français", "note": "local care",
        "nav": {"index": "Home", "features": "Features", "download": "Download", "privacy": "Privacy",
                "support": "Support", "developer": "Developers"},
        "footer": "See what fills your Mac. Clear it safely. Free and open source, Apache 2.0.",
        "footer_links": "Explore",
        "unpublished": "CoreTend 2.1 is almost ready. The download appears here on release day.",
        "cta_download": "Download for Mac", "cta_features": "See what it does",
        "requirements": "macOS 14 Sonoma or later · Apple silicon · English and French",
        "home": {
            "title": "See what fills your Mac. Clear it safely.",
            "description": "CoreTend 2.1 for macOS: see what takes space, clean caches and developer files, uninstall apps completely. Everything goes to the Trash. Free, open source, no telemetry.",
            "lead": "CoreTend reads your whole Mac, shows what takes the space and gives it back in one click — to the Trash, never erased, with Undo. Free, open source, and nothing leaves your Mac.",
            "tools_title": "Four spaces, one question each",
            "tools_lead": "No dashboard to decode: each space answers one question and has one main button.",
            "alive_title": "A greenhouse that lives",
            "alive": [
                ("Motion with a cause", "Roots descend as files are read. A moved file falls as a leaf into the Trash. A file that stays says why."),
                ("Alive, never busy", "Leaves sway and pollen drifts while the window is in front — drawn by macOS itself, for almost no energy — and everything rests the moment you look away."),
                ("Calm on request", "Reduce Motion, Low Power Mode or one switch in Settings: the greenhouse stands still, every piece of information still in place."),
            ],
            "never_title": "What CoreTend will never do",
            "never": [
                ("Erase for good", "Every move goes to the macOS Trash, after your review. Undo puts it back."),
                ("Scare you", "No health score, no alarm, no invented figure. Only what macOS measures, explained in plain words."),
                ("Watch you", "No account, no telemetry. The only network request asks the site whether an update exists — and you can turn it off."),
            ],
            "final_title": "Give your Mac its space back.",
            "tools_cta": "Every feature in detail",
            "proof": [
                ("1 click", "from the Home to the space you can give back"),
                ("14", "cleanup rules, each with its risk said plainly"),
                ("Undo", "puts back what went to the Trash"),
            ],
            "show": [
                ("onboarding", "Ready in three screens",
                 "What CoreTend promises, Full Disk Access explained in one sentence (CoreTend notices when you allow it), and you start."),
            ],
        },
        "features": {
            "title": "Everything CoreTend does",
            "description": "The four spaces of CoreTend 2.1 — Home, Space, Clean and Apps — plus the command line and the MCP server for AI assistants.",
            "lead": "Every space reads first and explains what it found. Nothing moves without your review, and everything that moves goes to the Trash.",
            "jump": "Jump to a space",
            "also_title": "Across the app",
            "also": [
                ("Command line", "coretend clean lists what can go; --confirm sends the safe items to the Trash."),
                ("For AI assistants", "coretend mcp lets Claude, Cursor and others ask what fills your disk — read-only."),
                ("Signed updates", "Sparkle checks the site for a new version, only if you allow it, and installs it when you accept."),
                ("Menu bar", "Optional: free space, memory and load at a glance."),
            ],
        },
        "download": {
            "title": "Get CoreTend",
            "description": "Download CoreTend for macOS 14 or later on Apple silicon: signed and notarized by Apple, free and open source. Also on Homebrew and npm.",
            "lead": "Free, signed with a Developer ID and notarized by Apple. It updates itself when you allow it.",
            "install_title": "Install",
            "install": [
                ("Direct download", "Open the disk image and move CoreTend into Applications. On first launch, allow Full Disk Access when CoreTend asks."),
                ("Homebrew", "brew install --cask ahmetbsbnr/coretend/coretend"),
                ("Terminal and AI assistants", "npx coretend mcp"),
            ],
            "npm_link": "The coretend package on npm (command line and MCP server)",
            "new_title": "New in 2.1",
            "new": "Four spaces instead of eight tools. Your whole Mac in one click with Full Disk Access. Clean reads 14 rules at once — Xcode, simulators, npm, pnpm, Gradle, Cargo, Mail — and Undo puts things back. Apps uninstall completely. Signed automatic updates, a command line that cleans, and an MCP server for AI assistants.",
            "from1": "Coming from 2.0? Download 2.1 once (or run brew upgrade); later versions arrive on their own.",
            "sha": "SHA-256 · DMG",
            "sha_dmg": "SHA-256 · ZIP",
            "dmg": "ZIP archive",
            "zip": "ZIP archive",
            "notarized": "Signed with Developer ID · notarized by Apple",
            "released": "Released",
            "files": "Files and checksums",
            "version": "Version",
        },
        "privacy": {
            "title": "Built to be trusted",
            "description": "How CoreTend handles your files: read-only scans, every move to the Trash after review with Undo, Full Disk Access explained, no telemetry.",
            "lead": "CoreTend works on your Mac and nowhere else. It reads freely and changes nothing until you decide.",
            "sections": [
                ("Why Full Disk Access", "macOS hides Mail, Safari and app data from every app. With Full Disk Access CoreTend can measure them; without it, it reads what macOS allows and says so."),
                ("Reading is not changing", "Scans read names, sizes and dates; file contents are read only to compare copies. Nothing is written into what is scanned."),
                ("Every move is yours, and reversible", "You review, then CoreTend checks each item again just before moving it to the macOS Trash. Undo puts it back; nothing is ever erased."),
                ("Nothing leaves your Mac", "No account, no analytics. The only request asks coretend.ahmetbsbnr.com whether an update exists, and you can turn it off. Open source, so anyone can check."),
            ],
        },
        "support": {
            "title": "Help in the greenhouse",
            "description": "Help for CoreTend: Full Disk Access, getting a file back, uninstalling, updates and reporting a problem.",
            "lead": "Answers to the usual questions. For anything else, open an issue on GitHub — without personal paths.",
            "sections": [
                ("Full Disk Access", "System Settings › Privacy & Security › Full Disk Access: turn CoreTend on. macOS may ask to reopen it."),
                ("A folder cannot be read", "Without Full Disk Access, macOS keeps some folders closed. CoreTend says when a result is partial."),
                ("Getting a file back", "Click Undo right after a clean, or open the Trash and choose Put Back."),
                ("An app will not move", "Some apps belong to the system or to an administrator. CoreTend leaves them in place and says so; remove them in the Finder if you are sure."),
                ("Removing CoreTend", "Quit it and move it to the Trash. Its local data live in ~/Library/Application Support/CoreTend-Reconstruction."),
                ("Reporting a problem", "Open a GitHub issue with your macOS version and what you saw. Leave out personal file names and paths."),
            ],
        },
        "developer": {
            "title": "For developers",
            "description": "CoreTend from the terminal and for AI assistants: coretend clean, the read-only MCP server, npm and Homebrew; building from source.",
            "lead": "Clean from the terminal, let your AI assistant read your disk, or build CoreTend yourself. Swift 6, Apache 2.0.",
            "sections": [
                ("Clean from the terminal", "A dry run first; --confirm moves the safe items to the Trash.", ["coretend clean", "coretend clean --confirm"]),
                ("MCP server for AI assistants", "Read-only tools: disk_usage, cleanup_candidates, largest_items, app_leftovers.", ["npx -y coretend mcp"]),
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
        "footer": "Voyez ce qui remplit votre Mac. Libérez-le sans risque. Gratuit et open source, Apache 2.0.",
        "footer_links": "Explorer",
        "unpublished": "CoreTend 2.1 est presque prête. Le téléchargement apparaîtra ici le jour de la sortie.",
        "cta_download": "Télécharger pour Mac", "cta_features": "Voir ce qu’elle fait",
        "requirements": "macOS 14 Sonoma ou plus récent · Apple silicon · français et anglais",
        "home": {
            "title": "Voyez ce qui remplit votre Mac. Libérez-le sans risque.",
            "description": "CoreTend 2.1 pour macOS : voyez ce qui prend de la place, nettoyez caches et fichiers de développement, désinstallez complètement vos apps. Tout part à la Corbeille. Gratuit, open source, sans télémétrie.",
            "lead": "CoreTend lit tout votre Mac, montre ce qui prend la place et vous la rend en un clic — à la Corbeille, jamais effacé, avec Annuler. Gratuit, open source, et rien ne quitte votre Mac.",
            "tools_title": "Quatre espaces, une question chacun",
            "tools_lead": "Pas de tableau de bord à déchiffrer : chaque espace répond à une question et a un seul bouton principal.",
            "alive_title": "Une serre qui vit",
            "alive": [
                ("Des mouvements qui ont une cause", "Les racines descendent au rythme des fichiers lus. Un fichier déplacé tombe en feuille dans la Corbeille. Un fichier resté en place dit pourquoi."),
                ("Vivante, jamais agitée", "Les feuilles se balancent et le pollen flotte quand la fenêtre est devant — dessinés par macOS lui-même, pour presque aucune énergie — et tout se repose dès que vous regardez ailleurs."),
                ("Calme sur demande", "« Réduire les animations », le mode économie d’énergie ou un interrupteur dans Réglages : la serre s’immobilise, toute l’information reste en place."),
            ],
            "never_title": "Ce que CoreTend ne fera jamais",
            "never": [
                ("Effacer définitivement", "Tout déplacement va dans la Corbeille de macOS, après votre revue. Annuler le remet en place."),
                ("Vous faire peur", "Ni score de santé, ni alarme, ni chiffre inventé. Seulement ce que macOS mesure, dit simplement."),
                ("Vous surveiller", "Ni compte, ni télémétrie. La seule requête demande au site si une mise à jour existe — et vous pouvez la désactiver."),
            ],
            "final_title": "Rendez de l’espace à votre Mac.",
            "tools_cta": "Toutes les fonctionnalités en détail",
            "proof": [
                ("1 clic", "de l’Accueil à l’espace récupérable"),
                ("14", "règles de nettoyage, chacune avec son risque dit clairement"),
                ("Annuler", "remet en place ce qui est parti à la Corbeille"),
            ],
            "show": [
                ("onboarding", "Prête en trois écrans",
                 "Ce que CoreTend promet, l’accès complet au disque expliqué en une phrase (CoreTend s’en aperçoit dès que vous l’autorisez), et c’est parti."),
            ],
        },
        "features": {
            "title": "Tout ce que fait CoreTend",
            "description": "Les quatre espaces de CoreTend 2.1 — Accueil, Espace, Nettoyer et Apps — plus la ligne de commande et le serveur MCP pour les assistants IA.",
            "lead": "Chaque espace lit d’abord et explique ce qu’il a trouvé. Rien ne bouge sans votre revue, et tout ce qui bouge part à la Corbeille.",
            "jump": "Aller à un espace",
            "also_title": "Dans toute l’app",
            "also": [
                ("Ligne de commande", "coretend clean liste ce qui peut partir ; --confirm envoie les éléments sûrs à la Corbeille."),
                ("Pour les assistants IA", "coretend mcp permet à Claude, Cursor et d’autres de demander ce qui remplit votre disque — en lecture seule."),
                ("Mises à jour signées", "Sparkle demande au site s’il existe une nouvelle version, seulement si vous l’autorisez, et l’installe quand vous acceptez."),
                ("Barre des menus", "En option : espace libre, mémoire et charge d’un coup d’œil."),
            ],
        },
        "download": {
            "title": "Obtenir CoreTend",
            "description": "Téléchargez CoreTend pour macOS 14 ou plus récent sur Apple silicon : signée et notarisée par Apple, gratuite et open source. Aussi sur Homebrew et npm.",
            "lead": "Gratuite, signée avec un Developer ID et notarisée par Apple. Elle se met à jour seule si vous l’autorisez.",
            "install_title": "Installer",
            "install": [
                ("Téléchargement direct", "Ouvrez l’image disque et placez CoreTend dans Applications. Au premier lancement, autorisez l’accès complet au disque quand CoreTend le demande."),
                ("Homebrew", "brew install --cask ahmetbsbnr/coretend/coretend"),
                ("Terminal et assistants IA", "npx coretend mcp"),
            ],
            "npm_link": "Le paquet coretend sur npm (ligne de commande et serveur MCP)",
            "new_title": "Nouveautés de la 2.1",
            "new": "Quatre espaces au lieu de huit outils. Tout votre Mac en un clic avec l’accès complet au disque. Nettoyer lit 14 règles d’un coup — Xcode, simulateurs, npm, pnpm, Gradle, Cargo, Mail — et Annuler remet tout en place. Apps désinstalle complètement. Mises à jour automatiques signées, une ligne de commande qui nettoie et un serveur MCP pour les assistants IA.",
            "from1": "Vous avez la 2.0 ? Téléchargez la 2.1 une fois (ou lancez brew upgrade) ; les versions suivantes arriveront seules.",
            "sha": "SHA-256 · DMG",
            "sha_dmg": "SHA-256 · ZIP",
            "dmg": "Archive ZIP",
            "zip": "Archive ZIP",
            "notarized": "Signée Developer ID · notarisée par Apple",
            "released": "Publiée le",
            "files": "Fichiers et empreintes",
            "version": "Version",
        },
        "privacy": {
            "title": "Conçue pour inspirer confiance",
            "description": "Comment CoreTend traite vos fichiers : analyses en lecture seule, déplacements vers la Corbeille après revue avec Annuler, accès complet au disque expliqué, sans télémétrie.",
            "lead": "CoreTend travaille sur votre Mac et nulle part ailleurs. Elle lit librement et ne change rien avant votre décision.",
            "sections": [
                ("Pourquoi l’accès complet au disque", "macOS cache Mail, Safari et les données des apps à toutes les apps. Avec l’accès complet au disque, CoreTend peut les mesurer ; sans lui, elle lit ce que macOS permet et le dit."),
                ("Lire n’est pas modifier", "Les analyses lisent noms, tailles et dates ; le contenu n’est lu que pour comparer des copies. Rien n’est écrit dans ce qui est analysé."),
                ("Chaque déplacement vous appartient, et se défait", "Vous revoyez, puis CoreTend revérifie chaque élément juste avant de le placer dans la Corbeille. Annuler le remet en place ; rien n’est jamais effacé."),
                ("Rien ne quitte votre Mac", "Ni compte, ni statistique. La seule requête demande à coretend.ahmetbsbnr.com si une mise à jour existe, et vous pouvez la désactiver. Open source : chacun peut vérifier."),
            ],
        },
        "support": {
            "title": "De l’aide dans la serre",
            "description": "Aide pour CoreTend : accès complet au disque, récupérer un fichier, désinstaller, mises à jour et signaler un problème.",
            "lead": "Les réponses aux questions courantes. Pour le reste, ouvrez une issue sur GitHub — sans chemins personnels.",
            "sections": [
                ("Accès complet au disque", "Réglages Système › Confidentialité et sécurité › Accès complet au disque : activez CoreTend. macOS peut demander de la rouvrir."),
                ("Un dossier ne peut pas être lu", "Sans l’accès complet au disque, macOS garde certains dossiers fermés. CoreTend dit quand un résultat est partiel."),
                ("Récupérer un fichier", "Cliquez sur Annuler juste après un nettoyage, ou ouvrez la Corbeille et choisissez Remettre en place."),
                ("Une app ne se déplace pas", "Certaines apps appartiennent au système ou à un administrateur. CoreTend les laisse en place et le dit ; retirez-les dans le Finder si vous en êtes sûr."),
                ("Retirer CoreTend", "Quittez-la et placez-la dans la Corbeille. Ses données locales sont dans ~/Library/Application Support/CoreTend-Reconstruction."),
                ("Signaler un problème", "Ouvrez une issue GitHub avec votre version de macOS et ce que vous avez vu. Laissez de côté noms de fichiers et chemins personnels."),
            ],
        },
        "developer": {
            "title": "Pour les développeurs",
            "description": "CoreTend dans le terminal et pour les assistants IA : coretend clean, le serveur MCP en lecture seule, npm et Homebrew ; construire depuis les sources.",
            "lead": "Nettoyez depuis le terminal, laissez votre assistant IA lire votre disque, ou construisez CoreTend vous-même. Swift 6, Apache 2.0.",
            "sections": [
                ("Nettoyer depuis le terminal", "Une simulation d’abord ; --confirm place les éléments sûrs dans la Corbeille.", ["coretend clean", "coretend clean --confirm"]),
                ("Serveur MCP pour assistants IA", "Outils en lecture seule : disk_usage, cleanup_candidates, largest_items, app_leftovers.", ["npx -y coretend mcp"]),
                ("Construire", "Clonez le dépôt et construisez avec Swift Package Manager sur macOS 14 ou plus récent.", ["swift build --product CoreTendApp", "make qualify"]),
                ("Système de design", "Le système Serre — palette, typographie, formes de feuille, jetons de mouvement, la serre vivante — vit dans un module et est vérifié par des tests."),
                ("Règles de sûreté", "Un seul module peut déplacer des fichiers, seulement vers la Corbeille, après revalidation. La construction vérifie qu’aucun autre code ne peut supprimer ou renommer un fichier."),
                ("Contribuer", "Lisez CONTRIBUTING.md, ouvrez d’abord une issue pour les changements importants, et reliez chaque affirmation à une mesure."),
            ],
        },
    },
}

# ---------------------------------------------------------------------------------------------
# Living pieces (all decorative; the content never depends on them). No inline style attribute:
# the site's CSP (style-src 'self') would block it, so per-item timing lives in living.css.

MARK = (
    '<svg class="mark" viewBox="200 180 624 680" aria-hidden="true" focusable="false">'
    '<path class="mark-stem" pathLength="1" d="M512 780 C 512 640, 506 520, 520 400"/>'
    '<path class="mark-leaf mark-leaf-1" d="M518 470 C 430 470, 330 420, 300 300 C 410 290, 500 350, 518 470 Z"/>'
    '<path class="mark-leaf mark-leaf-2" d="M524 400 C 560 290, 660 220, 770 230 C 760 350, 660 420, 524 400 Z"/>'
    '<path class="mark-soil" d="M250 800 Q 512 730 774 800"/>'
    '</svg>'
)

SHOOT_HEIGHTS = [120, 170, 90, 200, 150, 230, 110, 185, 140, 210, 100, 160, 130, 195, 105, 175, 145, 220, 115, 165,
                 125, 205, 95, 180, 150, 225, 110, 170]
WILTED = 11
POLLEN = 22
# Narrow scenes (13 shoots, 960 wide) and wide ones (20 shoots, 1440 wide) share the same timing classes.
# scene: (shoots, width, arch starts, shoot height factor, fit). "full" fills the width
# ("slice") with lower shoots, so a height capped by the screen only trims the empty sky.
SCENES = {"narrow": (13, 960, (20, 330, 640), 1.0, "meet"), "wide": (20, 1440, (20, 330, 640, 950, 1260), 1.0, "meet"),
          "full": (28, 2016, (20, 330, 640, 950, 1260, 1570), .72, "slice")}


def sprout(x: float, height: float, index: int) -> str:
    top = 300 - height
    return (f'<g class="shoot shoot-{index}{" shoot-wilted" if index == WILTED else ""}" transform="translate({x} 0)">'
            f'<g class="shoot-sway">'
            f'<path class="shoot-stem" pathLength="1" d="M0 300 C 0 {300 - height * 0.5}, -4 {top + 20}, 2 {top}"/>'
            f'<path class="shoot-leaf" d="M1 {top + height * 0.35} C -18 {top + height * 0.35}, -34 {top + height * 0.2}, -38 {top} C -20 {top - 2}, -4 {top + 10}, 1 {top + height * 0.35} Z"/>'
            f'<path class="shoot-leaf" d="M2 {top + 8} C 10 {top - 14}, 28 {top - 26}, 44 {top - 24} C 42 {top - 4}, 24 {top + 10}, 2 {top + 8} Z"/>'
            f'</g></g>')


def greenhouse(css: str = "", scene: str = "narrow") -> str:
    count, width, arch_starts, factor, fit = SCENES[scene]
    shoots = "".join(sprout(60 + i * 72, SHOOT_HEIGHTS[i] * factor, i) for i in range(count))
    arches = "".join(f'<path class="glass" d="M{x} 300 Q {x + 150} {-20} {x + 300} 300"/><path class="mullion" d="M{x + 150} 300 V 140"/>'
                     for x in arch_starts if x + 300 <= width)
    pollen = "".join(f'<span class="p{i}"></span>' for i in range(POLLEN))
    return (f'<div class="greenhouse{" " + css if css else ""}" aria-hidden="true">'
            f'<svg viewBox="0 0 {width} 310" preserveAspectRatio="xMidYMax {fit}" focusable="false">'
            f'{arches}{shoots}<rect class="soil" x="0" y="300" width="{width}" height="10"/></svg>'
            f'<div class="pollen">{pollen}</div></div>')


def living_css() -> str:
    """Per-shoot and per-pollen timing, generated so the HTML needs no style attribute."""
    rules = ["/* Generated by Scripts/build_site.py: per-item timing of the living greenhouse. */"]
    for i in range(len(SHOOT_HEIGHTS)):
        rules.append(f".shoot-{i} .shoot-sway {{ animation-duration: {2.6 + i * .17:.2f}s; animation-delay: {1.4 - i * .3:.2f}s; }}")
        rules.append(f".shoot-{i} .shoot-stem {{ animation-delay: {.3 + i * .07:.2f}s; }}")
        rules.append(f".shoot-{i} .shoot-leaf {{ animation-delay: {.9 + i * .07:.2f}s; }}")
    for i in range(POLLEN):
        rules.append(f".pollen .p{i} {{ left: {(i * 37) % 100}%; animation-duration: {7 + (i * 3) % 7}s; animation-delay: {-(i * 1.3):.1f}s; }}")
    return "\n".join(rules) + "\n"


VINE = ('<svg class="vine" viewBox="0 0 1200 40" preserveAspectRatio="none" aria-hidden="true" focusable="false">'
        '<path pathLength="1" d="M0 20 C 100 0, 200 40, 300 20 S 500 0, 600 20 S 800 40, 900 20 S 1100 0, 1200 20"/></svg>')

LEAF = '<svg class="leaf-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M5 19 C 5 10, 11 4, 20 4 C 20 13, 14 19, 5 19 Z"/><path class="leaf-vein" d="M5 19 L 14 10"/></svg>'


# ---------------------------------------------------------------------------------------------
# Page pieces

def file_name(route: str) -> str:
    return "index.html" if route == "index" else f"{route}.html"


def route_url(lang: str, route: str) -> str:
    return f"/{lang}" + ("" if route == "index" else f"/{route}")


def header(lang: str, route: str) -> str:
    c = COPY[lang]
    links = "".join(f'<a href="{route_url(lang, r)}"{" aria-current=\"page\"" if r == route else ""}>{escape(c["nav"][r])}</a>'
                    for r in ROUTES if r != "index")
    other = "fr" if lang == "en" else "en"
    return f"""<a class="skip-link" href="#main">{escape(c['skip'])}</a>
<header class="site-header">
  <div class="header-inner">
    <a class="brand" href="{route_url(lang, 'index')}" aria-label="CoreTend — {escape(c['nav']['index'])}">{MARK}<span>CoreTend<small>{escape(c['note'])}</small></span></a>
    <nav class="primary-nav" aria-label="{escape(c['nav_label'])}">{links}</nav>
    <a class="lang" href="{route_url(other, route)}" lang="{other}" hreflang="{other}">{escape(c['other'])}</a>
  </div>
</header>"""


def footer(lang: str) -> str:
    c = COPY[lang]
    links = "".join(f'<a href="{route_url(lang, r)}">{escape(c["nav"][r])}</a>' for r in ROUTES if r != "index")
    return f"""<footer class="site-footer">
  {greenhouse("greenhouse-footer", "full")}
  <div class="footer-inner">
    <div class="footer-brand"><a class="brand" href="{route_url(lang, 'index')}">{MARK}<span>CoreTend<small>{escape(c['note'])}</small></span></a><p>{escape(c['footer'])}</p></div>
    <nav aria-label="{escape(c['footer_links'])}">{links}<a href="{REPO}">GitHub</a></nav>
    <p class="footer-meta">© 2026 CoreTend · Apache 2.0</p>
  </div>
</footer>"""


def download_button(lang: str, rel: dict, *, large: bool = False) -> str:
    c = COPY[lang]
    if rel.get("published") and rel.get("url"):
        return (f'<a class="button button-primary{" button-large" if large else ""}" href="{escape(rel["url"], quote=True)}">'
                f'{escape(c["cta_download"])}<span aria-hidden="true"> ↓</span></a>')
    return f'<p class="unpublished">{escape(c["unpublished"])}</p>'


def capture(lang: str, surface: str, title: str, *, hero: bool = False, caption: bool = True) -> str:
    image = f"../screenshots/{surface}-{lang}"
    return (f'<figure class="capture{" capture-hero" if hero else " reveal"}">'
            f'<picture><source media="(prefers-color-scheme: light)" srcset="{image}-light.png">'
            f'<img src="{image}-dark.png" alt="CoreTend — {escape(title, quote=True)}" width="2880" height="1800" loading="{"eager" if hero else "lazy"}"></picture>'
            + (f'<figcaption>{escape(title)}</figcaption>' if caption else "") + '</figure>')


def cards(items, css: str = "card") -> str:
    out = []
    for item in items:
        title, body, *extra = item
        detail = f"<p>{escape(body)}</p>" if body else ""
        if extra:
            detail += "".join(f"<code>{escape(line)}</code>" for line in extra[0])
        out.append(f'<article class="{css} reveal">{LEAF}<h3>{escape(title)}</h3>{detail}</article>')
    return "".join(out)


def section_head(title: str, lead: str = "", ident: str = "") -> str:
    return (f'<div class="section-head reveal"><h2{f" id=\"{ident}\"" if ident else ""}>{escape(title)}</h2>'
            + (f'<p>{escape(lead)}</p>' if lead else "") + '</div>')


SURFACE = {key: key for key in ("home", "space", "clean", "apps", "record")}

MONTHS = {"en": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"],
          "fr": ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"]}


def long_date(lang: str, iso: str) -> str:
    year, month, day = (int(part) for part in iso.split("-"))
    name = MONTHS[lang][month - 1]
    return f"{name} {day}, {year}" if lang == "en" else f"{day} {name} {year}"


def home(lang: str, rel: dict) -> str:
    c, p = COPY[lang], COPY[lang]["home"]
    tools = "".join(
        f'<a class="tool reveal" href="{route_url(lang, "features")}#{key}">'
        f'<strong>{escape(name)}</strong><span class="tool-body">{escape(tag)}. {escape(body)}</span></a>'
        for key, name, tag, body in DESTINATIONS[lang])
    proof = "".join(f'<div class="proof-item reveal"><strong>{escape(value)}</strong><span>{escape(label)}</span></div>'
                    for value, label in p["proof"])
    shows = "".join(
        f'<section class="split{" split-flip" if n % 2 else ""}"><div class="split-copy reveal">'
        f'<h2>{escape(title)}</h2><p>{escape(body)}</p></div>{capture(lang, surface, title, caption=False)}</section>'
        for n, (surface, title, body) in enumerate(p["show"]))
    return f"""<main id="main">
  <section class="hero">
    <div class="hero-inner">
    <div class="hero-copy">
      <h1>{escape(p['title'])}</h1>
      <p class="lead">{escape(p['lead'])}</p>
      <div class="actions">{download_button(lang, rel, large=True)}<a class="button button-secondary button-large" href="{route_url(lang, "features")}">{escape(c['cta_features'])}<span aria-hidden="true"> →</span></a></div>
      <p class="requirements">{escape(c['requirements'])}</p>
      {channels(lang)}
    </div>
    <div class="hero-icon"><img src="../brand/coretend-app-icon-512.png" alt="CoreTend" width="512" height="512"></div>
    </div>
    {greenhouse("greenhouse-hero", "full")}
  </section>
  <div class="stage">{capture(lang, "home", DESTINATIONS[lang][0][1] + " — " + DESTINATIONS[lang][0][2], hero=True, caption=False)}</div>
  <section class="proof" aria-label="CoreTend">{proof}</section>
  <section class="band" aria-labelledby="tools-title">{section_head(p['tools_title'], p['tools_lead'], "tools-title")}<div class="tools">{tools}</div>
    <p class="more reveal"><a href="{route_url(lang, "features")}">{escape(p['tools_cta'])} <span aria-hidden="true">→</span></a></p></section>
  {shows}
  <section class="band" aria-labelledby="alive-title">{section_head(p['alive_title'], ident="alive-title")}<div class="cards cards-three">{cards(p['alive'])}</div></section>
  <section class="band" aria-labelledby="never-title">{section_head(p['never_title'], ident="never-title")}<div class="cards cards-three">{cards(p['never'], "card card-never")}</div></section>
  <section class="final reveal"><div class="final-mark">{MARK}</div><h2>{escape(p['final_title'])}</h2><div class="actions">{download_button(lang, rel, large=True)}</div><p class="requirements">{escape(c['requirements'])}</p></section>
</main>"""


def features(lang: str) -> str:
    p = COPY[lang]["features"]
    chips = "".join(f'<a href="#{key}">{escape(name)}</a>' for key, name, _, _ in DESTINATIONS[lang])
    blocks = "".join(
        f'<section class="split feature{" split-flip" if n % 2 else ""}" id="{key}"><div class="split-copy reveal">'
        f'<h2>{escape(tag)}</h2><p>{escape(body)}</p></div>{capture(lang, SURFACE[key], name + " — " + tag, caption=False)}</section>'
        for n, (key, name, tag, body) in enumerate(DESTINATIONS[lang]))
    return f"""<main id="main">
  {intro(p)}
  <nav class="chips" aria-label="{escape(p['jump'])}">{chips}</nav>
  {blocks}
  <section class="band">{section_head(p['also_title'])}<div class="cards cards-four">{cards(p['also'])}</div></section>
</main>"""


def download(lang: str, rel: dict) -> str:
    c, p = COPY[lang], COPY[lang]["download"]
    published = bool(rel.get("published") and rel.get("url"))
    dmg = rel.get("dmg") if published else None
    if published:
        buttons = download_button(lang, rel, large=True)
        if dmg:
            buttons += f'<a class="button button-secondary button-large" href="{escape(dmg["url"], quote=True)}">{escape(p["dmg"])}</a>'
        date = f' · {escape(p["released"])} {escape(long_date(lang, rel["date"]))}' if rel.get("date") else ""
        panel_meta = f'<p class="panel-meta">{escape(p["notarized"])}{date}</p>'
    else:
        buttons, panel_meta = download_button(lang, rel), ""
    rows = [(p["version"], escape(rel["version"])), ("macOS", escape(c["requirements"]))]
    if published:
        rows.append((p["sha"], f'<code>{escape(rel["sha256"])}</code>'))
        if dmg:
            rows.append((p["sha_dmg"], f'<code>{escape(dmg["sha256"])}</code>'))
    facts = "".join(f'<div><dt>{escape(term)}</dt><dd>{value}</dd></div>' for term, value in rows)
    install = cards([(t, "", [b]) if b.startswith(("brew ", "npx ")) else (t, b) for t, b in p['install']])
    return f"""<main id="main">
  {intro(p)}
  <section class="band band-tight">
    <div class="download-panel reveal">
      <div class="panel-main"><img class="panel-icon" src="../brand/coretend-app-icon-512.png" alt="CoreTend" width="512" height="512">
        <div><h2>CoreTend {escape(rel['version'])}</h2>{panel_meta}<div class="actions">{buttons}</div></div></div>
      <div class="panel-facts"><h3>{escape(p['files'])}</h3><dl class="facts">{facts}</dl></div>
    </div>
  </section>
  <section class="band">{section_head(p['install_title'])}<div class="cards cards-three">{install}</div>
    <p class="more reveal"><a href="{NPM}">{escape(p['npm_link'])} <span aria-hidden="true">→</span></a></p></section>
  <section class="band">{section_head(p['new_title'])}<div class="prose reveal"><p>{escape(p['new'])}</p><p>{escape(p['from1'])}</p></div></section>
</main>"""


def intro(p: dict) -> str:
    return (f'<section class="intro"><h1>{escape(p["title"])}</h1>'
            f'<p class="lead">{escape(p["lead"])}</p>{VINE}</section>')


def simple(lang: str, route: str) -> str:
    p = COPY[lang][route]
    extra = channels(lang) if route == "developer" else ""
    return f"""<main id="main">
  {intro(p)}
  <section class="band band-tight"><div class="cards cards-two">{cards(p['sections'])}</div>{extra}</section>
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
  <link rel="stylesheet" href="../living.css">
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
  <meta name="description" content="CoreTend — see what fills your Mac, clear it safely. Voyez ce qui remplit votre Mac, libérez-le sans risque.">
  <meta name="theme-color" content="#0F2019">
  <link rel="icon" href="brand/coretend-mark-dark.svg" type="image/svg+xml">
  <meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'none'; style-src 'self'; img-src 'self'; font-src 'self'; connect-src 'self'; base-uri 'none'; object-src 'none'; form-action 'self'">
  <title>CoreTend — choose your language / choisir la langue</title>
  <link rel="stylesheet" href="design-tokens.css">
  <link rel="stylesheet" href="site.css">
  <link rel="stylesheet" href="living.css">
</head>
<body class="page-language">
  <a class="skip-link" href="#main">Skip / Aller au contenu</a>
  <main id="main" class="language">
    <div class="language-card">
      <img class="language-icon" src="brand/coretend-app-icon-512.png" alt="CoreTend" width="512" height="512">
      <p class="language-name">CoreTend</p>
      <h1>See what fills your Mac. Clear it safely.<span lang="fr">Voyez ce qui remplit votre Mac. Libérez-le sans risque.</span></h1>
      <nav class="actions" aria-label="Language / Langue"><a class="button button-primary button-large" href="/en" lang="en">English <span aria-hidden="true">→</span></a><a class="button button-secondary button-large" href="/fr" lang="fr">Français <span aria-hidden="true">→</span></a></nav>
    </div>
    {greenhouse("greenhouse-ground", "full")}
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
                 "coretend-logotype-light.svg", "coretend-app-icon-1024.png", "coretend-app-icon-512.png"):
        shutil.copyfile(ROOT / "Resources/Brand/Logo" / name, brand / name)
    (SITE / "living.css").write_text(living_css(), encoding="utf-8")
    for lang in LANGUAGES:
        (SITE / lang).mkdir(exist_ok=True)
        for route in ROUTES:
            (SITE / lang / file_name(route)).write_text(document(lang, route, rel), encoding="utf-8")
    (SITE / "index.html").write_text(language_index(), encoding="utf-8")


if __name__ == "__main__":
    main()
