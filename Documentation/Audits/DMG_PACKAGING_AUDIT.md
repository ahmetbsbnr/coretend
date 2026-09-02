<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# DMG packaging audit — 2026-08-09

Everything below was executed for real this session (`Scripts/package-dmg.sh`,
`Scripts/test-dmg-layout.sh`, `Scripts/test-dmg-headless.sh`, plus a manual
`hdiutil attach`/copy/`codesign`/detach cycle), not assumed from reading the
scripts. Split, as instructed, into what's proven and what still needs a
real display session — these are not the same claim.

## Implementation: complete, verified

- **Mechanism**: `dmgbuild` (pure Python, `ds_store`/`mac_alias`) writes the
  window layout directly — no Finder, no AppleScript, no Automation/TCC
  grant. This already replaced an older AppleScript-driven path; that
  replacement is why `0.9.1-rc.2`'s unstyled-DMG bug (missing TCC grant →
  layout pass silently failed → bare Finder window) cannot recur. Confirmed
  by `test-dmg-layout.sh`'s own `no Finder or AppleScript dependency` check.
- **Reproducible build**: ran `package-dmg.sh` twice this session
  (`test-dmg-headless.sh`'s internal run, then a standalone manual run) —
  both produced a DMG that passed every layout/content assertion.
- **Real mount/copy/detach cycle** (this session, not simulated):
  `hdiutil attach` succeeds, volume name reads `CoreTend 0.0.0-manualtest`
  (version-templated correctly), `cp -R CoreTend.app` off the volume
  succeeds, `codesign -dv` on the copy shows a clean ad-hoc signature
  (`flags=0x2(adhoc)`, expected — no Developer ID), `hdiutil detach` is
  clean.
- **Volume contents**: exactly `CoreTend.app` + `Applications` symlink
  visible; `.DS_Store`, `.VolumeIcon.icns`, `.background.tiff` present but
  dot-prefixed (hidden from Finder icon view, confirmed by the layout
  test's `only CoreTend.app and Applications are visible` assertion, not
  just by `ls -la` showing them — `ls -la` intentionally shows dotfiles,
  Finder does not).
- **No clutter**: no README, no loose licence file, no temp files on the
  volume root; licence texts are sealed inside the app bundle.
- **Checksummed**: `SHA256SUMS`/`latest.json` generation already covered by
  `Scripts/test-release-manifest.sh` (part of `ci.yml`'s
  `distribution-check` job, which passed on PR #13, see
  `SESSION_2026-08-09_AUDIT.md` §13).
- **Icon geometry**: `icon_locations` in `Scripts/dmg-settings.py` — CoreTend
  at (170, 215), Applications at (430, 215), 600×400 window, 104pt icons —
  read back correctly from the generated `.DS_Store` by
  `inspect-dsstore`.
- **Background artwork exists and is on-brand**: `DMG-Background.png`
  (600×400) / `@2x.png` (1200×800) both present, both correctly embedded as
  the two representations of one HiDPI TIFF. Visually inspected the source
  PNG this session (not just checked its existence): CoreTend wordmark and
  radar-arc mark, cobalt accent color, "Drag CoreTend to Applications"
  instruction, and an honest "Unsigned build — first launch needs System
  Settings › Privacy & Security" disclosure baked into the artwork itself.
  This is a real, deliberate, on-brand design — not a placeholder gradient
  — contrary to what `TODO.md`'s prior "visually rejected" framing might
  suggest was still the state.

## Visual validation: still pending (cannot be done here)

The above proves the DMG *is* built correctly and *contains* real, on-brand
artwork with correct geometry. It does not prove how it **looks and feels
when a person actually opens it in Finder**:

- Icon-well alignment against the artwork's guide circles, rendered by
  the real macOS Finder (not just coordinate assertions against the
  `.DS_Store` bytes)
- Retina vs. non-Retina rendering in practice
- Contrast/legibility of the instruction text at real screen scale
- The drag-and-drop motion itself feeling right (this was the literal
  complaint in `TODO.md` — "le glisser-déposer est visuellement mauvais")
- Icon shadow/highlight rendering, which `dmgbuild` does not control

This needs a real display session — it is the "DMG visual redesign +
capture" item already tracked as open in the rewritten `TODO.md`, now
narrowed: the *packaging pipeline* is proven solid, so what's left is
purely visual/perceptual judgment on an already-correct artifact, not a
rebuild from scratch.
