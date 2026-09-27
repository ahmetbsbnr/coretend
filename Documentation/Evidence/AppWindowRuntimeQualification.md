# Isolated macOS app-window observation

**Date:** 2026-09-27
**Host:** arm64, macOS 27.0
**Scope:** Release app launch and on-screen window observed on arm64/macOS 27.0; install-to-runtime smoke uses a temporary `.app` fixture in the current GUI session.

The runtime smoke copies the Release executable into a temporary `CoreTend.app`, installs it through `Scripts/install_local.sh` into a temporary `HOME/Applications`, then launches that installed bundle executable. After observing fixture SQLite, it stops and waits for the process, scans again for sidecars produced during shutdown, uninstalls only the app with `--keep-data`, and confirms the installed bundle is gone while the fixture database remains. `HOME`, `CFFIXED_USER_HOME`, `TMPDIR`, and the explicit CoreTend test store stay under the fixture root. In test mode, `CoreTendPreferences` reads only `CORETEND_TEST_*` overrides and skips `UserDefaults.standard` reads/writes. Runtime checks the expected database and scans the fixture for SQLite database/journal/WAL/SHM files outside the declared store; none were found before or after shutdown.

CoreGraphics observed an on-screen window named `CoreTend`. Accessibility inspection found the first-run sheet and French title/scope/privacy text. A nine-launch matrix supplied each of eight known `CORETEND_TEST_LAST_DESTINATION` values, then one obsolete value; each window exposed the expected localized destination heading, and obsolete ID opened Overview. These are fixture overrides, not reads of persisted production preferences.

The named-window and AX observations came from the temporary bundle launch; the install-to-runtime smoke separately proves fixture install, installed executable startup, app-only uninstall, and store preservation. This does not verify production `UserDefaults` persistence, sidebar mouse/keyboard activation, spoken VoiceOver output, Dynamic Type, zoom, contrast, motion settings, Finder/Launch Services launch, interactive uninstall, signature/notarization, or another macOS version. FR-01 and `shell.nav` remain `PARTIEL`; FR-14 and NFR-07 remain `PARTIEL`.

## Menu-bar scene launch — 2026-09-27

The Release install-to-runtime smoke now sets `CORETEND_TEST_MENU_BAR_ENABLED=1` within its temporary HOME/store fixture. The app remained alive for 12 Internet-socket samples, opened SQLite only beneath the fixture store, and was removed by the fixture uninstaller. This proves the enabled MenuBarExtra scene does not prevent isolated app startup. The smoke does not inspect rendered menu visibility, open the menu window, activate a command, wait for the 30-second refresh, or observe task cancellation on close; those native behaviors remain unqualified.

## Fresh-store launch race — 2026-09-27

An AX-driven Debug launch with isolated `HOME`, `CFFIXED_USER_HOME`, `TMPDIR`, preference overrides and SQLite store exposed `Données locales indisponibles.` on Overview. The app shell and Saved Files view each opened a store connection and could race their initial migrations. A two-connection SQLite fixture reproduced the stale-version migration failure while both waited for `BEGIN IMMEDIATE`; migration now rereads `user_version` under the acquired lock. After the fix, the same AX launch and Overview selection showed the normal empty Favorites and Recents state without a store error, and SQLite existed only under the explicit fixture store. The temporary root was removed after the process exited. This qualifies one Overview runtime path on this host; it does not qualify persistent production preferences or other native accessibility criteria.

## Keyboard command-palette route — 2026-09-27

In a temporary `.app` bundle on arm64/macOS 27 with isolated HOME/preferences/store, keyboard automation sent `⌘K`; AX found the palette search field focused. It typed `Performances`, sent Return, and AX then exposed Performance metrics/history content in the main window. The app was stopped before the fixture root was removed. This proves one keyboard route through the palette in the fixture bundle. It does not verify arrow movement among multiple results, Settings activation, sidebar arrow behavior, or VoiceOver speech.

## Packaged app install-to-runtime — 2026-09-27

`make app-runtime-smoke` now builds the actual Release `.app` and ZIP in a unique temporary artifact directory, validates the bundle plist/archive/Mach-O, installs that packaged `.app` into fixture `HOME/Applications`, launches the installed executable, then removes the app while preserving its fixture database. The runtime remained alive through 14 Internet-socket samples with none open; SQLite database and sidecars remained under the explicit fixture store before and after shutdown. SHA-256 of the tested temporary ZIP: `5904b8efb73fac47054153a2ca578204b7399c30b0e09cd62824112f4b388868`.

This closes the previous gap where runtime smoke rebuilt a synthetic bundle around the Release executable. It still does not qualify Finder/Launch Services, interactive GUI uninstall, signature/notarization, or the minimum macOS host; FR-14 stays `PARTIEL`.
