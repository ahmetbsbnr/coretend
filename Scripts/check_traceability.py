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
requirement_rows=re.findall(r'^\| ((?:FR|NFR)-\d+) \| (?:\*\*)?([^|]+)',spec,re.MULTILINE)
requirement_priorities={}
for requirement_id,priority in requirement_rows:
 priority=priority.strip().strip('*')
 if priority not in ('M','S','C','W'):
  if requirement_id.startswith('FR-'):
   raise SystemExit(f"Cahier-des-charges.md requirement {requirement_id} has no approved MoSCoW priority")
  # NFR rows use a domain label; all NFR invariants are Must by §6.
  if requirement_id.startswith('NFR-'):
   priority='M'
  else:
   continue
 if requirement_id in requirement_priorities:
  raise SystemExit(f"Cahier-des-charges.md has duplicate requirement ID: {requirement_id}")
 requirement_priorities[requirement_id]=priority
requirements=set(requirement_priorities)
# Capability priorities come from the explicit source-ID reconciliation in §7.
moscow=re.search(r'^## 7\. MoSCoW\s*$([\s\S]*?)(?=^## |\Z)',spec,re.MULTILINE)
if not moscow:
 raise SystemExit('Cahier-des-charges.md has no MoSCoW section 7')
reconciliation=re.search(r'^Réconciliation des capacités source : ([^\n]+)',moscow.group(1),re.MULTILINE)
if not reconciliation:
 raise SystemExit('MoSCoW section has no capability inventory reconciliation')
should_capabilities=set(re.findall(r'`([a-z][a-z0-9.]+)`',reconciliation.group(1).split('sont Should',1)[0]))
capability_priorities={capability:('S' if capability in should_capabilities else 'M') for capability in caps}
unknown_should=should_capabilities-caps
if unknown_should:
 raise SystemExit('MoSCoW Should IDs missing from capability inventory: '+', '.join(sorted(unknown_should)))
expected_columns=['ID','priority','description','code','tests','documentation','evidence','status','gap/owner']
with (root/'Documentation/Traceability.csv').open(newline='') as f:
 reader=csv.DictReader(f)
 if reader.fieldnames!=expected_columns:
  raise SystemExit(f"Traceability.csv columns differ from the required schema: {reader.fieldnames}")
 rows=[]
 for line_number,row in enumerate(reader,start=2):
  if None in row or any(value is None for value in row.values()):
   raise SystemExit(f"Traceability.csv line {line_number} has a malformed column count")
  rows.append((line_number,row))
by_id={}
for line_number,row in rows:
 if row['ID'] in by_id:
  raise SystemExit(f"Traceability.csv line {line_number} duplicates ID {row['ID']}")
 by_id[row['ID']]=row
expected=caps|requirements
missing=expected-set(by_id)
extra=set(by_id)-expected
if missing or extra:
 print('Missing:',', '.join(sorted(missing))); print('Extra:',', '.join(sorted(extra))); raise SystemExit(1)
approved_priorities=requirement_priorities|capability_priorities
for line_number,row in rows:
    expected_priority=approved_priorities.get(row['ID'])
    if row['priority'] != expected_priority:
        raise SystemExit(f"Traceability.csv line {line_number} priority {row['priority']} for {row['ID']} differs from approved priority {expected_priority}")
    if row['description'].strip() in ('Capability inventory ID', '', 'TODO'):
        raise SystemExit(f"{row['ID']} has no capability description")
    if row['status'] not in ('PARTIEL', 'EN_COURS', 'À_CONSTRUIRE', 'VÉRIFIÉ'):
        raise SystemExit(f"{row['ID']} has unknown status: {row['status']}")
    if row['priority'] not in ('M', 'S', 'C', 'W'):
        raise SystemExit(f"{row['ID']} has unknown priority: {row['priority']}")

    required = ('documentation', 'evidence', 'gap/owner')
    if row['status'] != 'À_CONSTRUIRE':
        required += ('code', 'tests')
    if row['priority'] == 'M':
        required += ('code', 'tests')
    missing=[key for key in required if not row[key].strip()]
    if missing:
        raise SystemExit(f"{row['ID']} traceability row missing fields: {', '.join(sorted(set(missing)))}")

    if row['status'] in ('PARTIEL', 'EN_COURS', 'À_CONSTRUIRE', 'VÉRIFIÉ'):
        evidence_match=re.match(r'(?:Revue du registre )?(\d{4}-\d{2}-\d{2})(?:;|:)',row['evidence'])
        evidence_date=iso_date(evidence_match.group(1)) if evidence_match else None
        if not evidence_date:
            raise SystemExit(f"{row['ID']} evidence has no valid anchored ISO review date")
        if evidence_match.group(1)!=current_review:
            raise SystemExit(f"{row['ID']} evidence review date {evidence_match.group(1)} is stale; Progress.md says {current_review}")

    for field in ('code', 'tests', 'documentation'):
        for reference in row[field].split(';'):
            reference=reference.strip().split(' (',1)[0]
            if not reference or reference.startswith(('make ', 'swift ', 'python3 ', 'bash ')):
                continue
            if not (root/reference).exists():
                raise SystemExit(f"{row['ID']} {field} reference does not exist: {reference}")

    if row['priority']=='M' and row['status'] != 'À_CONSTRUIRE':
        missing=[key for key in ('code','tests','evidence','gap/owner') if not row[key].strip()]
        if missing:
            raise SystemExit(f"{row['ID']} Must row missing traceability fields: {', '.join(missing)}")
print(f'Traceability complete: {len(requirements)} FR/NFR + {len(caps)} capabilities; current statuses remain explicit.')
