#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: The CoreTend Authors
#
# Renders every mockup in Documentation/Mockups to a PNG beside it, so design
# candidates are compared as pictures. Offline and deterministic.
set -euo pipefail
cd "$(dirname "$0")/.."
out="Documentation/Mockups/Renders"
mkdir -p "$out"
shopt -s nullglob
for html in Documentation/Mockups/[A-Z]*.html; do
  name="$(basename "$html" .html)"
  swift -module-cache-path "${TMPDIR:-/tmp}/coretend-modulecache" Scripts/support/render-html.swift "$html" "$out/$name.png" 1180 800
done
