#!/usr/bin/env python3
"""Recursive Markdown link validator.

Checks every `[text](target)` link in every tracked *.md file (excluding
.build/.git/node_modules-equivalents):
  - relative file links resolve to a real file on disk
  - a `#anchor` on a relative link resolves to a real heading in the target
    file (GitHub-style slug: lowercase, spaces -> hyphens, punctuation
    stripped)
  - a bare `#anchor` (same-file) resolves to a real heading in the same file
  - external (http/https/mailto) links are reported separately as
    "untested" — this script does not make network calls
Exit 0 only if there are zero broken internal links.
"""
import os
import re
import subprocess
import sys

ROOT = subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip()

LINK_RE = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*#*$")


def slugify(heading):
    s = heading.strip().lower()
    s = re.sub(r"[`*_]", "", s)  # strip markdown emphasis/code markers
    s = re.sub(r"[^\w\s-]", "", s)  # strip punctuation (GitHub-style)
    s = re.sub(r"\s+", "-", s)
    return s


def headings_for(path):
    slugs = set()
    seen = {}
    try:
        with open(path, encoding="utf-8", errors="ignore") as f:
            text = f.read()
    except OSError:
        return slugs
    in_code_fence = False
    for line in text.splitlines():
        if line.strip().startswith("```"):
            in_code_fence = not in_code_fence
            continue
        if in_code_fence:
            continue
        m = HEADING_RE.match(line)
        if m:
            base = slugify(m.group(2))
            n = seen.get(base, 0)
            slug = base if n == 0 else f"{base}-{n}"
            seen[base] = n + 1
            slugs.add(slug)
    return slugs


def tracked_md_files():
    out = subprocess.check_output(["git", "ls-files", "*.md"], cwd=ROOT, text=True)
    return [os.path.join(ROOT, p) for p in out.splitlines() if p]


def main():
    files = tracked_md_files()
    heading_cache = {}

    def headings_of(path):
        if path not in heading_cache:
            heading_cache[path] = headings_for(path)
        return heading_cache[path]

    broken = []
    external = []
    checked_internal = 0

    for path in files:
        try:
            with open(path, encoding="utf-8", errors="ignore") as f:
                lines = f.readlines()
        except OSError:
            continue
        in_code_fence = False
        for lineno, line in enumerate(lines, start=1):
            if line.strip().startswith("```"):
                in_code_fence = not in_code_fence
                continue
            if in_code_fence:
                continue
            for m in LINK_RE.finditer(line):
                target = m.group(1).strip()
                # Strip an optional "title" suffix: (path "Title")
                target = target.split(" ", 1)[0]
                if not target or target.startswith(("http://", "https://", "mailto:")):
                    if target:
                        external.append((path, lineno, target))
                    continue
                if target.startswith(("x-apple.systempreferences:", "macappstore:")):
                    continue  # OS-level URI scheme, not a doc link
                checked_internal += 1
                if target.startswith("#"):
                    anchor = target[1:]
                    if anchor and anchor not in headings_of(path):
                        broken.append((path, lineno, target, "anchor not found in same file"))
                    continue
                file_part, _, anchor = target.partition("#")
                resolved = os.path.normpath(os.path.join(os.path.dirname(path), file_part))
                if not os.path.exists(resolved):
                    broken.append((path, lineno, target, f"file not found: {os.path.relpath(resolved, ROOT)}"))
                    continue
                if anchor and resolved.endswith(".md"):
                    if anchor not in headings_of(resolved):
                        broken.append((path, lineno, target, f"anchor not found in {os.path.relpath(resolved, ROOT)}"))

    rel = lambda p: os.path.relpath(p, ROOT)

    print(f"Checked {checked_internal} internal links across {len(files)} tracked Markdown files.")
    print(f"External links found (untested, no network calls made): {len(external)}")

    if broken:
        print(f"\n{len(broken)} BROKEN internal link(s):")
        for path, lineno, target, reason in broken:
            print(f"  {rel(path)}:{lineno}: [{target}] — {reason}")
        print("\ncheck-markdown-links.py: FAILED")
        return 1

    print("\ncheck-markdown-links.py: PASSED (0 broken internal links)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
