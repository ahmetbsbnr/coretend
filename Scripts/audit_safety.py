#!/usr/bin/env python3
import re
from pathlib import Path
root=Path(__file__).resolve().parents[1]
errors=[]
for file in (root/'Sources').rglob('*.swift'):
 text=file.read_text()
 for pattern in (r'FileManager\.(?:default\.)?removeItem', r'\bunlink\s*\(', r'FileManager\.(?:default\.)?moveItem', r'\.removeItem\s*\('):
  if re.search(pattern,text): errors.append(f'production mutation API in {file.relative_to(root)}: {pattern}')
trash=[f for f in (root/'Sources').rglob('*.swift') if 'trashItem(' in f.read_text()]
if len(trash)!=1 or trash[0].relative_to(root).as_posix()!='Sources/SafetyCore/SafetyCore.swift':
 errors.append('production Trash API must exist only in SafetyCore')
for file in (root/'Tests').rglob('*.swift'):
 text=file.read_text()
 if re.search(r'/(?:Users|Volumes)/|~\/\.Trash|homeDirectoryForCurrentUser|\.trashDirectory',text):
  errors.append(f'personal-store path reference in test: {file.relative_to(root)}')
for file in (root/'Sources').rglob('*.swift'):
 if 'homeDirectoryForCurrentUser' in file.read_text(): errors.append(f'implicit HOME lookup in runtime: {file.relative_to(root)}')
network_patterns = (
 r'^\s*import\s+(?:Network|MetricKit)\b',
 r'\b(?:URLSession|URLRequest|URLProtocol|NWConnection|NWListener|WebSocketTask|MQTTClient)\b',
 r'\b(?:TelemetryDeck|PostHog|Mixpanel|Amplitude)\b',
 r'\b(?:connect|getaddrinfo|socket)\s*\(',
 r'\bProcess\s*\(',
)
for file in (root/'Sources').rglob('*.swift'):
 text=file.read_text()
 for pattern in network_patterns:
  if re.search(pattern,text,re.MULTILINE):
   errors.append(f'network client or telemetry API in runtime: {file.relative_to(root)}: {pattern}')
manifest=(root/'Package.swift').read_text()
if re.search(r'\.package\s*\(\s*url\s*:',manifest):
 errors.append('external SwiftPM package dependency present; review privacy and network surface')
if errors: print('\n'.join(errors)); raise SystemExit(1)
print('Safety audit passed: Trash boundary intact; no permanent-removal API, personal test paths, network client, or known telemetry SDK/import.')
