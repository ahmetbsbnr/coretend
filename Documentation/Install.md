# Build, install and remove local preview

This reconstruction has no public release. Build an unsigned local bundle with `make package-local`; output lives under ignored `Artifacts/`. `make verify-package` checks ZIP integrity, bundle structure, executable and checksum. It does not attest runtime behavior, signature or notarization.

The ZIP contains `CoreTend.app`. Install by naming both source bundle and an existing destination directory; installer never selects a destination, replaces an existing app, asks for elevation, launches the app, or removes app data:

```sh
bash Scripts/install_local.sh --app Artifacts/CoreTend.app --destination "$HOME/Applications"
```

`make install-smoke` verifies installer behavior against a synthetic app. `make verify-install-package` rebuilds the release bundle and installs that actual bundle into a temporary HOME fixture, then checks duplicate/symlink refusal. Neither command launches the app. macOS may refuse to launch the unsigned app; this preview has no signing identity or notarization. For development, `swift run CoreTendApp` launches the source-built executable.

For an isolated process test, set both `CORETEND_TEST_MODE=1` and `CORETEND_TEST_STORE_DIR` to an existing fixture directory under the system temporary directory. Set `HOME` and `CFFIXED_USER_HOME` to the same temporary profile there. The app opens SQLite under the selected store directory; a partial, mismatched, missing, or symlinked setup fails closed instead of using the user store. The test mode changes no production default path.

To remove the app while preserving its local data, use Finder or run the local uninstaller in its default dry-run mode:

```sh
bash Scripts/uninstall_local.sh --app "$HOME/Applications/CoreTend.app"
```

`--keep-data` removes only the explicitly named app bundle after confirmation. `--remove-all` also removes the current app data directory and its preferences; it requires confirmation unless `--yes` is supplied. Legacy data from the former MacCare app is never selected unless `--include-legacy` is explicitly added. That option can be combined with either removal mode; legacy paths are removed last. The script accepts no elevation and uses a strict path list. `make uninstall-smoke` exercises dry-run, current-only removal, legacy opt-in and symlink refusal under an isolated temporary HOME. Review every displayed path before confirming; removed data cannot be restored by this script.

The local installer has only been exercised against a synthetic app and temporary destination. The production package has not been launched from Finder, installed, signed, notarized, or tested on the minimum macOS version. Do not redistribute it as a release.

`make app-runtime-smoke` builds the Release executable, wraps it in a temporary `.app` fixture, and launches it with `HOME`, `CFFIXED_USER_HOME`, `TMPDIR`, and the explicit test-store override under one temporary root. It requires the process to remain alive for eight seconds and SQLite to appear only under the fixture store. This confirms isolated runtime startup; it does not verify a visible Finder launch, window rendering, signing, or notarization.
