#!/usr/bin/env python3
"""Generate CoreTend's small, bilingual, no-framework static website."""

from html import escape
from pathlib import Path

from export_design_tokens import export_tokens

ROOT = Path(__file__).resolve().parents[1]
LANGUAGES = ("en", "fr")
ROUTES = ("index", "features", "privacy", "developer", "support")

COPY = {
    "en": {
        "language": "English",
        "other_language": "Français",
        "skip": "Skip to content",
        "nav_label": "Main navigation",
        "menu": "Menu",
        "brand_note": "LOCAL MACOS EXPLORER",
        "preview": "Unreleased local reconstruction",
        "preview_short": "Local preview · unreleased",
        "no_download": "No download is published.",
        "language_title": "Choose your language",
        "language_intro": "CoreTend is a macOS reconstruction in progress. Read about its direction and current limits.",
        "nav": {"index": "Overview", "features": "Features", "privacy": "Privacy", "developer": "Developers", "support": "Support"},
        "footer_note": "Local-first by design. No release is available.",
        "footer_links": "Explore",
        "home": {
            "title": "A clearer view of your Mac.",
            "description": "CoreTend is a local-first macOS disk and system explorer in active reconstruction. See what works today, how review stays in your hands, and what remains unqualified.",
            "kicker": "A quieter way to inspect",
            "lead": "Understand what is on your Mac before deciding what to do. CoreTend keeps folder scans read-only and asks for explicit review before a selected item can move to Trash.",
            "primary": "Explore current capabilities",
            "secondary": "Read the privacy model",
            "scene_label": "A review flow, not a screenshot",
            "scene_caption": "Concept diagram · The app is still being rebuilt; this is not a capture of its interface.",
            "scene_steps": [("01", "Choose", "Select a folder to inspect."), ("02", "Understand", "Review measured items and their context."), ("03", "Decide", "Keep files, or confirm a move to macOS Trash.")],
            "section_title": "Clarity before action",
            "section_intro": "The interface is being reshaped around observable evidence, clear scope and explicit choices.",
            "sections": [
                ("Space, with context", "Explore a chosen folder with search, sorting, measured sizes and a proportional space map. Unknown and cloud-backed sizes stay out of the measured total."),
                ("Duplicates you can review", "Exact duplicates come from content comparison. Similar-image matches are advisory candidates. Nothing is selected for removal automatically."),
                ("A local record", "Favorites and optional recent paths stay on this Mac. Recent paths are off by default and limited to 100 entries."),
            ],
            "status_title": "A work in progress",
            "status_text": "This branch is public source for an unreleased reconstruction. Some flows work locally; accessibility, migration and distribution still need qualification. No download is published.",
            "status_link": "See what is implemented",
        },
        "features": {
            "title": "Tools for careful inspection",
            "description": "Current and planned CoreTend capabilities, with implemented behaviors separated from work still needing qualification.",
            "kicker": "Product scope",
            "lead": "The target has eight macOS destinations. This page describes implemented preview behavior and names important limits alongside it.",
            "sections": [
                ("Explore a chosen folder", "Read-only scans support exclusions, search and sorting, a proportional map, Quick Look, and explicit size or age filters. Partial scans say when access limits results. Unknown sizes are not presented as measured space."),
                ("Review before cleanup", "Cleanup rules require an explicit folder and candidates stay unselected until reviewed. Exact duplicate groups use content comparison; similar-image pairs are heuristic. A move requires review, confirmation, target revalidation and macOS Trash."),
                ("Inspect app and system signals", "A chosen-folder inventory reports app metadata and partial-read reasons. Code signature, quarantine marker and configured login-item evidence appear as separate signals, without a combined safe or malicious verdict."),
                ("Keep a local record", "The app can store activity records, manual performance samples, favorites and optional recent paths locally. Recent paths are off by default and capped at 100. The read-only command-line interface reports partial scan status explicitly."),
            ],
            "limits_title": "Not yet qualified",
            "limits": "Verified app-data attribution and complete uninstall; an App Store update source and version comparison; cloud storage details; native accessibility qualification; broader migration evidence; and signed distribution remain open work.",
            "cta": "Read privacy and safety details",
        },
        "privacy": {
            "title": "Your files stay in your hands",
            "description": "How CoreTend's local macOS reconstruction handles scans, file contents, saved paths, history and destructive actions.",
            "kicker": "Privacy and safety",
            "lead": "This reconstruction sends no telemetry and has no account or cloud sync. Inspection is scoped to the folder you choose; any file change follows an explicit review and confirmation flow.",
            "sections": [
                ("Local inspection", "A scan reads metadata from the selected folder. It reads file contents only when needed to hash content for exact-duplicate comparison. It does not write into the scanned tree. Access is limited by the folder you select and macOS permissions."),
                ("Paths and saved history", "Favorites and enabled recent history store paths and last known sizes locally. Recent history is off by default and limited to 100 entries. Activity records and manual performance samples are local; their retention and complete export flow still need qualification."),
                ("Moves need your decision", "A candidate is never removed just because it was found. You select items, inspect a proposal, confirm the action, and CoreTend revalidates targets before using macOS Trash. It does not promise to remove related application data."),
                ("Network boundary", "There is no telemetry, account, or cloud synchronization in this reconstruction. An app-declared HTTPS update-feed link can open in your browser when you choose it; the feed is not independently verified by that signal."),
            ],
            "notice_title": "Before sharing diagnostics",
            "notice": "Exports and event records can contain file names or paths. Review any material before sharing it. Do not include private paths or database contents in source feedback.",
        },
        "developer": {
            "title": "Build and inspect the source",
            "description": "Developer notes for the unreleased CoreTend macOS reconstruction: local build products, interface boundaries and known qualification gaps.",
            "kicker": "For contributors",
            "lead": "The repository contains a Swift 6 package with a native macOS app and a read-only command-line product. No external runtime package dependency is required.",
            "sections": [
                ("Build locally", "From the repository root, use Swift Package Manager to build the app or command-line product. The website is generated separately with the Python scripts in Scripts/.", ["swift build --product CoreTendApp", "swift build --product CoreTendCLI", "python3 Scripts/build_site.py"]),
                ("Keep boundaries intact", "Scan code is read-only. File actions must retain chosen-folder scope, explicit selection, proposal review, confirmation, target revalidation and macOS Trash. Do not treat signature, quarantine or login-item presence as a security verdict."),
                ("Report source issues safely", "Include macOS version, architecture, command and complete error output. Use repository issues for code feedback. Remove personal file paths and database contents before sharing logs."),
                ("Release status", "This branch is an unreleased public-source reconstruction. Signing, notarization, release artifacts, download links and product support are not available or promised."),
            ],
            "notice_title": "Repository scope",
            "notice": "No new runtime dependency, telemetry, remote asset, or account flow is part of this website rebuild.",
        },
        "support": {
            "title": "Help for a work in progress",
            "description": "Source-feedback guidance and practical notes for CoreTend's unreleased local reconstruction.",
            "kicker": "Support and feedback",
            "lead": "CoreTend is not a released product. The repository is public source for an ongoing reconstruction, with no download or product-support commitment.",
            "sections": [
                ("Folder access", "Choose a folder you intend to inspect and grant only the access macOS requests for that location. A denied or partial result should be treated as incomplete, not as an empty folder."),
                ("Unexpected scan result", "Record the macOS version, Mac architecture, selected scope and exact error message. Avoid attaching private file paths, file names or database contents to a public issue."),
                ("Before a file move", "Review the selected items and destination summary. The action should ask for confirmation and use macOS Trash. Cancel if the scope, item list or expected result is unclear."),
                ("Source feedback", "Use the repository issue tracker for implementation feedback. There is no published download, release channel, response-time promise or commercial support contact for this reconstruction."),
            ],
            "notice_title": "No product download yet",
            "notice": "Do not install a build from an unverified source or treat this website as a release announcement.",
        },
    },
    "fr": {
        "language": "Français",
        "other_language": "English",
        "skip": "Aller au contenu",
        "nav_label": "Navigation principale",
        "menu": "Menu",
        "brand_note": "EXPLORATEUR MACOS LOCAL",
        "preview": "Reconstruction locale non publiée",
        "preview_short": "Aperçu local · non publié",
        "no_download": "Aucun téléchargement n’est publié.",
        "language_title": "Choisir votre langue",
        "language_intro": "CoreTend est une reconstruction macOS en cours. Découvrez sa direction et ses limites actuelles.",
        "nav": {"index": "Vue d’ensemble", "features": "Fonctionnalités", "privacy": "Confidentialité", "developer": "Développeur", "support": "Assistance"},
        "footer_note": "Pensé pour le local. Aucune version n’est publiée.",
        "footer_links": "Explorer",
        "home": {
            "title": "Mieux comprendre son Mac.",
            "description": "CoreTend est un explorateur local du disque et du système sur macOS, en reconstruction active. Découvrez les fonctions présentes, gardez la main sur chaque revue et voyez ce qui reste à qualifier.",
            "kicker": "Inspecter avec plus de calme",
            "lead": "Comprenez le contenu de votre Mac avant de décider. CoreTend garde les analyses de dossiers en lecture seule et demande une revue explicite avant tout déplacement vers la Corbeille.",
            "primary": "Voir les fonctions actuelles",
            "secondary": "Lire le modèle de confidentialité",
            "scene_label": "Un parcours de revue, pas une capture",
            "scene_caption": "Schéma de principe · L’app est en reconstruction ; ceci n’est pas une capture de son interface.",
            "scene_steps": [("01", "Choisir", "Sélectionner un dossier à inspecter."), ("02", "Comprendre", "Examiner les éléments mesurés et leur contexte."), ("03", "Décider", "Garder les fichiers ou confirmer leur envoi à la Corbeille macOS.")],
            "section_title": "Comprendre avant d’agir",
            "section_intro": "L’interface se recentre sur les éléments observables, le périmètre clair et les choix explicites.",
            "sections": [
                ("L’espace, avec son contexte", "Explorer un dossier choisi avec recherche, tri, tailles mesurées et carte proportionnelle. Les tailles inconnues ou liées au cloud restent exclues du total mesuré."),
                ("Des doublons à examiner", "Les doublons exacts reposent sur la comparaison du contenu. Les images similaires sont des candidates indicatives. Aucun élément n’est automatiquement sélectionné pour retrait."),
                ("Un historique local", "Favoris et chemins récents facultatifs restent sur ce Mac. L’historique récent est désactivé par défaut et limité à 100 entrées."),
            ],
            "status_title": "Un projet en cours",
            "status_text": "Cette branche est le code source public d’une reconstruction non publiée. Certains parcours fonctionnent en local ; accessibilité, migration et distribution restent à qualifier. Aucun téléchargement n’est publié.",
            "status_link": "Voir ce qui est implémenté",
        },
        "features": {
            "title": "Des outils pour inspecter avec soin",
            "description": "Fonctions présentes et prévues de CoreTend : comportements implémentés distingués des sujets qui restent à qualifier.",
            "kicker": "Périmètre produit",
            "lead": "La cible comporte huit destinations macOS. Cette page décrit l’aperçu implémenté et précise ses limites à proximité.",
            "sections": [
                ("Explorer un dossier choisi", "Les analyses en lecture seule prennent en charge exclusions, recherche, tri, carte proportionnelle, Quick Look et filtres explicites de taille ou d’âge. Un état partiel indique les limites d’accès. Les tailles inconnues ne sont pas présentées comme espace mesuré."),
                ("Examiner avant le nettoyage", "Les règles de nettoyage exigent un dossier explicite ; les candidates restent désélectionnées jusqu’à leur revue. Les groupes de doublons exacts reposent sur le contenu ; les paires d’images similaires sont heuristiques. Un déplacement exige revue, confirmation, nouvelle validation de la cible et Corbeille macOS."),
                ("Inspecter apps et signaux système", "L’inventaire d’un dossier choisi indique les métadonnées des apps et les raisons d’une lecture partielle. Signature, marque de quarantaine et éléments de connexion configurés apparaissent comme signaux séparés, sans verdict global de sécurité."),
                ("Garder un historique local", "L’app peut enregistrer localement événements, mesures Performance manuelles, favoris et chemins récents facultatifs. Les chemins récents sont désactivés par défaut et limités à 100. L’interface en ligne de commande en lecture seule signale explicitement les analyses partielles."),
            ],
            "limits_title": "Pas encore qualifié",
            "limits": "Attribution vérifiée des données d’apps et désinstallation complète ; source App Store et comparaison des versions ; détails du stockage cloud ; qualification native d’accessibilité ; preuves de migration plus larges et distribution signée restent à réaliser.",
            "cta": "Lire les détails de confidentialité et de sûreté",
        },
        "privacy": {
            "title": "Vos fichiers restent sous votre contrôle",
            "description": "Comment la reconstruction locale CoreTend sur macOS traite analyses, contenus, chemins enregistrés, historique et actions destructives.",
            "kicker": "Confidentialité et sûreté",
            "lead": "Cette reconstruction n’envoie aucune télémétrie et ne propose ni compte ni synchronisation cloud. L’inspection se limite au dossier choisi ; toute modification suit une revue et une confirmation explicites.",
            "sections": [
                ("Inspection locale", "Une analyse lit les métadonnées du dossier sélectionné. Le contenu est lu uniquement si nécessaire au calcul d’empreintes comparées pour les doublons exacts. L’analyse n’écrit pas dans l’arborescence inspectée. L’accès dépend du dossier choisi et des permissions macOS."),
                ("Chemins et historique conservés", "Les favoris et l’historique récent activé conservent localement les chemins et dernières tailles connues. L’historique récent est désactivé par défaut et limité à 100 entrées. Événements et mesures Performance manuelles restent locaux ; conservation et export complet restent à qualifier."),
                ("Un déplacement exige votre décision", "Une candidate n’est jamais retirée du seul fait de sa détection. Vous choisissez les éléments, examinez la proposition, confirmez l’action ; CoreTend revalide ensuite les cibles avant d’utiliser la Corbeille macOS. L’app ne promet pas de retirer les données associées."),
                ("Limite réseau", "Cette reconstruction ne comporte ni télémétrie, ni compte, ni synchronisation cloud. Un lien HTTPS de mise à jour déclaré par l’app peut s’ouvrir dans votre navigateur après votre clic ; ce signal ne vérifie pas le flux indépendamment."),
            ],
            "notice_title": "Avant de partager un diagnostic",
            "notice": "Les exports et événements peuvent contenir des noms de fichiers ou des chemins. Relisez tout contenu avant partage. N’incluez pas de chemins privés ou de base de données dans un retour public.",
        },
        "developer": {
            "title": "Construire et examiner le code source",
            "description": "Notes pour les développeurs de la reconstruction CoreTend non publiée : produits locaux, limites d’interface et sujets de qualification.",
            "kicker": "Pour contribuer",
            "lead": "Le dépôt contient un paquet Swift 6 avec une app macOS native et un produit en ligne de commande en lecture seule. Aucun paquet externe n’est requis à l’exécution.",
            "sections": [
                ("Construire en local", "Depuis la racine du dépôt, Swift Package Manager construit l’app ou le produit en ligne de commande. Le site est généré séparément par les scripts Python dans Scripts/.", ["swift build --product CoreTendApp", "swift build --product CoreTendCLI", "python3 Scripts/build_site.py"]),
                ("Préserver les frontières", "Le code d’analyse reste en lecture seule. Toute action doit conserver le dossier choisi, la sélection explicite, la revue, la confirmation, la revalidation de la cible et la Corbeille macOS. Ne transformez pas les signaux de signature, quarantaine ou connexion en verdict de sécurité."),
                ("Signaler un problème sans exposer de données", "Indiquez la version de macOS, l’architecture du Mac, la commande et le message complet. Utilisez les issues du dépôt pour les retours. Retirez chemins personnels et contenu de base de données des journaux partagés."),
                ("État de publication", "Cette branche est une reconstruction publique en source, non publiée. Signature, notarisation, artefacts, liens de téléchargement et support produit ne sont ni disponibles ni promis."),
            ],
            "notice_title": "Périmètre du dépôt",
            "notice": "Cette refonte du site n’ajoute ni dépendance runtime, ni télémétrie, ni ressource distante, ni parcours de compte.",
        },
        "support": {
            "title": "Aide pour un projet en cours",
            "description": "Conseils pour les retours sur le code et l’usage prudent de la reconstruction locale CoreTend non publiée.",
            "kicker": "Assistance et retours",
            "lead": "CoreTend n’est pas un produit publié. Le dépôt est le code source public d’une reconstruction en cours, sans téléchargement ni engagement de support produit.",
            "sections": [
                ("Accès aux dossiers", "Choisissez le dossier que vous souhaitez inspecter et accordez seulement l’accès demandé par macOS pour cet emplacement. Un refus ou résultat partiel signifie que l’inspection est incomplète, pas que le dossier est vide."),
                ("Résultat d’analyse inattendu", "Notez la version de macOS, l’architecture du Mac, le périmètre choisi et le message d’erreur exact. Évitez de joindre chemins privés, noms de fichiers ou contenu de base de données à une issue publique."),
                ("Avant un déplacement", "Relisez les éléments choisis et le résumé de destination. L’action doit demander confirmation et utiliser la Corbeille macOS. Annulez si le périmètre, la liste ou le résultat attendu n’est pas clair."),
                ("Retour sur le code source", "Utilisez le suivi des issues du dépôt pour parler d’implémentation. Cette reconstruction n’a ni téléchargement publié, ni canal de release, ni délai de réponse, ni contact de support commercial."),
            ],
            "notice_title": "Aucun téléchargement produit",
            "notice": "N’installez pas de build d’une source non vérifiée et ne prenez pas ce site pour une annonce de publication.",
        },
    },
}


def file_name(route: str) -> str:
    return "index.html" if route == "index" else f"{route}.html"


def rel_path(from_route: str, to_route: str) -> str:
    if from_route == "root":
        return f"{to_route}/{file_name('index' if to_route == 'index' else to_route)}"
    return file_name(to_route)


def section_markup(sections: list[tuple], *, ordered: bool = False) -> str:
    out = []
    for item in sections:
        title, body, *extra = item
        detail = f"<p>{escape(body)}</p>"
        if extra:
            detail += "<ul class=\"command-list\">" + "".join(
                f"<li><code>{escape(command)}</code></li>" for command in extra[0]
            ) + "</ul>"
        out.append(f"<article class=\"topic\"><h3>{escape(title)}</h3>{detail}</article>")
    return "\n".join(out)


def header(lang: str, route: str) -> str:
    copy = COPY[lang]
    nav_items = []
    for item in ROUTES:
        current_attr = ' aria-current="page"' if route == item else ""
        nav_items.append(
            f'<a href="{escape(rel_path(route, item))}"{current_attr}>{escape(copy["nav"][item])}</a>'
        )
    nav_links = "".join(nav_items)
    switch_lang = "fr" if lang == "en" else "en"
    return f"""<a class="skip-link" href="#main">{escape(copy['skip'])}</a>
<header class="site-header">
  <a class="brand" href="{escape(rel_path(route, 'index'))}" aria-label="CoreTend — {escape(copy['nav']['index'])}">
    <span class="brand-mark" aria-hidden="true"><i></i></span><span class="brand-name">CoreTend<small>{escape(copy['brand_note'])}</small></span>
  </a>
  <button class="menu-toggle" type="button" aria-expanded="false" aria-controls="primary-navigation"><span class="menu-icon" aria-hidden="true"><i></i><i></i></span><span>{escape(copy['menu'])}</span></button>
  <nav class="primary-navigation" id="primary-navigation" aria-label="{escape(copy['nav_label'])}" data-collapsed="false">{nav_links}</nav>
  <a class="language-link" href="../{switch_lang}/{escape(file_name(route))}" lang="{switch_lang}" hreflang="{switch_lang}">{escape(copy['other_language'])}<span aria-hidden="true"> ↗</span></a>
</header>"""


def footer(lang: str, route: str) -> str:
    copy = COPY[lang]
    links = "".join(
        f'<a href="{escape(rel_path(route, item))}">{escape(copy["nav"][item])}</a>'
        for item in ("features", "privacy", "developer", "support")
    )
    return f"""<footer class="site-footer">
  <div class="footer-brand"><a class="brand" href="{escape(rel_path(route, 'index'))}"><span class="brand-mark" aria-hidden="true"><i></i></span><span class="brand-name">CoreTend<small>{escape(copy['brand_note'])}</small></span></a><p>{escape(copy['footer_note'])}</p></div>
  <div class="footer-nav"><h2>{escape(copy['footer_links'])}</h2><nav aria-label="{escape(copy['footer_links'])}">{links}</nav></div>
  <p class="footer-meta">© 2026 CoreTend · {escape(copy['preview'])}</p>
</footer>"""


def home_content(lang: str) -> str:
    page = COPY[lang]["home"]
    steps = "".join(
        f'<li><span class="step-index">{escape(number)}</span><div><h3>{escape(title)}</h3><p>{escape(body)}</p></div></li>'
        for number, title, body in page["scene_steps"]
    )
    topics = section_markup(page["sections"])
    return f"""<main id="main">
  <section class="hero section-shell" aria-labelledby="hero-title">
    <div class="hero-copy"><p class="eyebrow"><span class="status-dot" aria-hidden="true"></span>{escape(page['kicker'])}</p><h1 id="hero-title">{escape(page['title'])}</h1><p class="hero-lead">{escape(page['lead'])}</p><div class="hero-actions"><a class="button button-primary" href="features.html">{escape(page['primary'])}<span aria-hidden="true"> ↗</span></a><a class="text-link" href="privacy.html">{escape(page['secondary'])}</a></div><p class="release-note"><span class="release-marker" aria-hidden="true">i</span>{escape(COPY[lang]['preview'])}. {escape(COPY[lang]['no_download'])}</p></div>
    <figure class="flow-scene" aria-labelledby="scene-title" aria-describedby="scene-caption">
      <div class="scene-heading"><span class="scene-index">CORETEND / 01</span><span class="scene-status"><span aria-hidden="true"></span>{'READ-ONLY BY DEFAULT' if lang == 'en' else 'LECTURE SEULE PAR DÉFAUT'}</span></div>
      <ol class="flow-steps">{steps}</ol>
      <div class="scene-baseline"><span aria-hidden="true"></span><p id="scene-title">{escape(page['scene_label'])}</p><span aria-hidden="true"></span></div>
      <figcaption id="scene-caption">{escape(page['scene_caption'])}</figcaption>
    </figure>
  </section>
  <section class="section-shell intro-section" aria-labelledby="intro-title"><div class="section-heading"><p class="eyebrow">{'A measured approach' if lang == 'en' else 'Une approche mesurée'}</p><h2 id="intro-title">{escape(page['section_title'])}</h2><p>{escape(page['section_intro'])}</p></div><div class="topic-grid topic-grid-three">{topics}</div></section>
  <section class="section-shell status-section" aria-labelledby="status-title"><div class="status-copy"><p class="eyebrow">{'Current status' if lang == 'en' else 'État actuel'}</p><h2 id="status-title">{escape(page['status_title'])}</h2><p>{escape(page['status_text'])}</p></div><a class="button button-secondary" href="features.html">{escape(page['status_link'])}<span aria-hidden="true"> →</span></a></section>
</main>"""


def content_for(lang: str, route: str) -> str:
    if route == "index":
        return home_content(lang)
    page = COPY[lang][route]
    topics = section_markup(page["sections"])
    notice = ""
    if "notice" in page:
        notice = f'<aside class="notice" aria-labelledby="notice-title"><span class="notice-symbol" aria-hidden="true">!</span><div><h2 id="notice-title">{escape(page["notice_title"])}</h2><p>{escape(page["notice"])}</p></div></aside>'
    limit = ""
    if "limits" in page:
        limit = f'<aside class="limits-panel"><p class="eyebrow">{escape(page["limits_title"])}</p><p>{escape(page["limits"])}</p><a class="text-link" href="privacy.html">{escape(page["cta"])} <span aria-hidden="true">→</span></a></aside>'
    return f"""<main id="main" class="page-main">
  <section class="page-intro section-shell" aria-labelledby="page-title"><p class="eyebrow">{escape(page['kicker'])}</p><h1 id="page-title">{escape(page['title'])}</h1><p class="page-lead">{escape(page['lead'])}</p></section>
  <section class="page-content section-shell" aria-label="{escape(page['title'])}"><div class="topic-list">{topics}</div>{limit}{notice}</section>
</main>"""


def document(lang: str, route: str) -> str:
    copy, page = COPY[lang], COPY[lang]["home" if route == "index" else route]
    title = page["title"]
    description = page["description"]
    opposite = "fr" if lang == "en" else "en"
    canonical = file_name(route)
    return f"""<!doctype html>
<html lang="{lang}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="robots" content="noindex, nofollow">
  <meta name="description" content="{escape(description, quote=True)}">
  <link rel="canonical" href="{escape(canonical, quote=True)}">
  <link rel="alternate" hreflang="{lang}" href="{escape(canonical, quote=True)}">
  <link rel="alternate" hreflang="{opposite}" href="../{opposite}/{escape(canonical, quote=True)}">
  <link rel="alternate" hreflang="x-default" href="../index.html">
  <meta property="og:type" content="website">
  <meta property="og:title" content="{escape(title, quote=True)} — CoreTend">
  <meta property="og:description" content="{escape(description, quote=True)}">
  <meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self'; font-src 'self'; connect-src 'self'; base-uri 'none'; object-src 'none'; frame-ancestors 'none'; form-action 'self'">
  <title>{escape(title)} — CoreTend</title>
  <link rel="stylesheet" href="../design-tokens.css">
  <link rel="stylesheet" href="../site.css">
  <script src="../site.js" defer></script>
</head>
<body class="page-{escape(route)}">
  {header(lang, route)}
  {content_for(lang, route)}
  {footer(lang, route)}
</body>
</html>
"""


def language_index() -> str:
    return """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="robots" content="noindex, nofollow">
  <meta name="description" content="CoreTend local reconstruction — choose English or French. Reconstruction locale CoreTend — choisir anglais ou français.">
  <meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self'; font-src 'self'; connect-src 'self'; base-uri 'none'; object-src 'none'; frame-ancestors 'none'; form-action 'self'">
  <title>CoreTend — choose language / choisir la langue</title>
  <link rel="stylesheet" href="design-tokens.css">
  <link rel="stylesheet" href="site.css">
</head>
<body class="language-page">
  <a class="skip-link" href="#main">Skip to language choice / Aller au choix de langue</a>
  <main class="language-choice" id="main">
    <a class="brand" href="en/index.html"><span class="brand-mark" aria-hidden="true"><i></i></span><span class="brand-name">CoreTend<small>LOCAL MACOS EXPLORER</small></span></a>
    <p class="eyebrow"><span class="status-dot" aria-hidden="true"></span>LOCAL PREVIEW · UNRELEASED</p>
    <h1>Choose your language<span lang="fr">Choisir votre langue</span></h1>
    <p class="language-lead">CoreTend is an unreleased macOS reconstruction. This local site explains current behavior and limits.<br><span lang="fr">CoreTend est une reconstruction macOS non publiée. Ce site local présente ses fonctions et limites actuelles.</span></p>
    <nav class="language-options" aria-label="Language / Langue"><a class="button button-primary" href="en/index.html" lang="en">English <span aria-hidden="true">→</span></a><a class="button button-secondary" href="fr/index.html" lang="fr">Français <span aria-hidden="true">→</span></a></nav>
  </main>
</body>
</html>
"""


def main() -> None:
    export_tokens()
    for lang in LANGUAGES:
        for route in ROUTES:
            target = ROOT / "Website" / lang / file_name(route)
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(document(lang, route), encoding="utf-8")
    (ROOT / "Website/index.html").write_text(language_index(), encoding="utf-8")


if __name__ == "__main__":
    main()
