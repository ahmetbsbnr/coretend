# Installer Experience

CoreTend is distributed as an **unsigned, un-notarized** local build. There
is no App Store listing, no paid installer, no license key, and no account. See
[INSTALL_UNSIGNED.md](INSTALL_UNSIGNED.md) and [INSTALLATION.md](INSTALLATION.md)
for the exact commands.

## How you get the app
1. Build from source (`Scripts/build.sh` / `Scripts/package-local.sh`) or take a
   local `.app` / `.dmg` produced by the packaging scripts.
2. On first open of an unsigned app, macOS Gatekeeper warns. You approve it once
   via right-click → Open, or System Settings → Privacy & Security.

## First open
- The app opens the [first-run wizard](FIRST_RUN_STATE_MACHINE.md) when
  `onboardingDone` is false.
- If the app is running from a disk image, Downloads, or a translocated
  temporary location, the wizard offers a **user-space move to Applications**
  (a plain `FileManager` copy to `/Applications`, falling back to
  `~/Applications`, then reveal-for-drag). No `sudo`, no password, no privileged
  helper — nothing is installed outside the app bundle and its
  `~/Library/Application Support/CoreTend` data directory.

## What is never done
- No login item, launch agent, daemon, or background installer.
- No network calls during install or first run.
- No code signing / notarization step (this is a local, unsigned distribution;
  signing is a documented human blocker for any future public release).

## Motion during onboarding
The onboarding uses only the static `CoreBloomMark`; the animated Core Bloom /
Orbital Ecology motion is reserved for real scan state and always honors Reduce
Motion. See [MOTION_SYSTEM.md](MOTION_SYSTEM.md).

## Removal
Uninstall is a manual, documented set of steps — see [UNINSTALL.md](UNINSTALL.md).
Because nothing is installed outside the bundle and one support directory,
removal is deleting those two locations.
