#!/usr/bin/env python3
import csv, re
from pathlib import Path
root=Path(__file__).resolve().parents[1]
cap_source=(root/'Sources/ProductContract/Capability.swift').read_text()
caps=set(re.findall(r'case\s+\w+\s*=\s*"([a-z][a-z0-9.]+)"',cap_source))
spec=(root/'Documentation/Project/Cahier-des-charges.md').read_text()
requirements=set(re.findall(r'\| ((?:FR|NFR)-\d+) \|',spec))
with (root/'Documentation/Traceability.csv').open(newline='') as f: rows=list(csv.DictReader(f))
by_id={row['ID']:row for row in rows}
expected=caps|requirements
missing=expected-set(by_id)
extra=set(by_id)-expected
if missing or extra:
 print('Missing:',', '.join(sorted(missing))); print('Extra:',', '.join(sorted(extra))); raise SystemExit(1)
for row in rows:
 if row['description'].strip() in ('Capability inventory ID', '', 'TODO'):
  raise SystemExit(f"{row['ID']} has no capability description")
 if row['priority']=='M':
  missing=[key for key in ('code','tests','evidence','gap/owner') if not row[key].strip()]
  if missing:
   raise SystemExit(f"{row['ID']} Must row missing traceability fields: {', '.join(missing)}")
  if not re.search(r'20\d{2}-\d{2}-\d{2}', row['evidence']):
   raise SystemExit(f"{row['ID']} Must evidence has no review date")
  for field in ('code','tests'):
   for reference in row[field].split(';'):
    reference=reference.strip().split(' (',1)[0]
    if reference.startswith(('make ', 'swift ', 'python3 ', 'bash ')):
     continue
    if not (root/reference).exists():
     raise SystemExit(f"{row['ID']} {field} reference does not exist: {reference}")
 if row['status']=='VÉRIFIÉ' and not all(row[k].strip() for k in ('code','tests','evidence')):
  raise SystemExit(f"{row['ID']} marked VÉRIFIÉ without code/test/evidence")
print(f'Traceability complete: {len(requirements)} FR/NFR + {len(caps)} capabilities; current statuses remain explicit.')
