#!/usr/bin/env python3
from html.parser import HTMLParser
import json
from pathlib import Path
import re
from urllib.parse import urlparse
from site_accessibility_contract import reduced_motion_contract_errors
root = Path(__file__).resolve().parents[1] / 'Website'
class Page(HTMLParser):
    def __init__(self): super().__init__(); self.links=[]; self.scripts=0; self.lang=None; self.has_main=False; self.descriptions=[]; self.images=[]
    def handle_starttag(self, tag, attrs):
        data=dict(attrs)
        if tag=='a' and data.get('href'): self.links.append(data['href'])
        if tag=='script': self.scripts+=1
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
        # The only external link allowed is the project's own GitHub (releases, source).
        if parsed.scheme == 'javascript' or (parsed.scheme in ('http', 'https') and not link.startswith('https://github.com/ahmetbsbnr/coretend')):
            errors.append(f'{file}: external/script link {link}')
        if parsed.scheme or link.startswith('#'): continue
        target=(file.parent / parsed.path).resolve()
        if root not in target.parents and target != root: errors.append(f'{file}: link escapes Website: {link}')
        elif not target.is_file(): errors.append(f'{file}: missing target: {link}')
if not (root/'_headers').is_file(): errors.append('missing static security headers')
stylesheet = root/'site.css'
if not stylesheet.is_file():
    errors.append('missing site stylesheet')
else:
    errors.extend(f'{stylesheet}: {message}' for message in reduced_motion_contract_errors(stylesheet.read_text()))
manifest=json.loads((root/'product-manifest.json').read_text())
source=(root.parent/'Sources/ProductContract/Capability.swift').read_text()
capabilities=sorted(re.findall(r'case\s+\w+\s*=\s*"([a-z][a-z0-9.]+)"',source))
if manifest.get('capabilityIDs') != capabilities: errors.append('site manifest capability IDs differ from ProductContract')
if len(manifest.get('destinations',[])) != 8: errors.append('site manifest must list exactly eight destinations')
release=json.loads((root/'release.json').read_text())
if manifest.get('state') != ('released' if release.get('published') else 'release candidate, unpublished'): errors.append('site release state is not explicit')
if release.get('published') and not (release.get('url') and release.get('sha256')): errors.append('a published release needs its download URL and SHA-256')
for page in ('index.html','features.html','download.html','privacy.html','support.html','developer.html'):
    for lang in ('en','fr'):
        if not (root/lang/page).is_file(): errors.append(f'missing {lang}/{page}')
if errors:
    print('\n'.join(errors)); raise SystemExit(1)
print('Static site checks passed: bilingual routes, local links, landmarks, meta descriptions, CSP headers, reduced-motion CSS contract, no scripts.')
