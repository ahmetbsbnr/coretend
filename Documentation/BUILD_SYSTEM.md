# Build System

Plain Swift Package Manager — `swift-tools-version: 6.0`, no Xcode project
checked in, no CocoaPods/Carthage.

## Package layout (`Package.swift`)

Executable: `MacCareApp` (product name `MacCareLocal`), depending on every
library target.

Libraries: `ScanCore` (deps: SafetyCore), `SafetyCore` (no deps),
`FileRules` (deps: ScanCore, SafetyCore), `DesignSystem` (no deps),
`Persistence` (no deps), `SystemMetrics` (no deps), `AppDiscovery` (no
deps), `MalwareEngine` (no deps).

Test targets: one per library target that has tests, plus
`MacCareAppTests` for the app layer. See
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
- `Scripts/package-local.sh` — produces `build/MacCare Local.app`, ad-hoc
  signed (no notarization; that's out of scope until a real signed release
  — see `Documentation/PUBLIC_RELEASE_READINESS.md`).

## No CI yet

There is no `.github/workflows/` pipeline as of this writing (tracked as
remaining Open Source Foundation work); everything above must currently be
run locally before a PR.
