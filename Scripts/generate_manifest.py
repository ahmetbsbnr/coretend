#!/usr/bin/env python3
import json
import re
from pathlib import Path
root = Path(__file__).resolve().parents[1]
source = (root / 'Sources/ProductContract/Capability.swift').read_text()
ids = sorted(re.findall(r'case\s+\w+\s*=\s*"([a-z][a-z0-9.]+)"', source))
manifest = {
  'product': 'CoreTend',
  'state': 'released' if json.loads((root / 'Website/release.json').read_text()).get('published') else 'release candidate, unpublished',
  'version': json.loads((root / 'Website/release.json').read_text())['version'],
  'destinations': ['Home', 'Space', 'Clean', 'Apps', 'History'],
  'capabilityIDs': ids,
  'knownLimits': ['macOS 14 and 15 not yet tested on hardware (built for macOS 14+)', 'VoiceOver not yet reviewed by a person', 'app leftovers are matched by exact bundle identifier or app name at known Library places']
}
(root / 'Website/product-manifest.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + '\n')
