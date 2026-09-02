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
from typing import Optional, Sequence


SITE_ROOT = Path(__file__).resolve().parent
REPO_ROOT = SITE_ROOT.parent
TEMPLATE = SITE_ROOT / "index.html"
DEFAULT_OUTPUT = SITE_ROOT / "dist"
ORIGIN = "https://coretend.ahmetbsbnr.com"
REPOSITORY = "https://github.com/ahmetbsbnr/coretend"
RELEASE = REPO_ROOT / "Configuration" / "published-release.json"

# Deliberately excludes old authored CSS/JS, dev notes, Vercel configuration,
# Python bytecode and any historical generated pages.
PUBLIC_ASSET_PATTERNS = (
    "app/*.png",
    "app/*.webp",
    "brand/favicon-v2-*.png",
    "brand/opengraph.png",
    "brand/*.svg",
    "demos/*.mp4",
    "demos/*.vtt",
    "demos/*.webm",
    "demos/*.webp",
    "fonts/*.woff2",
    "shell/*.css",
    "shell/*.js",
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


def structured_data(language: str, canonical_path: str, release: dict) -> str:
    """A single SoftwareApplication node describing the current public build.

    Every field is derived from the same canonical record the rest of the page
    renders, so the JSON-LD can never drift from the visible facts.
    """
    meta = META[language]
    graph = {
        "@context": "https://schema.org",
        "@type": "SoftwareApplication",
        "name": "CoreTend",
        "applicationCategory": "UtilitiesApplication",
        "operatingSystem": f"macOS {release['minimumMacOS']}+",
        "processorRequirements": "Apple silicon (arm64)",
        "softwareVersion": str(release["version"]),
        "url": f"{ORIGIN}{canonical_path}",
        "downloadUrl": f"{REPOSITORY}/releases/latest",
        "image": f"{ORIGIN}/assets/brand/opengraph.png",
        "description": meta["description"],
        "inLanguage": "fr" if language == "fr" else "en",
        "license": "https://www.apache.org/licenses/LICENSE-2.0",
        "isAccessibleForFree": True,
        "offers": {"@type": "Offer", "price": "0", "priceCurrency": "USD"},
        "author": {
            "@type": "Organization",
            "name": "CoreTend",
            "url": REPOSITORY,
        },
    }
    payload = json.dumps(graph, ensure_ascii=False, separators=(",", ":"))
    # A JSON-LD data block cannot contain a literal "</script>"; escape defensively.
    payload = payload.replace("</", "<\\/")
    return f'<script type="application/ld+json">{payload}</script>'


def landing_metadata(language: str, canonical_path: str, release: dict) -> str:
    meta = META[language]
    alternate = "fr_FR" if language == "en" else "en_US"
    return "\n".join(
        (
            '<meta name="robots" content="index, follow">',
            '<meta name="theme-color" media="(prefers-color-scheme: light)" content="#f6f4ef">',
            '<meta name="theme-color" media="(prefers-color-scheme: dark)" content="#16191e">',
            f'<link rel="canonical" href="{ORIGIN}{canonical_path}">',
            f'<link rel="alternate" hreflang="en" href="{ORIGIN}/en">',
            f'<link rel="alternate" hreflang="fr" href="{ORIGIN}/fr">',
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
            structured_data(language, canonical_path, release),
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
    `data-fr`.  Public `/fr` output must never rely on a late client-side swap,
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
        type_match = re.search(r'\btype\s*=\s*["\']([^"\']+)["\']', attrs, flags=re.I)
        if type_match and type_match.group(1).strip().lower() not in (
            "text/javascript",
            "application/javascript",
            "module",
        ):
            # A non-executable data block (e.g. application/ld+json). CSP's
            # script-src never applies to it, so leave it inline rather than
            # emitting a bogus .js file.
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


def render_release_facts(document: str, release: dict) -> str:
    signed = bool(release.get("signed")) and bool(release.get("notarized"))
    replacements = {
        "@@CORETEND_RELEASE_VERSION@@": str(release["version"]),
        "@@CORETEND_DMG_SHA256@@": str(release["dmgSHA256"]),
        "@@CORETEND_MINIMUM_MACOS@@": str(release["minimumMacOS"]),
        "@@CORETEND_ARCHITECTURE@@": str(release["architecture"]),
        "@@CORETEND_SIGNING_EN@@": "Developer ID · Apple-notarized" if signed else "no Developer ID · not notarized",
        "@@CORETEND_SIGNING_FR@@": "Developer ID · notarisé Apple" if signed else "sans Developer ID · non notarisé",
    }
    for token, value in replacements.items():
        if token not in document:
            raise SystemExit(f"gold master is missing release token: {token}")
        document = document.replace(token, html.escape(value))
    unresolved = sorted(set(re.findall(r"@@CORETEND_[A-Z0-9_]+@@", document)))
    if unresolved:
        raise SystemExit(f"unresolved release token(s): {', '.join(unresolved)}")
    return document


def build_landing(template: str, language: str, canonical_path: str, output: Path, release: dict) -> str:
    document = strip_route_metadata(template)
    document = set_document_language(document, language)
    document = render_release_facts(document, release)
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
    document = document.replace("</head>", landing_metadata(language, canonical_path, release) + "\n</head>", 1)

    route_key = language if canonical_path != "/" else "root"
    document = externalise_styles(document, output, route_key)
    return externalise_scripts(document, output, route_key)


def route_for(page: str, language: str) -> str:
    if page == "home":
        return "/fr" if language == "fr" else "/en"
    if page == "404":
        return route_for("home", language)
    return f"/fr/{page}" if language == "fr" else f"/{page}"


def logo_svg(modifier: str, *, label: Optional[str] = None, initializing: bool = False) -> str:
    classes = f"mark ct-logo ct-logo--{modifier}"
    if initializing:
        classes += " is-initializing"
    identity = (
        f'role="img" aria-label="{html.escape(label, quote=True)}"'
        if label
        else 'aria-hidden="true" focusable="false"'
    )
    return f"""<svg class="{classes}" viewBox="0 0 512 512" {identity}>
  <g class="ct-arc ct-arc-outer"><path d="M 135.680 464.400 A 240.640 240.640 0 0 0 464.400 135.680" fill="none" stroke="var(--cobalt)" stroke-width="38.4" stroke-linecap="round"/></g>
  <g class="ct-arc ct-arc-middle"><path d="M 434.039 208.294 A 184.320 184.320 0 0 0 137.521 114.803" fill="none" stroke="var(--ink)" stroke-width="38.4" stroke-linecap="round"/></g>
  <g class="ct-arc ct-arc-inner"><path d="M 135.719 212.221 A 128.000 128.000 0 0 0 192.000 366.851" fill="none" stroke="var(--line-strong)" stroke-width="38.4" stroke-linecap="round"/></g>
  <circle class="ct-wave" cx="256" cy="256" r="61.44"/>
  <circle class="ct-core" cx="256" cy="256" r="61.44" fill="var(--cobalt)"/>
</svg>"""


def public_head(
    title: str,
    description: str,
    canonical: str,
    *,
    language: str,
    page: str,
    robots: str = "index, follow",
) -> str:
    alternate_en = route_for(page, "en")
    alternate_fr = route_for(page, "fr")
    locale = "fr_FR" if language == "fr" else "en_US"
    alternate_locale = "en_US" if language == "fr" else "fr_FR"
    return f"""<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)}</title>
<meta name="description" content="{html.escape(description, quote=True)}">
<meta name="color-scheme" content="light dark">
<meta name="theme-color" media="(prefers-color-scheme: light)" content="#f6f4ef">
<meta name="theme-color" media="(prefers-color-scheme: dark)" content="#16191e">
<meta name="robots" content="{robots}">
<link rel="canonical" href="{ORIGIN}{canonical}">
<link rel="alternate" hreflang="en" href="{ORIGIN}{alternate_en}">
<link rel="alternate" hreflang="fr" href="{ORIGIN}{alternate_fr}">
<link rel="alternate" hreflang="x-default" href="{ORIGIN}{alternate_en}">
<meta property="og:type" content="website">
<meta property="og:site_name" content="CoreTend">
<meta property="og:title" content="{html.escape(title, quote=True)}">
<meta property="og:description" content="{html.escape(description, quote=True)}">
<meta property="og:url" content="{ORIGIN}{canonical}">
<meta property="og:locale" content="{locale}">
<meta property="og:locale:alternate" content="{alternate_locale}">
<meta property="og:image" content="{ORIGIN}/assets/brand/opengraph.png">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta name="twitter:card" content="summary_large_image">
<link rel="icon" href="/assets/brand/favicon.svg" type="image/svg+xml">
<link rel="icon" href="/assets/brand/favicon-v2-16.png" sizes="16x16" type="image/png">
<link rel="icon" href="/assets/brand/favicon-v2-32.png" sizes="32x32" type="image/png">
<link rel="icon" href="/favicon.ico" sizes="16x16 32x32">
<link rel="apple-touch-icon" href="/assets/brand/favicon-v2-180.png">
<link rel="manifest" href="/manifest.webmanifest">
<script src="/assets/shell/boot.js"></script>
<link rel="stylesheet" href="/assets/tokens/design-tokens.css">
<link rel="stylesheet" href="/assets/shell/public.css">
<script src="/assets/shell/public.js" defer></script>"""


def shell(
    release: dict,
    page: str,
    language: str,
    title: str,
    description: str,
    canonical: str,
    content: str,
    *,
    robots: str = "index, follow",
) -> str:
    is_fr = language == "fr"
    skip = "Aller au contenu" if is_fr else "Skip to content"
    navigation = "Navigation principale" if is_fr else "Main navigation"
    home_label = "CoreTend, accueil" if is_fr else "CoreTend, home"
    download = "Télécharger" if is_fr else "Download"
    privacy = "Confidentialité" if is_fr else "Privacy"
    support = "Assistance" if is_fr else "Support"
    legal = "Mentions légales" if is_fr else "Legal"
    licenses = "Licences" if is_fr else "Licenses"
    source = "Code source" if is_fr else "Source"
    _signed = bool(release.get("signed")) and bool(release.get("notarized"))
    if _signed:
        version_status = (
            f"{release['version']} · Developer ID · notarisé Apple"
            if is_fr
            else f"{release['version']} · Developer ID · Apple-notarized"
        )
    else:
        version_status = (
            f"{release['version']} · sans Developer ID · non notarisé"
            if is_fr
            else f"{release['version']} · no Developer ID · not notarized"
        )
    en_path = route_for(page, "en")
    fr_path = route_for(page, "fr")
    privacy_current = ' aria-current="page"' if page == "privacy" else ""
    support_current = ' aria-current="page"' if page == "support" else ""
    return f"""<!doctype html>
<html lang="{language}" data-theme="light" data-theme-mode="system" data-build="public">
<head>
{public_head(title, description, canonical, language=language, page=page, robots=robots)}
</head>
<body data-page="{page}">
<a class="skip" href="#main">{skip}</a>
<canvas id="field" aria-hidden="true"></canvas>
<div id="grain" aria-hidden="true"></div>
<div id="spot" aria-hidden="true"></div>
<div id="progress" aria-hidden="true"></div>
<header class="bar" id="bar"><div class="wrap">
  <a class="wordmark" href="{route_for('home', language)}" aria-label="{home_label}">{logo_svg('header', initializing=True)}<span>CoreTend</span></a>
  <nav class="bar-actions" aria-label="{navigation}">
    <a class="bar-link" href="{route_for('privacy', language)}"{privacy_current}>{privacy}</a>
    <a class="bar-link" href="{route_for('support', language)}"{support_current}>{support}</a>
    <div class="switch" role="group" aria-label="{'Langue' if is_fr else 'Language'}">
      <a href="{en_path}" hreflang="en" lang="en" aria-current="{'page' if not is_fr else 'false'}">EN</a>
      <a href="{fr_path}" hreflang="fr" lang="fr" aria-current="{'page' if is_fr else 'false'}">FR</a>
    </div>
    <button class="icon-btn" id="theme" type="button" aria-label="{'Changer d’apparence' if is_fr else 'Change appearance'}">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="12" r="4"/><path d="M12 2.5v2M12 19.5v2M4.5 12h-2M21.5 12h-2M6.7 6.7 5.3 5.3M18.7 18.7l-1.4-1.4M17.3 6.7l1.4-1.4M5.3 18.7l1.4-1.4"/><circle class="system-dot" cx="12" cy="12" r="1" fill="currentColor" stroke="none"/></svg>
    </button>
    <a class="download-pill" href="/download"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 3v12M7 11l5 5 5-5M4 20h16"/></svg><span>{download}</span></a>
  </nav>
</div></header>
<main id="main">{content}</main>
<footer class="foot"><div class="wrap">
  <div class="foot-row">
    <a class="wordmark" href="{route_for('home', language)}">{logo_svg('footer')}<span>CoreTend</span></a>
    <ul class="foot-links">
      <li><a href="{route_for('privacy', language)}">{privacy}</a></li>
      <li><a href="{route_for('support', language)}">{support}</a></li>
      <li><a href="{route_for('legal', language)}">{legal}</a></li>
      <li><a href="{route_for('licenses', language)}">{licenses}</a></li>
      <li><a href="{REPOSITORY}">{source}</a></li>
    </ul>
  </div>
  <div class="foot-base"><span>© CoreTend contributors · Apache-2.0</span><span>{version_status}</span></div>
</div></footer>
<div id="toast" role="status" aria-live="polite"></div>
</body>
</html>
"""


def info_hero(page: str, language: str, eyebrow: str, heading: str, lead: str, chips: Sequence[str]) -> str:
    chip_markup = "".join(
        f'<span class="chip{" safe" if index == 0 else ""}">{html.escape(chip)}</span>'
        for index, chip in enumerate(chips)
    )
    return f"""<section class="info-hero"><div class="wrap">
  <span class="info-mark">{logo_svg('intro', label='CoreTend', initializing=True)}</span>
  <div class="info-copy"><p class="eyebrow"><b>{page.upper()}</b> {html.escape(eyebrow)}</p><h1>{heading}</h1><p class="lead">{lead}</p><div class="status-line">{chip_markup}</div></div>
</div></section>"""


def privacy_content(release: dict, language: str) -> str:
    if language == "fr":
        hero = info_hero("privacy", language, "Limites vérifiables", "Vos résultats restent sur le Mac.", "CoreTend analyse les emplacements pris en charge sur l’appareil. Une vérification de mise à jour lancée manuellement contacte uniquement le manifeste public de version.", ["Traitement local", "Aucun compte", "Aucune télémétrie publicitaire"])
        return hero + """<section class="info-section"><div class="wrap"><div class="section-head"><p class="section-index">01 / Flux local</p><div><h2>Ce qui reste local, ce qui utilise le réseau.</h2><p class="section-intro">La frontière est documentée au point où elle se présente, sans promettre une absence absolue de connexion.</p></div></div>
<ul class="measure-list"><li><strong>Résultats d’analyse</strong><p>Les chemins, tailles, correspondances de doublons et activités agrégées restent dans le stockage local de CoreTend.</p></li><li><strong>Mise à jour manuelle</strong><p>Une action de l’utilisateur peut demander <code>/latest.json</code>. Aucun index de fichiers n’est envoyé avec cette requête.</p></li><li><strong>Site public</strong><p>Le code du site ne configure ni cookie publicitaire, ni pixel analytique, ni relecture de session. Vercel héberge le site et GitHub sert les artefacts.</p></li></ul>
<div class="local-flow" aria-label="Schéma de flux local"><span class="local-node" style="--x:9%;--y:20%;--tx:18px;--ty:10px;--delay:-1s">Storage</span><span class="local-node" style="--x:72%;--y:18%;--tx:-16px;--ty:14px;--delay:-2s">Duplicates</span><span class="local-node" style="--x:12%;--y:72%;--tx:20px;--ty:-13px;--delay:-3s">Integrity</span><span class="local-node" style="--x:73%;--y:70%;--tx:-18px;--ty:-10px;--delay:-4s">Activity</span><span class="local-core">stockage<br>local</span></div>
<pre class="local-log" aria-label="Journal local illustratif">scan.store = ~/Library/Application Support/CoreTend/store.sqlite
telemetry = false
account_required = false
update_check = user_initiated → /latest.json</pre></div></section>"""
    hero = info_hero("privacy", language, "Inspectable boundaries", "Your findings stay on the Mac.", "CoreTend processes supported locations on-device. A user-initiated update check contacts only the public release manifest.", ["Local processing", "No account", "No advertising telemetry"])
    return hero + """<section class="info-section"><div class="wrap"><div class="section-head"><p class="section-index">01 / Local flow</p><div><h2>What stays local, what reaches the network.</h2><p class="section-intro">The boundary is documented where it occurs, without claiming the app never makes a network request.</p></div></div>
<ul class="measure-list"><li><strong>Scan findings</strong><p>Paths, sizes, duplicate matches and aggregate activity remain in CoreTend’s local store.</p></li><li><strong>Manual update check</strong><p>A user action may request <code>/latest.json</code>. No file index is sent with that request.</p></li><li><strong>Public website</strong><p>The site code configures no advertising cookies, analytics pixels or session replay. Vercel hosts the site and GitHub serves release artifacts.</p></li></ul>
<div class="local-flow" aria-label="Local data flow diagram"><span class="local-node" style="--x:9%;--y:20%;--tx:18px;--ty:10px;--delay:-1s">Storage</span><span class="local-node" style="--x:72%;--y:18%;--tx:-16px;--ty:14px;--delay:-2s">Duplicates</span><span class="local-node" style="--x:12%;--y:72%;--tx:20px;--ty:-13px;--delay:-3s">Integrity</span><span class="local-node" style="--x:73%;--y:70%;--tx:-18px;--ty:-10px;--delay:-4s">Activity</span><span class="local-core">local<br>store</span></div>
<pre class="local-log" aria-label="Illustrative local log">scan.store = ~/Library/Application Support/CoreTend/store.sqlite
telemetry = false
account_required = false
update_check = user_initiated → /latest.json</pre></div></section>"""


def support_content(release: dict, language: str) -> str:
    version = html.escape(str(release["version"]))
    checksum = html.escape(str(release["dmgSHA256"]))
    dmg_name = html.escape(str(release["dmgName"]))
    minimum = html.escape(str(release["minimumMacOS"]))
    architecture = html.escape(str(release["architecture"]))
    signed = bool(release.get("signed")) and bool(release.get("notarized"))
    if language == "fr":
        lead = (
            f"CoreTend {version} est signé avec un identifiant Developer ID et notarisé par Apple. Il s’ouvre normalement ; les vérifications ci-dessous confirment la provenance."
            if signed else
            f"CoreTend {version} est sans signature Developer ID et non notarisé. Le premier blocage Gatekeeper est donc attendu, pas un crash."
        )
        hero = info_hero("support", language, "Diagnostic", "Résoudre sans affaiblir macOS.", lead, [f"Version {version}", f"macOS {minimum}+", architecture])
        if signed:
            steps = """<li><div><h3>Vérifier l’empreinte</h3><p>Comparez le SHA-256 du DMG avec <code>SHA256SUMS</code> publié à côté.</p></div><span class="scan-state">Provenance</span></li><li><div><h3>Vérifier la signature</h3><p><code>minisign -Vm SHA256SUMS -P …</code> avec la clé publiée, et <code>xcrun stapler validate</code> sur le DMG.</p></div><span class="scan-state">Signature</span></li><li><div><h3>Installer</h3><p>Ouvrez le .dmg, glissez CoreTend dans Applications, double-cliquez. Aucune exception Gatekeeper n’est nécessaire.</p></div><span class="scan-state">Direct</span></li>"""
            devid, notarised = "oui (NSCUV5G738)", "oui"
            faq_open = "<p>Une version notarisée s’ouvre normalement. Si ce n’est pas le cas, re-téléchargez et re-vérifiez le SHA-256 : un téléchargement corrompu, pas Gatekeeper, est la cause la plus probable.</p>"
        else:
            steps = """<li><div><h3>Vérifier le téléchargement</h3><p>Comparez l’empreinte SHA-256 avec le fichier publié à côté du DMG.</p></div><span class="scan-state">Provenance</span></li><li><div><h3>Ouvrir une première fois</h3><p>Copiez CoreTend dans Applications et double-cliquez. Le blocage initial fait apparaître l’option système suivante.</p></div><span class="scan-state">Attendu</span></li><li><div><h3>Autoriser cette copie</h3><p>Réglages Système → Confidentialité et sécurité → Ouvrir quand même. Ne désactivez jamais Gatekeeper globalement.</p></div><span class="scan-state">Une fois</span></li>"""
            devid, notarised = "non", "non"
            faq_open = "<p>Vérifiez l’empreinte, lancez une première fois, puis utilisez Ouvrir quand même dans Confidentialité et sécurité. Le rejet attendu d’une version non notarisée ne doit pas être confondu avec un crash.</p>"
        return hero + f"""<section class="info-section"><div class="wrap"><div class="section-head"><p class="section-index">01 / Parcours</p><div><h2>Trois vérifications avant de signaler un problème.</h2><p class="section-intro">Chaque étape conserve les protections de macOS.</p></div></div><ol class="scan-list">{steps}</ol></div></section>
<section class="info-section"><div class="wrap"><div class="section-head"><p class="section-index">02 / Informations</p><div><h2>Un bloc technique prêt à joindre.</h2><p class="section-intro">Il ne contient aucun chemin personnel ni donnée d’analyse.</p></div></div><div class="support-tools"><div><pre class="tech-block" id="support-details">CoreTend {version}
{dmg_name}
macOS minimum: {minimum}
architecture: {architecture}
Developer ID: {devid}
notarisation: {notarised}
SHA-256: {checksum}</pre><button class="copy-button" type="button" data-copy-target="support-details">Copier les informations techniques</button></div><ul class="link-stack"><li><a href="{REPOSITORY}/issues">Suivi public des problèmes</a></li><li><a href="{REPOSITORY}/security/advisories/new">Signalement privé de vulnérabilité</a></li><li><a href="{REPOSITORY}/blob/main/Documentation/README.md">Documentation</a></li></ul></div>
<div class="faq"><details><summary>L’application ne s’ouvre pas après le téléchargement</summary>{faq_open}</details><details><summary>Une analyse ne voit pas certains dossiers</summary><p>Vérifiez les exclusions et l’Accès complet au disque. N’accordez que l’autorisation requise pour le workflow utilisé.</p></details><details><summary>Que joindre à un rapport ?</summary><p>La version, macOS, l’architecture, le module concerné et des étapes reproductibles. Supprimez les noms de fichiers personnels de toute capture.</p></details></div></div></section>"""
    lead = (
        f"CoreTend {version} is Developer ID signed and notarized by Apple. It opens normally; the checks below confirm provenance."
        if signed else
        f"CoreTend {version} has no Developer ID signature and is not notarized. The first Gatekeeper block is expected, not an application crash."
    )
    hero = info_hero("support", language, "Diagnostics", "Resolve issues without weakening macOS.", lead, [f"Version {version}", f"macOS {minimum}+", architecture])
    if signed:
        steps = """<li><div><h3>Check the digest</h3><p>Compare the DMG's SHA-256 with the published <code>SHA256SUMS</code> beside it.</p></div><span class="scan-state">Provenance</span></li><li><div><h3>Check the signature</h3><p><code>minisign -Vm SHA256SUMS -P …</code> with the published key, and <code>xcrun stapler validate</code> on the DMG.</p></div><span class="scan-state">Signature</span></li><li><div><h3>Install</h3><p>Open the .dmg, drag CoreTend to Applications, double-click it. No Gatekeeper exception is needed.</p></div><span class="scan-state">Direct</span></li>"""
        devid, notarised = "yes (NSCUV5G738)", "yes"
        faq_open = "<p>A notarized build opens normally. If it does not, re-download and re-check the SHA-256; a corrupted download, not Gatekeeper, is the likely cause.</p>"
    else:
        steps = """<li><div><h3>Verify the download</h3><p>Compare its SHA-256 with the checksum file published beside the DMG.</p></div><span class="scan-state">Provenance</span></li><li><div><h3>Open it once</h3><p>Copy CoreTend to Applications and double-click it. The initial block makes the next system option available.</p></div><span class="scan-state">Expected</span></li><li><div><h3>Allow this copy</h3><p>System Settings → Privacy &amp; Security → Open Anyway. Never disable Gatekeeper globally.</p></div><span class="scan-state">Once</span></li>"""
        devid, notarised = "no", "no"
        faq_open = "<p>Verify the checksum, try opening once, then use Open Anyway in Privacy &amp; Security. The expected rejection of an unnotarized build is not the same as a crash.</p>"
    return hero + f"""<section class="info-section"><div class="wrap"><div class="section-head"><p class="section-index">01 / Path</p><div><h2>Three checks before reporting a problem.</h2><p class="section-intro">Every step keeps macOS protections enabled.</p></div></div><ol class="scan-list">{steps}</ol></div></section>
<section class="info-section"><div class="wrap"><div class="section-head"><p class="section-index">02 / Details</p><div><h2>A technical block ready to attach.</h2><p class="section-intro">It contains no personal path or scan data.</p></div></div><div class="support-tools"><div><pre class="tech-block" id="support-details">CoreTend {version}
{dmg_name}
minimum macOS: {minimum}
architecture: {architecture}
Developer ID: {devid}
notarized: {notarised}
SHA-256: {checksum}</pre><button class="copy-button" type="button" data-copy-target="support-details">Copy technical information</button></div><ul class="link-stack"><li><a href="{REPOSITORY}/issues">Public issue tracker</a></li><li><a href="{REPOSITORY}/security/advisories/new">Private vulnerability report</a></li><li><a href="{REPOSITORY}/blob/main/Documentation/README.md">Documentation index</a></li></ul></div>
<div class="faq"><details><summary>The app does not open after download</summary>{faq_open}</details><details><summary>A scan cannot see some folders</summary><p>Review exclusions and Full Disk Access. Grant only the permission required by the workflow you are using.</p></details><details><summary>What should a report include?</summary><p>The version, macOS release, architecture, affected module and reproducible steps. Remove personal file names from every screenshot.</p></details></div></div></section>"""


def legal_content(release: dict, language: str) -> str:
    signed = bool(release.get("signed")) and bool(release.get("notarized"))
    _v = html.escape(str(release["version"]))
    distribution_fr = (
        f"La version {_v} est distribuée hors du Mac App Store. Elle est signée avec un identifiant Apple Developer ID et notarisée par Apple. Cette mention ne revendique aucune disponibilité sur le Mac App Store ni approbation éditoriale d’Apple."
        if signed else
        f"La version {_v} est distribuée hors du Mac App Store. Elle n’a pas de signature Developer ID et n’est pas notarisée. Cette mention ne revendique aucune certification ou approbation d’Apple."
    )
    distribution_en = (
        f"Version {_v} is distributed outside the Mac App Store. It is signed with an Apple Developer ID and notarized by Apple. This notice claims no Mac App Store availability and no editorial approval by Apple."
        if signed else
        f"Version {_v} is distributed outside the Mac App Store. It has no Developer ID signature and is not notarized. This notice makes no claim of Apple certification or approval."
    )
    if language == "fr":
        hero = info_hero("legal", language, "Document public", "Des limites lisibles, même sur papier.", "CoreTend est un logiciel libre distribué sans compte ni abonnement. Cette page décrit le projet public et son mode de distribution actuel.", ["Apache-2.0", "Hébergement Vercel", "Hors Mac App Store"])
        nav = [("project", "Projet"), ("distribution", "Distribution"), ("hosting", "Hébergement"), ("warranty", "Garanties")]
        sections = f"""<section id="project"><h2>Projet et source</h2><p>Projet : CoreTend. Le code public, l’historique et le suivi des problèmes sont disponibles sur <a href="{REPOSITORY}">{REPOSITORY}</a>. Le code est distribué sous licence Apache-2.0.</p></section><section id="distribution"><h2>Distribution actuelle</h2><p>{distribution_fr}</p></section><section id="hosting"><h2>Site et hébergement</h2><p>Le site public est hébergé par Vercel Inc. Les fichiers de publication sont servis par GitHub. Consultez la page Confidentialité pour la frontière réseau vérifiée.</p></section><section id="warranty"><h2>Garanties et responsabilité</h2><p>Les conditions complètes figurent dans la licence Apache-2.0 versionnée avec le dépôt. L’interface explique les résultats avant une action, mais l’utilisateur reste responsable de la sélection validée.</p></section>"""
    else:
        hero = info_hero("legal", language, "Public document", "Readable limits, including on paper.", "CoreTend is free software distributed without an account or subscription. This page records the public project and its current distribution model.", ["Apache-2.0", "Hosted by Vercel", "Outside the Mac App Store"])
        nav = [("project", "Project"), ("distribution", "Distribution"), ("hosting", "Hosting"), ("warranty", "Warranty")]
        sections = f"""<section id="project"><h2>Project and source</h2><p>Project: CoreTend. Public source, history and issue tracking are available at <a href="{REPOSITORY}">{REPOSITORY}</a>. The code is distributed under Apache-2.0.</p></section><section id="distribution"><h2>Current distribution</h2><p>{distribution_en}</p></section><section id="hosting"><h2>Website and hosting</h2><p>Vercel Inc. hosts the public website. GitHub serves release files. See Privacy for the verified network boundary.</p></section><section id="warranty"><h2>Warranty and responsibility</h2><p>The complete terms remain in the Apache-2.0 license versioned with the repository. The interface explains findings before an action, but the user remains responsible for an approved selection.</p></section>"""
    links = "".join(f'<li><a href="#{anchor}">{label}</a></li>' for anchor, label in nav)
    return hero + f"""<section class="info-section"><div class="wrap doc-layout"><nav class="doc-nav" aria-label="{'Navigation du document' if language == 'fr' else 'Document navigation'}"><p>{'Dans ce document' if language == 'fr' else 'In this document'}</p><ol>{links}</ol></nav><article class="legal-doc">{sections}</article></div></section>"""


def licenses_content(release: dict, language: str) -> str:
    if language == "fr":
        hero = info_hero("licenses", language, "Inventaire", "Chaque attribution reliée à sa source.", "L’application exécutable ne livre aucune bibliothèque tierce. Le site auto-héberge deux familles de caractères sous OFL-1.1.", ["Code Apache-2.0", "2 polices OFL-1.1", "Aucun moteur antivirus"])
        label, placeholder, result = "Filtrer l’inventaire", "Nom, licence ou usage", "3 licences"
        entries = [
            ("CoreTend", "Apache-2.0 · code produit", f"Le code source CoreTend est distribué sous Apache-2.0. Consultez <a href=\"{REPOSITORY}/blob/main/LICENSE\">LICENSE</a>, <a href=\"{REPOSITORY}/blob/main/NOTICE\">NOTICE</a> et <a href=\"{REPOSITORY}/blob/main/THIRD_PARTY_NOTICES.md\">THIRD_PARTY_NOTICES.md</a>."),
            ("Archivo", "SIL Open Font License 1.1 · site", "Archivo est auto-hébergée par le site. <a href=\"/assets/licenses/Archivo-OFL.txt\">Lire la licence incluse</a>. Source : <a href=\"https://github.com/Omnibus-Type/Archivo\">Omnibus-Type/Archivo</a>."),
            ("IBM Plex Mono", "SIL Open Font License 1.1 · site", "IBM Plex Mono est auto-hébergée par le site. <a href=\"/assets/licenses/IBM-Plex-OFL.txt\">Lire la licence incluse</a>. Source : <a href=\"https://github.com/IBM/plex\">IBM/plex</a>."),
        ]
        build_note = "Swift Testing est une dépendance de test et dmgbuild un outil de packaging. Aucun des deux n’est embarqué dans CoreTend.app."
    else:
        hero = info_hero("licenses", language, "Inventory", "Every attribution linked to its source.", "The executable application ships no third-party runtime library. The website self-hosts two font families under OFL-1.1.", ["Apache-2.0 code", "2 OFL-1.1 fonts", "No antivirus engine"])
        label, placeholder, result = "Filter inventory", "Name, license or use", "3 license entries"
        entries = [
            ("CoreTend", "Apache-2.0 · product code", f"CoreTend source is distributed under Apache-2.0. Read <a href=\"{REPOSITORY}/blob/main/LICENSE\">LICENSE</a>, <a href=\"{REPOSITORY}/blob/main/NOTICE\">NOTICE</a> and <a href=\"{REPOSITORY}/blob/main/THIRD_PARTY_NOTICES.md\">THIRD_PARTY_NOTICES.md</a>."),
            ("Archivo", "SIL Open Font License 1.1 · website", "Archivo is self-hosted by the website. <a href=\"/assets/licenses/Archivo-OFL.txt\">Read the bundled license</a>. Source: <a href=\"https://github.com/Omnibus-Type/Archivo\">Omnibus-Type/Archivo</a>."),
            ("IBM Plex Mono", "SIL Open Font License 1.1 · website", "IBM Plex Mono is self-hosted by the website. <a href=\"/assets/licenses/IBM-Plex-OFL.txt\">Read the bundled license</a>. Source: <a href=\"https://github.com/IBM/plex\">IBM/plex</a>."),
        ]
        build_note = "Swift Testing is a test dependency and dmgbuild is packaging tooling. Neither is embedded in CoreTend.app."
    items = "".join(f"""<details class="license-item" data-license><summary><span class="license-name"><strong>{name}</strong><span>{meta}</span></span></summary><div class="license-body"><p>{body}</p></div></details>""" for name, meta, body in entries)
    return hero + f"""<section class="info-section"><div class="wrap"><div class="section-head"><p class="section-index">01 / {'Registre' if language == 'fr' else 'Register'}</p><div><h2>{'Inventaire public vérifiable.' if language == 'fr' else 'A verifiable public inventory.'}</h2><p class="section-intro">{build_note}</p></div></div><div class="license-toolbar"><label class="field-label" for="license-filter">{label}<input id="license-filter" type="search" placeholder="{placeholder}" autocomplete="off"></label><p id="license-result" role="status">{result}</p></div><div class="license-list">{items}</div></div></section>"""


def information_pages(release: dict) -> dict[str, str]:
    pages: dict[str, str] = {}
    definitions = {
        "privacy": {
            "en": ("Privacy — CoreTend", "Verified local processing and network boundaries for CoreTend.", privacy_content),
            "fr": ("Confidentialité — CoreTend", "Limites vérifiées du traitement local et du réseau de CoreTend.", privacy_content),
        },
        "support": {
            "en": ("Support — CoreTend", "Installation, diagnostics, verification and security support for CoreTend.", support_content),
            "fr": ("Assistance — CoreTend", "Installation, diagnostic, vérification et assistance de sécurité pour CoreTend.", support_content),
        },
        "legal": {
            "en": ("Legal notice — CoreTend", "Public project, distribution and hosting notice for CoreTend.", legal_content),
            "fr": ("Mentions légales — CoreTend", "Informations publiques sur le projet, la distribution et l’hébergement de CoreTend.", legal_content),
        },
        "licenses": {
            "en": ("Licenses — CoreTend", "Exact CoreTend code and website attribution inventory.", licenses_content),
            "fr": ("Licences — CoreTend", "Inventaire exact des licences du code et du site CoreTend.", licenses_content),
        },
    }
    for page, locales in definitions.items():
        for language, (title, description, renderer) in locales.items():
            canonical = route_for(page, language)
            filename = f"fr-{page}.html" if language == "fr" else f"{page}.html"
            pages[filename] = shell(
                release,
                page,
                language,
                title,
                description,
                canonical,
                renderer(release, language),
            )
    return pages


def not_found_page(release: dict) -> str:
    content = info_hero(
        "404",
        "en",
        "Route scan",
        "This route is outside the map.<br>Cette route est hors carte.",
        "The radar found no public destination at this address. Le radar ne trouve aucune destination publique à cette adresse.",
        ["HTTP 404", "EN + FR", "No redirect"],
    )
    content = content.replace(
        '<section class="info-hero">',
        '<section class="not-found"><div class="wrap"><div class="info-copy"><div class="radar-search" aria-hidden="true"></div>',
        1,
    )
    # info_hero carries its own two-column wrapper; use a purpose-built compact
    # body for the error route so the footer still meets short viewports.
    content = f"""<section class="not-found"><div class="wrap"><div class="radar-search" aria-hidden="true"></div><p class="eyebrow"><b>404</b> Route scan</p><h1>This route is outside the map.<br>Cette route est hors carte.</h1><p class="lead">The requested address does not exist. L’adresse demandée n’existe pas.</p><div class="action-row"><a class="primary-action" href="/en">Return home · Retour à l’accueil</a><a class="secondary-action" href="/support">Support</a></div></div></section>"""
    page = shell(
        release,
        "404",
        "en",
        "404 — CoreTend",
        "The requested CoreTend route does not exist.",
        "/404",
        content,
        robots="noindex, follow",
    )
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


def write_favicon(stage: Path) -> None:
    # Keep the conventional root URL available for browsers, bookmarks and
    # crawlers that request it directly instead of following the document's
    # versioned asset link. The bytes remain owned by the canonical brand
    # asset, so the two URLs cannot drift.
    (stage / "favicon.svg").write_bytes(
        (SITE_ROOT / "assets" / "brand" / "favicon.svg").read_bytes()
    )
    entries = []
    for size in (16, 32):
        png = (SITE_ROOT / "assets" / "brand" / f"favicon-v2-{size}.png").read_bytes()
        entries.append((size, png))
    offset = 6 + 16 * len(entries)
    directory = [struct.pack("<HHH", 0, 1, len(entries))]
    payload = []
    for size, png in entries:
        directory.append(
            struct.pack("<BBBBHHII", size, size, 0, 0, 1, 32, len(png), offset)
        )
        payload.append(png)
        offset += len(png)
    (stage / "favicon.ico").write_bytes(b"".join(directory + payload))


def write_documents(stage: Path, release: dict) -> None:
    sitemap_paths = (
        "/",
        "/en",
        "/fr",
        "/privacy",
        "/support",
        "/legal",
        "/licenses",
        "/fr/privacy",
        "/fr/support",
        "/fr/legal",
        "/fr/licenses",
    )
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
    (stage / "llms.txt").write_text(
        "\n".join(
            (
                "# CoreTend",
                "",
                "> Local, transparent and reversible macOS care. CoreTend reviews "
                "supported on-device locations and explains every finding before an "
                "approved action moves anything to the Trash. No account, no telemetry; "
                "the only network request is a user-initiated update check.",
                "",
                f"- Version: {release['version']} ("
                + ("Developer ID signed and Apple-notarized" if release.get("signed") and release.get("notarized") else "unsigned, not notarized")
                + f"), macOS {release['minimumMacOS']}+, {release['architecture']}",
                "- License: Apache-2.0 (source code)",
                "",
                "## Pages",
                "",
                f"- [Home]({ORIGIN}/): what CoreTend does, module overview, install",
                f"- [Privacy]({ORIGIN}/privacy): verified local-processing and network boundary",
                f"- [Support]({ORIGIN}/support): install, diagnostics, verification",
                f"- [Legal]({ORIGIN}/legal): public-project, distribution and hosting notice",
                f"- [Licenses]({ORIGIN}/licenses): code and website attribution inventory",
                "",
                "## Source",
                "",
                f"- [Repository]({REPOSITORY}) (public, Apache-2.0)",
                f"- [Releases]({REPOSITORY}/releases): signed DMG, SHA256SUMS, Minisign signatures",
                "",
            )
        ),
        encoding="utf-8",
    )
    manifest = {
        "name": "CoreTend",
        "short_name": "CoreTend",
        "id": "/",
        "start_url": "/",
        "display": "browser",
        "background_color": "#f6f4ef",
        "theme_color": "#f6f4ef",
        "icons": [
            {
                "src": "/assets/brand/favicon-v2-192.png",
                "sizes": "192x192",
                "type": "image/png",
                "purpose": "any",
            },
            {
                "src": "/assets/brand/favicon-v2-512.png",
                "sizes": "512x512",
                "type": "image/png",
                "purpose": "any",
            },
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

        root_page = build_landing(template, "en", "/", stage, release)
        en_page = build_landing(template, "en", "/en", stage, release)
        fr_page = build_landing(template, "fr", "/fr", stage, release)
        (stage / "index.html").write_text(root_page, encoding="utf-8")
        (stage / "en").mkdir()
        (stage / "fr").mkdir()
        (stage / "en" / "index.html").write_text(en_page, encoding="utf-8")
        (stage / "fr" / "index.html").write_text(fr_page, encoding="utf-8")
        # Keep the public clean locale routes at HTTP 200 without exposing the
        # internal `.html` route files.
        (stage / "en-route.html").write_text(en_page, encoding="utf-8")
        (stage / "fr-route.html").write_text(fr_page, encoding="utf-8")
        # Do not leave physical locale directories in the deploy tree: Vercel
        # canonicalizes locale directories before a rewrite can run when such
        # a directory exists. The route files above are the sole public targets.
        shutil.rmtree(stage / "en")
        shutil.rmtree(stage / "fr")

        for name, page in information_pages(release).items():
            (stage / name).write_text(page, encoding="utf-8")
        (stage / "404.html").write_text(not_found_page(release), encoding="utf-8")
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
