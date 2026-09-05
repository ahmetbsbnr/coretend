<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# CoreTend website — product screenshot pipeline

The site shows the **real** CoreTend app UI, never a generative mock-up
(`.claude/rules/site-design.md`). Screenshots live in
`Website/assets/app/screens/` and are derived from the approved capture set
in `Documentation/VisualAudit/After/`.

## Naming

```
Website/assets/app/screens/<module>-<theme>.webp        1600 w  (primary)
Website/assets/app/screens/<module>-<theme>-sm.webp      800 w  (srcset small)
```

- `<module>` ∈ `dashboard storage space-lens duplicates applications
  integrity activity`
- `<theme>` ∈ `light dark`
- Deterministic — no dates, no locale in the filename. (FR captures exist in
  the source set; the site currently uses EN screenshots with localized
  `alt`/caption text. Wiring FR image variants is a P2 follow-up.)

## Source of truth

`Documentation/VisualAudit/After/2026-09-04-en-<theme>-<module>.png` — the
44-capture set accepted by the maintainer on 2026-09-04 (`FEATURE_MATRIX.md`
→ "Visual QA campaign"). All use the synthetic demo dataset; no private user
data, metadata stripped.

## Regenerating (requires `cwebp`)

```sh
SRC=Documentation/VisualAudit/After
DST=Website/assets/app/screens
for m in dashboard storage space-lens duplicates applications integrity activity; do
  for th in light dark; do
    cwebp -quiet -q 78 -resize 1600 0 "$SRC/2026-09-04-en-$th-$m.png" -o "$DST/$m-$th.webp"
    cwebp -quiet -q 74 -resize  800 0 "$SRC/2026-09-04-en-$th-$m.png" -o "$DST/$m-$th-sm.webp"
  done
done
```

Full set ≈ 800 KB. `q 78` / `q 74` keeps them sharp at display size; do not
go below `q 70`.

## Capture parameters (for a fresh capture pass)

| Parameter | Value |
|---|---|
| App window | 1800 × 1264 px source (the VisualAudit harness size) |
| Appearance | one `light` + one `dark` capture per module |
| Dataset | the app's synthetic demo dataset only — never real files |
| Locale | `en` for the site (FR optional) |
| Crop / padding | full app window, no OS chrome, no drop shadow (the site adds its own frame) |
| Post | strip metadata; `cwebp` as above |

## How the site consumes them

`Website/index.html`:
- Hero: `<figure class="shot shot--hero">` → a plain macOS window frame
  (`.shot-frame` / `.shot-bar`) around `dashboard-light/dark`.
- `#modules` gallery: `<figure class="shot">` × 6 (dashboard, storage,
  space-lens, duplicates, applications, integrity).

Every image is a `<picture>` with a `(prefers-color-scheme: dark)` `<source>`,
`srcset` (`-sm` 800 w + 1600 w), `sizes`, explicit `width`/`height`
(`1600×1124`), `loading="lazy"` (hero: `fetchpriority="high"`, no lazy) and
`decoding="async"`. Descriptive `alt`; captions carry `data-fr`.

## HUMAN ASSET CAPTURE REQUIRED

- A dedicated **Smart Scan** screenshot once that app UI is finalized (the
  hero currently uses Dashboard, which is truthful and shipping).
- Refreshed captures when the 1.1 UI (Restore Center, Finder Settings
  section) is merged — the current set is the 1.0 UI.
- Optional FR image variants if the site later localizes screenshots.
