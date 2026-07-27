<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Media Review Report

Preflight: branch `feat/coretend-media-integration`, HEAD `c58596460b504c8c7624018c1ef4e2b709adf749`,
tree clean, tag `v0.9.0` verified (tag object `23cbfa870a3fee0b5ad0ac8be2dae075e309c21b`
→ commit `a6aa3bf20cc1f3b7623291660c4943db2e5d4a50`, unchanged). `TRANSFER_SHA256.txt`:
12/12 files OK.

No media has been transformed. Classification only. All raw files remain untouched
under `$MEDIA_WORKSPACE/CoreTendMedia/raw/`.

## Videos

### 1. `Enregistrement de l'écran 2026-07-27 à 20.40.50.mov`
- 3360×2100, h264, 60fps, 14.16s, no audio track, ReplayKit recording.
- Sequence: Finder window titled "CoreTendDemo" showing `CoreTend-0.9.0-arm64-unsigned.dmg`
  → DMG opened (Applications alias, CoreTend icon, LICENSE, NOTICE, THIRD_PARTY_NOTICES)
  → drag toward Applications.
- Finder sidebar shows generic items + home folder `coretenddemo` (dedicated demo
  account, not personal — acceptable).
- At ~9s an admin authentication dialog appears ("Le Finder souhaite copier «CoreTend».
  Saisissez le nom et le mot de passe...") and remains through end of clip, fields
  empty.
- **Classification: NEEDS_HUMAN_REVIEW**
- Issue: authentication dialog shown from ~9s to end — absolute rule forbids showing
  any authentication UI, regardless of empty fields.
- Usable range: 0.0s–~8.5s (before dialog appears).
- Proposed crop: trim to usable range only; re-verify exact dialog onset frame before
  export.

### 2. `Enregistrement de l'écran 2026-07-27 à 20.42.37.mov`
- 3360×2100, h264, 60fps, 7.76s, no audio.
- Sequence: Finder `/Applications` folder, full listing view.
- Listing exposes real personal applications: AiTools, WhatsApp, Claude, NordVPN,
  Pages, Adobe Lightroom CC, Visual Studio Code, Disk Space Analyzer, Atlas, Canon
  Utilities, Windows App, Adobe Creative Cloud, Spotify, Utilities, and more.
- **Classification: REJECTED**
- Issue: real personal application inventory, not a dedicated/minimal demo account
  state. Contradicts capture guide requirement ("no personal... unneeded applications
  closed").
- Usable range: none.
- Not integrated. Not deleted (kept in raw/).

### 3. `Enregistrement de l'écran 2026-07-27 à 20.57.25.mov`
- 3360×2100, h264, 60fps, 7.99s, no audio.
- Sequence: System Settings → Privacy & Security → real Gatekeeper block message
  ("CoreTend a été bloqué afin de protéger votre Mac") → "Ouvrir quand même".
- At final frame an admin authentication dialog appears with username field labeled
  and empty password field.
- **Classification: NEEDS_HUMAN_REVIEW**
- Issue: same authentication-dialog rule as clip 1 — ends in an auth prompt.
- Usable range: 0.0s–just before the auth dialog appears (needs frame-exact cut).
- Proposed crop: trim before dialog onset.

### 4. `Enregistrement de l'écran 2026-07-27 à 20.57.56.mov`
- 3360×2100, h264, 60fps, 9.11s, no audio.
- Frame 1 (first sampled frame, ~0s) shows the admin authentication dialog with a
  **typed username ("corentendinstaller"-like string) and password field showing
  dots** — active credential entry.
- Later frames show a clean "Welcome to CoreTend" onboarding screen.
- **Classification: REJECTED**
- Issue: absolute rule — never show a password or authentication. This raw capture
  itself contains live credential entry, not just an empty prompt. Reject the whole
  file; do not attempt to salvage by trimming, given the sensitivity of the exposed
  material.
- Usable range: none certified from this file. If the onboarding screen is wanted,
  it must be re-captured as its own clip that never touches the auth dialog.

### 5. `Enregistrement de l'écran 2026-07-27 à 21.03.21.mov`
- 3360×2100, h264, 60fps, 6.11s, no audio.
- Sequence: CoreTend "Smart Care" main screen ("Ready to look after this Mac",
  Cleanup/Protection cards) → app closes → bare desktop wallpaper for remainder.
- Menu bar shows a generic system notification-permission toast ("Notifications •
  CoreTend • ..."), not personal.
- **Classification: NEEDS_HUMAN_REVIEW**
- Issue: no personal data found, but trailing ~2s is dead air (empty desktop) after
  app quits — should be trimmed for pacing, not for privacy.
- Usable range: 0.0s–~4s (Smart Care screen visible).

### 6. `coretend-step-01-download-dmg-raw.mov`
- 3360×2100, h264, 60fps, 7.42s, no audio.
- Sequence: Safari, single tab, official CoreTend Download page, version 0.9.0,
  ZIP/DMG SHA-256 fields, "unsigned"/"not notarized" notices.
- Native-resolution visual reinspection (3360×2100; not OCR-only) confirms the
  address bar normally displays the exact official domain `coretend.ahmetbsbnr.com`.
  The earlier report reading `coretend.almetidev.com` was incorrect.
- However, after the DMG link is activated, the address bar visibly changes at
  ~3.0s–~3.4s: first to `github.com`, then to
  `release-assets.githubusercontent.com`, before returning to the official domain.
- No personal bookmarks, no other tabs, no visible personal browser data.
- **Classification: NEEDS_RECAPTURE**
- Issue: although the official domain is correctly shown for most of the clip, the
  capture also displays other domains during the download redirect. The supplied
  rule requires NEEDS_RECAPTURE or REJECTED whenever another domain is displayed.
- Usable range: none certified for integration. Human verification point if any
  partial reuse is considered: the address-bar transition at ~3.0s–~3.4s. Prefer a
  fresh capture in which the address bar never leaves the official domain.

### 7. `coretend-step-03-gatekeeper-blocked-raw.mov`
- 926×880 (cropped window capture, not full screen), h264, 60fps, 7.73s, no audio.
- Sequence: real macOS Gatekeeper dialog "Élément «CoreTend» non ouvert" — "Apple n'a
  pas pu confirmer que «CoreTend» ne contenait pas de logiciel malveillant...", with
  "Placer dans la corbeille" / "Terminé" buttons, on a plain gradient background.
- No personal data, no machine name, no auth prompt, no extra chrome.
- **Classification: ACCEPTED**
- Usable range: full clip.

## Metadata (all files)

`mdls` shows `kMDItemAuthors = ReplayKitRecording` on all seven, no `kMDItemCreator`,
no `kMDItemWhereFroms`, no `kMDItemUserTags`. No extended attributes (`xattr -l`
empty on all). No embedded personal identifiers found via `ffprobe`/`mdls` metadata
inspection. Metadata still must be stripped at export time per Phase 4 regardless.

## Screenshots

### 1. `coretend-additional-screen-review.png`
- Audited authorized working copy only:
  `$MEDIA_WORKSPACE/processing/incoming/coretend-additional-screen-review.png`.
  The original was not opened or modified.
- SHA-256:
  `553aee4b6ab844b18911ff6475d8cf0242bba0a64a8efccf1135a2659ed5e68e`.
- 660×806, PNG, 293 kB (approximately 286 KiB), 8-bit RGBA, non-interlaced.
- Exact visible content: CoreTend menu-bar popover showing CPU 23%, Memory 66%
  (normal), Free space 36.74 GB, Thermal Nominal, Protection warning "ClamAV not
  installed", "Last Smart Care: Smart Care scan: 75437 items", "6 j et 4 h", and
  the buttons "Open CoreTend", "Settings...", and "Quit".
- Visible surroundings: a narrow strip of generic macOS wallpaper and menu-bar
  status icons (CoreTend, generic utility/status icons, generic user silhouette,
  AirPods, Wi-Fi, and a partially cropped status icon). No app or document window is
  visible in the background.
- Privacy inspection: no URL; account name; machine name; local path; browser
  favorite; browser extension; tab; notification; document; authentication UI;
  password; email address; or direct personal identifier. The resource figures,
  scan item count, elapsed time, and generic connected-AirPods icon are indirect
  device-state information but do not identify a person, account, machine, file, or
  location.
- Metadata inspection (`exiftool`, PNG chunks, and extended attributes): screenshot
  markers, 2026 Apple display ICC profile, 144 dpi, dimensions, generic
  `UserComment=Screenshot`, and macOS screenshot extended attributes. No author,
  username, machine name, path, GPS, URL, account, or other personal identifier was
  found. Strip ancillary metadata and extended attributes from any exported asset.
- The verdict is based on full pixel-level and metadata inspection, not merely on
  the fact that the image is cropped.
- **Classification: ACCEPTED**

### 2. New Smart Care application screenshot
- The user identified the newest screenshot in Downloads for review. Only that
  exact recent PNG was inspected; no other Downloads content was searched.
- Source SHA-256:
  `08421c6247fd472e7fbabebf639d37d2e124b6569d4d917a6a9d9ce829a7ad73`.
- 2024×1488, PNG, 562 kB source, 8-bit RGBA, non-interlaced.
- Exact visible content: CoreTend's dark Smart Care idle screen, navigation,
  “Ready to look after this Mac”, the scan button, and waiting/not-available
  category states.
- Privacy inspection: the capture contains only the CoreTend window on a
  transparent/black surround. No desktop, other application, account, machine
  name, path, URL, notification, file, authentication UI, or personal data is
  visible.
- Metadata inspection found only generic screenshot markers, dimensions,
  resolution, and a display ICC profile. No author, username, path, GPS, URL,
  account, or device name was present.
- Approved exports:
  `Website/assets/app/smart-care.png` and
  `Website/assets/app/smart-care.webp`. Both have metadata and extended
  attributes removed. Exact hashes and sizes are recorded in
  `Documentation/SCREENSHOT_MANIFEST.md`.
- Version labeling: treated as a post-v0.9.0 development-interface capture.
  It must not be represented as included in the immutable 0.9.0 binary.
- **Classification: ACCEPTED**

The prohibited Chrome capture from 21.23.01 (tabs, favorites, and extensions
visible) was not used and must never be integrated.

## Summary

| File | Classification |
|---|---|
| 20.40.50.mov | NEEDS_HUMAN_REVIEW (trim before auth dialog) |
| 20.42.37.mov | REJECTED (personal Applications listing) |
| 20.57.25.mov | NEEDS_HUMAN_REVIEW (trim before auth dialog) |
| 20.57.56.mov | REJECTED (live credential entry visible) |
| 21.03.21.mov | NEEDS_HUMAN_REVIEW (trim trailing dead air) |
| coretend-step-01-download-dmg-raw.mov | NEEDS_RECAPTURE (other domains visible at ~3.0s–~3.4s) |
| coretend-step-03-gatekeeper-blocked-raw.mov | ACCEPTED |
| coretend-additional-screen-review.png | ACCEPTED |
| newest Smart Care application screenshot | ACCEPTED |

No raw original has been deleted, modified, or added to Git. Production may use
only ACCEPTED media or explicitly human-approved ranges that contain no private
data. It must exclude all REJECTED and NEEDS_RECAPTURE media and wait for
explicit human confirmation on every NEEDS_HUMAN_REVIEW range above.
