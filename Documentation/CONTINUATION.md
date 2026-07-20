# CONTINUATION

## Where we are (v0.2.0)
All 10 sidebar modules are real and functional. 46 tests green, 0 warnings,
Release app packaged. See PROJECT_STATE.json + FEATURE_MATRIX.md.

## Toolchain (unchanged, read first)
- No Xcode — CommandLineTools only. Build `swift build`, tests **only** via
  `Scripts/test.sh`, bundle via `Scripts/package-local.sh`.
- After changing a public struct's stored layout, run `rm -rf .build` once —
  SwiftPM incremental builds have produced corrupted cross-module reads twice.

## Next step (in order)
1. Privacy Cleaner: browser profile detection (Safari limited by TCC; Chrome/Firefox
   profiles under ~/Library/Application Support), sizes per category, sqlite backup
   before any modification, refuse when browser running.
2. App Updater: read Sparkle SUFeedURL from installed apps' Info.plist, compare
   versions, open official page. No downloads.
3. FSEvents watcher on ~/Downloads feeding Protection (only if ClamAV present).
4. Accessibility pass (labels on toggles/buttons, focus order).
5. fr localization.

## Gotchas accumulated
- DirectoryEnumerator iteration is banned in async contexts → sync static helpers.
- /var vs /private/var: use ScanConfiguration.canonical for path comparisons.
- @Observable stored property initializers cannot reference covariant Self.

## v0.4.0 — Visual Foundation (2026-07-20)
- Direction: Orbital Ecology / Core Bloom. Tout est documenté dans
  VISUAL_DIRECTION.md, BRAND_SYSTEM.md, DESIGN_TOKENS.md, MOTION_SYSTEM.md,
  VISUAL_AUDIT.md (+ bugs données à corriger), VISUAL_QA.md, ASSET_PIPELINE.md.
- QA visuelle: `Scripts/capture.sh out.png "Nom Module"` sur le bundle réel;
  clair via defaults NSRequiresAquaSystemAppearance.
- Assets: régénérer via swift Resources/Brand/Sources/generate-brand-assets.swift
  + iconutil (voir ASSET_PIPELINE.md). package-local.sh copie dans le bundle.
- Reprise: densifier identités secondaires des modules (voir VISUAL_QA tableau),
  puis corriger les 2 bugs données notés dans VISUAL_AUDIT.md.
