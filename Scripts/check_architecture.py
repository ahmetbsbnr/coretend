#!/usr/bin/env python3
"""Check architecture constraints from SwiftPM's evaluated package graph."""

import json
import re
import subprocess
import sys
from pathlib import Path


def dependency_names(target):
    names = set()
    for dependency in target.get("dependencies", []):
        for kind in ("byName", "byTarget"):
            value = dependency.get(kind)
            if value:
                names.add(value[0] if isinstance(value, list) else value)
    return names


def reachable_dependencies(target, targets):
    pending = list(dependency_names(target))
    visited = set()
    while pending:
        name = pending.pop()
        if name in visited:
            continue
        visited.add(name)
        dependency = targets.get(name)
        if dependency is not None:
            pending.extend(dependency_names(dependency) - visited)
    return visited


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
    elif reachable_dependencies(scan_core, targets) & {"SafetyCore", "Persistence"}:
        errors.append("ScanCore may not depend on SafetyCore or Persistence")

    if "SafetyCore" not in targets:
        errors.append("SafetyCore target is missing")
    return errors


# Serre UI guide (Documentation/Design/UI-guide.md §§ 2, 7, 8, 11): views outside
# Sources/DesignSystem use its components and tokens instead of these.
DESIGN_RULES = (
    (re.compile(r"\.buttonStyle\(\s*(?:\.plain|PlainButtonStyle\(\))\s*\)"),
     "unstyled plain button (use a Serre button style)"),
    (re.compile(r"\bColor\s*\(\s*(?:red|hue|white|\.sRGB|\.displayP3)\b"),
     "literal colour (use a Palette role)"),
    (re.compile(r"(?:\bColor\.|[(,:]\s*\.)(?:blue|red|green|orange|yellow|purple|pink|teal|cyan|indigo|mint|brown)\b(?!\s*[:=])"),
     "system colour (use a Palette role)"),
    (re.compile(r"\brepeatForever\b"),
     "looping animation outside DesignSystem (no loop at rest)"),
)


def design_violations(sources):
    """sources: {relative path: text}. Returns messages for files outside Sources/DesignSystem."""
    errors = []
    for path, text in sorted(sources.items()):
        if path.startswith("Sources/DesignSystem/"):
            continue
        for number, line in enumerate(text.splitlines(), start=1):
            if line.lstrip().startswith("//"):
                continue
            for pattern, message in DESIGN_RULES:
                if pattern.search(line):
                    errors.append(f"{path}:{number}: {message}")
    return errors



def trash_dialog_violations(sources):
    """A confirmation or alert with a destructive button must make another button the Return
    default, so a stray Return never moves or clears anything."""
    errors = []
    for path, text in sorted(sources.items()):
        lines = text.splitlines()
        for number, line in enumerate(lines, start=1):
            if ".confirmationDialog(" not in line and ".alert(" not in line:
                continue
            block = "\n".join(lines[number - 1:number + 8])
            block = block.split("} message:")[0]
            if "role: .destructive" in block and ".keyboardShortcut(.defaultAction)" not in block:
                errors.append(f"{path}:{number}: destructive confirmation without a non-destructive Return default")
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

    root = Path(__file__).resolve().parents[1]
    sources = {path.relative_to(root).as_posix(): path.read_text(encoding="utf-8")
               for path in (root / "Sources").rglob("*.swift")}
    errors = validate(package) + design_violations(sources) + trash_dialog_violations(sources)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print("Architecture audit passed: Swift 6+, macOS 14+, no external SwiftPM packages, ScanCore isolated from action and persistence layers, views use the Serre design system.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
