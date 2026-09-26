#!/usr/bin/env python3
import json
import re
from pathlib import Path
root = Path(__file__).resolve().parents[1]
source = (root / 'Sources/ProductContract/Capability.swift').read_text()
ids = sorted(re.findall(r'case\s+\w+\s*=\s*"([a-z][a-z0-9.]+)"', source))
manifest = {
  'product': 'CoreTend',
  'state': 'local reconstruction, unreleased',
  'destinations': ['Overview', 'Record', 'Cleanup', 'Explore', 'Duplicates', 'Applications', 'Integrity', 'Performance'],
  'capabilityIDs': ids,
  'implementedPreview': ['read-only explicit-folder scan', 'exact duplicate identification', 'Trash-only action boundary', 'local versioned event store', 'read-only CLI'],
  'notYetQualified': ['cleanup review, exclusions and action flow', 'system integrity and performance evidence', 'application inventory', 'legacy migration UI', 'signed or published distribution']
}
(root / 'Website/product-manifest.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + '\n')
