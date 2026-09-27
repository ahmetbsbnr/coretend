#!/usr/bin/env python3
import csv, re
from datetime import date
from pathlib import Path
root=Path(__file__).resolve().parents[1]

def iso_date(value):
 try:
  parsed=date.fromisoformat(value)
  return parsed if parsed.isoformat()==value else None
 except ValueError:
  return None

progress=(root/'Documentation/Progress.md').read_text()
progress_match=re.search(r'^\*\*Relevé :\*\* (\d{4}-\d{2}-\d{2})\.',progress,re.MULTILINE)
if not progress_match or not iso_date(progress_match.group(1)):
 raise SystemExit('Progress.md has no valid authoritative review date')
current_review=progress_match.group(1)

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
  evidence_match=re.match(r'(?:Revue du registre )?(\d{4}-\d{2}-\d{2})(?:;|:)',row['evidence'])
  evidence_date=iso_date(evidence_match.group(1)) if evidence_match else None
  if not evidence_date:
   raise SystemExit(f"{row['ID']} Must evidence has no valid anchored ISO review date")
  if evidence_match.group(1)!=current_review:
   raise SystemExit(f"{row['ID']} Must evidence review date {evidence_match.group(1)} is stale; Progress.md says {current_review}")
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
