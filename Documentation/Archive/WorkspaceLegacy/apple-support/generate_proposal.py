#!/usr/bin/env python3
"""Generate the self-contained proposal HTML from its Markdown source.

This intentionally small renderer supports only the Markdown constructs used by
the proposal. Page and layout wrappers remain explicit in the source so the
Markdown is authoritative and the print result is deterministic.
"""

from __future__ import annotations

import html
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "Coretend_Apple_Support_Proposal.md"
STYLE = ROOT / "assets" / "proposal.css"
OUTPUT = ROOT / "Coretend_Apple_Support_Proposal.html"


def inline(text: str) -> str:
    placeholders: list[str] = []

    def keep(value: str) -> str:
        placeholders.append(value)
        return f"\x00{len(placeholders) - 1}\x00"

    text = re.sub(r"`([^`]+)`", lambda m: keep(f"<code>{html.escape(m.group(1))}</code>"), text)
    text = html.escape(text, quote=False)
    text = re.sub(
        r"!\[([^\]]*)\]\(([^)]+)\)",
        lambda m: keep(
            f'<img src="{html.escape(m.group(2), quote=True)}" '
            f'alt="{html.escape(m.group(1), quote=True)}">'
        ),
        text,
    )
    text = re.sub(
        r"\[([^\]]+)\]\(([^)]+)\)",
        lambda m: keep(
            f'<a href="{html.escape(m.group(2), quote=True)}">{html.escape(m.group(1))}</a>'
        ),
        text,
    )
    text = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"(?<!\*)\*([^*]+)\*(?!\*)", r"<em>\1</em>", text)
    text = text.replace("  ", " ")
    for index, value in enumerate(placeholders):
        text = text.replace(f"\x00{index}\x00", value)
    return text


def render_table(lines: list[str]) -> str:
    rows = []
    for line in lines:
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        rows.append(cells)
    header, body = rows[0], rows[2:]
    out = ["<table><thead><tr>"]
    out.extend(f"<th>{inline(cell)}</th>" for cell in header)
    out.append("</tr></thead><tbody>")
    for row in body:
        out.append("<tr>")
        out.extend(f"<td>{inline(cell)}</td>" for cell in row)
        out.append("</tr>")
    out.append("</tbody></table>")
    return "".join(out)


def render_markdown(lines: list[str]) -> str:
    out: list[str] = []
    paragraph: list[str] = []
    list_type: str | None = None
    index = 0

    def flush_paragraph() -> None:
        nonlocal paragraph
        if paragraph:
            out.append(f"<p>{inline(' '.join(part.strip() for part in paragraph))}</p>")
            paragraph = []

    def close_list() -> None:
        nonlocal list_type
        if list_type:
            out.append(f"</{list_type}>")
            list_type = None

    while index < len(lines):
        raw = lines[index].rstrip()
        stripped = raw.strip()

        if not stripped:
            flush_paragraph()
            close_list()
            index += 1
            continue

        if stripped.startswith("<") and stripped.endswith(">"):
            flush_paragraph()
            close_list()
            out.append(raw)
            index += 1
            continue

        if stripped.startswith("|") and index + 1 < len(lines) and re.match(r"^\s*\|?\s*:?-+", lines[index + 1]):
            flush_paragraph()
            close_list()
            block = [raw, lines[index + 1].rstrip()]
            index += 2
            while index < len(lines) and lines[index].strip().startswith("|"):
                block.append(lines[index].rstrip())
                index += 1
            out.append(render_table(block))
            continue

        heading = re.match(r"^(#{1,4})\s+(.+)$", stripped)
        if heading:
            flush_paragraph()
            close_list()
            level = len(heading.group(1))
            out.append(f"<h{level}>{inline(heading.group(2))}</h{level}>")
            index += 1
            continue

        bullet = re.match(r"^[-*]\s+(.+)$", stripped)
        ordered = re.match(r"^\d+\.\s+(.+)$", stripped)
        if bullet or ordered:
            flush_paragraph()
            wanted = "ul" if bullet else "ol"
            if list_type != wanted:
                close_list()
                list_type = wanted
                out.append(f"<{wanted}>")
            text = (bullet or ordered).group(1)
            out.append(f"<li>{inline(text)}</li>")
            index += 1
            continue

        if stripped.startswith("> "):
            flush_paragraph()
            close_list()
            out.append(f"<blockquote>{inline(stripped[2:])}</blockquote>")
            index += 1
            continue

        paragraph.append(stripped)
        index += 1

    flush_paragraph()
    close_list()
    return "\n".join(out)


def main() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    css = STYLE.read_text(encoding="utf-8")
    parts = re.split(r"^<!-- PAGE:([^>]+)-->\s*$", source, flags=re.MULTILINE)
    if len(parts) < 3:
        raise SystemExit("No PAGE markers found in Markdown source")

    pages: list[tuple[str, str]] = []
    for position in range(1, len(parts), 2):
        classes = parts[position].strip()
        body = parts[position + 1].strip().splitlines()
        pages.append((classes, render_markdown(body)))

    sections = []
    for number, (classes, body) in enumerate(pages, start=1):
        footer = "" if "cover" in classes.split() else (
            f'<footer class="page-footer"><span>Coretend hardware support proposal</span>'
            f'<span>{number}</span></footer>'
        )
        sections.append(
            f'<section class="page {html.escape(classes, quote=True)}" id="page-{number}" '
            f'data-page="{number}"><div class="page-inner">{body}</div>{footer}</section>'
        )

    document = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="light">
  <title>Coretend - Hardware Support Proposal for Apple</title>
  <style>{css}</style>
</head>
<body>
{''.join(sections)}
</body>
</html>
"""
    OUTPUT.write_text(document, encoding="utf-8")
    print(f"Generated {OUTPUT} from {SOURCE} ({len(pages)} pages)")


if __name__ == "__main__":
    main()
