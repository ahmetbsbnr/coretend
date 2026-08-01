#!/usr/bin/env python3
"""Build the public CoreTend website into an isolated, publish-only directory.

`Website/index.html` remains the visual gold-master working file.  This build
never edits it and never publishes the surrounding source directory.  It
adds route-specific metadata, creates the compact public-information pages,
copies an explicit asset allow-list and externalises inline scripts so the
production CSP can keep `script-src 'self'`.
"""

from __future__ import annotations

import argparse
import hashlib
import html
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import tempfile


SITE_ROOT = Path(__file__).resolve().parent
REPO_ROOT = SITE_ROOT.parent
TEMPLATE = SITE_ROOT / "index.html"
DEFAULT_OUTPUT = SITE_ROOT / "dist"
ORIGIN = "https://coretend.ahmetbsbnr.com"
REPOSITORY = "https://github.com/ahmetbsbnr/coretend"
RELEASE = REPO_ROOT / "Configuration" / "published-release.json"

# Deliberately excludes Website/generate.py, old authored CSS/JS, dev notes,
# Vercel configuration, Python bytecode and historical generated pages.
PUBLIC_ASSET_PATTERNS = (
    "app/*.png",
    "app/*.webp",
    "brand/*.png",
    "brand/*.svg",
    "demos/*.mp4",
    "demos/*.vtt",
    "demos/*.webm",
    "demos/*.webp",
    "fonts/*.woff2",
    "tokens/*.css",
    "tokens/*.json",
)

META = {
    "en": {
        "title": "CoreTend — See what your Mac is holding",
        "description": (
            "Local, transparent and reversible care for macOS. CoreTend "
            "reviews supported locations on-device and explains findings "
            "before an approved action."
        ),
        "locale": "en_US",
    },
    "fr": {
        "title": "CoreTend — Voyez ce que votre Mac conserve",
        "description": (
            "Entretien local, transparent et réversible pour macOS. CoreTend "
            "examine les emplacements pris en charge sur l’appareil et explique "
            "chaque résultat avant une action approuvée."
        ),
        "locale": "fr_FR",
    },
}


PUBLIC_CSS = r"""
@font-face{font-family:Archivo;font-display:swap;font-style:normal;font-weight:100 900;src:url('/assets/fonts/archivo-latin.woff2') format('woff2')}
@font-face{font-family:'IBM Plex Mono';font-display:swap;font-style:normal;font-weight:400;src:url('/assets/fonts/plexmono-400-latin.woff2') format('woff2')}
:root{color-scheme:light dark;--paper:#f4f4f0;--paper2:#e9e8df;--ink:#17191d;--muted:#59606b;--line:#d7d5ca;--cobalt:#1b45e0;--panel:#fbfbf8;--safe:#0f7a4d;--r:14px;--sans:Archivo,system-ui,-apple-system,sans-serif;--mono:'IBM Plex Mono',ui-monospace,monospace}
@media(prefers-color-scheme:dark){:root{--paper:#0d0f13;--paper2:#171a20;--ink:#edece5;--muted:#a7abb5;--line:#303540;--cobalt:#6c8cff;--panel:#12151b;--safe:#43c98c}}
*{box-sizing:border-box}html{background:var(--paper);color:var(--ink);font-family:var(--sans);scroll-behavior:smooth}body{margin:0;min-height:100vh;background:radial-gradient(circle at 80% 5%,color-mix(in srgb,var(--cobalt) 11%,transparent),transparent 32rem),var(--paper);line-height:1.6}a{color:inherit;text-decoration-thickness:.08em;text-underline-offset:.2em}a:hover{color:var(--cobalt)}:focus-visible{outline:2px solid var(--cobalt);outline-offset:3px}.skip{position:absolute;left:1rem;top:-5rem;background:var(--ink);color:var(--paper);padding:.7rem 1rem;border-radius:.6rem;z-index:5}.skip:focus{top:1rem}.wrap{width:min(860px,calc(100% - 2rem));margin:auto}.bar{border-bottom:1px solid var(--line);backdrop-filter:blur(14px);background:color-mix(in srgb,var(--paper) 86%,transparent)}.bar .wrap,.footer .wrap{min-height:68px;display:flex;align-items:center;justify-content:space-between;gap:1rem}.brand{display:flex;align-items:center;gap:.7rem;font-weight:750;text-decoration:none}.brand img{width:30px;height:30px}.nav{display:flex;align-items:center;gap:1rem;flex-wrap:wrap}.nav a{text-decoration:none;font-size:.92rem}.download{background:var(--cobalt);color:white!important;padding:.55rem 1rem;border-radius:999px}.hero{padding:clamp(4rem,10vw,7rem) 0 2rem}.eyebrow{font:500 .75rem/1 var(--mono);letter-spacing:.14em;text-transform:uppercase;color:var(--cobalt)}h1{font-size:clamp(2.25rem,7vw,4.75rem);line-height:1.02;letter-spacing:-.045em;max-width:15ch;margin:.8rem 0 1.2rem}.lead{font-size:clamp(1.02rem,2vw,1.22rem);color:var(--muted);max-width:62ch}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:1rem;padding:2rem 0 5rem}.card{background:var(--panel);border:1px solid var(--line);border-radius:var(--r);padding:clamp(1.25rem,4vw,2rem);box-shadow:0 22px 55px -42px color-mix(in srgb,var(--ink) 45%,transparent)}.card h2{font-size:1.25rem;margin:0 0 .75rem}.card h3{font-size:1rem;margin:1.5rem 0 .4rem}.card p,.card li{color:var(--muted)}.card code{font-family:var(--mono);font-size:.86em;overflow-wrap:anywhere}.card ul{padding-left:1.2rem}.footer{border-top:1px solid var(--line);font-size:.88rem;color:var(--muted)}.radar{width:72px;height:72px;border:1px solid var(--line);border-radius:50%;position:relative;margin-bottom:1.5rem;background:repeating-radial-gradient(circle,transparent 0 11px,var(--line) 12px 13px)}.radar:after{content:'';position:absolute;inset:5px 50% 50% 5px;border-top:2px solid var(--cobalt);transform-origin:100% 100%;animation:sweep 3.5s linear infinite}@keyframes sweep{to{transform:rotate(360deg)}}@media(prefers-reduced-motion:reduce){*{scroll-behavior:auto!important}.radar:after{animation:none;transform:rotate(35deg)}}@media(max-width:680px){.grid{grid-template-columns:1fr}.bar .wrap{align-items:flex-start;padding:.9rem 0}.nav{justify-content:flex-end}.footer .wrap{align-items:flex-start;flex-direction:column;padding:1rem 0}}
""".strip() + "\nbody{display:flex;flex-direction:column}\nmain{flex:1}"


def load_release() -> dict:
    with RELEASE.open(encoding="utf-8") as handle:
        release = json.load(handle)
    required = {
        "version",
        "dmgName",
        "dmgURL",
        "dmgSHA256",
        "minimumMacOS",
        "architecture",
        "signed",
        "notarized",
    }
    missing = sorted(required - release.keys())
    if missing:
        raise SystemExit(f"published release is missing: {', '.join(missing)}")
    return release


def replace_or_insert_head(document: str, pattern: str, replacement: str) -> str:
    updated, count = re.subn(pattern, replacement, document, count=1, flags=re.I | re.S)
    if count:
        return updated
    return document.replace("</head>", replacement + "\n</head>", 1)


def strip_route_metadata(document: str) -> str:
    patterns = (
        r'\s*<link\s+rel=["\']canonical["\'][^>]*>',
        r'\s*<link\s+rel=["\']alternate["\'][^>]*>',
        r'\s*<meta\s+name=["\']robots["\'][^>]*>',
        r'\s*<meta\s+property=["\']og:(?:url|locale|locale:alternate)["\'][^>]*>',
        r'\s*<meta\s+property=["\']og:(?:title|description|image|type|site_name)["\'][^>]*>',
        r'\s*<link\s+rel=["\']manifest["\'][^>]*>',
    )
    for pattern in patterns:
        document = re.sub(pattern, "", document, flags=re.I)
    return document


def landing_metadata(language: str, canonical_path: str) -> str:
    meta = META[language]
    alternate = "fr_FR" if language == "en" else "en_US"
    return "\n".join(
        (
            '<meta name="robots" content="index, follow">',
            f'<link rel="canonical" href="{ORIGIN}{canonical_path}">',
            f'<link rel="alternate" hreflang="en" href="{ORIGIN}/en/">',
            f'<link rel="alternate" hreflang="fr" href="{ORIGIN}/fr/">',
            f'<link rel="alternate" hreflang="x-default" href="{ORIGIN}/">',
            '<meta property="og:type" content="website">',
            '<meta property="og:site_name" content="CoreTend">',
            f'<meta property="og:title" content="{html.escape(meta["title"], quote=True)}">',
            f'<meta property="og:description" content="{html.escape(meta["description"], quote=True)}">',
            f'<meta property="og:url" content="{ORIGIN}{canonical_path}">',
            f'<meta property="og:locale" content="{meta["locale"]}">',
            f'<meta property="og:locale:alternate" content="{alternate}">',
            f'<meta property="og:image" content="{ORIGIN}/assets/brand/opengraph.png">',
            '<meta property="og:image:width" content="1200">',
            '<meta property="og:image:height" content="630">',
            '<meta name="twitter:card" content="summary_large_image">',
            '<link rel="manifest" href="/manifest.webmanifest">',
        )
    )


def set_document_language(document: str, language: str) -> str:
    match = re.search(r"<html\b[^>]*>", document, flags=re.I)
    if not match:
        raise SystemExit("gold master has no <html> element")
    tag = match.group(0)
    for name, value in (("lang", language), ("data-lang", language), ("data-build", "public")):
        attr = rf'\s{name}=(?:"[^"]*"|\'[^\']*\')'
        if re.search(attr, tag, flags=re.I):
            tag = re.sub(attr, f' {name}="{value}"', tag, count=1, flags=re.I)
        else:
            tag = tag[:-1] + f' {name}="{value}">'
    return document[: match.start()] + tag + document[match.end() :]


def render_translated_content(document: str, language: str) -> str:
    """Render the authored bilingual data attributes before first paint.

    The source keeps English content in the DOM and the matching French HTML in
    `data-fr`.  Public `/fr/` output must never rely on a late client-side swap,
    so this small deterministic renderer replaces the relevant inner HTML at
    build time.  It deliberately handles balanced same-name tags and applies
    only outermost translated intervals, avoiding overlapping replacements.
    """
    if language != "fr":
        return document

    token_re = re.compile(
        r"<(?P<closing>/)?(?P<tag>[A-Za-z][A-Za-z0-9:-]*)(?P<attrs>[^>]*)>",
        flags=re.S,
    )
    tokens = list(token_re.finditer(document))
    intervals: list[tuple[int, int, str]] = []
    for index, token in enumerate(tokens):
        if token.group("closing") or token.group(0).rstrip().endswith("/>"):
            continue
        attribute = re.search(
            r"\sdata-fr=(?P<quote>[\"'])(?P<value>.*?)(?P=quote)",
            token.group("attrs"),
            flags=re.S,
        )
        if not attribute:
            continue
        tag = token.group("tag").lower()
        depth = 1
        closing = None
        for candidate in tokens[index + 1 :]:
            if candidate.group("tag").lower() != tag:
                continue
            if candidate.group("closing"):
                depth -= 1
                if depth == 0:
                    closing = candidate
                    break
            elif not candidate.group(0).rstrip().endswith("/>"):
                depth += 1
        if closing is None:
            raise SystemExit(f"unclosed translated <{tag}> element")
        intervals.append(
            (token.end(), closing.start(), html.unescape(attribute.group("value")))
        )

    outermost = [
        interval
        for interval in intervals
        if not any(
            other[0] <= interval[0] and interval[1] <= other[1] and other != interval
            for other in intervals
        )
    ]
    for start, end, translated in sorted(outermost, reverse=True):
        document = document[:start] + translated + document[end:]
    return document


def externalise_scripts(document: str, output: Path, route_key: str) -> str:
    generated = output / "assets" / "generated"
    generated.mkdir(parents=True, exist_ok=True)
    index = 0

    def replace(match: re.Match[str]) -> str:
        nonlocal index
        attrs = match.group("attrs")
        body = match.group("body")
        if re.search(r"\bsrc\s*=", attrs, flags=re.I):
            return match.group(0)
        digest = hashlib.sha256(body.encode("utf-8")).hexdigest()[:16]
        filename = f"{route_key}-{index}-{digest}.js"
        (generated / filename).write_text(body.strip() + "\n", encoding="utf-8")
        index += 1
        return f'<script{attrs} src="/assets/generated/{filename}"></script>'

    return re.sub(
        r"<script(?P<attrs>[^>]*)>(?P<body>.*?)</script>",
        replace,
        document,
        flags=re.I | re.S,
    )


def externalise_styles(document: str, output: Path, route_key: str) -> str:
    generated = output / "assets" / "generated"
    generated.mkdir(parents=True, exist_ok=True)
    index = 0

    def replace(match: re.Match[str]) -> str:
        nonlocal index
        body = match.group("body")
        digest = hashlib.sha256(body.encode("utf-8")).hexdigest()[:16]
        filename = f"{route_key}-{index}-{digest}.css"
        (generated / filename).write_text(body.strip() + "\n", encoding="utf-8")
        index += 1
        return f'<link rel="stylesheet" href="/assets/generated/{filename}">'

    return re.sub(
        r"<style[^>]*>(?P<body>.*?)</style>",
        replace,
        document,
        flags=re.I | re.S,
    )


def build_landing(template: str, language: str, canonical_path: str, output: Path) -> str:
    document = strip_route_metadata(template)
    document = set_document_language(document, language)
    document = render_translated_content(document, language)
    for code in ("en", "fr"):
        current = "page" if code == language else "false"
        document = re.sub(
            rf'(<a\b[^>]*data-lang-link=["\']{code}["\'][^>]*aria-current=)["\'][^"\']*["\']',
            rf'\1"{current}"',
            document,
            count=1,
            flags=re.I,
        )
    meta = META[language]
    document = replace_or_insert_head(
        document,
        r"<title>.*?</title>",
        f"<title>{html.escape(meta['title'])}</title>",
    )
    document = replace_or_insert_head(
        document,
        r'<meta\s+name=["\']description["\'][^>]*>',
        f'<meta name="description" content="{html.escape(meta["description"], quote=True)}">',
    )
    document = document.replace("</head>", landing_metadata(language, canonical_path) + "\n</head>", 1)

    route_key = language if canonical_path != "/" else "root"
    document = externalise_styles(document, output, route_key)
    return externalise_scripts(document, output, route_key)


def public_head(title: str, description: str, canonical: str, *, robots: str = "index, follow") -> str:
    return f"""<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)}</title>
<meta name="description" content="{html.escape(description, quote=True)}">
<meta name="color-scheme" content="light dark">
<meta name="robots" content="{robots}">
<link rel="canonical" href="{ORIGIN}{canonical}">
<link rel="alternate" hreflang="x-default" href="{ORIGIN}{canonical}">
<meta property="og:type" content="website">
<meta property="og:site_name" content="CoreTend">
<meta property="og:title" content="{html.escape(title, quote=True)}">
<meta property="og:description" content="{html.escape(description, quote=True)}">
<meta property="og:url" content="{ORIGIN}{canonical}">
<meta property="og:image" content="{ORIGIN}/assets/brand/opengraph.png">
<link rel="icon" href="/favicon.ico" sizes="32x32">
<link rel="apple-touch-icon" href="/assets/brand/favicon-180.png">
<link rel="manifest" href="/manifest.webmanifest">
<link rel="stylesheet" href="/assets/public.css">"""


def shell(title: str, description: str, canonical: str, content: str) -> str:
    return f"""<!doctype html>
<html lang="en">
<head>
{public_head(title, description, canonical)}
</head>
<body>
<a class="skip" href="#main">Skip to content · Aller au contenu</a>
<header class="bar"><div class="wrap">
  <a class="brand" href="/"><img src="/assets/brand/favicon-32.png" alt="">CoreTend</a>
  <nav class="nav" aria-label="Public navigation · Navigation publique">
    <a href="/en/" hreflang="en">EN</a><a href="/fr/" hreflang="fr">FR</a>
    <a href="/privacy">Privacy</a><a href="/support">Support</a>
    <a class="download" href="/download">Download</a>
  </nav>
</div></header>
<main id="main" class="wrap">{content}</main>
<footer class="footer"><div class="wrap"><span>CoreTend · Apache-2.0</span><nav class="nav"><a href="/legal">Legal</a><a href="/licenses">Licenses</a><a href="{REPOSITORY}">GitHub</a></nav></div></footer>
</body>
</html>
"""


def information_pages(release: dict) -> dict[str, str]:
    checksum = html.escape(str(release["dmgSHA256"]))
    version = html.escape(str(release["version"]))
    dmg_name = html.escape(str(release["dmgName"]))
    minimum = html.escape(str(release["minimumMacOS"]))
    architecture = html.escape(str(release["architecture"]))
    privacy = shell(
        "Privacy · Confidentialité — CoreTend",
        "CoreTend privacy information in English and French.",
        "/privacy",
        """<section class="hero"><p class="eyebrow">CORETEND / PRIVACY</p><h1>Private by design.<br>Confidentiel par conception.</h1><p class="lead">The application’s supported scans run on the Mac. The website has no advertising analytics, account system or session replay.</p></section>
<section class="grid"><article class="card" lang="en"><h2>English</h2><p>CoreTend does not upload scan findings or require an account. It contains no advertising telemetry. A user-initiated update check may request <code>/latest.json</code>; the site builds that stable manifest from the reviewed public-release record.</p><h3>This website</h3><p>No advertising cookies, analytics pixels or session replay are configured by the site code. Vercel provides the hosting layer and GitHub serves release files.</p></article><article class="card" lang="fr"><h2>Français</h2><p>CoreTend ne téléverse pas les résultats d’analyse et n’exige aucun compte. Il ne contient aucune télémétrie publicitaire. Une recherche de mise à jour lancée par l’utilisateur peut demander <code>/latest.json</code> ; le site génère ce manifeste stable depuis la version publique vérifiée.</p><h3>Ce site</h3><p>Le code du site ne configure ni cookie publicitaire, ni pixel analytique, ni relecture de session. Vercel assure l’hébergement et GitHub sert les fichiers de publication.</p></article></section>""",
    )
    support = shell(
        "Support · Assistance — CoreTend",
        "CoreTend installation, verification and support routes.",
        "/support",
        f"""<section class="hero"><p class="eyebrow">CORETEND / SUPPORT</p><h1>Help without lowering macOS security.</h1><p class="lead">Version {version} is unsigned and not notarized. macOS will show an accurate first-launch warning.</p></section>
<section class="grid"><article class="card" lang="en"><h2>English</h2><h3>Install</h3><p>Requires macOS {minimum}+ on {architecture}. Open CoreTend once, then use System Settings → Privacy &amp; Security → Open Anyway. Never disable Gatekeeper globally.</p><h3 id="documentation">Documentation</h3><p><a href="{REPOSITORY}/blob/main/Documentation/README.md">Documentation index</a> · <a href="{REPOSITORY}/issues">Public issue tracker</a></p><h3 id="security">Security</h3><p>Report vulnerabilities through <a href="{REPOSITORY}/security/advisories/new">GitHub private vulnerability reporting</a>.</p><h3 id="releases">Verification and releases</h3><p><code>{dmg_name}</code><br><code>{checksum}</code></p><h3 id="roadmap">Roadmap</h3><p>Developer ID and notarization are planned as a later distribution update.</p><h3 id="source">Source</h3><p><a href="{REPOSITORY}">Read and build the public source.</a></p></article><article class="card" lang="fr"><h2>Français</h2><h3>Installation</h3><p>macOS {minimum}+ et architecture {architecture}. Ouvrez CoreTend une première fois, puis utilisez Réglages Système → Confidentialité et sécurité → Ouvrir quand même. Ne désactivez jamais Gatekeeper globalement.</p><h3>Documentation</h3><p><a href="{REPOSITORY}/blob/main/Documentation/README.md">Index de documentation</a> · <a href="{REPOSITORY}/issues">Suivi public des problèmes</a></p><h3>Sécurité</h3><p>Signalez une vulnérabilité par le <a href="{REPOSITORY}/security/advisories/new">canal privé GitHub</a>.</p><h3>Vérification</h3><p><code>{dmg_name}</code><br><code>{checksum}</code></p><h3>Feuille de route</h3><p>Developer ID et notarisation sont prévus dans une future mise à jour de distribution.</p><h3>Source</h3><p><a href="{REPOSITORY}">Consulter et compiler le code public.</a></p></article></section>""",
    )
    legal = shell(
        "Legal notice · Mentions légales — CoreTend",
        "CoreTend public project and hosting notice.",
        "/legal",
        f"""<section class="hero"><p class="eyebrow">CORETEND / LEGAL</p><h1>Public project notice.<br>Informations publiques.</h1><p class="lead">CoreTend is free, open-source software distributed without an account or subscription.</p></section><section class="grid"><article class="card" lang="en"><h2>English</h2><p>Project: CoreTend. Source repository: <a href="{REPOSITORY}">{REPOSITORY}</a>. Code license: Apache-2.0. Hosting provider: Vercel Inc. CoreTend is currently distributed outside the Mac App Store.</p><p>The current binary is unsigned and not notarized. This notice does not claim Apple certification or App Store availability.</p></article><article class="card" lang="fr"><h2>Français</h2><p>Projet : CoreTend. Dépôt source : <a href="{REPOSITORY}">{REPOSITORY}</a>. Licence du code : Apache-2.0. Hébergeur : Vercel Inc. CoreTend est actuellement distribué hors du Mac App Store.</p><p>Le binaire actuel n’est ni signé ni notarisé. Cette notice ne revendique aucune certification Apple ni disponibilité sur l’App Store.</p></article></section>""",
    )
    licenses = shell(
        "Licenses · Licences — CoreTend",
        "CoreTend code and website asset license information.",
        "/licenses",
        f"""<section class="hero"><p class="eyebrow">CORETEND / LICENSES</p><h1>Open source, with attribution.</h1><p class="lead">The authoritative legal texts remain versioned with the source.</p></section><section class="grid"><article class="card" lang="en"><h2>English</h2><p>CoreTend source code is distributed under Apache-2.0. Read <a href="{REPOSITORY}/blob/main/LICENSE">LICENSE</a>, <a href="{REPOSITORY}/blob/main/NOTICE">NOTICE</a> and <a href="{REPOSITORY}/blob/main/THIRD_PARTY_NOTICES.md">THIRD_PARTY_NOTICES.md</a>.</p><p>The site self-hosts Archivo and IBM Plex Mono under SIL Open Font License 1.1. Read the bundled <a href="/assets/licenses/Archivo-OFL.txt">Archivo license</a> and <a href="/assets/licenses/IBM-Plex-OFL.txt">IBM Plex license</a>.</p></article><article class="card" lang="fr"><h2>Français</h2><p>Le code source de CoreTend est distribué sous Apache-2.0. Consultez <a href="{REPOSITORY}/blob/main/LICENSE">LICENSE</a>, <a href="{REPOSITORY}/blob/main/NOTICE">NOTICE</a> et <a href="{REPOSITORY}/blob/main/THIRD_PARTY_NOTICES.md">THIRD_PARTY_NOTICES.md</a>.</p><p>Le site auto-héberge Archivo et IBM Plex Mono sous SIL Open Font License 1.1. Consultez la <a href="/assets/licenses/Archivo-OFL.txt">licence Archivo</a> et la <a href="/assets/licenses/IBM-Plex-OFL.txt">licence IBM Plex</a> incluses.</p></article></section>""",
    )
    return {
        "privacy.html": privacy,
        "support.html": support,
        "legal.html": legal,
        "licenses.html": licenses,
    }


def not_found_page() -> str:
    content = """<section class="hero"><div class="radar" aria-hidden="true"></div><p class="eyebrow">CORETEND / 404</p><h1>Route not found.<br>Route introuvable.</h1><p class="lead">The requested address does not exist. L’adresse demandée n’existe pas.</p><p><a class="download" href="/">Return home · Retour à l’accueil</a></p></section>"""
    page = shell("404 — CoreTend", "The requested CoreTend route does not exist.", "/404", content)
    page = re.sub(r'<meta name="robots"[^>]*>', '<meta name="robots" content="noindex, follow">', page)
    page = re.sub(r'\s*<link rel="canonical"[^>]*>', "", page)
    page = re.sub(r'\s*<link rel="alternate"[^>]*>', "", page)
    page = re.sub(r'\s*<meta property="og:url"[^>]*>', "", page)
    return page


def copy_assets(stage: Path) -> None:
    source = SITE_ROOT / "assets"
    destination = stage / "assets"
    copied: set[Path] = set()
    for pattern in PUBLIC_ASSET_PATTERNS:
        for item in sorted(source.glob(pattern)):
            if not item.is_file() or item.is_symlink():
                continue
            relative = item.relative_to(source)
            target = destination / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(item, target)
            copied.add(relative)
    if not copied:
        raise SystemExit("public asset allow-list copied nothing")
    license_destination = destination / "licenses"
    license_destination.mkdir(parents=True, exist_ok=True)
    for name in ("Archivo-OFL.txt", "IBM-Plex-OFL.txt"):
        source_license = REPO_ROOT / "LICENSES" / name
        if not source_license.is_file():
            raise SystemExit(f"missing required font license: {source_license}")
        shutil.copy2(source_license, license_destination / name)
    (destination / "public.css").write_text(PUBLIC_CSS + "\n", encoding="utf-8")


def write_favicon(stage: Path) -> None:
    png = (SITE_ROOT / "assets" / "brand" / "favicon-32.png").read_bytes()
    # ICO supports a PNG image payload.  The 22-byte header below describes a
    # single 32x32, 32-bit entry followed by the original PNG bytes.
    header = struct.pack("<HHHBBBBHHII", 0, 1, 1, 32, 32, 0, 0, 1, 32, len(png), 22)
    (stage / "favicon.ico").write_bytes(header + png)


def write_documents(stage: Path, release: dict) -> None:
    sitemap_paths = ("/", "/en/", "/fr/", "/privacy", "/support", "/legal", "/licenses")
    sitemap = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        + "\n".join(f"  <url><loc>{ORIGIN}{path}</loc></url>" for path in sitemap_paths)
        + "\n</urlset>\n"
    )
    (stage / "sitemap.xml").write_text(sitemap, encoding="utf-8")
    (stage / "robots.txt").write_text(
        f"User-agent: *\nAllow: /\n\nSitemap: {ORIGIN}/sitemap.xml\n",
        encoding="utf-8",
    )
    manifest = {
        "name": "CoreTend",
        "short_name": "CoreTend",
        "id": "/",
        "start_url": "/",
        "display": "browser",
        "background_color": "#f4f4f0",
        "theme_color": "#1b45e0",
        "icons": [
            {"src": "/assets/brand/favicon-180.png", "sizes": "180x180", "type": "image/png"},
            {"src": "/assets/brand/favicon-512.png", "sizes": "512x512", "type": "image/png"},
        ],
    }
    (stage / "manifest.webmanifest").write_text(
        json.dumps(manifest, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )


def write_release_documents(stage: Path) -> None:
    gate = REPO_ROOT / "Scripts" / "generate-public-release.py"
    subprocess.run(
        [sys.executable, str(gate), str(stage)],
        cwd=REPO_ROOT,
        check=True,
    )


def safe_output(path: Path) -> Path:
    resolved = path.expanduser().resolve()
    forbidden = {Path("/").resolve(), REPO_ROOT.resolve(), SITE_ROOT.resolve()}
    if resolved in forbidden:
        raise SystemExit(f"refusing unsafe output directory: {resolved}")
    return resolved


def build(output: Path) -> None:
    output = safe_output(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix=".coretend-site-build-", dir=output.parent))
    try:
        template = TEMPLATE.read_text(encoding="utf-8")
        if "CoreTend" not in template or "</html>" not in template:
            raise SystemExit("Website/index.html is not a usable CoreTend gold master")
        release = load_release()
        copy_assets(stage)

        root_page = build_landing(template, "en", "/", stage)
        en_page = build_landing(template, "en", "/en/", stage)
        fr_page = build_landing(template, "fr", "/fr/", stage)
        (stage / "index.html").write_text(root_page, encoding="utf-8")
        (stage / "en").mkdir()
        (stage / "fr").mkdir()
        (stage / "en" / "index.html").write_text(en_page, encoding="utf-8")
        (stage / "fr" / "index.html").write_text(fr_page, encoding="utf-8")

        for name, page in information_pages(release).items():
            (stage / name).write_text(page, encoding="utf-8")
        (stage / "404.html").write_text(not_found_page(), encoding="utf-8")
        write_documents(stage, release)
        write_release_documents(stage)
        write_favicon(stage)

        if output.exists():
            shutil.rmtree(output)
        os.replace(stage, output)
    except BaseException:
        shutil.rmtree(stage, ignore_errors=True)
        raise


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    build(args.output)
    print(f"Built public CoreTend site: {safe_output(args.output)}")


if __name__ == "__main__":
    main()
