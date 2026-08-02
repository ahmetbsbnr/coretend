# Build and install

The current public release candidate is
[`v0.9.1-rc.4`](https://github.com/ahmetbsbnr/coretend/releases/tag/v0.9.1-rc.4).
For an end-user install, download the DMG through
[`https://coretend.ahmetbsbnr.com/download`](https://coretend.ahmetbsbnr.com/download),
verify its SHA-256 against the release's `SHA256SUMS`, mount it and drag
`CoreTend.app` to the Applications shortcut. It requires macOS 14 or later on
Apple silicon.

The public build is ad-hoc signed, not Developer ID signed and not notarized.
Follow [the unsigned-install guide](INSTALL_UNSIGNED.md) for the first-launch
Gatekeeper path; never disable Gatekeeper or strip quarantine globally.

## Building from source

Requirements: macOS 14+, Apple Silicon, Swift Command Line Tools (Xcode is not
required for SwiftPM builds).

- Debug build: `Scripts/build.sh`
- Release build: `Scripts/build.sh release`
- Tests: `Scripts/test.sh` (do NOT use plain `swift test`; see DECISIONS D2)
- App bundle: `Scripts/package-local.sh` → `build/CoreTend.app` (ad-hoc signed)
- Install: copy the bundle to `/Applications`.
- Full Disk Access: System Settings → Privacy & Security → Full Disk Access → add app.

Uninstall: delete the app. No helper, agent, or hidden files are installed yet;
UNINSTALL.md will grow as components are added.
