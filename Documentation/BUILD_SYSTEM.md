# Build System

Swift Package Manager — `swift-tools-version: 6.0`, no CocoaPods/Carthage.
SwiftPM is authoritative for every domain module, service, and test;
`Scripts/build.sh` / `Scripts/test.sh` never need Xcode.

A second, separate lane produces the *shipping* app bundle only:
`CoreTend.xcodeproj` (a tracked artifact generated from `project.yml` by
xcodegen) wraps the SwiftPM code so it can embed two app extensions (a
WidgetKit status widget and a Finder Sync extension), emit the App Intents
metadata bundle, and carry per-target entitlements —
Apple bundle structures SwiftPM cannot express. It is built by
`Scripts/build-xcode.sh` and adds no domain logic of its own. See
[XCODE_INTEGRATION.md](XCODE_INTEGRATION.md).

## Package layout (`Package.swift`)

Executable: `CoreTend` (product name `CoreTend`), which launches the
`CoreTendApp` library target.

Libraries: `ScanCore` (deps: SafetyCore), `SafetyCore` (no deps),
`FileRules` (deps: ScanCore, SafetyCore), `DesignSystem` (no deps),
`Persistence` (dep: SafetyCore), `SystemMetrics` (no deps), `AppDiscovery`
(no deps), `IntegrityCore` (no deps). IntegrityCore reads native macOS
provenance, signature and login-item metadata; it has no scanner subprocess.

Two tiny Foundation-only libraries exist solely so an app extension can link
a minimal shared slice instead of the whole app: `WidgetShared` (widget
snapshot value + IO, shared with the WidgetKit extension) and `FinderShared`
(handoff payload, URL-only selection classification, the `coretend://`
(de)serialiser, and a read-only `SelectionValidator`, shared with the Finder
Sync extension). Neither depends on any destructive module.

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
- `Scripts/package-local.sh` — fast arm64 `.app` + DMG straight from
  SwiftPM, ad-hoc signed, **no extensions / no App Intents metadata bundle**.
  Local dev only.
- `Scripts/build-xcode.sh` — the shipping bundle: unsigned Release `.app`
  via `xcodebuild` with both embedded extensions
  (`CoreTendWidget.appex`, `CoreTendFinder.appex`) and
  `Contents/Resources/Metadata.appintents`, followed by structural
  verification. This `.app` (copied to `build/CoreTend.app`) is the input
  to `Scripts/sign-and-notarize.sh`.

## CI

GitHub Actions runs build/test, distribution and security gates for pull
requests and `main`. Release packaging is also reproducible on a clean macOS
runner; local and CI flows share the scripts above.
