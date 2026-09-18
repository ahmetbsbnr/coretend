#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: The CoreTend Authors
"""Writes an index.html beside a folder of matrix captures: one row per
module, columns per appearance × size, so the product can be read across at
once (docs/REMAINING_WORK.md I-01)."""
import pathlib, sys, re, html
folder = pathlib.Path(sys.argv[1])
rows = {}
for png in sorted(folder.glob("*.png")):
    m = re.match(r"(.+?)-(.+?)-(dark|light)-(compact|standard|large)\.png", png.name)
    if not m: continue
    module, state, appearance, size = m.groups()
    rows.setdefault((module, state), {})[(appearance, size)] = png.name
cols = [(a, s) for a in ("light", "dark") for s in ("compact", "standard", "large")]
out = ["<!doctype html><meta charset=utf-8><title>CoreTend captures</title>",
       "<style>body{font:13px -apple-system,sans-serif;margin:20px;background:#f4f5f7}"
       "table{border-collapse:collapse}th,td{padding:6px;vertical-align:top;text-align:left}"
       "img{width:300px;border:1px solid #ccc;border-radius:4px;display:block}"
       "th{position:sticky;top:0;background:#f4f5f7}</style>",
       "<h1>CoreTend — capture matrix</h1><table><tr><th>module · state</th>"]
out += [f"<th>{a} · {s}</th>" for a, s in cols]
out.append("</tr>")
for (module, state), cells in rows.items():
    out.append(f"<tr><th>{html.escape(module)}<br><small>{html.escape(state)}</small></th>")
    for c in cols:
        name = cells.get(c)
        out.append(f'<td><a href="{name}"><img src="{name}" alt="{name}"></a><small>{name}</small></td>' if name else "<td>—</td>")
    out.append("</tr>")
out.append("</table>")
(folder / "index.html").write_text("\n".join(out))
print(folder / "index.html")
