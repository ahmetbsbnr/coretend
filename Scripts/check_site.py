#!/usr/bin/env python3
from html.parser import HTMLParser
import json
from pathlib import Path
import re
from xml.etree import ElementTree
from urllib.parse import urlparse
from site_accessibility_contract import reduced_motion_contract_errors
root = Path(__file__).resolve().parents[1] / 'Website'
class Page(HTMLParser):
    def __init__(self): super().__init__(); self.links=[]; self.scripts=0; self.lang=None; self.has_main=False; self.descriptions=[]; self.images=[]
    def handle_starttag(self, tag, attrs):
        data=dict(attrs)
        if tag=='a' and data.get('href'): self.links.append(data['href'])
        if tag=='script' and data.get('type')!='application/ld+json': self.scripts+=1
        if tag=='img':
            self.images.append(data.get('src') or '')
            if not (data.get('alt') or '').strip(): self.images.append('missing-alt')
        if tag=='source' and data.get('srcset'): self.images.extend(item.strip().split()[0] for item in data['srcset'].split(','))
        if tag=='html': self.lang=data.get('lang')
        if tag=='main': self.has_main=True
        if tag=='meta' and data.get('name')=='description': self.descriptions.append((data.get('content') or '').strip())
errors=[]
for file in sorted(root.rglob('*.html')):
    page=Page(); page.feed(file.read_text())
    if not page.lang: errors.append(f'{file}: missing lang')
    if not page.has_main: errors.append(f'{file}: missing main landmark')
    if len(page.descriptions)!=1 or not page.descriptions[0]: errors.append(f'{file}: needs exactly one non-empty meta description')
    if page.scripts: errors.append(f'{file}: scripts are forbidden in site preview')
    for image in page.images:
        parsed=urlparse(image)
        target=(file.parent / parsed.path).resolve()
        if parsed.scheme or not image or image == 'missing-alt': errors.append(f'{file}: image must be local and have meaningful alt: {image}')
        elif root not in target.parents or not target.is_file(): errors.append(f'{file}: missing or escaping image: {image}')
    for link in page.links:
        parsed=urlparse(link)
        # External links allowed: the project's own channels — GitHub (releases, source), its
        # Homebrew tap and its npm package page.
        allowed=('https://github.com/ahmetbsbnr/coretend', 'https://github.com/ahmetbsbnr/homebrew-coretend', 'https://www.npmjs.com/package/coretend')
        if parsed.scheme == 'javascript' or (parsed.scheme in ('http', 'https') and not link.startswith(allowed)):
            errors.append(f'{file}: external/script link {link}')
        if parsed.scheme or link.startswith('#'): continue
        if not parsed.path.startswith('/'):
            errors.append(f'{file}: internal links must be root-relative for Vercel clean URLs: {link}')
            continue
        target=(root / parsed.path.lstrip('/')).resolve()
        if not target.is_file():
            clean_url_target=target.with_suffix('.html')
            index_target=target/'index.html'
            if clean_url_target.is_file(): target=clean_url_target
            elif index_target.is_file(): target=index_target
        if root not in target.parents and target != root: errors.append(f'{file}: link escapes Website: {link}')
        elif not target.is_file(): errors.append(f'{file}: missing target: {link}')
if not (root/'_headers').is_file(): errors.append('missing static security headers')
language_index=(root/'index.html').read_text()
for expected in (
    '<title>CoreTend for macOS — Safe storage analysis and cleanup</title>',
    '<link rel="canonical" href="https://coretend.ahmetbsbnr.com/">',
    'hreflang="en" href="https://coretend.ahmetbsbnr.com/en"',
    'hreflang="fr" href="https://coretend.ahmetbsbnr.com/fr"',
    'hreflang="x-default" href="https://coretend.ahmetbsbnr.com/"',
    'og:title',
    'storage analysis and cleanup',
):
    if expected not in language_index: errors.append(f'language chooser SEO metadata missing: {expected}')
if 'choose your language' in language_index.lower(): errors.append('language chooser SEO title must describe CoreTend')
origin='https://coretend.ahmetbsbnr.com'
for lang in ('en','fr'):
    for page in ('index','features','download','privacy','support','developer','press'):
        route=f'/{lang}' + ('' if page=='index' else f'/{page}')
        html=(root/lang/('index.html' if page=='index' else f'{page}.html')).read_text()
        if f'<link rel="canonical" href="{origin}{route}">' not in html:
            errors.append(f'{lang}/{page}: missing canonical URL')
        for locale in ('en','fr'):
            alternate=f'<link rel="alternate" hreflang="{locale}" href="{origin}{("/"+locale) + ("" if page=="index" else "/"+page)}">'
            if alternate not in html: errors.append(f'{lang}/{page}: missing {locale} alternate URL')
        if page=='index' and f'<link rel="alternate" hreflang="x-default" href="{origin}/">' not in html:
            errors.append(f'{lang}/{page}: missing x-default language URL')
for lang in ('en','fr'):
    home_html=(root/lang/'index.html').read_text()
    blocks=re.findall(r'<script type="application/ld\+json">(.*?)</script>', home_html, re.S)
    if len(blocks)!=1: errors.append(f'{lang}/index: expected one SoftwareApplication JSON-LD block')
    else:
        try:
            data=json.loads(blocks[0])
            if data.get('@type')!='SoftwareApplication' or data.get('name')!='CoreTend': errors.append(f'{lang}/index: JSON-LD must describe CoreTend')
        except json.JSONDecodeError as error: errors.append(f'{lang}/index: invalid JSON-LD: {error}')
indexnow=[f for f in root.glob('*.txt') if re.fullmatch(r'[0-9a-f]{32}', f.stem)]
if len(indexnow)!=1 or indexnow[0].read_text()!=indexnow[0].stem: errors.append('missing or invalid IndexNow key file')
robots=root/'robots.txt'
sitemap=root/'sitemap.xml'
if not robots.is_file() or f'Sitemap: {origin}/sitemap.xml' not in robots.read_text():
    errors.append('robots.txt must allow crawling and point to the sitemap')
if not sitemap.is_file():
    errors.append('missing sitemap.xml')
else:
    try:
        sitemap_urls={node.text for node in ElementTree.parse(sitemap).iter('{http://www.sitemaps.org/schemas/sitemap/0.9}loc')}
        expected_urls={f'{origin}/'} | {f'{origin}/{lang}' + ('' if page=='index' else f'/{page}') for lang in ('en','fr') for page in ('index','features','download','privacy','support','developer','press')}
        if sitemap_urls != expected_urls: errors.append('sitemap.xml must list every canonical EN/FR route and the language landing page')
    except ElementTree.ParseError as error:
        errors.append(f'sitemap.xml is invalid: {error}')
vercel_config=json.loads((root.parent/'vercel.json').read_text())
for redirect in vercel_config.get('redirects', []):
    if redirect.get('source') in ('/en', '/fr'):
        errors.append(f"vercel.json: {redirect['source']} must resolve to its index page under cleanUrls, not redirect to /index")
stylesheet = root/'site.css'
if not stylesheet.is_file():
    errors.append('missing site stylesheet')
else:
    errors.extend(f'{stylesheet}: {message}' for message in reduced_motion_contract_errors(stylesheet.read_text()))
manifest=json.loads((root/'product-manifest.json').read_text())
source=(root.parent/'Sources/ProductContract/Capability.swift').read_text()
capabilities=sorted(re.findall(r'case\s+\w+\s*=\s*"([a-z][a-z0-9.]+)"',source))
if manifest.get('capabilityIDs') != capabilities: errors.append('site manifest capability IDs differ from ProductContract')
if manifest.get('destinations') != ['Home', 'Space', 'Clean', 'Apps', 'History']: errors.append('site manifest must list the four spaces and History')
release=json.loads((root/'release.json').read_text())
if manifest.get('state') != ('released' if release.get('published') else 'release candidate, unpublished'): errors.append('site release state is not explicit')
if release.get('published') and not (release.get('url') and release.get('sha256')): errors.append('a published release needs its download URL and SHA-256')
if release.get('dmg') and not (release['dmg'].get('url') and release['dmg'].get('sha256')): errors.append('a published disk image needs its URL and SHA-256')
for page in ('index.html','features.html','download.html','privacy.html','support.html','developer.html','press.html'):
    for lang in ('en','fr'):
        if not (root/lang/page).is_file(): errors.append(f'missing {lang}/{page}')
if errors:
    print('\n'.join(errors)); raise SystemExit(1)
print('Static site checks passed: bilingual routes, local links, landmarks, meta descriptions, CSP headers, reduced-motion CSS contract, no scripts.')
