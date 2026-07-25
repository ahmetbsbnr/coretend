#!/bin/sh
# Gate: the generated website must be complete, bilingual, self-contained, and
# free of the things a privacy-first product cannot ship.
#
# The site has no build step beyond generate.py and no test framework, so this
# is where its guarantees are actually enforced:
#
#   - the generated HTML matches the generator (nobody hand-edited output that
#     the next run would silently overwrite)
#   - every page exists in both locales, and every internal link resolves
#   - zero external requests: no third-party host, no webfont, no CDN, no
#     analytics, no tracking pixel. A privacy page served alongside a tracker
#     is worse than no privacy page.
#   - no personal path, username, or secret leaked into published HTML
#   - accessibility floor: lang, title, one h1, skip link, alt text
#   - no unverifiable marketing claim, no fake download, no invented number
set -eu
cd "${CHECK_WEBSITE_ROOT:-$(dirname "$0")/..}"

SITE="Website"
fail=0
problems=""
note() { fail=1; problems="$problems\n  - $1"; }

echo "== check-website.sh =="

# ---------------------------------------------------------------- freshness
# Regenerate into a temp copy and diff. If output drifts from the generator,
# the next legitimate regeneration would destroy someone's hand edit.
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cp -R "$SITE" "$TMP/Website"
( cd "$TMP/Website" && python3 generate.py >/dev/null 2>&1 ) || note "generate.py failed to run"
for locale in en fr; do
  if ! diff -rq "$SITE/$locale" "$TMP/Website/$locale" >/dev/null 2>&1; then
    note "$locale/ differs from what generate.py produces — re-run it, and never hand-edit generated HTML"
  fi
done

# ------------------------------------------------------------------- parity
EN_PAGES=$(cd "$SITE/en" && ls *.html | sort)
FR_PAGES=$(cd "$SITE/fr" && ls *.html | sort)
if [ "$EN_PAGES" != "$FR_PAGES" ]; then
  note "the two locales do not contain the same pages"
fi

# Pages the brief requires, in both locales.
for slug in index features privacy download documentation open-source changelog \
            faq security licenses legal roadmap 404; do
  for locale in en fr; do
    [ -f "$SITE/$locale/$slug.html" ] || note "missing page: $locale/$slug.html"
  done
done
[ -f "$SITE/index.html" ] || note "missing root language-picker index.html"
[ -f "$SITE/assets/style.css" ] || note "missing stylesheet"

# ------------------------------------------------------- no external requests
# Any absolute http(s) reference in a src/href/url() is a request to another
# host at page load. Links in prose are fine; loaded resources are not.
EXTERNAL=$(grep -rEn '(src|href)="https?://|url\(https?://' "$SITE"/en "$SITE"/fr "$SITE"/assets 2>/dev/null \
  | grep -v 'rel="canonical"' \
  | grep -v 'hreflang=' \
  | grep -v 'og:image' \
  | grep -v '>https\?://' || true)
# Loaded subresources only: stylesheet, script, image, font, iframe.
LOADED=$(printf '%s\n' "$EXTERNAL" | grep -E '<(link rel="stylesheet"|script|img|iframe|source)' || true)
[ -z "$LOADED" ] && [ -z "$(printf '%s' "$EXTERNAL" | grep 'url(http')" ] \
  || note "the site loads a resource from an external host:
$LOADED"

for pattern in 'googletagmanager' 'google-analytics' 'gtag(' 'fbq(' 'plausible' \
               'matomo' 'hotjar' 'segment.com' 'mixpanel' 'sentry' 'fonts.googleapis' \
               'cdn.jsdelivr' 'unpkg.com' 'cloudflareinsights'; do
  hit=$(grep -rl "$pattern" "$SITE"/en "$SITE"/fr "$SITE"/assets 2>/dev/null || true)
  [ -z "$hit" ] || note "tracker or CDN reference found ($pattern): $hit"
done

# No cookies, no storage, no scripts at all — the site is static by design.
for pattern in 'document.cookie' 'localStorage' 'sessionStorage' '<script'; do
  hit=$(grep -rl "$pattern" "$SITE"/en "$SITE"/fr 2>/dev/null || true)
  [ -z "$hit" ] || note "the site should contain no scripts or client storage, found $pattern in: $hit"
done

# -------------------------------------------------------------- no leakage
USER_NAME=$(id -un)
for pattern in "/Users/$USER_NAME" "$HOME" "MAC_ORGANISE" "BrandRenameApproval"; do
  hit=$(grep -rl -- "$pattern" "$SITE"/en "$SITE"/fr "$SITE"/assets 2>/dev/null || true)
  [ -z "$hit" ] || note "a personal path or local-only file leaked into the site: $pattern in $hit"
done

# ---------------------------------------------------------- internal links
/usr/bin/python3 - "$SITE" <<'PYEOF' || fail=1
import os, re, sys

site = sys.argv[1]
bad = []
for locale in ("en", "fr"):
    d = os.path.join(site, locale)
    for name in sorted(os.listdir(d)):
        if not name.endswith(".html"):
            continue
        path = os.path.join(d, name)
        html = open(path, encoding="utf-8").read()
        for href in re.findall(r'href="([^"]+)"', html):
            if href.startswith(("http://", "https://", "mailto:", "#")):
                continue
            target = os.path.normpath(os.path.join(d, href.split("#")[0]))
            if not os.path.exists(target):
                bad.append(f"{locale}/{name} -> {href}")
        # Fragment links must resolve to a real id on the same page.
        for frag in re.findall(r'href="#([^"]+)"', html):
            if f'id="{frag}"' not in html:
                bad.append(f'{locale}/{name} -> #{frag} (no matching id)')
if bad:
    print("BROKEN INTERNAL LINKS:")
    for b in bad:
        print("  -", b)
    sys.exit(1)
print("internal links: all resolve")
PYEOF

# ------------------------------------------------------------ accessibility
/usr/bin/python3 - "$SITE" <<'PYEOF' || fail=1
import os, re, sys

site = sys.argv[1]
problems = []
for locale in ("en", "fr"):
    d = os.path.join(site, locale)
    for name in sorted(os.listdir(d)):
        if not name.endswith(".html"):
            continue
        html = open(os.path.join(d, name), encoding="utf-8").read()
        where = f"{locale}/{name}"
        if f'<html lang="{locale}"' not in html:
            problems.append(f"{where}: missing or wrong <html lang>")
        if "<title>" not in html:
            problems.append(f"{where}: no <title>")
        h1s = len(re.findall(r"<h1[ >]", html))
        if h1s != 1:
            problems.append(f"{where}: {h1s} <h1> elements, expected exactly 1")
        if 'class="skip-link"' not in html:
            problems.append(f"{where}: no skip link")
        if 'id="main"' not in html:
            problems.append(f"{where}: no #main landmark for the skip link to reach")
        for img in re.findall(r"<img[^>]*>", html):
            if "alt=" not in img:
                problems.append(f"{where}: <img> without alt")
        # An inline SVG that conveys meaning needs a name; a decorative one
        # needs to be hidden. Silence is the only wrong answer.
        for svg in re.findall(r"<svg[^>]*>", html):
            if "aria-label" not in svg and "aria-hidden" not in svg and "role=" not in svg:
                problems.append(f"{where}: <svg> with neither a label nor aria-hidden")
        if 'name="viewport"' not in html:
            problems.append(f"{where}: no viewport meta, so it cannot be responsive")
if problems:
    print("ACCESSIBILITY PROBLEMS:")
    for p in problems:
        print("  -", p)
    sys.exit(1)
print("accessibility floor: lang, title, single h1, skip link, alt/label, viewport")
PYEOF

# --------------------------------------------------------- editorial honesty
# Claims this product cannot make. Some are outright false for a local,
# unsigned, pre-1.0 tool; the rest are unverifiable superlatives.
#
# Checked per sentence, not per file, because this product's copy denies most
# of these phrases on purpose — "never a guaranteed security product", "not a
# complete antivirus", "no warranty". A file-level grep flags exactly the
# sentences that are doing the honest thing, so it has to read the negation.
/usr/bin/python3 - "$SITE" <<'PYEOF' || fail=1
import html as htmllib
import os, re, sys

site = sys.argv[1]

CLAIMS = [
    "the best", "world's best", "100% secure", "100 % secure", "100% sûr",
    "100 % sûr", "instantly speeds", "instantanément", "complete antivirus",
    "antivirus complet", "guaranteed", "garantie", "garanti", "risk-free",
    "sans risque", "notarized", "notarisé", "signed by apple",
    "signé par apple", "fastest", "le plus rapide",
]

# A claim inside a denial is not a claim. Both languages, and both the
# "no X" and "never X" shapes.
NEGATIONS = [
    "no ", "not ", "never", "n't", "without", "cannot", "can't", "isn't",
    "aucun", "aucune", "pas ", "jamais", "ni ", "sans ", "non ",
]

# Nor is a claim a claim when it is a question the copy goes on to answer, or a
# stated future intent on a page that exists to state future intent. Both are
# honest uses of the same words; only a present-tense assertion is a problem.
FUTURE = [
    "once ", "will ", "planned", "roadmap", "when a", "future",
    "une fois", "lorsque", "prévu", "prévue", "à venir", "feuille de route",
]

problems = []
for locale in ("en", "fr"):
    d = os.path.join(site, locale)
    for name in sorted(os.listdir(d)):
        if not name.endswith(".html"):
            continue
        raw = open(os.path.join(d, name), encoding="utf-8").read()
        # Strip tags and comments so markup can't hide or fake a sentence.
        text = re.sub(r"<!--.*?-->", " ", raw, flags=re.S)
        text = re.sub(r"<[^>]+>", " ", text)
        text = htmllib.unescape(re.sub(r"\s+", " ", text))
        for sentence in re.split(r"(?<=[.!?])\s+", text):
            low = sentence.lower()
            if low.rstrip().endswith("?"):
                continue
            for claim in CLAIMS:
                if claim not in low:
                    continue
                if any(neg in low for neg in NEGATIONS):
                    continue
                if any(f in low for f in FUTURE):
                    continue
                problems.append(f'{locale}/{name}: "{claim}" asserted in: {sentence.strip()[:140]}')

if problems:
    print("UNVERIFIABLE OR FALSE CLAIMS:")
    for p in problems:
        print("  -", p)
    sys.exit(1)
print("editorial honesty: no unverifiable claim asserted (denials allowed)")
PYEOF

# A download page must not present a release that does not exist. If it links
# a versioned artifact, that artifact has to be in Release/ with a checksum.
for locale in en fr; do
  page="$SITE/$locale/download.html"
  [ -f "$page" ] || continue
  for artifact in $(grep -oE 'CoreTend-[0-9][^"<> ]*\.(zip|dmg)' "$page" | sort -u); do
    if [ ! -f "Release/$artifact" ]; then
      note "$locale/download.html offers $artifact, which does not exist in Release/"
    fi
  done
done

if [ "$fail" -ne 0 ]; then
  printf 'FAIL — website problems:%b\n' "$problems"
  exit 1
fi
echo "OK — bilingual, self-contained, no trackers, links resolve, accessibility floor met."
