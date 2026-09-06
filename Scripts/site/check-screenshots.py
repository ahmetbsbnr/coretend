#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: The CoreTend Authors
"""
Screenshot sanitisation gate for the CoreTend website.

The safety model is deterministic, NOT OCR:

  approved source manifest  +  filename / path allow-list  +  metadata text scan
  +  explicit human review (the `approved` flag, set only by a person)

This script checks Website/screenshots.json and every source asset it names for
obvious private-data leaks. It never inspects pixels. It can strip text
metadata from the source PNG/WebP (`--strip`) but never alters the image.

Exit non-zero on any finding. `HUMAN ASSET REVIEW REQUIRED` entries with
`source: null` are fine — they are pending, not unsafe.

Usage:
  Scripts/site/check-screenshots.py [--strip]
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SITE = os.path.join(ROOT, "Website")
MANIFEST = os.path.join(SITE, "screenshots.json")

# Source captures may live only here (the maintainer-approved VisualAudit set)
# or a demo-fixture directory. Anything else is an unvetted arbitrary file.
ALLOWED_SOURCE_PREFIXES = (
    "Documentation/VisualAudit/After/",
    "Website/assets/app/screens/",
    "Resources/DemoFixtures/",
)
FORBIDDEN_SOURCE_SUBSTR = (
    "VisualAudit/_tmp", "_capture_", "/tmp/", "/private/tmp/", "/var/folders/",
    "/Desktop/", "/Downloads/",
)

ACCOUNT_NAME = ""
try:
    ACCOUNT_NAME = subprocess.check_output(["id", "-un"], text=True).strip()
except Exception:
    pass
if ACCOUNT_NAME in ("runner", "runneradmin", "root"):
    ACCOUNT_NAME = ""

# Text patterns that must never appear in a manifest field or in source-asset
# text metadata. Emails are allowed only when clearly synthetic.
PRIVATE_PATTERNS = [
    (re.compile(r"/Users/(?!demo\b)[A-Za-z0-9._-]+/"), "absolute /Users/<real-name> path"),
    (re.compile(r"\b[A-Za-z0-9._%+-]+@(?!example\.|demo\.|synthetic\.)"
                r"[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"), "non-synthetic email address"),
    (re.compile(r"\b[A-Za-z0-9-]+(?:’s| |-)?(?:MacBook|iMac|Mac mini|Mac Studio|Mac Pro)\b"),
     "real device name"),
    (re.compile(r"\b(?:coretend|stagepilot|ahmetbsbnr)-(?:secret|private|internal)\b", re.I),
     "private project marker"),
    (re.compile(r"\b(?:RESEND_API_KEY|ADMIN_TOKEN|POSTGRES_URL|AUTH_SECRET)\b"),
     "server secret name"),
]
if ACCOUNT_NAME:
    PRIVATE_PATTERNS.append(
        (re.compile(r"\b" + re.escape(ACCOUNT_NAME) + r"\b"), "build-account username")
    )


def scan_text(text, where, problems):
    for rx, label in PRIVATE_PATTERNS:
        m = rx.search(text or "")
        if m:
            problems.append(f"{where}: {label} — matched {m.group(0)!r}")


    # Groups that describe the file ON DISK (its current path, mtime, the
    # exiftool version) rather than anything embedded in the image. A capture's
    # on-disk path is not a leak in the shipped asset.
_FS_GROUPS = ("[File]", "[System]", "[ExifTool]", "[SourceFile]", "[Composite]")


def metadata_text(path):
    """Best-effort EMBEDDED-metadata dump. Uses `exiftool` if present (filtered
    to embedded groups), else a raw scan for common text-chunk markers
    (iTXt/tEXt/XMP). No pixel decode."""
    try:
        out = subprocess.check_output(
            ["exiftool", "-s", "-G", "-charset", "utf8", path],
            text=True, stderr=subprocess.DEVNULL)
        return "\n".join(
            ln for ln in out.splitlines()
            if not any(ln.startswith(g) for g in _FS_GROUPS)
        )
    except Exception:
        pass
    try:
        with open(path, "rb") as f:
            blob = f.read()
    except OSError:
        return ""
    chunks = []
    for marker in (b"iTXt", b"tEXt", b"zTXt", b"<x:xmpmeta", b"<rdf:RDF", b"Comment"):
        i = blob.find(marker)
        if i != -1:
            chunks.append(blob[i:i + 4000].decode("latin-1", "replace"))
    return "\n".join(chunks)


def strip_metadata(path):
    if path.lower().endswith(".webp"):
        subprocess.check_call(["cwebp", "-quiet", "-metadata", "none", path, "-o", path])
        return True
    try:
        subprocess.check_call(["exiftool", "-overwrite_original", "-all=", path],
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    except Exception:
        return False


def main(argv):
    strip = "--strip" in argv
    if not os.path.exists(MANIFEST):
        print(f"check-screenshots.py: FAIL — {MANIFEST} missing")
        return 1
    doc = json.load(open(MANIFEST, encoding="utf-8"))
    shots = doc.get("screenshots", [])
    problems = []
    seen_ids = set()

    for e in shots:
        sid = e.get("id", "<no id>")
        if sid in seen_ids:
            problems.append(f"{sid}: duplicate id")
        seen_ids.add(sid)

        for field in ("id", "module", "state", "alt", "notes", "source",
                      "web1x", "web2x"):
            v = e.get(field)
            if isinstance(v, str):
                scan_text(v, f"{sid}.{field}", problems)

        src = e.get("source")
        if src is None:
            if e.get("approved"):
                problems.append(f"{sid}: approved:true with source:null")
            continue

        rel = src[len("Website/"):] if src.startswith("Website/") else src
        if not any(src.startswith(p) or rel.startswith(p) for p in ALLOWED_SOURCE_PREFIXES):
            problems.append(f"{sid}: source {src!r} is outside the allowed capture directories")
        if any(bad in src for bad in FORBIDDEN_SOURCE_SUBSTR):
            problems.append(f"{sid}: source {src!r} points at a temp/arbitrary path")

        abspath = os.path.join(ROOT, src)
        if not os.path.exists(abspath):
            problems.append(f"{sid}: source {src!r} does not exist")
            continue

        meta = metadata_text(abspath)
        # Drop the benign camera/size fields; only prose-ish metadata matters.
        scan_text(meta, f"{sid}.source-metadata", problems)
        if strip and meta.strip():
            ok = strip_metadata(abspath)
            print(f"  {'stripped' if ok else 'could-not-strip'} metadata: {src}")

        # The shipped web exports must themselves carry no text metadata.
        for field in ("web1x", "web2x"):
            wp = e.get(field)
            if not wp:
                continue
            wabs = os.path.join(SITE, wp)
            if not os.path.exists(wabs):
                problems.append(f"{sid}.{field}: {wp!r} does not exist")
                continue
            wmeta = metadata_text(wabs)
            if re.search(r"\[(XMP|IPTC|EXIF:UserComment|PNG:Comment|PNG:Description|"
                         r"PNG:Author|PNG:Title|Photoshop)\]", wmeta):
                problems.append(f"{sid}.{field}: shipped export {wp!r} still carries text metadata")
            scan_text(wmeta, f"{sid}.{field}-metadata", problems)

    if problems:
        print("check-screenshots.py: FAIL")
        for p in problems:
            print(f"  - {p}")
        return 1
    approved = sum(1 for e in shots if e.get("approved"))
    print(f"check-screenshots.py: OK — {len(shots)} entries, {approved} approved, "
          f"{len(shots) - approved} pending (HUMAN ASSET REVIEW REQUIRED)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
