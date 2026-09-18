#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: The CoreTend Authors
"""Fails if a captured window shows an empty NavigationSplitView sidebar.

This exists because the 1.0.1 blank-sidebar defect was invisible to every
other gate the project has. The rows were still in the accessibility tree —
`select row` worked, the UI-test harness was happy — they were simply laid
out at zero width, because a `.fixedSize(horizontal: false, vertical: true)`
on a long Text propagated that Text's ideal, unwrapped width upward as the
detail column's minimum. Only looking at pixels catches it.

Usage:  python3 Scripts/check-sidebar-rendered.py capture1.png [capture2.png ...]
Exits non-zero if any capture's sidebar region is a single flat colour.

No third-party dependency: PNG is inflate + unfilter, both in the stdlib.
"""
import sys
from pathlib import Path

# convert png -> raw rgb via sips to a small BMP is messy; use Python's builtin? Use `sips` to tiff then PIL? No PIL.
# Simplest: use `sips -s format png` and read with a tiny PNG decoder -> too much.
# Use macOS `qlmanage`? No. Use `python3 -c` with zlib PNG decode (PNG is decodable with zlib).
import zlib, struct
def read_png(p):
    d = open(p,'rb').read()
    assert d[:8]==b'\x89PNG\r\n\x1a\n'
    i=8; idat=b''; w=h=None; bd=ct=None
    while i < len(d):
        ln = struct.unpack('>I', d[i:i+4])[0]; typ=d[i+4:i+8]; data=d[i+8:i+8+ln]; i+=12+ln
        if typ==b'IHDR': w,h,bd,ct = struct.unpack('>IIBB', data[:10])
        elif typ==b'IDAT': idat+=data
        elif typ==b'IEND': break
    raw = zlib.decompress(idat)
    ch = {0:1,2:3,3:1,4:2,6:4}[ct]
    assert bd==8, bd
    stride = w*ch
    out=bytearray(); prev=bytearray(stride)
    pos=0
    for y in range(h):
        f=raw[pos]; pos+=1
        line=bytearray(raw[pos:pos+stride]); pos+=stride
        if f==1:
            for x in range(ch,stride): line[x]=(line[x]+line[x-ch])&255
        elif f==2:
            for x in range(stride): line[x]=(line[x]+prev[x])&255
        elif f==3:
            for x in range(stride): line[x]=(line[x]+((line[x-ch] if x>=ch else 0)+prev[x])//2)&255
        elif f==4:
            for x in range(stride):
                a=line[x-ch] if x>=ch else 0; b=prev[x]; c=prev[x-ch] if x>=ch else 0
                pp=a+b-c; pa=abs(pp-a); pb=abs(pp-b); pc=abs(pp-c)
                pr=a if (pa<=pb and pa<=pc) else (b if pb<=pc else c)
                line[x]=(line[x]+pr)&255
        out+=line; prev=line
    return w,h,ch,bytes(out)

failed = []
paths = sys.argv[1:]
if not paths:
    sys.exit("usage: check-sidebar-rendered.py <capture.png> [...]")

for p in sorted(paths):
    w, h, ch, px = read_png(p)
    # The sidebar column, inset from the window edge and from the title bar and
    # the bottom, so neither the traffic lights nor the window chrome can supply
    # the colour variation this check is looking for.
    colours = set()
    for y in range(200, h - 120, 7):
        for x in range(40, 380, 5):
            o = (y * w + x) * ch
            colours.add(px[o:o + 3])
    blank = len(colours) < 12
    if blank:
        failed.append(p)
    print(f"{Path(p).stem:18s} {len(colours):5d} distinct colours  {'BLANK SIDEBAR' if blank else 'ok'}")

if failed:
    sys.exit(f"\n{len(failed)} capture(s) show an empty sidebar: {', '.join(failed)}")
