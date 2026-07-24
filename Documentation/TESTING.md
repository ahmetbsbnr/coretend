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
- `MalwareEngineTests` — `ClamAVScanner` output parsing, `Quarantine`
  move/restore/delete round-trip.
- `CoreTendAppTests` — view-model level tests (e.g. duplicate-engine
  totals, large-result-set behavior — see `engineStreamsAllFindingsUncappedAt5001`).

As of this session: 83 tests, 0 failing, 0 warnings on release build. This
must stay true after every change — run `Scripts/test.sh` and
`swift build -c release` before committing.

## Writing new tests

Uses [swift-testing](https://github.com/apple/swift-testing) style
(`@Test`, `#expect`) alongside XCTest where already present — match the
style already used in the target you're editing. Prefer a real, small
in-memory/temp-directory fixture over mocking `FileManager` — several
suites already create temp dirs and clean them up; follow that pattern
rather than inventing a new one.

## What's tested that matters for safety

Anything that changes `SafetyCore.PathValidator`, `FileRules` allowlists,
or `Quarantine` move/restore logic needs a test that proves the invariant
(protected root rejected, symlink escape rejected, restore returns exact
original path) — these are the paths a regression would be most damaging
on.
