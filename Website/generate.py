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
import os

ROOT = os.path.dirname(os.path.abspath(__file__))

NAV = [
    ("index", {"en": "Home", "fr": "Accueil"}),
    ("features", {"en": "Features", "fr": "Fonctionnalités"}),
    ("download", {"en": "Download", "fr": "Télécharger"}),
    ("documentation", {"en": "Documentation", "fr": "Documentation"}),
    ("open-source", {"en": "Open Source", "fr": "Open Source"}),
    ("roadmap", {"en": "Roadmap", "fr": "Feuille de route"}),
    ("faq", {"en": "FAQ", "fr": "FAQ"}),
]

FOOTER_LINKS = [
    ("privacy", {"en": "Privacy", "fr": "Confidentialité"}),
    ("security", {"en": "Security", "fr": "Sécurité"}),
    ("changelog", {"en": "Changelog", "fr": "Journal des modifications"}),
    ("licenses", {"en": "Licenses", "fr": "Licences"}),
    ("legal", {"en": "Legal notice", "fr": "Mentions légales"}),
]

SITE_TITLE = "CoreTend"

TAGLINE = {
    "en": "A local-only, open source utility to scan, clean, organize and "
          "optimize Apple Silicon Macs.",
    "fr": "Un utilitaire open source, entièrement local, pour analyser, "
          "nettoyer, organiser et optimiser les Mac Apple Silicon.",
}


def page_shell(locale, slug, title, body_html, other_locale_slug=None):
    other = "fr" if locale == "en" else "en"
    other_slug = other_locale_slug or slug
    nav_items = "\n".join(
        f'<a href="{n}.html" class="{"active" if n == slug else ""}">{label[locale]}</a>'
        for n, label in NAV
    )
    footer_items = "\n".join(
        f'<a href="{n}.html">{label[locale]}</a>' for n, label in FOOTER_LINKS
    )
    lang_switch = (
        f'<div class="lang-switch">'
        f'<a href="../en/{other_slug if locale == "fr" else slug}.html" class="{"active" if locale == "en" else ""}">EN</a>'
        f'<a href="../fr/{other_slug if locale == "en" else slug}.html" class="{"active" if locale == "fr" else ""}">FR</a>'
        f'</div>'
    )
    return f"""<!doctype html>
<html lang="{locale}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} — {SITE_TITLE}</title>
<meta name="description" content="{TAGLINE[locale]}">
<meta name="robots" content="noindex">
<link rel="stylesheet" href="../assets/style.css">
</head>
<body>
<header class="site">
  <div class="wrap">
    <a class="brand" href="index.html"><span class="mark"></span>{SITE_TITLE}</a>
    <nav class="primary">{nav_items}</nav>
    {lang_switch}
  </div>
</header>
<main>
  <div class="wrap">
{body_html}
  </div>
</main>
<footer class="site">
  <div class="wrap">
    <span>&copy; CoreTend contributors. Open source — see LICENSE.</span>
    <nav>{footer_items}</nav>
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
def home_body(l):
    if l == "en":
        return f"""
<section class="hero">
  <h1>{SITE_TITLE}</h1>
  <p class="lead">{TAGLINE['en']}</p>
  <div class="badge-row">
    <span class="badge">Local-only, no account</span>
    <span class="badge violet">Open source</span>
    <span class="badge amber">No telemetry</span>
    <span class="badge">Apple Silicon</span>
  </div>
  <div class="warning-banner">
    <strong>Pre-1.0 status.</strong> CoreTend is under active development
    and has not reached a stable 1.0 release. Expect rough edges. See the
    <a href="roadmap.html">roadmap</a> and <a href="download.html">download page</a>
    for current status.
  </div>
</section>

{screenshot_placeholder("Screenshot placeholder — pending real capture. This box must never ship in a production build; see Website/README.md.")}

<section class="cards">
  <div class="card">
    <h3>Entirely local</h3>
    <p>Everything runs on your Mac. No account, no subscription, no cloud
    processing, no telemetry sent anywhere.</p>
  </div>
  <div class="card">
    <h3>Explained before acting</h3>
    <p>Every detected item is explained before any action is taken — you
    decide what happens, module by module.</p>
  </div>
  <div class="card">
    <h3>Reversible by default</h3>
    <p>Deletions go to the Trash by default, not straight to disk removal,
    so mistakes stay recoverable.</p>
  </div>
  <div class="card">
    <h3>Open source</h3>
    <p>The full source is public. Read it, audit it, build it yourself —
    see the <a href="open-source.html">Open Source</a> page.</p>
  </div>
</section>
"""
    return f"""
<section class="hero">
  <h1>{SITE_TITLE}</h1>
  <p class="lead">{TAGLINE['fr']}</p>
  <div class="badge-row">
    <span class="badge">100% local, sans compte</span>
    <span class="badge violet">Open source</span>
    <span class="badge amber">Sans télémétrie</span>
    <span class="badge">Apple Silicon</span>
  </div>
  <div class="warning-banner">
    <strong>Statut pré-1.0.</strong> CoreTend est en développement actif
    et n'a pas encore atteint une version stable 1.0. Attendez-vous à des
    aspérités. Voir la <a href="roadmap.html">feuille de route</a> et la
    page <a href="download.html">Télécharger</a> pour le statut actuel.
  </div>
</section>

{screenshot_placeholder("Capture d'écran à venir — en attente d'une capture réelle. Cette zone ne doit jamais être présente dans une version de production ; voir Website/README.md.")}

<section class="cards">
  <div class="card">
    <h3>Entièrement local</h3>
    <p>Tout s'exécute sur votre Mac. Aucun compte, aucun abonnement, aucun
    traitement dans le cloud, aucune télémétrie envoyée où que ce soit.</p>
  </div>
  <div class="card">
    <h3>Expliqué avant d'agir</h3>
    <p>Chaque élément détecté est expliqué avant toute action — vous
    décidez, module par module.</p>
  </div>
  <div class="card">
    <h3>Réversible par défaut</h3>
    <p>Les suppressions utilisent la Corbeille par défaut, jamais un effacement
    direct, pour rester réversibles en cas d'erreur.</p>
  </div>
  <div class="card">
    <h3>Open source</h3>
    <p>Le code source complet est public. Lisez-le, auditez-le, compilez-le
    vous-même — voir la page <a href="open-source.html">Open Source</a>.</p>
  </div>
</section>
"""


add("index", {"en": "Home", "fr": "Accueil"}, home_body)


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

<div id="release-status" class="status-box" aria-live="polite"></div>
<script>
// Renders release state from a latest.json-shaped object. Today this is a
// local stub (no public manifest exists yet); once a real release ships,
// point MANIFEST_URL at the published Release/latest.json and this same
// renderer handles every state below without further changes.
const MANIFEST_URL = null; // e.g. "https://github.com/<org>/<repo>/releases/latest/download/latest.json"
const STUB_MANIFEST = null; // in-preparation: no manifest at all yet

function renderReleaseStatus(manifest) {
  const el = document.getElementById("release-status");
  if (!el) return;
  if (!manifest) {
    el.innerHTML = "<p><strong>No release manifest published yet.</strong> Nothing to download or verify until one exists.</p>";
    return;
  }
  const rows = [];
  rows.push(["Version", manifest.version || "unknown"]);
  rows.push(["Channel", manifest.prerelease ? "prerelease" : (manifest.channel || "unknown")]);
  rows.push(["Architecture", manifest.architecture || "unknown"]);
  rows.push(["Minimum macOS", manifest.minimumMacOS || "unknown"]);
  rows.push(["Code signing", manifest.signed ? "signed" : "unsigned"]);
  rows.push(["Notarization", manifest.notarized ? "notarized" : "not notarized"]);
  rows.push(["Checksum (SHA-256)", manifest.zipSHA256 || "unavailable"]);
  const fileAvailable = !!manifest.zipName;
  let html = "<table>" + rows.map(r => `<tr><th>${r[0]}</th><td>${r[1]}</td></tr>`).join("") + "</table>";
  html += fileAvailable
    ? "<p>Download link will appear here once a public release exists.</p>"
    : "<p><strong>File unavailable.</strong> The manifest exists but no downloadable artifact is attached yet.</p>";
  el.innerHTML = html;
}

if (MANIFEST_URL) {
  fetch(MANIFEST_URL).then(r => r.ok ? r.json() : null).then(renderReleaseStatus).catch(() => renderReleaseStatus(null));
} else {
  renderReleaseStatus(STUB_MANIFEST);
}
</script>

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

<div id="release-status" class="status-box" aria-live="polite"></div>
<script>
// Affiche l'état de publication à partir d'un objet au format latest.json.
// Pour l'instant c'est un stub local (aucun manifeste public n'existe
// encore) ; une fois une vraie version publiée, il suffira de pointer
// MANIFEST_URL vers le Release/latest.json publié.
const MANIFEST_URL = null;
const STUB_MANIFEST = null;

function renderReleaseStatus(manifest) {
  const el = document.getElementById("release-status");
  if (!el) return;
  if (!manifest) {
    el.innerHTML = "<p><strong>Aucun manifeste de version publié pour l'instant.</strong> Rien à télécharger ni à vérifier tant qu'il n'existe pas.</p>";
    return;
  }
  const rows = [];
  rows.push(["Version", manifest.version || "inconnue"]);
  rows.push(["Canal", manifest.prerelease ? "prérelease" : (manifest.channel || "inconnu")]);
  rows.push(["Architecture", manifest.architecture || "inconnue"]);
  rows.push(["macOS minimum", manifest.minimumMacOS || "inconnu"]);
  rows.push(["Signature de code", manifest.signed ? "signé" : "non signé"]);
  rows.push(["Notarisation", manifest.notarized ? "notarisé" : "non notarisé"]);
  rows.push(["Empreinte (SHA-256)", manifest.zipSHA256 || "indisponible"]);
  const fileAvailable = !!manifest.zipName;
  let html = "<table>" + rows.map(r => `<tr><th>${r[0]}</th><td>${r[1]}</td></tr>`).join("") + "</table>";
  html += fileAvailable
    ? "<p>Le lien de téléchargement apparaîtra ici dès qu'une version publique existera.</p>"
    : "<p><strong>Fichier indisponible.</strong> Le manifeste existe mais aucun artefact téléchargeable n'y est encore attaché.</p>";
  el.innerHTML = html;
}

if (MANIFEST_URL) {
  fetch(MANIFEST_URL).then(r => r.ok ? r.json() : null).then(renderReleaseStatus).catch(() => renderReleaseStatus(null));
} else {
  renderReleaseStatus(STUB_MANIFEST);
}
</script>

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
    title = "Documentation" if l == "en" else "Documentation"
    intro = (
        "Full documentation lives in the repository's "
        "<code>Documentation/</code> folder. Links below point at the "
        "source files (readable directly on the source host once public)."
    ) if l == "en" else (
        "La documentation complète se trouve dans le dossier "
        "<code>Documentation/</code> du dépôt. Les liens ci-dessous pointent "
        "vers les fichiers source (lisibles directement sur l'hébergeur du "
        "code une fois public)."
    )
    items = "\n".join(
        f'<li><a href="[REPO_URL_TO_DEFINE]/blob/main/Documentation/{f}">{label}</a></li>'
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
<div class="warning-banner">
This page uses bracket placeholders (<span class="placeholder-token">[LEGAL_NAME_TO_DEFINE]</span>,
<span class="placeholder-token">[LEGAL_ADDRESS_TO_DEFINE]</span>) until a
real legal identity is defined. A production deployment must not ship while
these remain — see <code>Documentation/HUMAN_BLOCKERS.md</code>.
</div>
<h2>Site operator</h2>
<p>Publisher: <span class="placeholder-token">[LEGAL_NAME_TO_DEFINE]</span><br>
Contact: <span class="placeholder-token">[SECURITY_CONTACT_TO_DEFINE]</span></p>
"""
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
<div class="warning-banner">
Cette page utilise des espaces réservés entre crochets
(<span class="placeholder-token">[LEGAL_NAME_TO_DEFINE]</span>,
<span class="placeholder-token">[LEGAL_ADDRESS_TO_DEFINE]</span>) tant qu'une
identité légale réelle n'est pas définie. Un déploiement en production ne
doit pas avoir lieu tant qu'ils subsistent — voir
<code>Documentation/HUMAN_BLOCKERS.md</code>.
</div>
<h2>Éditeur du site</h2>
<p>Éditeur : <span class="placeholder-token">[LEGAL_NAME_TO_DEFINE]</span><br>
Contact : <span class="placeholder-token">[SECURITY_CONTACT_TO_DEFINE]</span></p>
"""


add("privacy", {"en": "Privacy", "fr": "Confidentialité"}, privacy_body)


# ------------------------------------------------------------ security ---
def security_body(l):
    if l == "en":
        return """
<h1>Security</h1>
<p>See <code>SECURITY.md</code> in the repository for the full
vulnerability disclosure policy and current contact
(<span class="placeholder-token">[SECURITY_CONTACT_TO_DEFINE]</span> until a
monitored channel is set up).</p>
<p>Planned HTTP security headers for this site once deployed (Content-Security-Policy,
Referrer-Policy, Permissions-Policy, X-Content-Type-Options) are documented
in <code>Documentation/WEBSITE_SECURITY.md</code>.</p>
"""
    return """
<h1>Sécurité</h1>
<p>Voir <code>SECURITY.md</code> dans le dépôt pour la politique complète de
divulgation des vulnérabilités et le contact actuel
(<span class="placeholder-token">[SECURITY_CONTACT_TO_DEFINE]</span> tant
qu'un canal surveillé n'est pas mis en place).</p>
<p>Les en-têtes de sécurité HTTP prévus pour ce site une fois déployé
(Content-Security-Policy, Referrer-Policy, Permissions-Policy,
X-Content-Type-Options) sont documentés dans
<code>Documentation/WEBSITE_SECURITY.md</code>.</p>
"""


add("security", {"en": "Security", "fr": "Sécurité"}, security_body)


# ------------------------------------------------------------- licenses ---
def licenses_body(l):
    title = "Licenses" if l == "en" else "Licences"
    note = (
        "See <code>LICENSE</code>, <code>LICENSES/</code>, "
        "<code>NOTICE</code> and <code>THIRD_PARTY_NOTICES.md</code> at the "
        "repository root for the project license and every third-party "
        "attribution."
    ) if l == "en" else (
        "Voir <code>LICENSE</code>, <code>LICENSES/</code>, "
        "<code>NOTICE</code> et <code>THIRD_PARTY_NOTICES.md</code> à la "
        "racine du dépôt pour la licence du projet et chaque attribution "
        "tierce."
    )
    return f"<h1>{title}</h1><p>{note}</p>"


add("licenses", {"en": "Licenses", "fr": "Licences"}, licenses_body)


# ---------------------------------------------------------------- legal ---
def legal_body(l):
    if l == "en":
        return """
<h1>Legal Notice</h1>
<div class="warning-banner">
Placeholders below (<span class="placeholder-token">[LEGAL_NAME_TO_DEFINE]</span>,
<span class="placeholder-token">[LEGAL_ADDRESS_TO_DEFINE]</span>,
<span class="placeholder-token">[DOMAIN_TO_DEFINE]</span>,
<span class="placeholder-token">[DOMAIN_TO_DEFINE]</span>) are tracked in
<code>Documentation/HUMAN_BLOCKERS.md</code>. No real personal or legal
information has been invented. A production deployment must not ship while
these remain unresolved.
</div>
<table>
<tr><td>Publisher</td><td><span class="placeholder-token">[LEGAL_NAME_TO_DEFINE]</span></td></tr>
<tr><td>Address</td><td><span class="placeholder-token">[LEGAL_ADDRESS_TO_DEFINE]</span></td></tr>
<tr><td>Contact</td><td><span class="placeholder-token">[SECURITY_CONTACT_TO_DEFINE]</span></td></tr>
<tr><td>Domain</td><td><span class="placeholder-token">[DOMAIN_TO_DEFINE]</span></td></tr>
<tr><td>Hosting</td><td><span class="placeholder-token">[DOMAIN_TO_DEFINE]</span></td></tr>
</table>
<p>CoreTend is not affiliated with Apple Inc. or MacPaw Inc.
(CleanMyMac). It makes no antivirus/security-guarantee claim.</p>
"""
    return """
<h1>Mentions légales</h1>
<div class="warning-banner">
Les espaces réservés ci-dessous
(<span class="placeholder-token">[LEGAL_NAME_TO_DEFINE]</span>,
<span class="placeholder-token">[LEGAL_ADDRESS_TO_DEFINE]</span>,
<span class="placeholder-token">[DOMAIN_TO_DEFINE]</span>,
<span class="placeholder-token">[DOMAIN_TO_DEFINE]</span>) sont suivis dans
<code>Documentation/HUMAN_BLOCKERS.md</code>. Aucune information personnelle
ou légale réelle n'a été inventée. Un déploiement en production ne doit pas
avoir lieu tant qu'ils ne sont pas résolus.
</div>
<table>
<tr><td>Éditeur</td><td><span class="placeholder-token">[LEGAL_NAME_TO_DEFINE]</span></td></tr>
<tr><td>Adresse</td><td><span class="placeholder-token">[LEGAL_ADDRESS_TO_DEFINE]</span></td></tr>
<tr><td>Contact</td><td><span class="placeholder-token">[SECURITY_CONTACT_TO_DEFINE]</span></td></tr>
<tr><td>Domaine</td><td><span class="placeholder-token">[DOMAIN_TO_DEFINE]</span></td></tr>
<tr><td>Hébergement</td><td><span class="placeholder-token">[DOMAIN_TO_DEFINE]</span></td></tr>
</table>
<p>CoreTend n'est affilié ni à Apple Inc. ni à MacPaw Inc.
(CleanMyMac). Aucune revendication d'antivirus ou de garantie de sécurité
n'est faite.</p>
"""


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
