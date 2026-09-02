# Testing

Run with `Scripts/test.sh` (never plain `swift test` — see
[BUILD_SYSTEM.md](BUILD_SYSTEM.md) / `Documentation/DECISIONS.md` D2).

## Suites (one XCTest/Swift Testing target per library, plus the app)

- `SafetyCoreTests` — `PathValidator` protected-root rejection, symlink
  traversal, allowlist enforcement.
- `ScanCoreTests` — `ScanEngine` streaming/cancellation, `ScanRule`
  filtering, `SpaceLensEngine` sizing/bucketing.
- `FileRulesTests` — built-in rules stay in sync with their deletion
  allowlists (this pairing is deliberately tested, not just documented).
- `DesignSystemTests` — semantic color/brand adaptation.
- `PersistenceTests` — `Store`/`Database` (migrations, exclusions,
  activity records).
- `SystemMetricsTests` — `MetricsCollector` snapshot plausibility.
- `AppDiscoveryTests` — app discovery/quarantine-attribute reads.
- `IntegrityCoreTests` — download provenance, native signature tiers and
  login-item parsing, including malformed-input behavior.
- `CoreTendAppTests` — view-model level tests (e.g. duplicate-engine
  totals, large-result-set behavior — see `engineStreamsAllFindingsUncappedAt5001`).
- `CoreTendIntegrationTests`, `CoreTendAccessibilityTests`,
  `CoreTendPerformanceTests` and `CoreTendUITests` cover cross-module,
  accessibility, performance and packaged-application contracts.

The rc.5 candidate must not regress below the recorded 338 Swift tests. Run
`Scripts/test.sh`, Debug/Release builds and the Xcode/package gates before
committing or packaging.

## Writing new tests

Uses [swift-testing](https://github.com/apple/swift-testing) style
(`@Test`, `#expect`) alongside XCTest where already present — match the
style already used in the target you're editing. Prefer a real, small
in-memory/temp-directory fixture over mocking `FileManager` — several
suites already create temp dirs and clean them up; follow that pattern
rather than inventing a new one.

## What's tested that matters for safety

Anything that changes `SafetyCore.PathValidator`, `FileRules` allowlists or
the confirmed Trash path needs a test that proves the invariant (protected
root rejected, symlink escape rejected, execution-time revalidation and no
unconfirmed action). These are the paths where a regression would be most
damaging.
