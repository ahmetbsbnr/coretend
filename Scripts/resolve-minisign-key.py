#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: The CoreTend Authors
"""Resolve which Minisign public key a given release version must verify with.

The single place that answers `version -> expected public key`. The release
preflight and release.yml both call it, so a release cannot be signed with one
key while the repository publishes another.

That is not hypothetical: v1.0.1 nearly shipped unverifiable because the key was
rotated in the GitHub Actions secret while `Configuration/minisign.pub` on main
still held the retired one. Nothing in the repository related a version to a
key, so no gate could notice. `Configuration/minisign-keys.json` is that
relation and this script is how it is read.

Usage:
    resolve-minisign-key.py <version>            # prints the key id
    resolve-minisign-key.py <version> --pub      # prints the public key file path
    resolve-minisign-key.py <version> --check    # also asserts minisign.pub agrees
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
REGISTRY = REPO / "Configuration" / "minisign-keys.json"
PUBLISHED = REPO / "Configuration" / "minisign.pub"


def fail(message: str) -> "None":
    print(f"resolve-minisign-key.py: FAIL — {message}", file=sys.stderr)
    raise SystemExit(1)


def version_key(version: str) -> tuple:
    """Order versions so that a prerelease sorts before its own release.

    1.0.0 < 1.0.1-beta.1 < 1.0.1. Plain `sort -V` gets this wrong often enough
    that a release boundary is not worth leaving to it.
    """
    core, _, pre = version.partition("-")
    parts = []
    for chunk in core.split("."):
        try:
            parts.append(int(chunk))
        except ValueError:
            fail(f"version '{version}' is not dotted numerals plus an optional -pre suffix")
    while len(parts) < 3:
        parts.append(0)
    if not pre:
        # No prerelease suffix sorts AFTER every prerelease of the same core.
        return (tuple(parts[:3]), 1, ())
    pre_parts = []
    for chunk in pre.replace("-", ".").split("."):
        pre_parts.append((0, int(chunk)) if chunk.isdigit() else (1, 0, chunk))
    return (tuple(parts[:3]), 0, tuple(pre_parts))


def load_registry() -> dict:
    if not REGISTRY.exists():
        fail(f"{REGISTRY.relative_to(REPO)} is missing — the key registry is required")
    try:
        return json.loads(REGISTRY.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        fail(f"{REGISTRY.relative_to(REPO)} is not valid JSON: {exc}")


def resolve(version: str) -> dict:
    registry = load_registry()
    target = version_key(version)
    matches = []
    for entry in registry.get("keys", []):
        first = entry.get("firstVersion")
        last = entry.get("lastVersion")
        if first and target < version_key(first):
            continue
        if last and target > version_key(last):
            continue
        matches.append(entry)

    if not matches:
        known = ", ".join(
            f"{k['keyId']} ({k.get('firstVersion', '?')}..{k.get('lastVersion') or 'now'})"
            for k in registry.get("keys", [])
        )
        fail(
            f"no Minisign key covers version {version}.\n"
            f"  Known ranges: {known}\n"
            f"  Expected: every releasable version falls inside exactly one range.\n"
            f"  Fix: add or extend an entry in Configuration/minisign-keys.json "
            f"(see Documentation/MINISIGN_KEY_ROTATION.md)."
        )
    if len(matches) > 1:
        ids = ", ".join(m["keyId"] for m in matches)
        fail(
            f"version {version} is covered by more than one Minisign key ({ids}).\n"
            f"  Expected: exactly one. Overlapping ranges make the expected key ambiguous.\n"
            f"  Fix: set lastVersion on the older entry in Configuration/minisign-keys.json."
        )
    return matches[0]


def main(argv: list) -> int:
    if len(argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    version = argv[1].lstrip("v")
    flags = set(argv[2:])
    entry = resolve(version)

    pub_path = REPO / entry["publicKeyFile"]
    if not pub_path.exists():
        fail(
            f"version {version} expects key {entry['keyId']}, whose public key file "
            f"{entry['publicKeyFile']} is missing from the repository.\n"
            f"  Fix: commit that .pub file, or correct publicKeyFile in "
            f"Configuration/minisign-keys.json."
        )

    if "--check" in flags:
        if not PUBLISHED.exists():
            fail("Configuration/minisign.pub is missing — releases would be unverifiable")
        published = PUBLISHED.read_text(encoding="utf-8").strip().splitlines()
        expected = pub_path.read_text(encoding="utf-8").strip().splitlines()
        if published[1:2] != expected[1:2]:
            fail(
                f"Configuration/minisign.pub does not carry the key version {version} requires.\n"
                f"  Expected: {entry['keyId']} (per Configuration/minisign-keys.json, "
                f"from {entry.get('firstVersion')})\n"
                f"  Found:    {published[0] if published else '<empty>'}\n"
                f"  Fix: copy {entry['publicKeyFile']} over Configuration/minisign.pub, "
                f"or correct the registry if the rotation boundary is wrong.\n"
                f"  Do NOT change the registry merely to make a release pass: that silently "
                f"breaks verification for everyone holding the published key."
            )
        print(f"OK: version {version} expects {entry['keyId']}, and Configuration/minisign.pub carries it.")
        return 0

    print(str(pub_path.relative_to(REPO)) if "--pub" in flags else entry["keyId"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
