# Build, install and remove local preview

This reconstruction has no public release. Build an unsigned local bundle with `make package-local`; output lives under ignored `Artifacts/`. `make verify-package` checks ZIP integrity, bundle structure, executable and checksum. It does not attest runtime behavior, signature or notarization.

The ZIP contains `CoreTend.app`. Copy it manually to a location you choose, such as `Applications`. macOS may refuse to launch an unsigned app; this preview has no signing identity and no notarization. For development, `swift run CoreTendApp` launches the source-built executable.

To remove the app, move only that copied `CoreTend.app` to Trash in Finder. App data lives separately in `~/Library/Application Support/CoreTend-Reconstruction/`; the app's History screen provides explicit clear-history control. Removing the app does not erase that data. No installer or uninstaller script touches system or user folders.

This local package has not been launched from Finder, installed, signed, notarized, or tested on the minimum macOS version. Do not redistribute it as a release.
