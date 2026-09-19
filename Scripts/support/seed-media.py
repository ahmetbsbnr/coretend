#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: The CoreTend Authors
"""Writes a small PNG. Used by seed-cleanup-home.sh to give the Similar
images lens something to look at: real pixels, because Vision is doing the
looking and a file with a .png extension and random bytes is not an image.

usage: seed-media.py <out.png> <width> <height> <phase>
"""
import sys, zlib, struct, math
out, w, h, phase = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), float(sys.argv[4])
rows = bytearray()
for y in range(h):
    rows.append(0)  # filter: none
    for x in range(w):
        # A smooth two-axis gradient with a soft blob, so two renderings at
        # different sizes are visually the same picture rather than noise.
        r = int(127 + 120 * math.sin(phase + x / (w / 6)))
        g = int(127 + 120 * math.sin(phase + y / (h / 5)))
        b = int(200 * math.exp(-(((x - w * 0.6) ** 2 + (y - h * 0.4) ** 2) / (0.08 * w * h))))
        rows += bytes((max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b))))
def chunk(kind, data):
    return (struct.pack(">I", len(data)) + kind + data
            + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF))
png = (b"\x89PNG\r\n\x1a\n"
       + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
       + chunk(b"IDAT", zlib.compress(bytes(rows), 6))
       + chunk(b"IEND", b""))
open(out, "wb").write(png)
print(out)
