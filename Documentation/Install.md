# Build, install and remove local preview

This reconstruction has no public release. Build an unsigned local bundle with `make package-local`; output lives under ignored `Artifacts/`. `make verify-package` checks ZIP integrity, bundle structure, executable and checksum. It does not attest runtime behavior, signature or notarization.

The ZIP contains `CoreTend.app`. Install by naming both source bundle and an existing destination directory; installer never selects a destination, replaces an existing app, asks for elevation, launches the app, or removes app data:

```sh
bash Scripts/install_local.sh --app Artifacts/CoreTend.app --destination "$HOME/Applications"
```

`make install-smoke` verifies installer behavior against a synthetic app. `make verify-install-package` rebuilds the release bundle and installs that actual bundle into a temporary HOME fixture, then checks duplicate/symlink refusal. Neither command launches the app. macOS may refuse to launch the unsigned app; this preview has no signing identity or notarization. For development, `swift run CoreTendApp` launches the source-built executable.

To remove the app, move only that copied `CoreTend.app` to Trash in Finder. App data lives separately in `~/Library/Application Support/CoreTend-Reconstruction/`; the app's History screen provides explicit clear-history control. Removing the app does not erase that data. No uninstaller script touches system or user folders.

The local installer has only been exercised against a synthetic app and temporary destination. The production package has not been launched from Finder, installed, signed, notarized, or tested on the minimum macOS version. Do not redistribute it as a release.
