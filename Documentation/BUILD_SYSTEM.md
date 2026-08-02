# Build System

Plain Swift Package Manager — `swift-tools-version: 6.0`, no Xcode project
checked in, no CocoaPods/Carthage.

## Package layout (`Package.swift`)

Executable: `CoreTend` (product name `CoreTend`), which launches the
`CoreTendApp` library target.

Libraries: `ScanCore` (deps: SafetyCore), `SafetyCore` (no deps),
`FileRules` (deps: ScanCore, SafetyCore), `DesignSystem` (no deps),
`Persistence` (dep: SafetyCore), `SystemMetrics` (no deps), `AppDiscovery`
(no deps), `IntegrityCore` (no deps). IntegrityCore reads native macOS
provenance, signature and login-item metadata; it has no scanner subprocess.

Test targets: one per library target that has tests, plus app, integration,
accessibility, UI and performance test targets. See
[TESTING.md](TESTING.md).

Platform floor: `.macOS(.v14)`. Default localization: `en`
(`defaultLocalization: "en"` in `Package.swift`) — see
[LOCALIZATION.md](LOCALIZATION.md).

## Why `Scripts/build.sh` / `Scripts/test.sh` and not raw `swift build`/`swift test`

The wrapper scripts pin flags and environment so local runs match what CI
will run, and `Scripts/test.sh` specifically works around a `swift test`
issue tracked in `Documentation/DECISIONS.md` (decision D2) — using plain
`swift test` can hide failures or hang; always use the script.

- `Scripts/build.sh` — debug build.
- `Scripts/build.sh release` — release build; the target must build with
  zero warnings before any commit lands (see `DEVELOPMENT.md`).
- `Scripts/test.sh` — full test suite.
- `Scripts/package-local.sh` — produces an arm64 `.app` and DMG, ad-hoc
  signed when no Developer ID is configured. The release remains explicitly
  unsigned/not notarized until Developer ID work is completed.

## CI

GitHub Actions runs build/test, distribution and security gates for pull
requests and `main`. Release packaging is also reproducible on a clean macOS
runner; local and CI flows share the scripts above.
