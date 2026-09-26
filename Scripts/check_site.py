#!/usr/bin/env python3
from html.parser import HTMLParser
import json
from pathlib import Path
import re
from urllib.parse import urlparse
root = Path(__file__).resolve().parents[1] / 'Website'
class Page(HTMLParser):
    def __init__(self): super().__init__(); self.links=[]; self.scripts=0; self.lang=None; self.has_main=False
    def handle_starttag(self, tag, attrs):
        data=dict(attrs)
        if tag=='a' and data.get('href'): self.links.append(data['href'])
        if tag=='script': self.scripts+=1
        if tag=='html': self.lang=data.get('lang')
        if tag=='main': self.has_main=True
errors=[]
for file in sorted(root.rglob('*.html')):
    page=Page(); page.feed(file.read_text())
    if not page.lang: errors.append(f'{file}: missing lang')
    if not page.has_main: errors.append(f'{file}: missing main landmark')
    if page.scripts: errors.append(f'{file}: scripts are forbidden in site preview')
    for link in page.links:
        parsed=urlparse(link)
        if parsed.scheme in ('http','https','javascript'): errors.append(f'{file}: external/script link {link}')
        if parsed.scheme or link.startswith('#'): continue
        target=(file.parent / parsed.path).resolve()
        if root not in target.parents and target != root: errors.append(f'{file}: link escapes Website: {link}')
        elif not target.is_file(): errors.append(f'{file}: missing target: {link}')
if not (root/'_headers').is_file(): errors.append('missing static security headers')
manifest=json.loads((root/'product-manifest.json').read_text())
source=(root.parent/'Sources/ProductContract/Capability.swift').read_text()
capabilities=sorted(re.findall(r'case\s+\w+\s*=\s*"([a-z][a-z0-9.]+)"',source))
if manifest.get('capabilityIDs') != capabilities: errors.append('site manifest capability IDs differ from ProductContract')
if len(manifest.get('destinations',[])) != 8: errors.append('site manifest must list exactly eight destinations')
if manifest.get('state') != 'local reconstruction, unreleased': errors.append('site release state is not explicit')
for page in ('index.html','features.html','privacy.html','support.html','developer.html'):
    for lang in ('en','fr'):
        if not (root/lang/page).is_file(): errors.append(f'missing {lang}/{page}')
if errors:
    print('\n'.join(errors)); raise SystemExit(1)
print('Static site checks passed: bilingual routes, local links, landmarks, CSP headers, no scripts.')
