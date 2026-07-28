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
import html as _html
import base64
import hashlib
import json
import os


def html_escape(value):
    """Escape a value destined for page text or an attribute."""
    return _html.escape(str(value), quote=True)

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
    ("demos", {"en": "Demos", "fr": "Démos"}),
    ("download", {"en": "Download", "fr": "Télécharger"}),
    ("documentation", {"en": "Docs", "fr": "Docs"}),
]

FOOTER_LINKS = [
    ("install", {"en": "Install", "fr": "Installer"}),
    ("support", {"en": "Support", "fr": "Assistance"}),
    ("faq", {"en": "FAQ", "fr": "FAQ"}),
    ("roadmap", {"en": "Roadmap", "fr": "Feuille de route"}),
    ("security", {"en": "Security", "fr": "Sécurité"}),
    ("privacy", {"en": "Privacy policy", "fr": "Politique de confidentialité"}),
    ("licenses", {"en": "Licenses", "fr": "Licences"}),
    ("legal", {"en": "Legal notice", "fr": "Mentions légales"}),
]

SITE_TITLE = "CoreTend"
SITE_URL = ident("websiteURL", "https://coretend.ahmetbsbnr.com")
# First-paint guard. The stylesheet is a separate request; until it lands the
# page must already be paper-on-ink rather than a white flash with default
# blue links. Kept to exactly the two properties that prevent that, because
# every byte here is hashed into the CSP.
CRITICAL_STYLE = "html,body{background:#f4f4f0;color:#17191d}"


def critical_style_hash():
    digest = hashlib.sha256(CRITICAL_STYLE.encode("utf-8")).digest()
    return "sha256-" + base64.b64encode(digest).decode("ascii")

# The repository is public, so this now comes from configuration rather than
# being pinned to None. Every place that links source or docs reads this one
# value: it was always meant to be one constant, not thirty edits. If the
# identity file ever stops defining it, those places name filenames again
# instead of emitting links that 404.
REPOSITORY_URL = ident("repositoryURL", "") or None

# Search indexing. False until the site is actually deployed and reachable.
# The page meta and robots.txt both read this, so they cannot drift apart.
SITE_INDEXABLE = bool(ident("siteIndexable", False))

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
# The mark, inlined. Same three-arc geometry as the app icon
# (Resources/Brand/Generated/Mark-*.svg, derived from MCBloomGeometry), drawn
# in the site's own two-colour system rather than the app's semantic palette:
# this site is ink, paper and cobalt, and a three-colour logo inside it would
# read as a second identity. The arcs keep their weights, so the mark is still
# the same shape at any size. viewBox is tight to the artwork, so the rendered
# box is the artwork — no invisible padding inflating it.
MARK_SVG = """<svg class="mark" viewBox="0 0 512 512" role="img" aria-label="CoreTend" focusable="false">
<path d="M 135.680 464.400 A 240.640 240.640 0 0 0 464.400 135.680" fill="none" stroke="var(--cobalt)" stroke-width="38.4" stroke-linecap="round"/>
<path d="M 434.039 208.294 A 184.320 184.320 0 0 0 137.521 114.803" fill="none" stroke="var(--ink)" stroke-width="38.4" stroke-linecap="round"/>
<path d="M 135.719 212.221 A 128.000 128.000 0 0 0 192.000 366.851" fill="none" stroke="var(--line-strong)" stroke-width="38.4" stroke-linecap="round"/>
<circle cx="256" cy="256" r="61.44" fill="var(--cobalt)"/>
</svg>"""

GITHUB_SVG = """<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">
<path fill="currentColor" d="M12 .7a11.5 11.5 0 0 0-3.64 22.41c.58.11.79-.25.79-.56v-2.02c-3.23.7-3.91-1.37-3.91-1.37-.53-1.34-1.29-1.7-1.29-1.7-1.05-.72.08-.71.08-.71 1.17.08 1.78 1.2 1.78 1.2 1.04 1.77 2.72 1.26 3.38.96.1-.75.41-1.26.74-1.55-2.58-.29-5.29-1.29-5.29-5.73 0-1.27.45-2.3 1.2-3.11-.12-.29-.52-1.47.11-3.07 0 0 .98-.31 3.16 1.19a10.95 10.95 0 0 1 5.76 0c2.19-1.5 3.16-1.19 3.16-1.19.63 1.6.23 2.78.11 3.07.75.81 1.2 1.84 1.2 3.11 0 4.45-2.72 5.43-5.31 5.72.42.36.79 1.07.79 2.16v3.02c0 .31.21.68.8.56A11.5 11.5 0 0 0 12 .7Z"/>
</svg>"""

MENU_SVG = """<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round">
<path d="M3 6h18M3 12h18M3 18h18"/></svg>"""

CLOSE_SVG = """<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round">
<path d="M5 5l14 14M19 5L5 19"/></svg>"""

ARROW_SVG = """<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
<path d="M5 12h13M12 5l7 7-7 7"/></svg>"""

DOWNLOAD_SVG = """<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
<path d="M12 3v12M7 11l5 5 5-5M4 20h16"/></svg>"""


# A body starting with this marker lays out its own sections (hero pages);
# anything else is dropped into the standard measured column.
FULL_BLEED = "<!--full-bleed-->"

RAIL_TAGLINE = {
    "en": ("macOS maintenance", "Local &amp; open source"),
    "fr": ("Entretien macOS", "Local et open source"),
}

UI = {
    "skip": {"en": "Skip to content", "fr": "Aller au contenu"},
    "home": {"en": "CoreTend — home", "fr": "CoreTend — accueil"},
    "main_nav": {"en": "Main", "fr": "Principale"},
    "footer_nav": {"en": "Site map", "fr": "Plan du site"},
    "open_menu": {"en": "Open menu", "fr": "Ouvrir le menu"},
    "close_menu": {"en": "Close menu", "fr": "Fermer le menu"},
    "lang_aria": {"en": "Language", "fr": "Langue"},
    "github_aria": {
        "en": "CoreTend source on GitHub",
        "fr": "Code source de CoreTend sur GitHub",
    },
    "get_cta": {"en": "Download", "fr": "Télécharger"},
    "project": {"en": "Project", "fr": "Projet"},
    "footer_blurb": {
        "en": "CoreTend is a free, open-source macOS maintenance app. It runs "
              "entirely on your Mac: no account, no telemetry, no network calls.",
        "fr": "CoreTend est une application d'entretien macOS libre et open "
              "source. Tout s'exécute sur votre Mac : aucun compte, aucune "
              "télémétrie, aucun appel réseau.",
    },
}


def asset_url(relative_path):
    """Content-addressed URL for a site asset.

    Everything under /assets is served `immutable, max-age=31536000`, which
    is correct only if a given URL never changes meaning. The filenames are
    stable (style.css, site.js), so without this a redesign ships new HTML
    that browsers and the CDN happily pair with a year-old stylesheet — which
    is exactly what happened on the first deploy of this rebuild. Appending a
    hash of the file's own bytes makes the URL change whenever the content
    does, so `immutable` stops being a lie."""
    path = os.path.join(ROOT, relative_path.replace("/", os.sep))
    try:
        with open(path, "rb") as handle:
            digest = hashlib.sha256(handle.read()).hexdigest()[:10]
    except OSError:
        return f"../{relative_path}"
    return f"../{relative_path}?v={digest}"


def page_shell(locale, slug, title, body_html, other_locale_slug=None):
    other_slug = other_locale_slug or slug
    version = ident("marketingVersion", "")

    def nav_link(n, label, cls="nav-link"):
        # aria-current is what a screen reader announces as "current page";
        # the class only makes it visible. Both, or neither is enough.
        current = ' aria-current="page"' if n == slug else ""
        active = " active" if n == slug else ""
        return (f'<li><a class="{cls}{active}" href="{n}.html"{current}>'
                f'{label[locale]}</a></li>')

    nav_items = "\n            ".join(nav_link(n, label) for n, label in NAV)
    menu_items = "\n            ".join(nav_link(n, label) for n, label in NAV)
    footer_items = "\n        ".join(
        f'<li><a href="{n}.html">{label[locale]}</a></li>'
        for n, label in FOOTER_LINKS
    )

    def lang_switch(extra_class=""):
        def item(code):
            href = f'../{code}/{slug if locale == code else other_slug}.html'
            if locale == code:
                return f'<span aria-current="true">{code.upper()}</span>'
            return (f'<a href="{href}" hreflang="{code}" lang="{code}">'
                    f'{code.upper()}</a>')
        return (f'<span class="lang-switch{extra_class}" role="group" '
                f'aria-label="{UI["lang_aria"][locale]}">'
                f'{item("fr")}<span class="sep" aria-hidden="true">|</span>'
                f'{item("en")}</span>')

    github_btn = (
        f'<a class="icon-btn" href="{REPOSITORY_URL}" target="_blank" '
        f'rel="noopener noreferrer" aria-label="{UI["github_aria"][locale]}">'
        f'{GITHUB_SVG}</a>'
        if REPOSITORY_URL else ""
    )
    tag_a, tag_b = RAIL_TAGLINE[locale]
    wordmark = f'{MARK_SVG}<span>{SITE_TITLE}</span>'

    return f"""<!doctype html>
<html lang="{locale}" class="no-js">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} — {SITE_TITLE}</title>
<meta name="description" content="{SUBTITLE[locale]}">
<meta name="color-scheme" content="light">
<!-- Indexing follows siteIndexable in the identity file. It stays noindex
     until the site is really deployed: an unreachable page in a search index
     is a promise nobody can keep. robots.txt is generated from the same flag,
     so the two can never disagree. -->
<meta name="robots" content="{"index, follow" if SITE_INDEXABLE else "noindex"}">
<link rel="canonical" href="{SITE_URL}/{locale}/{slug}.html">
<meta property="og:url" content="{SITE_URL}/{locale}/{slug}.html">
<link rel="alternate" hreflang="en" href="{SITE_URL}/en/{slug if locale == "en" else other_slug}.html">
<link rel="alternate" hreflang="fr" href="{SITE_URL}/fr/{slug if locale == "fr" else other_slug}.html">
<meta property="og:type" content="website">
<meta property="og:site_name" content="{SITE_TITLE}">
<meta property="og:title" content="{title} — {SITE_TITLE}">
<meta property="og:description" content="{SIGNATURE[locale]} {SUBTITLE[locale]}">
<meta property="og:locale" content="{"en_US" if locale == "en" else "fr_FR"}">
<meta property="og:image" content="{SITE_URL}/assets/brand/opengraph.png">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta name="twitter:card" content="summary_large_image">
<link rel="icon" href="../assets/brand/favicon-32.png" sizes="32x32">
<link rel="icon" href="../assets/brand/favicon-512.png" sizes="512x512">
<link rel="apple-touch-icon" href="../assets/brand/favicon-180.png">
<link rel="preload" href="../assets/fonts/archivo-latin.woff2" as="font" type="font/woff2" crossorigin>
<link rel="preload" href="../assets/fonts/plexmono-400-latin.woff2" as="font" type="font/woff2" crossorigin>
<style>{CRITICAL_STYLE}</style>
<link rel="stylesheet" href="{asset_url("assets/style.css")}">
<script src="{asset_url("assets/site.js")}" defer></script>
</head>
<body class="page-{slug}">
<a class="skip-link" href="#main">{UI["skip"][locale]}</a>

<aside class="rail">
  <a class="rail-brand" href="index.html" aria-label="{UI["home"][locale]}">
    <span class="wordmark">{wordmark}</span>
    <span class="tag">{tag_a}<br>{tag_b}</span>
  </a>
  <nav aria-label="{UI["main_nav"][locale]}">
    <ul>
            {nav_items}
    </ul>
    {lang_switch()}
  </nav>
  <div class="rail-foot">
    <p class="status">{version}</p>
    <p class="meta">macOS 14+ · Apple silicon</p>
    <a class="btn btn-primary" href="download.html">{UI["get_cta"][locale]}</a>
    <div class="icon-row">{github_btn}</div>
  </div>
</aside>

<header class="topbar">
  <a class="wordmark" href="index.html" aria-label="{UI["home"][locale]}">{wordmark}</a>
  <div class="topbar-actions">
    {lang_switch()}
    <button class="nav-toggle" type="button" aria-expanded="false"
      aria-controls="mobile-menu" aria-label="{UI["open_menu"][locale]}">{MENU_SVG}</button>
  </div>
</header>

<div class="mobile-menu" id="mobile-menu" data-open="false">
  <div class="mobile-menu-head">
    <span class="wordmark">{wordmark}</span>
    <button class="nav-toggle mobile-menu-close" type="button"
      aria-label="{UI["close_menu"][locale]}">{CLOSE_SVG}</button>
  </div>
  <nav aria-label="{UI["main_nav"][locale]}">
    <ul>
            {menu_items}
    </ul>
    {lang_switch()}
  </nav>
  <div class="mobile-menu-foot">
    <p class="status">{version}</p>
    <p class="meta">macOS 14+ · Apple silicon</p>
    <a class="btn btn-primary" href="download.html" style="width:100%;margin-top:1rem">{UI["get_cta"][locale]}</a>
  </div>
</div>

<div class="shell">
<main id="main">
{body_html if body_html.startswith(FULL_BLEED) else f'<div class="wrap"><div class="page-body">{body_html}</div></div>'}
</main>

<footer class="site-footer">
  <div class="wrap">
    <div class="footer-grid">
      <div>
        <p class="wordmark">{wordmark}</p>
        <p class="footer-blurb">{UI["footer_blurb"][locale]}</p>
      </div>
      <nav aria-label="{UI["footer_nav"][locale]}">
        <p class="kicker">{UI["footer_nav"][locale]}</p>
        <ul class="links-2col">
        {footer_items}
        </ul>
      </nav>
      <div>
        <p class="kicker">{UI["project"][locale]}</p>
        <ul>
          <li><a href="{REPOSITORY_URL}" target="_blank" rel="noopener noreferrer">GitHub</a></li>
          <li><a href="open-source.html">Open source</a></li>
          <li><a href="changelog.html">{"Changelog" if locale == "en" else "Journal"}</a></li>
        </ul>
        <div class="icon-row">{github_btn}</div>
      </div>
    </div>
    <div class="footer-base">
      <p>&copy; {"CoreTend contributors" if locale == "en" else "Les contributeurs de CoreTend"} · Apache-2.0</p>
      <p>{version}</p>
    </div>
  </div>
</footer>
</div>
</body>
</html>
"""


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
        "hero_eyebrow": "Native care for macOS",
        "hero_title": "Your Mac, lighter. Always under control.",
        "hero_body": "See what weighs down your Mac, review every finding, and decide what leaves.",
        "cta_download": "Download CoreTend",
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
        "hero_eyebrow": "Entretien natif pour macOS",
        "hero_title": "Votre Mac, plus léger. Toujours sous contrôle.",
        "hero_body": "Voyez ce qui alourdit votre Mac, examinez chaque résultat et décidez de ce qui part.",
        "cta_download": "Télécharger CoreTend",
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


def loop_video(name, ratio, describedby, width, height, track=False):
    """The one product-video treatment used everywhere on this site.

    Silent, looping, inline, no visible controls, and boxed at the clip's
    real intrinsic ratio so nothing reflows when it decodes. A poster is
    always given: if autoplay is refused (Low Power Mode, data saver) the
    poster is simply what stays on screen — never a play button drawn over
    a dead frame. Under prefers-reduced-motion the poster replaces the
    video entirely (see .loop img.reduced-only)."""
    track_el = (
        f'\n            <track kind="captions" srclang="en" '
        f'label="Visual description" src="../assets/demos/{name}.vtt" default>'
        if track else ""
    )
    return f"""<span class="loop" style="--ratio:{ratio}">
          <video data-loop autoplay muted loop playsinline preload="metadata"
            poster="../assets/demos/{name}-poster.webp"
            width="{width}" height="{height}" aria-describedby="{describedby}">
            <source src="../assets/demos/{name}.webm" type="video/webm">
            <source src="../assets/demos/{name}.mp4" type="video/mp4">{track_el}
          </video>
          <img class="reduced-only" src="../assets/demos/{name}-poster.webp"
            width="{width}" height="{height}" alt="">
        </span>"""


def media_exists(relative_path):
    return os.path.isfile(os.path.join(ROOT, relative_path))


def home_body(l):
    t = HOME_TEXT[l]
    en = l == "en"

    module_cards = "\n      ".join(
        f'<li class="card" data-reveal data-reveal-delay="{i * 60}">'
        f'<p class="kicker">{ROLE_LABEL[m["role"]][l]}</p>'
        f'<h3>{m[l][0]}</h3><p>{m[l][1]}</p></li>'
        for i, m in enumerate(HOME_MODULES)
    )

    principle_cards = "\n      ".join(
        f'<li class="card" data-reveal data-reveal-delay="{i * 60}">'
        f'<h3>{p[l][0]}</h3><p>{p[l][1]}</p></li>'
        for i, p in enumerate(HOME_PRINCIPLES)
    )

    faq_items = "\n      ".join(
        f'<div data-reveal><h3>{q[l][0]}</h3><p>{q[l][1]}</p></div>'
        for q in HOME_FAQ
    )

    # The one real recording that exists: Gatekeeper refusing an unsigned
    # first launch. It plays as a silent loop, no controls, poster reserved.
    if media_exists("assets/demos/gatekeeper-blocked.mp4"):
        demo_section = f"""
  <section class="section" id="demo">
    <div class="wrap">
      <div class="section-head" data-reveal>
        <p class="kicker">{"Demo" if en else "Démonstration"}</p>
        <h2>{"What the first launch looks like" if en else "À quoi ressemble le premier lancement"}</h2>
        <p class="lead">{"CoreTend is unsigned, so macOS blocks the first launch. This is the real dialog, and the two-step way past it — recorded, not described." if en else "CoreTend n\u2019est pas signé : macOS bloque donc le premier lancement. Voici la vraie boîte de dialogue et les deux étapes pour la passer — enregistrées, pas décrites."}</p>
      </div>
      <figure class="media" data-reveal>
        <span class="loop" style="--ratio:926/880">
          <video data-loop autoplay muted loop playsinline preload="metadata"
            poster="../assets/demos/gatekeeper-blocked-poster.webp"
            width="926" height="880" aria-describedby="demo-desc">
            <source src="../assets/demos/gatekeeper-blocked.webm" type="video/webm">
            <source src="../assets/demos/gatekeeper-blocked.mp4" type="video/mp4">
          </video>
          <img class="reduced-only" src="../assets/demos/gatekeeper-blocked-poster.webp"
            width="926" height="880" alt="">
        </span>
        <figcaption id="demo-desc">{"macOS refuses the unsigned app, then opens it after Control-click → Open. Silent, looping, no sound track." if en else "macOS refuse l\u2019app non signée, puis l\u2019ouvre après Ctrl-clic → Ouvrir. Silencieux, en boucle, sans bande-son."}</figcaption>
      </figure>
      <p data-reveal><a href="install.html">{"Read the full install notes" if en else "Lire les notes d\u2019installation complètes"}</a> · <a href="demos.html">{"All demos" if en else "Toutes les démos"}</a></p>
    </div>
  </section>"""
    else:
        demo_section = ""

    setup_media = f"""<ul class="chip-row">
              <li class="chip">{"Dry run by default" if en else "Simulation par défaut"}</li>
              <li class="chip">{"Trash, not erase" if en else "Corbeille, pas effacement"}</li>
              <li class="chip">{"Explicit permissions" if en else "Autorisations explicites"}</li>
              <li class="chip">{"No background agent" if en else "Aucun agent en arrière-plan"}</li>
            </ul>"""

    # The application itself — deliberately below the fold, after the brand,
    # the claim and the status have been established. Smart Care at full
    # measure where its interface is legible; the menu-bar panel beside it.
    product_section = f"""
  <section class="section" id="product">
    <div class="wrap">
      <div class="section-head" data-reveal>
        <p class="kicker">{"The application" if en else "L’application"}</p>
        <h2>{"What you actually get" if en else "Ce que vous obtenez"}</h2>
      </div>
      <div class="shot-pair">
        <figure class="media" data-reveal>
          <picture>
            <source srcset="../assets/app/smart-care.webp" type="image/webp">
            <img src="../assets/app/smart-care.png" width="2024" height="1488" loading="lazy"
              sizes="(min-width: 1024px) 660px, 92vw"
              alt="{"CoreTend Smart Care window: module sidebar on the left, scan summary and the list of findings to review on the right" if en else "Fenêtre Smart Care de CoreTend : barre latérale des modules à gauche, résumé d’analyse et liste des résultats à examiner à droite"}">
          </picture>
          <figcaption>{"Smart Care — every scan in one pass, every finding listed before anything is removed." if en else "Smart Care — toutes les analyses en une passe, chaque résultat listé avant toute suppression."}</figcaption>
        </figure>
        <figure class="media" data-reveal data-reveal-delay="80">
          <picture>
            <source srcset="../assets/app/menu-bar.webp" type="image/webp">
            <img src="../assets/app/menu-bar.png" width="660" height="806" loading="lazy"
              sizes="(min-width: 1024px) 300px, 70vw"
              alt="{"CoreTend menu bar panel showing CPU, memory, free space, thermal state and protection status" if en else "Panneau de la barre des menus CoreTend : processeur, mémoire, espace libre, état thermique et état de la protection"}">
          </picture>
          <figcaption>{"The menu bar panel — read-only status, no actions taken from here." if en else "Le panneau de la barre des menus — état en lecture seule, aucune action déclenchée d’ici."}</figcaption>
        </figure>
      </div>
    </div>
  </section>""" if media_exists("assets/app/smart-care.webp") else ""

    return f"""{FULL_BLEED}
  <section class="hero">
    <div class="wrap">
      <div class="hero-lockup">
        <span class="hero-mark" data-reveal aria-hidden="true">{MARK_SVG}</span>
        <h1 class="hero-wordmark">
          <span class="line"><span>CoreTend</span></span>
        </h1>
        <p class="hero-statement" data-reveal data-reveal-delay="60">
          {"Finds what is filling up your Mac, and removes only what you approve."
           if en else
           "Trouve ce qui remplit votre Mac, et ne supprime que ce que vous validez."}
        </p>
        <p class="hero-facts" data-reveal data-reveal-delay="110">
          {"Runs entirely on your Mac. No account, no telemetry, no network calls. Optional malware scanning uses ClamAV, installed and owned by you."
           if en else
           "S’exécute entièrement sur votre Mac. Aucun compte, aucune télémétrie, aucun appel réseau. L’analyse antivirus optionnelle utilise ClamAV, installé et contrôlé par vous."}
        </p>
        <div class="btn-row" data-reveal data-reveal-delay="160">
          <span data-magnetic><a class="btn btn-primary" href="download.html">{t['cta_download']}{ARROW_SVG}</a></span>
          <a class="btn btn-secondary" href="{REPOSITORY_URL}" target="_blank" rel="noopener noreferrer">{GITHUB_SVG}{"Source code" if en else "Code source"}</a>
        </div>
        <dl class="hero-status" data-reveal data-reveal-delay="210">
          <div>
            <dt>{"Version" if en else "Version"}</dt>
            <dd>{ident("marketingVersion", "")} · {"release candidate" if en else "release candidate"}</dd>
          </div>
          <div>
            <dt>{"Requires" if en else "Requiert"}</dt>
            <dd>macOS 14+ · Apple silicon</dd>
          </div>
          <div>
            <dt>{"Apple signature" if en else "Signature Apple"}</dt>
            <dd class="warn-text">{"Unsigned, not notarized" if en else "Non signé, non notarisé"}</dd>
          </div>
          <div>
            <dt>{"Licence" if en else "Licence"}</dt>
            <dd>Apache-2.0 · {"free" if en else "gratuit"}</dd>
          </div>
        </dl>
      </div>
    </div>
  </section>

  <section class="section" style="padding-top:0">
    <div class="wrap">
      <div class="note warn" data-reveal>
        <p class="kicker">{t['prerelease_title']}</p>
        <p>{t['prerelease']}</p>
      </div>
    </div>
  </section>

{product_section}
  <section class="section" id="modules">
    <div class="wrap">
      <div class="section-head" data-reveal>
        <p class="kicker">{t['modules_label']}</p>
        <h2>{t['modules_title']}</h2>
      </div>
      <ul class="cards cols-3">
      {module_cards}
      </ul>
    </div>
  </section>

  <section class="section">
    <div class="wrap">
      <div class="section-head" data-reveal>
        <p class="kicker">{t['space_label']}</p>
        <h2>{t['space_title']}</h2>
        <p class="lead">{t['space_body']}</p>
      </div>
    </div>
  </section>
{demo_section}
  <section class="section">
    <div class="wrap">
      <div class="section-head" data-reveal>
        <p class="kicker">{t['principles_label']}</p>
        <h2>{t['principles_title']}</h2>
      </div>
      <ul class="cards cols-3">
      {principle_cards}
      </ul>
    </div>
  </section>

  <section class="section">
    <div class="wrap">
      <div class="section-head" data-reveal>
        <p class="kicker">{t['setup_label']}</p>
        <h2>{t['setup_title']}</h2>
      </div>
      <ul class="rows">
        <li class="row-item" data-reveal>
          <div>
            <p>{t['setup_body']}</p>
            <ul class="bullets">
              <li>{"Explains what each permission is for before requesting it." if en else "Explique à quoi sert chaque autorisation avant de la demander."}</li>
              <li>{"Dry run is the default: findings are listed, nothing is removed." if en else "La simulation est le réglage par défaut : les résultats sont listés, rien n\u2019est supprimé."}</li>
              <li>{"Nothing is scanned or changed while the assistant runs." if en else "Rien n\u2019est analysé ni modifié pendant l\u2019assistant."}</li>
            </ul>
          </div>
          <div class="row-aside">
            {setup_media}
          </div>
        </li>
      </ul>
    </div>
  </section>

  <section class="section">
    <div class="wrap">
      <div class="section-head" data-reveal>
        <p class="kicker">{t['os_label']}</p>
        <h2>{t['os_title']}</h2>
        <p class="lead">{t['os_body']}</p>
      </div>
      <div class="btn-row" data-reveal style="margin-top:0">
        <span data-magnetic><a class="btn btn-primary" href="open-source.html">{t['os_cta']}{ARROW_SVG}</a></span>
        <a class="btn btn-secondary" href="{REPOSITORY_URL}" target="_blank" rel="noopener noreferrer">GitHub</a>
      </div>
    </div>
  </section>

  <section class="section">
    <div class="wrap">
      <div class="section-head" data-reveal>
        <p class="kicker">{t['faq_label']}</p>
        <h2>{t['faq_title']}</h2>
      </div>
      <div class="stack">
      {faq_items}
      </div>
      <p data-reveal style="margin-top:2rem">{t['faq_more']}</p>
    </div>
  </section>

  <section class="section">
    <div class="wrap">
      <div class="section-head" data-reveal>
        <h2>{t['download_title']}</h2>
        <p class="lead">{t['download_body']}</p>
      </div>
      <div class="btn-row" data-reveal style="margin-top:0">
        <span data-magnetic><a class="btn btn-primary" href="download.html">{DOWNLOAD_SVG}{t['cta_download']}</a></span>
        <a class="btn btn-secondary" href="documentation.html">Documentation</a>
      </div>
      <p class="muted mono" data-reveal style="margin-top:2rem;font-size:.8rem">{t['legal_body']}</p>
    </div>
  </section>
"""


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


# ---------------------------------------------------------------- demos ---
def demos_body(l):
    has_product_tour = media_exists("assets/demos/product-tour.webm")
    has_gatekeeper = media_exists("assets/demos/gatekeeper-blocked.webm")
    has_menu_bar = media_exists("assets/app/menu-bar.webp")
    if not (has_product_tour or has_gatekeeper or has_menu_bar):
        return (
            "<h1>Product demos</h1><p>Media will appear here only after capture "
            "and privacy review in the dedicated CoreTend Demo environment.</p>"
            if l == "en" else
            "<h1>Démonstrations</h1><p>Les médias apparaîtront ici uniquement "
            "après capture et validation de confidentialité dans l’environnement "
            "dédié CoreTend Demo.</p>"
        )
    title = "Real CoreTend media" if l == "en" else "Médias réels de CoreTend"
    intro = (
        "Every image and clip below passed visual and metadata privacy review. "
        "The media shows CoreTend 0.9.0 or its genuine first-open system warning; "
        "no personal files, paths, accounts or authentication are shown."
    ) if l == "en" else (
        "Chaque image et séquence ci-dessous a passé une revue visuelle et une "
        "revue des métadonnées. Les médias montrent CoreTend 0.9.0 ou son véritable "
        "avertissement système de première ouverture, sans fichier, chemin, compte "
        "ni authentification personnels."
    )
    captions = [
        ("smart-care", "Smart Care"),
        ("cleanup", "Cleanup" if l == "en" else "Nettoyage"),
        ("performance", "Performance" if l == "en" else "Performances"),
        ("applications", "Applications"),
        ("my-clutter", "My Clutter"),
        ("space-lens", "Space Lens"),
        ("protection", "Protection"),
        ("settings", "Settings" if l == "en" else "Réglages"),
    ]
    gallery_items = [
        f'<figure><a href="../assets/app/{name}.webp">'
        f'<img src="../assets/app/{name}.webp" '
        f'width="2024" height="1488" '
        f'loading="lazy" alt="CoreTend development interface — {caption}"></a>'
        f'<figcaption>{caption}</figcaption></figure>'
        for name, caption in captions
        if media_exists(f"assets/app/{name}.webp")
    ]
    if has_menu_bar:
        menu_caption = "Menu bar status" if l == "en" else "État dans la barre des menus"
        gallery_items.append(
            f'<figure><a href="../assets/app/menu-bar.png">'
            f'<img src="../assets/app/menu-bar.webp" width="660" height="806" '
            f'loading="lazy" alt="CoreTend 0.9.0 — {menu_caption}"></a>'
            f'<figcaption>{menu_caption}</figcaption></figure>'
        )
    gallery = "\n".join(gallery_items)
    description = (
        "The recording navigates between shipped modules. It contains no staged "
        "scan result and makes no claim about files that were not scanned."
    ) if l == "en" else (
        "L’enregistrement navigue entre les modules livrés. Il ne contient aucun "
        "résultat d’analyse mis en scène et ne revendique rien sur des fichiers "
        "qui n’ont pas été analysés."
    )
    product_tour = f"""
<figure class="media">
  {loop_video("product-tour", "1800/1264", "demo-description", 1800, 1264)}
  <figcaption id="demo-description">{description}</figcaption>
</figure>""" if has_product_tour else ""
    gatekeeper_description = (
        "Silent, genuine macOS first-open warning for the unsigned and not "
        "notarized CoreTend 0.9.0 beta. Wording can vary by macOS version. "
        "The clip does not show a bypass or authentication."
    ) if l == "en" else (
        "Véritable avertissement macOS silencieux de première ouverture pour la "
        "bêta CoreTend 0.9.0 non signée et non notarisée. Les libellés peuvent "
        "varier selon macOS. La séquence ne montre ni contournement ni authentification."
    )
    gatekeeper_video = f"""
<h2>{"First-open warning" if l == "en" else "Avertissement de première ouverture"}</h2>
<figure class="media">
  {loop_video("gatekeeper-blocked", "926/880", "gatekeeper-description", 926, 880, track=True)}
  <figcaption id="gatekeeper-description">{gatekeeper_description}</figcaption>
</figure>""" if has_gatekeeper else ""
    return f"""
<h1>{title}</h1>
<p class="lead">{intro}</p>
{product_tour}
{gatekeeper_video}
<section>
  <h2>{"Application gallery" if l == "en" else "Galerie de l’application"}</h2>
  <div class="media-grid">{gallery}</div>
</section>
"""


add("demos", {"en": "Demos", "fr": "Démos"}, demos_body)


# ------------------------------------------------------------- download ---
def _release_manifest():
    """The generated release manifest, when one exists.

    Release/latest.json is build output and is gitignored, so a fresh clone
    generates the site without it. That is the normal case, not an error: the
    page degrades to "prepared, not yet published" rather than inventing a
    checksum. Only a manifest carrying a releaseTag describes something a
    visitor can actually download.
    """
    path = os.path.join(ROOT, "..", "Release", "latest.json")
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def download_body(l):
    m = _release_manifest()
    repo = ident("repositoryURL", "")
    version = ident("marketingVersion", "")
    published = bool(m and m.get("releaseTag"))
    releases_url = f"{repo}/releases" if repo else ""

    if l == "en":
        if published:
            zip_name = html_escape(str(m.get("zipName", "")))
            dmg_name = html_escape(str(m.get("dmgName", "")))
            tag = html_escape(str(m.get("releaseTag", "")))
            release_url = f"{repo}/releases/tag/{tag}"
            asset_base = f"{repo}/releases/download/{tag}"
            head = f"""
<div class="status-box">
  <p><strong>CoreTend {html_escape(str(m.get('version','')))} — public beta.</strong>
  Unsigned and not notarized. Verify the checksum below before you open it.</p>
</div>
<p><a href="{release_url}">View the GitHub prerelease and release notes</a></p>
<table>
  <tr><th>Field</th><th>Value</th></tr>
  <tr><td>Version</td><td>{html_escape(str(m.get('version','')))}</td></tr>
  <tr><td>ZIP</td><td><a href="{asset_base}/{zip_name}"><code>{zip_name}</code></a></td></tr>
  <tr><td>ZIP size</td><td>{html_escape(str(m.get('zipSize','')))} bytes</td></tr>
  <tr><td>ZIP SHA-256</td><td><code>{html_escape(str(m.get('zipSHA256','')))}</code></td></tr>
  <tr><td>DMG</td><td><a href="{asset_base}/{dmg_name}"><code>{dmg_name}</code></a></td></tr>
  <tr><td>DMG size</td><td>{html_escape(str(m.get('dmgSize','')))} bytes</td></tr>
  <tr><td>DMG SHA-256</td><td><code>{html_escape(str(m.get('dmgSHA256','')))}</code></td></tr>
  <tr><td>Verification files</td><td><a href="{asset_base}/latest.json"><code>latest.json</code></a> · <a href="{asset_base}/SHA256SUMS"><code>SHA256SUMS</code></a></td></tr>
  <tr><td>Architecture</td><td>{html_escape(str(m.get('architecture','')))}</td></tr>
  <tr><td>Minimum macOS</td><td>{html_escape(str(m.get('minimumMacOS','')))}</td></tr>
  <tr><td>Source commit</td><td><code>{html_escape(str(m.get('sourceCommit','')))}</code></td></tr>
  <tr><td>Build date</td><td>{html_escape(str(m.get('buildDate_UTC','')))}</td></tr>
  <tr><td>Code signing</td><td><strong>unsigned</strong> — always disclosed, never hidden</td></tr>
  <tr><td>Notarization</td><td><strong>not notarized</strong> — requires an Apple Developer ID</td></tr>
</table>"""
        else:
            head = f"""
<div class="status-box">
  <p><strong>Release {html_escape(version)} is prepared but not published yet.</strong>
  There is no download link, because there is nothing public to link to. The
  version and checksum below appear here only once a tagged release exists —
  they are read from the generated manifest, never typed in by hand.</p>
</div>

<h2>What the release will look like</h2>
<p>The artifact will be named exactly:</p>
<pre>CoreTend-{html_escape(version)}-arm64-unsigned.zip</pre>
<table>
  <tr><th>Field</th><th>Status</th></tr>
  <tr><td>Version</td><td>{html_escape(version)} — prepared, not yet published</td></tr>
  <tr><td>Checksum (SHA-256)</td><td>published with the release</td></tr>
  <tr><td>Code signing</td><td><strong>unsigned</strong> — always disclosed, never hidden</td></tr>
  <tr><td>Notarization</td><td><strong>not notarized</strong> — requires an Apple Developer ID, out of scope pre-1.0</td></tr>
</table>"""

        source = (f'<h2>Source code</h2>\n<p>CoreTend is open source. The full '
                  f'source, tests, build scripts and gates are at '
                  f'<a href="{repo}">{html_escape(repo)}</a>.</p>') if repo else ""

        return f"""
<h1>Download</h1>{head}

{source}

<h2>Recommended: DMG</h2>
<p>The DMG gives a clear drag-to-Applications installation. The ZIP contains
the same application and is available as an alternative for experienced
users. Neither format changes the unsigned and not notarized status.</p>
<p><a class="btn btn-primary" href="install.html">Install CoreTend step by step</a></p>

<h2>Installing an unsigned app</h2>
<p>macOS will refuse to open CoreTend on first launch, saying the developer
cannot be verified. That warning is correct: no developer identity is attached,
because signing requires a paid Apple Developer Program membership this project
does not have.</p>
<ol>
  <li>Verify the SHA-256 checksum against the published value
  (<code>shasum -a 256 &lt;file&gt;</code>).</li>
  <li>Unzip and move CoreTend.app to /Applications.</li>
  <li>Right-click (or Control-click) the app and choose <strong>Open</strong>,
  then confirm. Once is enough — macOS remembers that copy.</li>
  <li>Grant Full Disk Access if you want full-coverage scanning (see the
  Documentation).</li>
</ol>
<p><strong>Do not disable Gatekeeper.</strong> The per-app step above is enough,
and turning off a system-wide protection for one app is not a trade worth
making.</p>
<p>Building from source is documented in
<a href="documentation.html">Documentation</a>.</p>
"""

    if published:
        zip_name = html_escape(str(m.get("zipName", "")))
        dmg_name = html_escape(str(m.get("dmgName", "")))
        tag = html_escape(str(m.get("releaseTag", "")))
        release_url = f"{repo}/releases/tag/{tag}"
        asset_base = f"{repo}/releases/download/{tag}"
        head = f"""
<div class="status-box">
  <p><strong>CoreTend {html_escape(str(m.get('version','')))} — bêta publique.</strong>
  Non signée et non notarisée. Vérifiez l'empreinte ci-dessous avant d'ouvrir
  l'application.</p>
</div>
<p><a href="{release_url}">Voir la préversion GitHub et ses notes</a></p>
<table>
  <tr><th>Champ</th><th>Valeur</th></tr>
  <tr><td>Version</td><td>{html_escape(str(m.get('version','')))}</td></tr>
  <tr><td>ZIP</td><td><a href="{asset_base}/{zip_name}"><code>{zip_name}</code></a></td></tr>
  <tr><td>Taille ZIP</td><td>{html_escape(str(m.get('zipSize','')))} octets</td></tr>
  <tr><td>SHA-256 du ZIP</td><td><code>{html_escape(str(m.get('zipSHA256','')))}</code></td></tr>
  <tr><td>DMG</td><td><a href="{asset_base}/{dmg_name}"><code>{dmg_name}</code></a></td></tr>
  <tr><td>Taille DMG</td><td>{html_escape(str(m.get('dmgSize','')))} octets</td></tr>
  <tr><td>SHA-256 du DMG</td><td><code>{html_escape(str(m.get('dmgSHA256','')))}</code></td></tr>
  <tr><td>Fichiers de vérification</td><td><a href="{asset_base}/latest.json"><code>latest.json</code></a> · <a href="{asset_base}/SHA256SUMS"><code>SHA256SUMS</code></a></td></tr>
  <tr><td>Architecture</td><td>{html_escape(str(m.get('architecture','')))}</td></tr>
  <tr><td>macOS minimal</td><td>{html_escape(str(m.get('minimumMacOS','')))}</td></tr>
  <tr><td>Commit source</td><td><code>{html_escape(str(m.get('sourceCommit','')))}</code></td></tr>
  <tr><td>Date de compilation</td><td>{html_escape(str(m.get('buildDate_UTC','')))}</td></tr>
  <tr><td>Signature de code</td><td><strong>non signé</strong> — toujours divulgué, jamais masqué</td></tr>
  <tr><td>Notarisation</td><td><strong>non notarisé</strong> — nécessite un Apple Developer ID</td></tr>
</table>"""
    else:
        head = f"""
<div class="status-box">
  <p><strong>La version {html_escape(version)} est prête mais pas encore publiée.</strong>
  Il n'y a aucun lien de téléchargement, car il n'existe rien de public vers quoi
  pointer. La version et l'empreinte n'apparaîtront ici qu'une fois une version
  étiquetée publiée — elles sont lues depuis le manifeste généré, jamais saisies
  à la main.</p>
</div>

<h2>À quoi ressemblera la publication</h2>
<p>L'artefact portera exactement ce nom :</p>
<pre>CoreTend-{html_escape(version)}-arm64-unsigned.zip</pre>
<table>
  <tr><th>Champ</th><th>Statut</th></tr>
  <tr><td>Version</td><td>{html_escape(version)} — prête, pas encore publiée</td></tr>
  <tr><td>Empreinte (SHA-256)</td><td>publiée avec la version</td></tr>
  <tr><td>Signature de code</td><td><strong>non signé</strong> — toujours divulgué, jamais masqué</td></tr>
  <tr><td>Notarisation</td><td><strong>non notarisé</strong> — nécessite un Apple Developer ID, hors périmètre avant la 1.0</td></tr>
</table>"""

    source = (f'<h2>Code source</h2>\n<p>CoreTend est open source. L\'intégralité '
              f'du code, des tests, des scripts de compilation et des gates se '
              f'trouve sur <a href="{repo}">{html_escape(repo)}</a>.</p>') if repo else ""

    return f"""
<h1>Télécharger</h1>{head}

{source}

<h2>Recommandé : DMG</h2>
<p>Le DMG offre une installation claire par glisser-déposer vers Applications.
Le ZIP contient la même application et reste une alternative pour les
utilisateurs expérimentés. Aucun format ne change le statut non signé et non
notarisé.</p>
<p><a class="btn btn-primary" href="install.html">Installer CoreTend étape par étape</a></p>

<h2>Installer une application non signée</h2>
<p>macOS refusera d'ouvrir CoreTend au premier lancement, en indiquant que le
développeur ne peut pas être vérifié. Cet avertissement est exact : aucune
identité de développeur n'est attachée, car la signature exige une adhésion
payante au Apple Developer Program dont ce projet ne dispose pas.</p>
<ol>
  <li>Vérifiez l'empreinte SHA-256 par rapport à la valeur publiée
  (<code>shasum -a 256 &lt;fichier&gt;</code>).</li>
  <li>Décompressez et déplacez CoreTend.app dans /Applications.</li>
  <li>Faites un clic droit (ou Contrôle-clic) sur l'application et choisissez
  <strong>Ouvrir</strong>, puis confirmez. Une seule fois suffit : macOS retient
  la décision pour cette copie.</li>
  <li>Accordez l'accès complet au disque pour une analyse à couverture complète
  (voir la Documentation).</li>
</ol>
<p><strong>Ne désactivez pas Gatekeeper.</strong> L'étape par application
ci-dessus suffit, et désactiver une protection système entière pour une seule
application n'est pas un échange raisonnable.</p>
<p>La compilation depuis les sources est documentée dans la
<a href="documentation.html">Documentation</a>.</p>
"""


add("download", {"en": "Download", "fr": "Télécharger"}, download_body)


# --------------------------------------------------------------- install ---
def install_body(l):
    gatekeeper_media = ""
    if media_exists("assets/demos/gatekeeper-blocked.webm"):
        visual_description = (
            "Silent recording of the genuine macOS first-open warning. Labels "
            "can vary by macOS version."
            if l == "en" else
            "Enregistrement silencieux du véritable avertissement macOS de "
            "première ouverture. Les libellés peuvent varier selon macOS."
        )
        gatekeeper_media = f"""
<figure class="media">
  {loop_video("gatekeeper-blocked", "926/880", "install-gatekeeper-description", 926, 880, track=True)}
  <figcaption id="install-gatekeeper-description">{visual_description}</figcaption>
</figure>"""
    if l == "en":
        return f"""
<h1>Install CoreTend</h1>
<p class="lead">From download to first scan without lowering your Mac's
security settings globally.</p>
<div class="warning-banner"><p><strong>CoreTend 0.9.0 is unsigned and not
notarized.</strong> macOS will block the first normal open. The steps below
authorize this copy of CoreTend only.</p></div>
{gatekeeper_media}
<ol class="install-steps">
  <li><h2>Check compatibility</h2><p>Choose Apple menu → About This Mac. The
  available build requires an Apple silicon chip and macOS 14 or later.</p></li>
  <li><h2>Download the DMG</h2><p>Use the DMG on the official
  <a href="download.html">Download page</a>. The ZIP is an alternative.</p></li>
  <li><h2>Move CoreTend to Applications</h2><p>Open the DMG, drag CoreTend to
  Applications, then eject the disk image.</p></li>
  <li><h2>Open this app once</h2><p>In Applications, Control-click CoreTend and
  choose <strong>Open</strong>. If your macOS version instead presents a
  CoreTend-specific option in System Settings → Privacy &amp; Security, use
  that option. Labels vary by macOS version.</p>
  <details><summary>Why is this needed?</summary><p>The beta has no Developer
  ID signature and is not notarized. This per-app choice is not a security
  certification. Never disable Gatekeeper or SIP globally.</p></details></li>
  <li><h2>Start with dry run</h2><p>Read the onboarding, keep dry run enabled,
  and start Smart Care. A scan previews findings before any approved action.</p></li>
</ol>
<h2>Optional: verify your download</h2>
<p>SHA-256 confirms that your file is byte-for-byte the published file. It
does not replace signing or notarization, and the checksum source must itself
be trusted.</p>
<pre><code>shasum -a 256 ~/Downloads/CoreTend-0.9.0-arm64-unsigned.dmg
cd ~/Downloads
shasum -a 256 -c SHA256SUMS</code></pre>
<p>The DMG result must be
<code>f2fbc7840ac4a5509836a495c51e72e6cfd52ef24e6cbdd792fa8404bd3f6c8d</code>.
If it differs, delete the file, download it again, and do not open it.</p>
<p>Need help? Continue to <a href="support.html">Support and troubleshooting</a>.</p>
"""
    return f"""
<h1>Installer CoreTend</h1>
<p class="lead">Du téléchargement à la première analyse sans réduire
globalement la sécurité du Mac.</p>
<div class="warning-banner"><p><strong>CoreTend 0.9.0 n'est ni signé ni
notarisé.</strong> macOS bloquera la première ouverture normale. Les étapes
ci-dessous autorisent uniquement cette copie de CoreTend.</p></div>
{gatekeeper_media}
<ol class="install-steps">
  <li><h2>Vérifier la compatibilité</h2><p>Menu Pomme → À propos de ce Mac. La
  version disponible exige une puce Apple et macOS 14 ou ultérieur.</p></li>
  <li><h2>Télécharger le DMG</h2><p>Choisissez le DMG sur la
  <a href="download.html">page Télécharger</a>. Le ZIP est une alternative.</p></li>
  <li><h2>Copier vers Applications</h2><p>Ouvrez le DMG, glissez CoreTend vers
  Applications, puis éjectez l'image disque.</p></li>
  <li><h2>Autoriser cette application une fois</h2><p>Dans Applications,
  Contrôle-cliquez CoreTend et choisissez <strong>Ouvrir</strong>. Si votre
  version de macOS propose plutôt une option nommant CoreTend dans Réglages
  Système → Confidentialité et sécurité, utilisez-la. Les libellés varient
  selon macOS.</p>
  <details><summary>Pourquoi cette étape ?</summary><p>La bêta n'a pas de
  signature Developer ID et n'est pas notarisée. Ce choix limité à l'app
  n'est pas une certification. Ne désactivez jamais globalement Gatekeeper
  ou SIP.</p></details></li>
  <li><h2>Commencer en simulation</h2><p>Lisez l'introduction, conservez la
  simulation activée et lancez Smart Care. L'analyse présente un aperçu avant
  toute action approuvée.</p></li>
</ol>
<h2>Facultatif : vérifier le téléchargement</h2>
<p>SHA-256 confirme que le fichier est identique à celui publié. Il ne
remplace ni signature ni notarisation, et la source du checksum doit elle-même
être fiable.</p>
<pre><code>shasum -a 256 ~/Downloads/CoreTend-0.9.0-arm64-unsigned.dmg
cd ~/Downloads
shasum -a 256 -c SHA256SUMS</code></pre>
<p>Le DMG doit produire
<code>f2fbc7840ac4a5509836a495c51e72e6cfd52ef24e6cbdd792fa8404bd3f6c8d</code>.
Si la valeur diffère, supprimez le fichier, retéléchargez-le et ne l'ouvrez
pas.</p>
<p>Besoin d'aide ? Consultez <a href="support.html">Assistance et dépannage</a>.</p>
"""


add("install", {"en": "Install CoreTend", "fr": "Installer CoreTend"}, install_body)


# --------------------------------------------------------------- support ---
def support_body(l):
    if l == "en":
        return """
<h1>Support</h1>
<p class="lead">Safe answers for installation, first launch and everyday use.</p>
<div class="cards">
  <article class="card"><h2>First launch</h2><p>Use the
  <a href="install.html">graphical installation guide</a> and authorize only
  CoreTend.</p></article>
  <article class="card"><h2>Permissions</h2><p>CoreTend works with reduced
  coverage after a refusal. Settings explains what each permission unlocks
  and links back to System Settings.</p></article>
  <article class="card"><h2>Keyboard</h2><p>Tab and Shift-Tab move focus;
  Return activates the primary action; Escape closes cancellable sheets;
  Command-Q quits.</p></article>
  <article class="card"><h2>Update</h2><p>Quit the old copy, verify the new
  release, then replace CoreTend in Applications. Preferences and activity
  remain unless deliberately reset.</p></article>
  <article class="card"><h2>Uninstall</h2><p>Quit CoreTend and move only
  CoreTend.app from Applications to the Trash. Data reset is optional.</p></article>
  <article class="card"><h2>Report a problem</h2><p>Use the public issue
  tracker for bugs and the private security route for vulnerabilities.</p></article>
</div>
<h2>Common problems</h2>
<p>If a checksum differs, do not open the file. If macOS blocks the first
open, follow the CoreTend-specific route; never disable system protections.
Intel Macs and macOS versions older than 14 cannot run the published binary.</p>
<p>See the repository's <code>Documentation/TROUBLESHOOTING.md</code> for the
complete symptom/cause/safe-resolution matrix.</p>
"""
    return """
<h1>Assistance</h1>
<p class="lead">Des réponses sûres pour l'installation, le premier lancement
et l'utilisation quotidienne.</p>
<div class="cards">
  <article class="card"><h2>Premier lancement</h2><p>Suivez le
  <a href="install.html">guide graphique</a> et autorisez uniquement
  CoreTend.</p></article>
  <article class="card"><h2>Permissions</h2><p>Après un refus, CoreTend reste
  utilisable avec une couverture réduite. Réglages explique chaque permission
  et renvoie vers Réglages Système.</p></article>
  <article class="card"><h2>Clavier</h2><p>Tab et Maj-Tab déplacent le focus ;
  Retour active l'action principale ; Échap ferme les feuilles annulables ;
  Commande-Q quitte.</p></article>
  <article class="card"><h2>Mise à jour</h2><p>Quittez l'ancienne copie,
  vérifiez la nouvelle publication puis remplacez CoreTend dans Applications.
  Les préférences restent sauf réinitialisation volontaire.</p></article>
  <article class="card"><h2>Désinstallation</h2><p>Quittez CoreTend puis
  placez uniquement CoreTend.app depuis Applications dans la Corbeille. La
  suppression des données reste facultative.</p></article>
  <article class="card"><h2>Signaler un problème</h2><p>Utilisez les issues
  publiques pour les bugs et la voie privée pour une vulnérabilité.</p></article>
</div>
<h2>Problèmes fréquents</h2>
<p>Si un checksum diffère, n'ouvrez pas le fichier. Si macOS bloque la première
ouverture, utilisez la voie limitée à CoreTend ; ne désactivez jamais les
protections système. Les Mac Intel et macOS antérieurs à 14 ne peuvent pas
exécuter le binaire publié.</p>
<p>La matrice complète se trouve dans
<code>Documentation/TROUBLESHOOTING.md</code>.</p>
"""


add("support", {"en": "Support", "fr": "Assistance"}, support_body)


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
    # A link that 404s is worse than no link: it makes the whole page look
    # abandoned. So these render as links only while REPOSITORY_URL resolves,
    # and fall back to filenames otherwise.
    if REPOSITORY_URL:
        intro = (
            "Full documentation ships inside the repository, in its "
            "<code>Documentation/</code> folder. Each entry below links "
            "straight to it."
        ) if l == "en" else (
            "La documentation complète est fournie dans le dépôt, dans son "
            "dossier <code>Documentation/</code>. Chaque entrée ci-dessous y "
            "renvoie directement."
        )
    else:
        intro = (
            "Full documentation ships inside the repository, in its "
            "<code>Documentation/</code> folder. No public repository is "
            "configured, so these are filenames rather than links."
        ) if l == "en" else (
            "La documentation complète est fournie dans le dépôt, dans son "
            "dossier <code>Documentation/</code>. Aucun dépôt public n'est "
            "configuré : ce sont donc des noms de fichiers et non des liens."
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
    ]
    qa_fr = [
        ("CoreTend envoie-t-il des données quelque part ?", "Non. Aucune télémétrie, aucune analytique, aucun appel réseau lié à son fonctionnement principal. Tout s'exécute localement."),
        ("Faut-il un compte ?", "Aucun compte, aucun abonnement, jamais."),
        ("Les suppressions sont-elles définitives ?", "Par défaut, non — les éléments vont à la Corbeille pour rester récupérables."),
        ("Est-ce un antivirus complet ?", "Non. Le module Protection optionnel est une aide d'analyse locale heuristique (via ClamAV), jamais un produit de sécurité garanti."),
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
<p>The optional Protection module is a local scanning aid and does not make
an antivirus or security-guarantee claim.</p>
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
<p>Le module Protection facultatif est une aide d’analyse locale et ne
revendique aucune garantie antivirus ou de sécurité.</p>
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


def write_robots():
    """robots.txt, driven by the same flag as the per-page robots meta.

    While the site is not deployed it disallows everything, so a crawler that
    finds the domain early cannot index pages that are not reachable yet.
    """
    if SITE_INDEXABLE:
        body = (
            "User-agent: *\n"
            "Allow: /\n"
            f"\nSitemap: {SITE_URL}/sitemap.xml\n"
        )
    else:
        body = (
            "# The site is not deployed yet. Nothing here should be indexed\n"
            "# until it is reachable. Flip siteIndexable in the identity file\n"
            "# and regenerate to open it up.\n"
            "User-agent: *\n"
            "Disallow: /\n"
        )
    with open(os.path.join(ROOT, "robots.txt"), "w") as f:
        f.write(body)


def write_sitemap():
    """sitemap.xml listing every generated page in both locales."""
    urls = []
    for locale in ("en", "fr"):
        for slug in PAGES:
            if slug == "404":
                continue  # a 404 page must never be advertised as content
            loc = f"{SITE_URL}/{locale}/{slug}.html"
            urls.append(
                "  <url>\n"
                f"    <loc>{loc}</loc>\n"
                "  </url>"
            )
    doc = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        + "\n".join(urls)
        + "\n</urlset>\n"
    )
    with open(os.path.join(ROOT, "sitemap.xml"), "w") as f:
        f.write(doc)


def write_vercel_config():
    """Hosting config, generated so it cannot contradict the site it serves.

    The security headers are the ones WEBSITE_SECURITY.md specifies. The
    Content-Security-Policy is strict because the site earns it: no JavaScript
    at all, no external origin, and no inline style attributes, so nothing here
    needs 'unsafe-inline'. X-Robots-Tag follows the same siteIndexable flag as
    the per-page meta and robots.txt, so all three move together.
    """
    csp = (
        f"default-src 'self'; script-src 'self'; "
        f"style-src 'self' '{critical_style_hash()}'; "
        "img-src 'self' data:; media-src 'self'; font-src 'self'; connect-src 'none'; "
        "frame-ancestors 'none'; form-action 'none'; base-uri 'none'; "
        "object-src 'none'"
    )
    common = [
        {"key": "Content-Security-Policy", "value": csp},
        {"key": "Referrer-Policy", "value": "no-referrer"},
        {"key": "X-Content-Type-Options", "value": "nosniff"},
        {"key": "X-Frame-Options", "value": "DENY"},
        {"key": "Permissions-Policy", "value": ", ".join(
            f"{feature}=()" for feature in (
                "accelerometer", "ambient-light-sensor", "autoplay", "battery",
                "camera", "display-capture", "encrypted-media", "fullscreen",
                "gamepad", "geolocation", "gyroscope", "hid", "idle-detection",
                "local-fonts", "magnetometer", "microphone", "midi", "payment",
                "picture-in-picture", "publickey-credentials-get",
                "screen-wake-lock", "serial", "usb", "xr-spatial-tracking",
            ))},
        {"key": "Strict-Transport-Security",
         "value": "max-age=63072000; includeSubDomains; preload"},
        {"key": "Cross-Origin-Opener-Policy", "value": "same-origin"},
        {"key": "Cross-Origin-Resource-Policy", "value": "same-origin"},
    ]
    if not SITE_INDEXABLE:
        common.append({"key": "X-Robots-Tag", "value": "noindex"})

    config = {
        "$schema": "https://openapi.vercel.sh/vercel.json",
        "outputDirectory": ".",
        "cleanUrls": False,
        "trailingSlash": False,
        "redirects": [
            {"source": "/", "destination": "/en/index.html", "permanent": False},
        ],
        "headers": [
            {"source": "/(.*)", "headers": common},
            {"source": "/assets/(.*)", "headers": [
                {"key": "Cache-Control",
                 "value": "public, max-age=31536000, immutable"}]},
        ],
    }
    with open(os.path.join(ROOT, "vercel.json"), "w") as f:
        json.dump(config, f, indent=2)
        f.write("\n")


def main():
    for locale in ("en", "fr"):
        out_dir = os.path.join(ROOT, locale)
        os.makedirs(out_dir, exist_ok=True)
        for slug, (title, body_fn) in PAGES.items():
            html = page_shell(locale, slug, title[locale], body_fn(locale))
            with open(os.path.join(out_dir, f"{slug}.html"), "w") as f:
                f.write(html)
    write_robots()
    write_sitemap()
    write_vercel_config()
    print(f"Generated {len(PAGES)} pages x 2 locales into {ROOT}/en and {ROOT}/fr")
    print(f"Generated robots.txt, sitemap.xml, vercel.json (indexable={SITE_INDEXABLE})")


if __name__ == "__main__":
    main()
