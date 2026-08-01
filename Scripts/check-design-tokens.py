#!/usr/bin/env python3
"""Fail when checked-in web tokens drift from Swift sources."""
import filecmp, shutil, subprocess, tempfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
    generated = root / "Website/assets/tokens"
    backup = Path(tmp) / "tokens"
    shutil.copytree(generated, backup)
    subprocess.run(["python3", "Scripts/export-design-tokens.py"], cwd=root, check=True, capture_output=True)
    ok = all(filecmp.cmp(generated / n, backup / n, shallow=False) for n in ("design-tokens.css", "design-tokens.json"))
    shutil.copytree(backup, generated, dirs_exist_ok=True)
if not ok:
    raise SystemExit("design token export drifted; run Scripts/export-design-tokens.py and commit the generated assets")
print("design token export: Swift and web values match")
