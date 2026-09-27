#!/usr/bin/env python3
"""Check architecture constraints from SwiftPM's evaluated package graph."""

import json
import subprocess
import sys


def dependency_names(target):
    names = set()
    for dependency in target.get("dependencies", []):
        for kind in ("byName", "byTarget"):
            value = dependency.get(kind)
            if value:
                names.add(value[0] if isinstance(value, list) else value)
    return names


def version_tuple(value):
    try:
        return tuple(int(part) for part in value.split("."))
    except (AttributeError, ValueError):
        return ()


def validate(package):
    errors = []
    tools_version = version_tuple(package.get("toolsVersion", {}).get("_version"))
    if tools_version < (6, 0):
        errors.append("Swift tools version must be at least 6.0")

    macos_versions = [
        version_tuple(platform.get("version"))
        for platform in package.get("platforms", [])
        if platform.get("platformName") == "macos"
    ]
    if not macos_versions or min(macos_versions) < (14, 0):
        errors.append("macOS deployment target must be at least 14.0")

    if package.get("dependencies"):
        errors.append("external SwiftPM dependencies are not allowed")

    targets = {target.get("name"): target for target in package.get("targets", [])}
    scan_core = targets.get("ScanCore")
    if scan_core is None:
        errors.append("ScanCore target is missing")
    elif dependency_names(scan_core) & {"SafetyCore", "Persistence"}:
        errors.append("ScanCore may not depend on SafetyCore or Persistence")

    if "SafetyCore" not in targets:
        errors.append("SafetyCore target is missing")
    return errors


def main():
    try:
        result = subprocess.run(
            ["swift", "package", "dump-package"],
            check=True,
            capture_output=True,
            text=True,
        )
        package = json.loads(result.stdout)
    except (OSError, subprocess.CalledProcessError, json.JSONDecodeError) as error:
        print(f"Could not inspect SwiftPM package graph: {error}", file=sys.stderr)
        return 1

    errors = validate(package)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print("Architecture audit passed: Swift 6+, macOS 14+, no external SwiftPM packages, ScanCore isolated from action and persistence layers.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
