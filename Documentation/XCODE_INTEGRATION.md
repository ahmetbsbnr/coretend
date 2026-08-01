# CoreTend Xcode Integration

SwiftPM remains the source of truth. Xcode opens the package from `Package.swift`; the shared files in `.swiftpm/xcode` only define useful schemes and test plans for local development.

## Schemes

- `CoreTend`: Debug app build, launch, profile, archive, and the primary isolated test plan.
- `CoreTendTests`: deterministic unit and integration tests.
- `CoreTendUITests`: XCUIAutomation entry point. Set `CORETEND_UI_APP_PATH` to a built `CoreTend.app`.
- `CoreTendAccessibility`: accessibility contract tests and manual Accessibility Inspector runs.
- `CoreTendPerformance`: deterministic performance smoke tests, intended for Release profiling.
- `CoreTendRelease`: Release launch, profile, analyze, and archive path for future Developer ID signing.

## Isolation

Every Xcode test plan sets:

- `CORETEND_TEST_MODE=1`
- `CORETEND_TEST_STORE_DIR=/tmp/coretend-xcode-*/store`

`Persistence.TestStoreOverride` only accepts an override when both variables are present and the path is under a temporary root. These schemes must not read or migrate the user's real CoreTend data.

## Professional Runs

- Unit and integration: run `CoreTendTests`.
- UI automation: build/package the app, then run `CoreTendUITests` with `CORETEND_UI_APP_PATH` pointing at that `.app`.
- Accessibility: run `CoreTendAccessibility`, then manually verify keyboard-only navigation, VoiceOver, Increase Contrast, Reduce Transparency, Reduce Motion, and enlarged text.
- Instruments: profile `CoreTendPerformance` or `CoreTendRelease` with Time Profiler, Allocations, Leaks, File Activity, Energy, and SwiftUI instruments when available.
- Archive/signing: use `CoreTendRelease`; keep `com.ahmetbsbnr.coretend` and the existing entitlements. Developer ID signing is only valid once a `Developer ID Application` identity is installed.
