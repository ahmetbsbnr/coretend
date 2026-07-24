# Logo Migration Plan

Sequencing for logo/icon work, once `BRAND_NAME_CLEARANCE.md` (or the
equivalent doc for whichever name is ultimately approved) reaches
`CLEAR_FOR_ENGINEERING` and `Configuration/BrandRenameApproval.local.json`
exists. **No asset is produced this phase.**

## Sequence

1. **Confirm the visual brief still holds** (`REBRAND_VISUAL_BRIEF.md`) —
   Core Bloom + Orbital Ecology heritage, the three functional pillars,
   the "must not" list — against the actually-approved name (a very
   different-sounding name might suggest a different mark; re-check
   fit, don't assume the brief survives unchanged).
2. **Design the mark** — human-led creative work, not automatable. Output:
   vector source (pick and document a real source-of-truth format —
   `.svg` is the safest cross-tool choice given no vector source exists
   today).
3. **Generate the raster set** from the vector source — extend or replace
   `Resources/Brand/Sources/generate-brand-assets.swift`'s pipeline so app
   icon/menu-bar-template/favicon/OG-image all derive from the same
   source, the same way the current app icon avoids 9 hand-maintained PNG
   sizes.
4. **Populate the gaps in `BRAND_ASSET_MATRIX.md`** one row at a time:
   favicon → OG image → Twitter card → horizontal logo → compact mark →
   light/dark/monochrome variants → DMG background (optional) →
   documentation header images (optional).
5. **Wire into the app bundle**: `Resources/Info.plist`
   (`CFBundleIconFile`), `Scripts/package-local.sh`/`package-dmg.sh`
   (asset copy steps), matching step 7-8 of `PRODUCT_RENAME_PLAN.md`.
6. **Wire into the website**: `Website/generate.py` template updates for
   favicon/OG/Twitter tags, matching step 3 of `PRODUCT_RENAME_PLAN.md`.
7. **Retire old MacCare-Local-branded assets**: move (not delete outright
   in the same commit — a follow-up cleanup commit once the new assets
   are confirmed working end-to-end) the old `AppIcon.iconset`/
   `MenuBarTemplate*` files, so a git history diff clearly shows old→new
   rather than a silent overwrite.

## Non-negotiables

- No asset produced under a `CONFLICT_HIGH` or unapproved name.
- No `®` symbol on anything (no name here has trademark registration).
- Every new asset traces back to a single vector source of truth — no
  hand-maintained per-size PNGs going forward, matching the discipline
  the current `generate-brand-assets.swift` already established for the
  app icon.
- Core Bloom / Orbital Ecology conceptual continuity is a design decision
  to revisit deliberately at step 1, not to silently drop.

## Gate

This entire plan stays inert until `Scripts/check-brand-clearance.sh`
(Section 14) passes for the actually-chosen name.
