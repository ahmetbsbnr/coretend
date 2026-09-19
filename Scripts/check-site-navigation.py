#!/usr/bin/env python3
"""Fail when the website's app demo contradicts the app's real navigation.

The landing page embeds an interactive demo with its own sidebar. It is a
simplified subset — showing six of eleven modules is a legitimate editorial
choice for a marketing page — but a *subset* is not licence to invent a
different structure, and it had:

  - a group called "Scan" that the app does not have, and
  - Integrity inside it, when the app puts Integrity under System.

Someone comparing the site to the app would conclude one of them was out of
date, and they would be right without being able to tell which.

So: the demo may show fewer modules than the app, never different ones, and
every group label it uses must be a group label the app uses, with the same
membership for the modules it does show.
"""
from pathlib import Path
import re, sys

ROOT = Path(__file__).resolve().parents[1]
SWIFT = ROOT / "Sources/CoreTendApp/App/ModuleCatalogue.swift"
PAGE = ROOT / "Website/index.html"

# The demo's `data-view` values are short slugs; this maps them onto ModuleID
# case names. Explicit because the slugs are also CSS/JS identifiers on the
# page and are not free to rename.
SLUG_TO_CASE = {
    "storage": "cleanup",
    "lens": "spaceLens",
    "dupes": "duplicates",
    "apps": "applications",
    "integrity": "protection",
    "record": "record",
}


def app_groups() -> dict[str, list[str]]:
    """Group localization key -> ModuleID case names, from SidebarGroup.all."""
    source = SWIFT.read_text(encoding="utf-8")
    block = re.search(r"static let all: \[SidebarGroup\] = \[(.*?)\n {4}\]",
                      source, re.S)
    if not block:
        sys.exit("error: could not find SidebarGroup.all — this checker needs updating")
    groups: dict[str, list[str]] = {}
    for title, modules in re.findall(
            r'SidebarGroup\(id: "[^"]+", title: (?:L\("([^"]+)"\)|nil),\s*\n?\s*modules: \[([^\]]+)\]',
            block.group(1)):
        key = title or ""
        names = [m.strip().lstrip(".") for m in modules.split(",") if m.strip()]
        groups[key] = names
    return groups


def site_groups() -> dict[str, list[str]]:
    """Displayed group label -> demo slugs, in document order."""
    page = PAGE.read_text(encoding="utf-8")
    nav = re.search(r'<nav class="app-side".*?</nav>', page, re.S)
    if not nav:
        sys.exit("error: could not find the demo sidebar in index.html")
    groups: dict[str, list[str]] = {}
    current = None
    for match in re.finditer(
            r'<small[^>]*>([^<]+)</small>|data-view="([a-z]+)"', nav.group(0)):
        label, slug = match.group(1), match.group(2)
        if label:
            current = label.strip()
            groups.setdefault(current, [])
        elif slug and current is not None:
            groups[current].append(slug)
    return groups


def main() -> int:
    app = app_groups()
    site = site_groups()
    # "sidebar.storage" -> "Storage"; the demo shows English labels.
    # "sidebar.mac" -> "This Mac". The demo shows the app's English labels, and
    # two of them are not one word.
    LABELS = {"sidebar.space": "Space", "sidebar.mac": "This Mac"}
    app_by_label = {LABELS.get(key, key.rsplit(".", 1)[-1].capitalize()): members
                    for key, members in app.items() if key}

    problems: list[str] = []
    for label, slugs in site.items():
        expected = app_by_label.get(label)
        if expected is None:
            problems.append(
                f'demo group "{label}" is not a group the app has '
                f'(app groups: {", ".join(sorted(app_by_label))})')
            continue
        for slug in slugs:
            case = SLUG_TO_CASE.get(slug)
            if case is None:
                problems.append(f'demo module "{slug}" maps to no ModuleID — update SLUG_TO_CASE')
            elif case not in expected:
                actual = next((g for g, m in app_by_label.items() if case in m), "no group")
                problems.append(
                    f'demo puts "{slug}" ({case}) under "{label}", '
                    f'but the app puts it under "{actual}"')

    if problems:
        print("The website's demo contradicts the app's navigation:\n", file=sys.stderr)
        for problem in problems:
            print(f"  - {problem}", file=sys.stderr)
        print("\nThe demo may show fewer modules than the app, never different ones.",
              file=sys.stderr)
        return 1

    shown = sum(len(v) for v in site.values())
    total = sum(len(v) for v in app.values())
    print(f"site navigation: demo shows {shown} of {total} modules, "
          f"grouped as the app groups them")
    return 0


if __name__ == "__main__":
    sys.exit(main())
