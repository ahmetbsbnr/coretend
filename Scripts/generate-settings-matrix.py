#!/usr/bin/env python3
"""Regenerates Documentation/SETTINGS_MATRIX.md from settings-matrix.json AND
verifies the declared setting set exactly matches the settings actually present
in Sources/ — the "no orphaned public setting" guarantee.

Discovery from source (the ground truth):
  - @AppStorage("key")            -> UserDefaults-backed settings
  - setSetting("key")/setting("key") -> Persistence Store key/value settings
  - .exclusions()                 -> the exclusions path-list setting

The JSON's `id` set must equal the discovered set. A setting in the JSON but
not in source is an ORPHAN (doc drift); a setting in source but not in the JSON
is UNDOCUMENTED. Either fails.

Usage:
  generate-settings-matrix.py           # regenerate the .md
  generate-settings-matrix.py --check   # verify committed .md + no orphans (CI)
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JSON_PATH = f"{ROOT}/Documentation/settings-matrix.json"
MD_PATH = f"{ROOT}/Documentation/SETTINGS_MATRIX.md"
SOURCES = f"{ROOT}/Sources"

COLUMNS = [
    ("id", "ID"), ("label", "Label"), ("default", "Default"),
    ("storage", "Storage"), ("type", "Type"), ("consumer", "Consumer(s)"),
    ("effect", "Effect"), ("restartRequired", "Restart"),
    ("availability", "Availability"), ("test", "Test"), ("status", "Status"),
]


def discover_source_settings():
    keys = set()
    patterns = [
        re.compile(r'@AppStorage\("([^"]+)"'),
        re.compile(r'setSetting\("([^"]+)"'),
        re.compile(r'\.setting\("([^"]+)"'),
    ]
    has_exclusions = False
    for dirpath, _, files in os.walk(SOURCES):
        for name in files:
            if not name.endswith(".swift"):
                continue
            text = open(os.path.join(dirpath, name), encoding="utf-8").read()
            for pat in patterns:
                keys.update(pat.findall(text))
            if ".exclusions()" in text:
                has_exclusions = True
    if has_exclusions:
        keys.add("exclusions")
    return keys


def load():
    with open(JSON_PATH) as f:
        return json.load(f)


def check_no_orphans(data):
    declared = {s["id"] for s in data["settings"]}
    discovered = discover_source_settings()
    orphans = declared - discovered
    undocumented = discovered - declared
    errs = []
    if orphans:
        errs.append(f"ORPHANED setting(s) in JSON but not in Sources/: {sorted(orphans)}")
    if undocumented:
        errs.append(f"UNDOCUMENTED setting(s) in Sources/ but not in JSON: {sorted(undocumented)}")
    return errs


def render_md(data):
    lines = ["# Settings Matrix — generated, do not hand-edit", ""]
    lines.append("Source of truth: `Documentation/settings-matrix.json`. Regenerate with")
    lines.append("`Scripts/generate-settings-matrix.py`. The generator also fails if the")
    lines.append("declared settings do not exactly match those present in `Sources/`")
    lines.append("(no orphaned or undocumented public setting).")
    lines.append("")
    lines.append("| " + " | ".join(h for _, h in COLUMNS) + " |")
    lines.append("|" + "|".join(["---"] * len(COLUMNS)) + "|")
    for s in data["settings"]:
        cells = [str(s.get(k, "")).replace("|", "\\|") for k, _ in COLUMNS]
        lines.append("| " + " | ".join(cells) + " |")
    lines.append("")
    lines.append(f"Total settings: {len(data['settings'])}")
    lines.append("")
    return "\n".join(lines)


def main():
    check = "--check" in sys.argv
    data = load()
    errs = check_no_orphans(data)
    if errs:
        for e in errs:
            print(f"error: {e}", file=sys.stderr)
        sys.exit(1)
    md = render_md(data)
    if check:
        current = open(MD_PATH).read() if os.path.exists(MD_PATH) else ""
        if current != md:
            print("error: SETTINGS_MATRIX.md is stale — run Scripts/generate-settings-matrix.py",
                  file=sys.stderr)
            sys.exit(1)
        print("settings matrix OK: {} settings, no orphans, .md current".format(len(data["settings"])))
    else:
        with open(MD_PATH, "w") as f:
            f.write(md)
        print(f"wrote {MD_PATH} ({len(data['settings'])} settings)")


if __name__ == "__main__":
    main()
