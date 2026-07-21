#!/usr/bin/env python3
"""Regenerates Documentation/FEATURE_INVENTORY.md and feature-inventory.csv
from Documentation/feature-inventory.json — the single canonical source.

No total, status count, or per-module count is ever hand-typed anywhere
else: this script is the only thing that computes them, from the `features`
array itself. Run with --check to verify the committed .md/.csv still match
what the JSON would generate (fails if someone hand-edited one without the
others, or edited the JSON without regenerating) — this is what
Scripts/test-feature-inventory.sh calls in CI.
"""
import json
import sys
from collections import Counter, OrderedDict

ROOT = "/Users/ahmetbasbunar/Documents/MACCLEAN"
JSON_PATH = f"{ROOT}/Documentation/feature-inventory.json"
MD_PATH = f"{ROOT}/Documentation/FEATURE_INVENTORY.md"
CSV_PATH = f"{ROOT}/Documentation/feature-inventory.csv"

STATUS_VOCAB = (
    "VERIFIED_COMPLETE, VERIFIED_PARTIAL, IMPLEMENTED_UNVERIFIED, UI_ONLY, SIMULATED, "
    "DOCUMENTATION_ONLY, BLOCKED_HUMAN, BLOCKED_ENVIRONMENT, BROKEN, DEPRECATED, "
    "NOT_STARTED, NOT_APPLICABLE, UNKNOWN"
)


def load():
    with open(JSON_PATH) as f:
        data = json.load(f)
    counts = Counter(f["status"] for f in data["features"])
    data["status_counts"] = dict(sorted(counts.items()))
    data["total"] = len(data["features"])
    return data


def render_md(data):
    lines = []
    lines.append("# Feature Inventory — generated, do not hand-edit")
    lines.append("")
    lines.append(
        f"Generated from `Documentation/feature-inventory.json` by "
        f"`Scripts/generate-feature-inventory.py` — the JSON is the single canonical "
        f"source; this file, `feature-inventory.csv`, and the totals below are all "
        f"derived from it, never typed by hand. Run `python3 "
        f"Scripts/generate-feature-inventory.py --check` to verify they still agree."
    )
    lines.append("")
    lines.append(f"**Total: {data['total']} features.** Status counts: " +
                 ", ".join(f"{k}={v}" for k, v in data["status_counts"].items()) + ".")
    lines.append("")
    lines.append(f"Status vocabulary: {STATUS_VOCAB}.")
    lines.append("")

    by_module = OrderedDict()
    for feat in data["features"]:
        by_module.setdefault(feat["module"], []).append(feat)

    for module, feats in by_module.items():
        module_counts = Counter(f["status"] for f in feats)
        summary = ", ".join(f"{k}={v}" for k, v in sorted(module_counts.items()))
        lines.append(f"## {module} ({len(feats)}: {summary})")
        lines.append("")
        lines.append("| id | Feature | Status | Evidence |")
        lines.append("|---|---|---|---|")
        for f in feats:
            feature = f.get("feature", "")
            lines.append(f"| {f['id']} | {feature} | {f['status']} | {f['evidence']} |")
        lines.append("")

    return "\n".join(lines) + "\n"


def render_csv(data):
    lines = ["id,module,status,feature,evidence"]
    for f in data["features"]:
        feature = f.get("feature", "").replace('"', "'")
        evidence = f["evidence"].replace('"', "'")
        lines.append(f'{f["id"]},{f["module"]},{f["status"]},"{feature}","{evidence}"')
    return "\n".join(lines) + "\n"


def main():
    check = "--check" in sys.argv
    data = load()
    md = render_md(data)
    csv = render_csv(data)

    if check:
        fail = False
        with open(MD_PATH) as f:
            if f.read() != md:
                print(f"FAIL: {MD_PATH} does not match what feature-inventory.json generates — rerun without --check.")
                fail = True
        with open(CSV_PATH) as f:
            if f.read() != csv:
                print(f"FAIL: {CSV_PATH} does not match what feature-inventory.json generates — rerun without --check.")
                fail = True
        if fail:
            sys.exit(1)
        print(f"OK: FEATURE_INVENTORY.md and feature-inventory.csv both match feature-inventory.json "
              f"({data['total']} features, {data['status_counts']}).")
        return

    with open(MD_PATH, "w") as f:
        f.write(md)
    with open(CSV_PATH, "w") as f:
        f.write(csv)
    print(f"Wrote {MD_PATH} and {CSV_PATH} ({data['total']} features, {data['status_counts']}).")


if __name__ == "__main__":
    main()
