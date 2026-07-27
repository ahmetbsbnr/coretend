# BUILD AND INSTALL

Requirements: macOS 14+, Apple Silicon, Swift CommandLineTools (Xcode not required).

- Debug build: `Scripts/build.sh`
- Release build: `Scripts/build.sh release`
- Tests: `Scripts/test.sh` (do NOT use plain `swift test`; see DECISIONS D2)
- App bundle: `Scripts/package-local.sh` → `build/CoreTend.app` (ad-hoc signed)
- Install: copy the bundle to /Applications.
- Full Disk Access: System Settings → Privacy & Security → Full Disk Access → add app.

Uninstall: delete the app. No helper, agent, or hidden files are installed yet;
UNINSTALL.md will grow as components are added.
