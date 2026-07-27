#!/usr/bin/env python3
"""Generates the static, bilingual CoreTend website.

No framework: plain HTML/CSS, this one script as the only "build step".
Run `python3 generate.py` from the Website/ directory (or anywhere — path
is resolved relative to this file) to regenerate en/*.html and fr/*.html
from the content tables below. Output is committed static HTML — nothing
runs server-side, there is no bundler, no node_modules, no database.

ponytail: hand-rolled string templating instead of a template engine —
add Jinja2 only if page count or logic genuinely outgrows this.
"""
import json
import os

ROOT = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(ROOT)


def _load_identity():
    """Public release identity, read from Configuration/.

    Two files, deliberately: `PublicIdentity.example.json` is tracked and holds
    the placeholder tokens, `PublicIdentity.local.json` is gitignored and holds
    the real legal and security values. The local file wins key by key, so it
    only has to carry what it actually overrides.

    Until the local file exists the placeholders render literally, which is what
    keeps `Scripts/check-placeholders.sh` honest: the site cannot silently ship
    with an undefined publisher or an undefined security contact, because the
    token is still sitting there in the HTML for the gate to find.
    """
    identity = {}
    for name in ("PublicIdentity.example.json", "PublicIdentity.local.json"):
        path = os.path.join(REPO_ROOT, "Configuration", name)
        if not os.path.exists(path):
            continue
        with open(path) as handle:
            identity.update(
                {k: v for k, v in json.load(handle).items() if not k.startswith("_")}
            )
    return identity


IDENTITY = _load_identity()


def ident(key, fallback=""):
    """One identity value, or its placeholder token if still undefined."""
    return IDENTITY.get(key, fallback)


def is_defined(key):
    """True when a value is real rather than a `[SOMETHING_TO_DEFINE]` token."""
    value = str(IDENTITY.get(key, "")).strip()
    return bool(value) and not (value.startswith("[") and value.endswith("]"))

NAV = [
    ("index", {"en": "Overview", "fr": "Aperçu"}),
    ("features", {"en": "Features", "fr": "Fonctionnalités"}),
    ("privacy", {"en": "Privacy", "fr": "Confidentialité"}),
    ("download", {"en": "Download", "fr": "Télécharger"}),
    ("documentation", {"en": "Documentation", "fr": "Documentation"}),
    ("open-source", {"en": "Open Source", "fr": "Open Source"}),
    ("changelog", {"en": "Changelog", "fr": "Journal"}),
]

FOOTER_LINKS = [
    ("faq", {"en": "FAQ", "fr": "FAQ"}),
    ("roadmap", {"en": "Roadmap", "fr": "Feuille de route"}),
    ("security", {"en": "Security", "fr": "Sécurité"}),
    ("privacy", {"en": "Privacy policy", "fr": "Politique de confidentialité"}),
    ("licenses", {"en": "Licenses", "fr": "Licences"}),
    ("legal", {"en": "Legal notice", "fr": "Mentions légales"}),
]

SITE_TITLE = "CoreTend"
SITE_URL = "https://coretend.ahmetbsbnr.com"

# The public repository does not exist yet — nothing has been pushed. Set this
# to "https://github.com/ahmetbsbnr/coretend" once it does, and every place
# that wants to link source or docs starts linking instead of naming.
REPOSITORY_URL = None

# The product signature. Same two lines everywhere: onboarding, DMG, README,
# site, metadata. A product that describes itself differently in each place
# reads as several products.
SIGNATURE = {
    "en": "A lighter Mac. Always under control.",
    "fr": "Un Mac plus léger. Toujours sous contrôle.",
}

SUBTITLE = {
    "en": "Local, transparent and reversible care for macOS.",
    "fr": "Entretien local, transparent et réversible pour macOS.",
}

TAGLINE = SUBTITLE

# The mark, inlined. Three asymmetric arcs and a nucleus, generated from the
# same geometry as the app (MCBloomGeometry) — see
# Resources/Brand/Generated/Mark-*.svg. Inlined rather than linked so the site
# makes zero extra requests and the arcs can inherit theme colours.
MARK_SVG = """<svg class="mark" viewBox="0 0 512 512" role="img" aria-label="CoreTend" focusable="false">
<path d="M 135.680 464.400 A 240.640 240.640 0 0 0 464.400 135.680" fill="none" stroke="var(--care)" stroke-width="38.4" stroke-linecap="round"/>
<path d="M 434.039 208.294 A 184.320 184.320 0 0 0 137.521 114.803" fill="none" stroke="var(--privacy)" stroke-width="38.4" stroke-linecap="round"/>
<path d="M 135.719 212.221 A 128.000 128.000 0 0 0 192.000 366.851" fill="none" stroke="var(--activity)" stroke-width="38.4" stroke-linecap="round"/>
<circle cx="256" cy="256" r="61.44" fill="var(--care)"/>
</svg>"""


def page_shell(locale, slug, title, body_html, other_locale_slug=None):
    other_slug = other_locale_slug or slug
    def nav_link(n, label):
        # aria-current is what a screen reader announces as "current page";
        # the class only makes it visible. Both, or neither is enough.
        current = ' class="active" aria-current="page"' if n == slug else ""
        return f'<a href="{n}.html"{current}>{label[locale]}</a>'

    nav_items = "\n      ".join(nav_link(n, label) for n, label in NAV)
    footer_items = "\n      ".join(
        f'<a href="{n}.html">{label[locale]}</a>' for n, label in FOOTER_LINKS
    )

    def lang_link(code, href):
        current = ' class="active" aria-current="true"' if locale == code else ""
        return (f'<a href="{href}" hreflang="{code}" lang="{code}"{current}>'
                f'{code.upper()}</a>')

    en_href = f'../en/{slug if locale == "en" else other_slug}.html'
    fr_href = f'../fr/{slug if locale == "fr" else other_slug}.html'
    lang_switch = ('<div class="lang-switch">'
                   + lang_link("en", en_href)
                   + lang_link("fr", fr_href)
                   + "</div>")
    skip = {"en": "Skip to content", "fr": "Aller au contenu"}[locale]
    home = {"en": "CoreTend — home", "fr": "CoreTend — accueil"}[locale]
    footer_note = {
        "en": "&copy; CoreTend contributors. Open source — see the "
              '<a href="licenses.html">licenses</a>.',
        "fr": "&copy; Les contributeurs de CoreTend. Open source — voir les "
              '<a href="licenses.html">licences</a>.',
    }[locale]
    disclaimer = {
        "en": "CoreTend is an independent project and is not affiliated with "
              "Apple Inc. Mac and macOS describe compatibility only.",
        "fr": "CoreTend est un projet indépendant et n'est pas affilié à "
              "Apple Inc. Mac et macOS décrivent uniquement la compatibilité.",
    }[locale]
    return f"""<!doctype html>
<html lang="{locale}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} — {SITE_TITLE}</title>
<meta name="description" content="{SUBTITLE[locale]}">
<meta name="color-scheme" content="light dark">
<!-- noindex until the site is actually published: an unreleased page in a
     search index is a promise nobody can keep. -->
<meta name="robots" content="noindex">
<link rel="canonical" href="{SITE_URL}/{locale}/{slug}.html">
<link rel="alternate" hreflang="en" href="{SITE_URL}/en/{slug if locale == "en" else other_slug}.html">
<link rel="alternate" hreflang="fr" href="{SITE_URL}/fr/{slug if locale == "fr" else other_slug}.html">
<meta property="og:type" content="website">
<meta property="og:site_name" content="{SITE_TITLE}">
<meta property="og:title" content="{title} — {SITE_TITLE}">
<meta property="og:description" content="{SIGNATURE[locale]} {SUBTITLE[locale]}">
<meta property="og:locale" content="{"en_US" if locale == "en" else "fr_FR"}">
<meta property="og:image" content="../assets/brand/opengraph.png">
<meta name="twitter:card" content="summary_large_image">
<link rel="icon" href="../assets/brand/favicon-32.png" sizes="32x32">
<link rel="icon" href="../assets/brand/favicon-512.png" sizes="512x512">
<link rel="apple-touch-icon" href="../assets/brand/favicon-180.png">
<link rel="stylesheet" href="../assets/style.css">
</head>
<body>
<a class="skip-link" href="#main">{skip}</a>
<header class="site">
  <div class="wrap">
    <a class="brand" href="index.html" aria-label="{home}">{MARK_SVG}<span>{SITE_TITLE}</span></a>
    <nav class="primary" aria-label="{"Main" if locale == "en" else "Principale"}">
      {nav_items}
    </nav>
    {lang_switch}
  </div>
</header>
<main id="main">
  <div class="wrap">
{body_html}
  </div>
</main>
<footer class="site">
  <div class="wrap">
    <div>
      <p style="margin:0 0 .5rem">{footer_note}</p>
      <p class="disclaimer" style="margin:0">{disclaimer}</p>
    </div>
    <nav aria-label="{"Footer" if locale == "en" else "Pied de page"}">
      {footer_items}
    </nav>
  </div>
</footer>
</body>
</html>
"""


def screenshot_placeholder(text):
    return f'<div class="screenshot-placeholder">{text}</div>'


PAGES = {}


def add(slug, title, body_fn):
    PAGES[slug] = (title, body_fn)


# ---------------------------------------------------------------- index ---
# The home page is built from bilingual data rather than two parallel HTML
# blobs. Duplicating the markup per locale is how one language quietly ends up
# a version behind the other.

HOME_MODULES = [
    {
        "role": "care",
        "en": ("Smart Care", "One pass that runs every scan in order and shows you a "
               "single reviewable list. Nothing is removed until you say so."),
        "fr": ("Smart Care", "Une passe qui enchaîne toutes les analyses et présente "
               "une seule liste à examiner. Rien n'est supprimé avant votre accord."),
    },
    {
        "role": "care",
        "en": ("Cleanup", "Caches, logs, build leftovers, and installer remnants — "
               "each item grouped, sized, and explained before anything happens."),
        "fr": ("Nettoyage", "Caches, journaux, restes de compilation et résidus "
               "d'installation — chaque élément regroupé, mesuré et expliqué avant "
               "toute action."),
    },
    {
        "role": "care",
        "en": ("My Clutter", "Large, old, and forgotten files, sorted so you can see "
               "what is actually taking the space before deciding anything."),
        "fr": ("Mon désordre", "Fichiers volumineux, anciens et oubliés, triés pour "
               "voir ce qui occupe réellement l'espace avant de décider."),
    },
    {
        "role": "care",
        "en": ("Space Lens", "A navigable map of your disk. Drill into any folder and "
               "see where the weight really sits, not just the top ten."),
        "fr": ("Space Lens", "Une carte navigable de votre disque. Explorez n'importe "
               "quel dossier et voyez où se trouve vraiment le poids, pas seulement "
               "le top dix."),
    },
    {
        "role": "privacy",
        "en": ("Privacy Cleaner", "Browser traces per browser and per profile, listed "
               "individually. You choose what goes; a login you want kept stays."),
        "fr": ("Nettoyage de confidentialité", "Traces de navigation par navigateur "
               "et par profil, listées une par une. Vous choisissez ce qui part ; une "
               "session que vous gardez reste."),
    },
    {
        "role": "privacy",
        "en": ("Local protection with ClamAV", "If you have ClamAV installed, CoreTend "
               "can run it and quarantine what it finds. ClamAV is optional, never "
               "bundled, and its database is never shipped here."),
        "fr": ("Protection locale avec ClamAV", "Si ClamAV est installé, CoreTend peut "
               "l'exécuter et mettre en quarantaine ce qu'il détecte. ClamAV est "
               "facultatif, jamais intégré, et sa base n'est jamais distribuée ici."),
    },
    {
        "role": "activity",
        "en": ("Applications", "What is installed, how large it is, and what each app "
               "leaves behind. Uninstall with its leftovers listed, not guessed at."),
        "fr": ("Applications", "Ce qui est installé, sa taille, et ce que chaque app "
               "laisse derrière elle. Désinstallation avec les résidus listés, pas "
               "devinés."),
    },
    {
        "role": "activity",
        "en": ("Cloud Cleanup", "Locally cached copies of cloud files, which can be "
               "re-downloaded. Nothing is uploaded and nothing is removed from the "
               "cloud itself."),
        "fr": ("Nettoyage du cloud", "Copies locales de fichiers cloud, qui peuvent "
               "être retéléchargées. Rien n'est envoyé et rien n'est supprimé du "
               "cloud lui-même."),
    },
    {
        "role": "activity",
        "en": ("History and restore", "Every action is recorded locally with what it "
               "touched. Items go to the Trash, so restoring is ordinary macOS."),
        "fr": ("Historique et restauration", "Chaque action est enregistrée localement "
               "avec ce qu'elle a touché. Les éléments vont à la Corbeille : restaurer "
               "reste une opération macOS normale."),
    },
]

HOME_PRINCIPLES = [
    {
        "en": ("Dry run first, always", "Every module runs as a preview by default. "
               "You see the full list, with sizes and reasons, before a single file "
               "moves."),
        "fr": ("Simulation d'abord, toujours", "Chaque module démarre en aperçu par "
               "défaut. Vous voyez la liste complète, avec tailles et raisons, avant "
               "qu'un seul fichier ne bouge."),
    },
    {
        "en": ("The Trash, not deletion", "Removals go to the macOS Trash. A mistake "
               "is a drag away from being undone, not a restore from backup."),
        "fr": ("La Corbeille, pas la suppression", "Les retraits vont à la Corbeille "
               "macOS. Une erreur se corrige d'un glisser-déposer, pas d'une "
               "restauration de sauvegarde."),
    },
    {
        "en": ("No account, no telemetry", "There is nothing to sign up for and "
               "nothing sent anywhere. No analytics, no crash reporting, no network "
               "call the app makes on its own."),
        "fr": ("Sans compte, sans télémétrie", "Il n'y a rien à créer et rien envoyé "
               "où que ce soit. Aucune analyse d'usage, aucun rapport de plantage, "
               "aucun appel réseau que l'app ferait d'elle-même."),
    },
    {
        "en": ("Explained, then optional", "Full Disk Access, notifications, ClamAV, "
               "and filesystem watching are each requested only when a feature needs "
               "them, and each can be declined."),
        "fr": ("Expliqué, puis facultatif", "Accès complet au disque, notifications, "
               "ClamAV et surveillance du système de fichiers sont demandés seulement "
               "quand une fonction en a besoin, et chacun peut être refusé."),
    },
]

HOME_FAQ = [
    {
        "en": ("Does CoreTend send anything over the network?",
               "No. The app makes no network call of its own. If you enable the "
               "optional ClamAV integration, ClamAV's own updater is a separate tool "
               "you run yourself."),
        "fr": ("CoreTend envoie-t-il quelque chose sur le réseau ?",
               "Non. L'app ne fait aucun appel réseau de sa propre initiative. Si "
               "vous activez l'intégration ClamAV facultative, le programme de mise "
               "à jour de ClamAV est un outil distinct que vous lancez vous-même."),
    },
    {
        "en": ("Is this an antivirus?",
               "No. CoreTend can run ClamAV if you have installed it, and quarantine "
               "what ClamAV reports. It is not a real-time antivirus and does not "
               "claim to be one."),
        "fr": ("Est-ce un antivirus ?",
               "Non. CoreTend peut exécuter ClamAV si vous l'avez installé et mettre "
               "en quarantaine ce que ClamAV signale. Ce n'est pas un antivirus en "
               "temps réel et il ne prétend pas l'être."),
    },
    {
        "en": ("How much space will it free?",
               "That depends entirely on your Mac, and no honest answer can be given "
               "in advance. The app reports a real measured figure after scanning, "
               "before you approve anything."),
        "fr": ("Combien d'espace vais-je récupérer ?",
               "Cela dépend entièrement de votre Mac, et aucune réponse honnête ne "
               "peut être donnée à l'avance. L'app affiche un chiffre réellement "
               "mesuré après analyse, avant toute validation."),
    },
    {
        "en": ("Is the download signed and notarized?",
               "Not yet. The builds are unsigned, which is why the download page "
               "explains exactly what macOS will say and how to verify the checksum "
               "yourself."),
        "fr": ("Le téléchargement est-il signé et notarié ?",
               "Pas encore. Les versions ne sont pas signées, c'est pourquoi la page "
               "de téléchargement explique précisément ce que macOS affichera et "
               "comment vérifier vous-même la somme de contrôle."),
    },
]

HOME_TEXT = {
    "en": {
        "cta_download": "Download the local build",
        "cta_how": "See how it works",
        "prerelease_title": "Pre-1.0, and unsigned",
        "prerelease": "CoreTend is under active development and has not reached a "
                      "stable 1.0. Builds are unsigned, so macOS will warn on first "
                      "launch. The <a href=\"download.html\">download page</a> "
                      "explains what that looks like and how to verify what you got.",
        "bloom_label": "The mark",
        "bloom_title": "One nucleus, three arcs",
        "bloom_body": "The mark is the product's structure, not decoration. The "
                      "nucleus is your Mac; the three arcs are the three things "
                      "CoreTend attends to — storage and care in green, privacy and "
                      "protection in violet, activity and performance in amber. Those "
                      "colours mean the same thing everywhere in the app, and each is "
                      "always paired with a label or a symbol, never colour alone.",
        "space_label": "Reclaimable space",
        "space_title": "A measured number, not a promise",
        "space_body": "CoreTend never shows an estimate it has not measured. After a "
                      "scan you get the real byte count of what it found, grouped by "
                      "where it came from, with the reason each item was flagged. "
                      "Anything it cannot safely judge is left out of the total and "
                      "labelled instead.",
        "modules_label": "Modules",
        "modules_title": "What it actually does",
        "principles_label": "How it behaves",
        "principles_title": "Reversible by default",
        "setup_label": "First run",
        "setup_title": "A setup assistant that explains, then asks",
        "setup_body": "The first launch walks through how CoreTend works locally, what "
                      "permissions each feature needs and why, which parts are "
                      "optional, and what dry run means — then runs a short diagnostic "
                      "and shows you a summary. Nothing is scanned or changed during "
                      "setup.",
        "os_label": "Open source",
        "os_title": "Readable, buildable, auditable",
        "os_body": "The full source is public under Apache-2.0. You can read what each "
                   "rule matches, build the app yourself, and check the claims on this "
                   "page against the code that makes them.",
        "os_cta": "Read the source and licenses",
        "download_title": "Get the current build",
        "download_body": "Apple Silicon, macOS 14 or later. Unsigned, so read the "
                         "first-launch notes before installing.",
        "faq_label": "Questions",
        "faq_title": "Straight answers",
        "faq_more": "More in the full <a href=\"faq.html\">FAQ</a>.",
        "legal_title": "Legal and licensing",
        "legal_body": "Apache-2.0 for the code, CC-BY-4.0 for original documentation, "
                      "third-party components under their own terms. The "
                      "<a href=\"legal.html\">legal notice</a>, "
                      "<a href=\"privacy.html\">privacy policy</a> and "
                      "<a href=\"security.html\">security policy</a> say what is and "
                      "is not yet in place.",
    },
    "fr": {
        "cta_download": "Télécharger la version locale",
        "cta_how": "Découvrir le fonctionnement",
        "prerelease_title": "Pré-1.0, et non signé",
        "prerelease": "CoreTend est en développement actif et n'a pas atteint une "
                      "version 1.0 stable. Les versions ne sont pas signées : macOS "
                      "affichera donc un avertissement au premier lancement. La page "
                      "<a href=\"download.html\">Télécharger</a> explique à quoi cela "
                      "ressemble et comment vérifier ce que vous avez reçu.",
        "bloom_label": "Le symbole",
        "bloom_title": "Un noyau, trois arcs",
        "bloom_body": "Le symbole traduit la structure du produit, pas un ornement. Le "
                      "noyau, c'est votre Mac ; les trois arcs sont les trois choses "
                      "dont CoreTend s'occupe — stockage et entretien en vert, "
                      "confidentialité et protection en violet, activité et "
                      "performances en ambre. Ces couleurs signifient la même chose "
                      "partout dans l'app, et chacune est toujours accompagnée d'un "
                      "libellé ou d'un symbole, jamais la couleur seule.",
        "space_label": "Espace récupérable",
        "space_title": "Un chiffre mesuré, pas une promesse",
        "space_body": "CoreTend n'affiche jamais une estimation qu'il n'a pas mesurée. "
                      "Après une analyse, vous obtenez le nombre d'octets réellement "
                      "trouvés, regroupé par origine, avec la raison de chaque "
                      "signalement. Ce qu'il ne peut pas juger sans risque est exclu "
                      "du total et signalé à part.",
        "modules_label": "Modules",
        "modules_title": "Ce qu'il fait réellement",
        "principles_label": "Son comportement",
        "principles_title": "Réversible par défaut",
        "setup_label": "Premier lancement",
        "setup_title": "Un assistant qui explique, puis demande",
        "setup_body": "Le premier lancement présente le fonctionnement local de "
                      "CoreTend, les autorisations dont chaque fonction a besoin et "
                      "pourquoi, ce qui est facultatif, et ce que signifie la "
                      "simulation — puis exécute un court diagnostic et affiche un "
                      "résumé. Rien n'est analysé ni modifié pendant la configuration.",
        "os_label": "Open source",
        "os_title": "Lisible, compilable, auditable",
        "os_body": "Le code source complet est public sous Apache-2.0. Vous pouvez "
                   "lire ce que chaque règle cible, compiler l'app vous-même, et "
                   "confronter les affirmations de cette page au code qui les produit.",
        "os_cta": "Lire le code et les licences",
        "download_title": "Obtenir la version actuelle",
        "download_body": "Apple Silicon, macOS 14 ou ultérieur. Non signé : lisez les "
                         "notes de premier lancement avant d'installer.",
        "faq_label": "Questions",
        "faq_title": "Réponses directes",
        "faq_more": "Davantage dans la <a href=\"faq.html\">FAQ</a> complète.",
        "legal_title": "Mentions et licences",
        "legal_body": "Apache-2.0 pour le code, CC-BY-4.0 pour la documentation "
                      "originale, composants tiers sous leurs propres conditions. Les "
                      "<a href=\"legal.html\">mentions légales</a>, la "
                      "<a href=\"privacy.html\">politique de confidentialité</a> et la "
                      "<a href=\"security.html\">politique de sécurité</a> indiquent ce "
                      "qui est en place et ce qui ne l'est pas encore.",
    },
}

ROLE_LABEL = {
    "care": {"en": "Storage &amp; care", "fr": "Stockage et entretien"},
    "privacy": {"en": "Privacy &amp; protection", "fr": "Confidentialité et protection"},
    "activity": {"en": "Activity &amp; performance", "fr": "Activité et performances"},
}


def home_body(l):
    t = HOME_TEXT[l]
    badges = {
        "en": ["Local only, no account", "Open source", "No telemetry", "Apple Silicon"],
        "fr": ["100 % local, sans compte", "Open source", "Sans télémétrie", "Apple Silicon"],
    }[l]
    badge_classes = ["", "violet", "amber", ""]
    badge_html = "\n    ".join(
        f'<span class="badge {c}">{b}</span>' for b, c in zip(badges, badge_classes)
    )

    module_cards = "\n  ".join(
        f'<article class="card {m["role"]} reveal">'
        f'<span class="role">{ROLE_LABEL[m["role"]][l]}</span>'
        f'<h3>{m[l][0]}</h3><p>{m[l][1]}</p></article>'
        for m in HOME_MODULES
    )

    principle_cards = "\n  ".join(
        f'<article class="card reveal"><h3>{p[l][0]}</h3><p>{p[l][1]}</p></article>'
        for p in HOME_PRINCIPLES
    )

    faq_items = "\n  ".join(
        f'<details><summary>{q[l][0]}</summary><p>{q[l][1]}</p></details>'
        for q in HOME_FAQ
    )

    return f"""
<section class="hero">
  <div>
    <h1>{SITE_TITLE}</h1>
    <p class="signature">{SIGNATURE[l]}</p>
    <p class="lead">{SUBTITLE[l]}</p>
    <div class="cta-row">
      <a class="btn btn-primary" href="download.html">{t['cta_download']}</a>
      <a class="btn btn-secondary" href="#how">{t['cta_how']}</a>
    </div>
  </div>
  <div class="hero-art">{MARK_SVG}</div>
</section>

<section>
  <div class="badge-row">
    {badge_html}
  </div>
  <div class="warning-banner">
    <p><strong>{t['prerelease_title']}.</strong> {t['prerelease']}</p>
  </div>
</section>

<section id="how" class="feature reveal">
  <div>
    <span class="section-label">{t['bloom_label']}</span>
    <h2>{t['bloom_title']}</h2>
    <p>{t['bloom_body']}</p>
  </div>
  <div class="feature-visual">{MARK_SVG}</div>
</section>

<section class="reveal">
  <span class="section-label">{t['space_label']}</span>
  <h2>{t['space_title']}</h2>
  <p>{t['space_body']}</p>
</section>

<section>
  <span class="section-label">{t['modules_label']}</span>
  <h2>{t['modules_title']}</h2>
  <div class="cards">
  {module_cards}
  </div>
</section>

<section>
  <span class="section-label">{t['principles_label']}</span>
  <h2>{t['principles_title']}</h2>
  <div class="cards">
  {principle_cards}
  </div>
</section>

<section class="feature reveal">
  <div>
    <span class="section-label">{t['setup_label']}</span>
    <h2>{t['setup_title']}</h2>
    <p>{t['setup_body']}</p>
  </div>
  <div class="feature-visual">
    {screenshot_placeholder(SETUP_SHOT[l])}
  </div>
</section>

<section class="reveal">
  <span class="section-label">{t['os_label']}</span>
  <h2>{t['os_title']}</h2>
  <p>{t['os_body']}</p>
  <p><a href="open-source.html">{t['os_cta']}</a></p>
</section>

<section class="reveal">
  <h2>{t['download_title']}</h2>
  <p>{t['download_body']}</p>
  <div class="cta-row">
    <a class="btn btn-primary" href="download.html">{t['cta_download']}</a>
    <a class="btn btn-secondary" href="documentation.html">Documentation</a>
  </div>
</section>

<section>
  <span class="section-label">{t['faq_label']}</span>
  <h2>{t['faq_title']}</h2>
  {faq_items}
  <p>{t['faq_more']}</p>
</section>

<section class="reveal">
  <h2>{t['legal_title']}</h2>
  <p>{t['legal_body']}</p>
</section>
"""


SETUP_SHOT = {
    "en": "Setup assistant screenshot — pending a real capture. This box must "
          "never ship in a published build; see Website/README.md.",
    "fr": "Capture de l'assistant de configuration — en attente d'une capture "
          "réelle. Cette zone ne doit jamais être publiée ; voir Website/README.md.",
}


add("index", {"en": "Overview", "fr": "Aperçu"}, home_body)


# ------------------------------------------------------------ features ---
def features_body(l):
    rows_en = [
        ("Smart Care", "One orchestrated pass across the cleanup modules with a single explained summary before anything runs."),
        ("Duplicates", "Finds identical files by content, not just by name, and lets you keep the copy you choose."),
        ("Similar Images", "Groups visually similar photos and marks a best-resolution keeper — nothing is removed automatically."),
        ("Space Lens", "A visual map of what is using disk space, down to individual folders."),
        ("Applications", "Finds full app leftovers (caches, preferences, support files) left behind after uninstalling."),
        ("Protection", "Optional local malware scan that requires the separately-installed ClamAV engine. It flags suspect files for your review — no automatic quarantine, no security guarantee."),
        ("Privacy Cleaner", "Clears browser caches only (Chrome-family, Firefox, Safari), and only while the browser is closed. History and cookies are shown for transparency but never deleted."),
        ("Cloud Cleanup", "Reviews cloud-synced local copies (e.g. iCloud Drive placeholders) for reclaimable local space."),
    ]
    rows_fr = [
        ("Smart Care", "Une passe orchestrée sur les modules de nettoyage avec un résumé unique expliqué avant toute exécution."),
        ("Doublons", "Trouve les fichiers identiques par contenu, pas seulement par nom, et vous laisse choisir la copie à garder."),
        ("Images similaires", "Regroupe les photos visuellement similaires et repère la meilleure résolution — rien n'est supprimé automatiquement."),
        ("Space Lens", "Une carte visuelle de l'utilisation de l'espace disque, jusqu'au niveau des dossiers individuels."),
        ("Applications", "Trouve les résidus complets d'applications (caches, préférences, fichiers de support) laissés après désinstallation."),
        ("Protection", "Analyse antimalware locale optionnelle qui nécessite le moteur ClamAV installé séparément. Elle signale les fichiers suspects pour votre examen — aucune mise en quarantaine automatique, aucune garantie de sécurité."),
        ("Nettoyeur de confidentialité", "Nettoie uniquement les caches des navigateurs (famille Chrome, Firefox, Safari), et seulement lorsque le navigateur est fermé. L'historique et les cookies sont affichés à titre indicatif mais jamais supprimés."),
        ("Cloud Cleanup", "Examine les copies locales synchronisées avec le cloud (ex. placeholders iCloud Drive) pour libérer de l'espace local."),
    ]
    rows = rows_en if l == "en" else rows_fr
    cards = "\n".join(f'<div class="card"><h3>{t}</h3><p>{d}</p></div>' for t, d in rows)
    title = "Features" if l == "en" else "Fonctionnalités"
    intro = ("Every module below explains what it found before you act on it, "
             "and deletions default to the Trash.") if l == "en" else (
        "Chaque module ci-dessous explique ce qu'il a trouvé avant toute action, "
        "et les suppressions utilisent la Corbeille par défaut.")
    return f"""
<h1>{title}</h1>
<p class="lead">{intro}</p>
<div class="cards">{cards}</div>
"""


add("features", {"en": "Features", "fr": "Fonctionnalités"}, features_body)


# ------------------------------------------------------------- download ---
def download_body(l):
    if l == "en":
        return """
<h1>Download</h1>
<div class="status-box">
  <p><strong>Public release in preparation.</strong> There is no stable
  release yet. This page is a placeholder for the future release — it does
  not link to any local build or ad-hoc artifact.</p>
</div>

<div class="status-box">
  <p><strong>No release manifest published yet.</strong> There is nothing to
  download or verify until one exists. When a release ships, this page will
  list its version, architecture, minimum macOS, signing status and SHA-256
  checksum — read from the published manifest, not typed in by hand.</p>
</div>

<h2>Source code</h2>
<p>CoreTend's source will be published on GitHub once the public
repository is created (see the project's
<a href="open-source.html">Open Source</a> page). There is no live
source-code link yet — the repository is not public. This page will link
directly to it as soon as that happens.</p>

<h2>What the release will look like</h2>
<p>The first public artifact will be named exactly:</p>
<pre>CoreTend-&lt;version&gt;-arm64-unsigned.zip</pre>

<table>
  <tr><th>Field</th><th>Status</th></tr>
  <tr><td>Version</td><td>not yet released</td></tr>
  <tr><td>Checksum (SHA-256)</td><td>will be published alongside the release</td></tr>
  <tr><td>Code signing</td><td><strong>unsigned</strong> — this will always be disclosed, never hidden</td></tr>
  <tr><td>Notarization</td><td>not yet available (requires an Apple Developer ID; out of scope pre-1.0)</td></tr>
</table>

<h2>Planned install steps (once a release exists)</h2>
<ol>
  <li>Download and verify the SHA-256 checksum against the published value.</li>
  <li>Unzip and move CoreTend.app to /Applications.</li>
  <li>Because the app is unsigned, macOS Gatekeeper will require an explicit
  right-click &rarr; Open the first time.</li>
  <li>Grant Full Disk Access if you want full-coverage scanning (see the
  Documentation).</li>
</ol>
<p>Until then, building from source is documented in
<a href="documentation.html">Documentation</a>.</p>
"""
    return """
<h1>Télécharger</h1>
<div class="status-box">
  <p><strong>Version publique en préparation.</strong> Aucune version stable
  n'est disponible pour le moment. Cette page est un espace réservé pour la
  future publication — elle ne pointe vers aucune build locale ni artefact
  improvisé.</p>
</div>

<div class="status-box">
  <p><strong>Aucun manifeste de version publié pour l'instant.</strong> Il n'y a
  rien à télécharger ni à vérifier tant qu'il n'en existe pas. Lorsqu'une
  version sera publiée, cette page affichera sa version, son architecture, la
  version minimale de macOS, l'état de la signature et la somme de contrôle
  SHA-256 — lues depuis le manifeste publié, jamais saisies à la main.</p>
</div>

<h2>Code source</h2>
<p>Le code source de CoreTend sera publié sur GitHub une fois le dépôt
public créé (voir la page <a href="open-source.html">Open Source</a> du
projet). Il n'y a pas encore de lien vers le code source en direct — le
dépôt n'est pas encore public. Cette page y renverra directement dès que
ce sera le cas.</p>

<h2>À quoi ressemblera la publication</h2>
<p>Le premier artefact public portera exactement ce nom :</p>
<pre>CoreTend-&lt;version&gt;-arm64-unsigned.zip</pre>

<table>
  <tr><th>Champ</th><th>Statut</th></tr>
  <tr><td>Version</td><td>non publiée</td></tr>
  <tr><td>Empreinte (SHA-256)</td><td>sera publiée avec la version</td></tr>
  <tr><td>Signature de code</td><td><strong>non signé</strong> — toujours divulgué, jamais masqué</td></tr>
  <tr><td>Notarisation</td><td>indisponible pour l'instant (nécessite un Apple Developer ID ; hors périmètre avant la 1.0)</td></tr>
</table>

<h2>Étapes d'installation prévues (une fois une version publiée)</h2>
<ol>
  <li>Téléchargez et vérifiez l'empreinte SHA-256 par rapport à la valeur publiée.</li>
  <li>Décompressez et déplacez CoreTend.app dans /Applications.</li>
  <li>L'application étant non signée, Gatekeeper demandera un clic droit &rarr;
  Ouvrir la première fois.</li>
  <li>Accordez l'accès complet au disque pour une analyse à couverture complète
  (voir la Documentation).</li>
</ol>
<p>En attendant, la compilation depuis les sources est documentée dans la
<a href="documentation.html">Documentation</a>.</p>
"""


add("download", {"en": "Download", "fr": "Télécharger"}, download_body)


# -------------------------------------------------------- documentation ---
def documentation_body(l):
    en_links = [
        ("USER_GUIDE.md", "User Guide"),
        ("INSTALLATION.md", "Installation"),
        ("FIRST_LAUNCH.md", "First Launch"),
        ("FULL_DISK_ACCESS.md", "Full Disk Access"),
        ("CLEANUP_GUIDE.md", "Cleanup Guide"),
        ("SMART_CARE.md", "Smart Care"),
        ("PROTECTION.md", "Protection"),
        ("EXCLUSIONS.md", "Exclusions"),
        ("RESTORE.md", "Restore"),
        ("QUARANTINE.md", "Quarantine"),
        ("UNINSTALL.md", "Uninstall"),
        ("TROUBLESHOOTING.md", "Troubleshooting"),
        ("FAQ.md", "FAQ (full)"),
        ("DATA_LOCATIONS.md", "Data Locations"),
        ("DEVELOPMENT.md", "Developer Guide"),
    ]
    title = "Documentation"
    # These were links to a repository that does not exist publicly yet. A
    # link that 404s is worse than no link: it makes the whole page look
    # abandoned. They are listed as filenames until there is somewhere real to
    # point them, at which point REPOSITORY_URL becomes non-None and they
    # become links again — one constant, not thirty edits.
    intro = (
        "Full documentation ships inside the repository, in its "
        "<code>Documentation/</code> folder. The repository is not public yet, "
        "so these are filenames rather than links — they become links here the "
        "moment there is somewhere real to point them."
    ) if l == "en" else (
        "La documentation complète est fournie dans le dépôt, dans son dossier "
        "<code>Documentation/</code>. Le dépôt n'est pas encore public : ce sont "
        "donc des noms de fichiers et non des liens — ils deviendront des liens "
        "ici dès qu'il y aura une destination réelle."
    )
    items = "\n".join(
        (f'<li><a href="{REPOSITORY_URL}/blob/main/Documentation/{f}">{label}</a></li>'
         if REPOSITORY_URL else
         f"<li><strong>{label}</strong> — <code>Documentation/{f}</code></li>")
        for f, label in en_links
    )
    return f"""
<h1>{title}</h1>
<p class="lead">{intro}</p>
<ul>
{items}
</ul>
"""


add("documentation", {"en": "Documentation", "fr": "Documentation"}, documentation_body)


# --------------------------------------------------------- open-source ---
def open_source_body(l):
    if l == "en":
        return """
<h1>Open Source</h1>
<p>CoreTend is open source. The full source code, build scripts and
documentation are public — nothing runs behind a closed service.</p>
<h2>License</h2>
<p>See <code>LICENSE</code>, <code>LICENSES/</code> and
<code>THIRD_PARTY_NOTICES.md</code> in the repository for the exact terms
and third-party attributions.</p>
<h2>Contributing</h2>
<p>Contribution guidelines, code of conduct and governance are documented
in <code>CONTRIBUTING.md</code>, <code>CODE_OF_CONDUCT.md</code> and
<code>GOVERNANCE.md</code>.</p>
<h2>Building from source</h2>
<p>Swift Package Manager only — no Xcode project required. See
<code>Scripts/bootstrap.sh</code> and <code>Scripts/doctor.sh</code> in the
repository to get a dev environment verified locally.</p>
"""
    return """
<h1>Open Source</h1>
<p>CoreTend est open source. Le code source complet, les scripts de
build et la documentation sont publics — rien ne s'exécute derrière un
service fermé.</p>
<h2>Licence</h2>
<p>Voir <code>LICENSE</code>, <code>LICENSES/</code> et
<code>THIRD_PARTY_NOTICES.md</code> dans le dépôt pour les termes exacts et
les attributions tierces.</p>
<h2>Contribuer</h2>
<p>Les directives de contribution, le code de conduite et la gouvernance
sont documentés dans <code>CONTRIBUTING.md</code>, <code>CODE_OF_CONDUCT.md</code>
et <code>GOVERNANCE.md</code>.</p>
<h2>Compiler depuis les sources</h2>
<p>Swift Package Manager uniquement — aucun projet Xcode requis. Voir
<code>Scripts/bootstrap.sh</code> et <code>Scripts/doctor.sh</code> dans le
dépôt pour vérifier un environnement de développement localement.</p>
"""


add("open-source", {"en": "Open Source", "fr": "Open Source"}, open_source_body)


# -------------------------------------------------------------- roadmap ---
def roadmap_body(l):
    if l == "en":
        return """
<h1>Roadmap</h1>
<div class="warning-banner"><strong>Pre-1.0.</strong> Scope and order can
change. This is a direction, not a promise.</div>
<ul>
  <li>Harden and document each cleanup module's safety boundaries.</li>
  <li>Finish the open source foundation (this website, CI, contribution
  docs).</li>
  <li>First signed/notarized public release once an Apple Developer ID is
  available.</li>
  <li>Community-driven exclusions and rule refinements.</li>
</ul>
<p>See <code>Documentation/ROADMAP.md</code> in the repository for the
authoritative, up-to-date version.</p>
"""
    return """
<h1>Feuille de route</h1>
<div class="warning-banner"><strong>Pré-1.0.</strong> Le périmètre et l'ordre
peuvent changer. C'est une direction, pas une promesse.</div>
<ul>
  <li>Renforcer et documenter les limites de sécurité de chaque module de
  nettoyage.</li>
  <li>Finaliser les fondations open source (ce site, la CI, la documentation
  de contribution).</li>
  <li>Première publication signée/notarisée une fois un Apple Developer ID
  disponible.</li>
  <li>Exclusions et règles affinées par la communauté.</li>
</ul>
<p>Voir <code>Documentation/ROADMAP.md</code> dans le dépôt pour la version
faisant foi, à jour.</p>
"""


add("roadmap", {"en": "Roadmap", "fr": "Feuille de route"}, roadmap_body)


# ------------------------------------------------------------- changelog ---
def changelog_body(l):
    title = "Changelog" if l == "en" else "Journal des modifications"
    note = (
        "The authoritative changelog lives in <code>CHANGELOG.md</code> at "
        "the repository root."
    ) if l == "en" else (
        "Le journal des modifications faisant foi se trouve dans "
        "<code>CHANGELOG.md</code> à la racine du dépôt."
    )
    return f"""
<h1>{title}</h1>
<p>{note}</p>
"""


add("changelog", {"en": "Changelog", "fr": "Journal des modifications"}, changelog_body)


# ------------------------------------------------------------------ faq ---
def faq_body(l):
    qa_en = [
        ("Does CoreTend send any data anywhere?", "No. It has no telemetry, no analytics, no network calls related to its core operation. Everything runs locally."),
        ("Do I need an account?", "No account, no subscription, ever."),
        ("Are deletions permanent?", "By default, no — items go to the Trash so you can recover them."),
        ("Is this a full antivirus?", "No. The optional Protection module is a heuristic local scan aid (via ClamAV), never a guaranteed security product."),
        ("Is CoreTend affiliated with Apple or CleanMyMac/MacPaw?", "No. It is an independent open source project."),
    ]
    qa_fr = [
        ("CoreTend envoie-t-il des données quelque part ?", "Non. Aucune télémétrie, aucune analytique, aucun appel réseau lié à son fonctionnement principal. Tout s'exécute localement."),
        ("Faut-il un compte ?", "Aucun compte, aucun abonnement, jamais."),
        ("Les suppressions sont-elles définitives ?", "Par défaut, non — les éléments vont à la Corbeille pour rester récupérables."),
        ("Est-ce un antivirus complet ?", "Non. Le module Protection optionnel est une aide d'analyse locale heuristique (via ClamAV), jamais un produit de sécurité garanti."),
        ("CoreTend est-il affilié à Apple ou à CleanMyMac/MacPaw ?", "Non. C'est un projet open source indépendant."),
    ]
    qa = qa_en if l == "en" else qa_fr
    items = "\n".join(f"<h3>{q}</h3><p>{a}</p>" for q, a in qa)
    title = "FAQ"
    return f"<h1>{title}</h1>\n{items}\n<p>See <code>Documentation/FAQ.md</code> for the full list.</p>" if l == "en" else \
        f"<h1>{title}</h1>\n{items}\n<p>Voir <code>Documentation/FAQ.md</code> pour la liste complète.</p>"


add("faq", {"en": "FAQ", "fr": "FAQ"}, faq_body)


# ------------------------------------------------------------- privacy ---
def privacy_body(l):
    if l == "en":
        return """
<h1>Privacy</h1>
<h2>The app</h2>
<p>CoreTend runs entirely locally. It collects no telemetry, no
analytics, no usage data, and makes no network calls as part of its core
scanning/cleaning operation. See <code>PRIVACY.md</code> and
<code>Documentation/PROTECTION_LIMITATIONS.md</code> in the repository for
full detail, including the one optional network dependency (ClamAV virus
definition updates, entirely opt-in).</p>
<h2>This website</h2>
<p>This site sets no analytics or advertising cookies, runs no trackers, no
pixels, and no session replay. See <code>Documentation/WEBSITE_PRIVACY.md</code>
in the repository for the full policy.</p>
%s
<h2>Site operator</h2>
<p>Publisher: %s<br>
Contact: %s</p>
<p>The publisher is an individual publishing non-professionally. Their personal
address is not published; the host holds it. Full detail on the
<a href="legal.html">Legal notice</a> page.</p>
""" % (
            _legal_pending_banner(l),
            _identity_cell("publisherOfRecord"),
            _identity_cell("securityContact"),
        )
    return """
<h1>Confidentialité</h1>
<h2>L'application</h2>
<p>CoreTend s'exécute entièrement en local. Elle ne collecte aucune
télémétrie, aucune analytique, aucune donnée d'usage, et n'effectue aucun
appel réseau dans le cadre de son fonctionnement principal d'analyse/nettoyage.
Voir <code>PRIVACY.md</code> et <code>Documentation/PROTECTION_LIMITATIONS.md</code>
dans le dépôt pour le détail complet, y compris l'unique dépendance réseau
optionnelle (mise à jour des définitions ClamAV, entièrement facultative).</p>
<h2>Ce site</h2>
<p>Ce site ne dépose aucun cookie analytique ou publicitaire, n'exécute aucun
traqueur, aucun pixel, aucune relecture de session. Voir
<code>Documentation/WEBSITE_PRIVACY.md</code> dans le dépôt pour la politique
complète.</p>
%s
<h2>Éditeur du site</h2>
<p>Éditeur : %s<br>
Contact : %s</p>
<p>L'éditeur est une personne physique publiant à titre non professionnel. Son
adresse personnelle n'est pas publiée ; l'hébergeur la détient. Détail complet
sur la page <a href="legal.html">Mentions légales</a>.</p>
""" % (
        _legal_pending_banner(l),
        _identity_cell("publisherOfRecord"),
        _identity_cell("securityContact"),
    )


add("privacy", {"en": "Privacy", "fr": "Confidentialité"}, privacy_body)


# ------------------------------------------------------------ security ---
def security_body(l):
    if l == "en":
        return """
<h1>Security</h1>
<p>See <code>SECURITY.md</code> in the repository for the full
vulnerability disclosure policy. Report privately through: %s</p>""" % (
            _identity_cell("securityContact"),
        ) + """
<p>Planned HTTP security headers for this site once deployed (Content-Security-Policy,
Referrer-Policy, Permissions-Policy, X-Content-Type-Options) are documented
in <code>Documentation/WEBSITE_SECURITY.md</code>.</p>
"""
    return """
<h1>Sécurité</h1>
<p>Voir <code>SECURITY.md</code> dans le dépôt pour la politique complète de
divulgation des vulnérabilités. Signalement privé via : %s</p>""" % (
        _identity_cell("securityContact"),
    ) + """
<p>Les en-têtes de sécurité HTTP prévus pour ce site une fois déployé
(Content-Security-Policy, Referrer-Policy, Permissions-Policy,
X-Content-Type-Options) sont documentés dans
<code>Documentation/WEBSITE_SECURITY.md</code>.</p>
"""


add("security", {"en": "Security", "fr": "Sécurité"}, security_body)


# ------------------------------------------------------------- licenses ---
def licenses_body(l):
    # This page used to list four filenames and name no licence at all, so a
    # visitor could not learn the terms without cloning the repository. It now
    # states them, and links to the files it names.
    title = "Licenses" if l == "en" else "Licences"
    repo = ident("repositoryURL", "")
    blob = f"{repo}/blob/main" if repo else ""

    def link(path, label):
        return f'<a href="{blob}/{path}">{label}</a>' if blob else f"<code>{label}</code>"

    if l == "en":
        body = f"""<h1>{title}</h1>
<p>CoreTend is open source. Different kinds of content carry different
licenses.</p>
<ul>
  <li><strong>Source code</strong> — Apache License 2.0
      ({link("LICENSES/Apache-2.0.txt", "full text")}).</li>
  <li><strong>Original documentation and illustrations</strong> — CC-BY-4.0
      ({link("LICENSES/CC-BY-4.0.txt", "full text")}).</li>
  <li><strong>The CoreTend name and logo</strong> — not granted by either
      license ({link("TRADEMARKS.md", "TRADEMARKS.md")}).</li>
</ul>
<h2>Third-party components</h2>
<p>CoreTend bundles no third-party code. It declares
<strong>zero external package dependencies</strong>, and builds only against
the system frameworks that ship with macOS.</p>
<p>ClamAV is the one optional exception, and it is not bundled: if you install
it yourself, CoreTend can run the <code>clamscan</code> binary as a separate
process. It is never linked into the app and its signature database is never
redistributed here. ClamAV is licensed separately under GPL-2.0 by its own
project.</p>
<p>The full statements live in {link("LICENSE", "LICENSE")},
{link("NOTICE", "NOTICE")} and
{link("THIRD_PARTY_NOTICES.md", "THIRD_PARTY_NOTICES.md")} at the repository
root.</p>"""
    else:
        body = f"""<h1>{title}</h1>
<p>CoreTend est open source. Les différents types de contenu relèvent de
licences différentes.</p>
<ul>
  <li><strong>Code source</strong> — Licence Apache 2.0
      ({link("LICENSES/Apache-2.0.txt", "texte intégral")}).</li>
  <li><strong>Documentation et illustrations originales</strong> — CC-BY-4.0
      ({link("LICENSES/CC-BY-4.0.txt", "texte intégral")}).</li>
  <li><strong>Le nom et le logo CoreTend</strong> — non couverts par ces
      licences ({link("TRADEMARKS.md", "TRADEMARKS.md")}).</li>
</ul>
<h2>Composants tiers</h2>
<p>CoreTend n'embarque aucun code tiers. Le projet déclare
<strong>zéro dépendance externe</strong> et ne compile que contre les
frameworks système livrés avec macOS.</p>
<p>ClamAV est la seule exception optionnelle, et il n'est pas embarqué : si
vous l'installez vous-même, CoreTend peut exécuter le binaire
<code>clamscan</code> comme processus distinct. Il n'est jamais lié à
l'application et sa base de signatures n'est jamais redistribuée ici. ClamAV
est sous licence GPL-2.0, par son propre projet.</p>
<p>Les déclarations complètes se trouvent dans {link("LICENSE", "LICENSE")},
{link("NOTICE", "NOTICE")} et
{link("THIRD_PARTY_NOTICES.md", "THIRD_PARTY_NOTICES.md")} à la racine du
dépôt.</p>"""
    return body


add("licenses", {"en": "Licenses", "fr": "Licences"}, licenses_body)


# ---------------------------------------------------------------- legal ---
def _legal_pending_banner(l):
    """Rendered only while the publisher or security contact is still a token.

    Once both are real the banner disappears on its own — there is no separate
    flag to remember to flip, and no way for the site to ship a reassuring page
    over undefined values.
    """
    if is_defined("publisherOfRecord") and is_defined("securityContact"):
        return ""
    if l == "en":
        return """
<div class="warning-banner">
Values shown as <span class="placeholder-token">[SOMETHING_TO_DEFINE]</span>
are not yet set. They are tracked in
<code>Documentation/HUMAN_BLOCKERS.md</code> and no personal or legal
information has been invented to fill them. A production deployment must not
ship while any remain.
</div>
"""
    return """
<div class="warning-banner">
Les valeurs affichées sous la forme
<span class="placeholder-token">[SOMETHING_TO_DEFINE]</span> ne sont pas encore
définies. Elles sont suivies dans
<code>Documentation/HUMAN_BLOCKERS.md</code> et aucune information personnelle
ou légale n'a été inventée pour les remplir. Un déploiement en production ne
doit pas avoir lieu tant qu'il en reste.
</div>
"""


def _identity_cell(key):
    """An identity value, marked up as a placeholder token when undefined."""
    value = ident(key, "[%s_TO_DEFINE]" % key.upper())
    if is_defined(key):
        return value
    return '<span class="placeholder-token">%s</span>' % value


def legal_body(l):
    if l == "en":
        return """
<h1>Legal Notice</h1>
%s
<table>
<tr><td>Publisher</td><td>%s</td></tr>
<tr><td>Status</td><td>Individual, non-professional publisher. CoreTend is free
and open source: no sale, no subscription, no advertising, no affiliate link,
no donation, no account, and no commercial data collection.</td></tr>
<tr><td>Address</td><td>Not published. Under Article 6 III-2 of the French LCEN,
a non-professional publisher may withhold their personal address from the public
provided the host holds their identity. The host below holds it.</td></tr>
<tr><td>Contact</td><td>%s</td></tr>
<tr><td>Domain</td><td>%s</td></tr>
<tr><td>Host</td><td>%s<br>%s</td></tr>
<tr><td>Publication director</td><td>%s</td></tr>
</table>
<p>CoreTend is not affiliated with Apple Inc. or MacPaw Inc.
(CleanMyMac). It makes no antivirus/security-guarantee claim.</p>
<p>“CoreTend” is used as an unregistered name. No trademark application has
been filed and no registration is claimed. See
<a href="licenses.html">Licenses</a>.</p>
""" % (
            _legal_pending_banner(l),
            _identity_cell("publisherOfRecord"),
            _identity_cell("securityContact"),
            ident("websiteURL", SITE_URL),
            ident("hostName", "[HOSTNAME_TO_DEFINE]"),
            ident("hostAddress", "[HOSTADDRESS_TO_DEFINE]"),
            _identity_cell("publisherOfRecord"),
        )
    return """
<h1>Mentions légales</h1>
%s
<table>
<tr><td>Éditeur</td><td>%s</td></tr>
<tr><td>Statut</td><td>Éditeur personne physique, à titre non professionnel.
CoreTend est gratuit et open source : aucune vente, aucun abonnement, aucune
publicité, aucun lien d'affiliation, aucun don, aucun compte, aucune collecte
commerciale de données.</td></tr>
<tr><td>Adresse</td><td>Non publiée. Conformément à l'article 6 III-2 de la
LCEN, l'éditeur non professionnel peut ne pas rendre publique son adresse
personnelle dès lors que l'hébergeur détient son identité. L'hébergeur
ci-dessous la détient.</td></tr>
<tr><td>Contact</td><td>%s</td></tr>
<tr><td>Domaine</td><td>%s</td></tr>
<tr><td>Hébergeur</td><td>%s<br>%s</td></tr>
<tr><td>Directeur de la publication</td><td>%s</td></tr>
</table>
<p>CoreTend n'est affilié ni à Apple Inc. ni à MacPaw Inc.
(CleanMyMac). Aucune revendication d'antivirus ou de garantie de sécurité
n'est faite.</p>
<p>« CoreTend » est utilisé comme nom non déposé. Aucune demande de marque n'a
été déposée et aucun enregistrement n'est revendiqué. Voir
<a href="licenses.html">Licences</a>.</p>
""" % (
        _legal_pending_banner(l),
        _identity_cell("publisherOfRecord"),
        _identity_cell("securityContact"),
        ident("websiteURL", SITE_URL),
        ident("hostName", "[HOSTNAME_TO_DEFINE]"),
        ident("hostAddress", "[HOSTADDRESS_TO_DEFINE]"),
        _identity_cell("publisherOfRecord"),
    )


add("legal", {"en": "Legal notice", "fr": "Mentions légales"}, legal_body)


# ----------------------------------------------------------------- 404 ---
def notfound_body(l):
    if l == "en":
        return '<h1>404 — Page not found</h1><p><a href="index.html">Back to home</a>.</p>'
    return '<h1>404 — Page introuvable</h1><p><a href="index.html">Retour à l\'accueil</a>.</p>'


add("404", {"en": "Page not found", "fr": "Page introuvable"}, notfound_body)


def main():
    for locale in ("en", "fr"):
        out_dir = os.path.join(ROOT, locale)
        os.makedirs(out_dir, exist_ok=True)
        for slug, (title, body_fn) in PAGES.items():
            html = page_shell(locale, slug, title[locale], body_fn(locale))
            with open(os.path.join(out_dir, f"{slug}.html"), "w") as f:
                f.write(html)
    print(f"Generated {len(PAGES)} pages x 2 locales into {ROOT}/en and {ROOT}/fr")


if __name__ == "__main__":
    main()
