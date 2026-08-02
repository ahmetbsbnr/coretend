# CoreTend Xcode Integration

SwiftPM remains the source of truth. Xcode opens the package from `Package.swift`; the shared files in `.swiftpm/xcode` only define useful schemes and test plans for local development.

## Schemes

- `CoreTend`: Debug app build, launch, profile, archive, and the primary isolated test plan.
- `CoreTendTests`: deterministic unit and integration tests.
- `CoreTendUITests`: UI contract source retained for a future native Xcode UI-test target. SwiftPM currently emits this test target as a unit-test bundle, so `XCUIApplication` is unsupported and these eight tests skip with that explicit reason rather than pretending to run.
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
- Artifact UI: build/package the app, launch it with `CORETEND_TEST_MODE=1` plus a validated temporary store, then use `Scripts/capture.sh` for the live window/navigation matrix. The current SwiftPM `CoreTendUITests` target is not counted as executed XCUI coverage; it needs a native Xcode UI-test product before `XCUIApplication` can run.
- Accessibility: run `CoreTendAccessibility`, then manually verify keyboard-only navigation, VoiceOver, Increase Contrast, Reduce Transparency, Reduce Motion, and enlarged text.
- Instruments: profile `CoreTendPerformance` or `CoreTendRelease` with Time Profiler, Allocations, Leaks, File Activity, Energy, and SwiftUI instruments when available.
- Archive/signing: use `CoreTendRelease`; keep `com.ahmetbsbnr.coretend` and the existing entitlements. Developer ID signing is only valid once a `Developer ID Application` identity is installed.
