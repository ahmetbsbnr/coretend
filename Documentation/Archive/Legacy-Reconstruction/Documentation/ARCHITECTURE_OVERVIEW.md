# Architecture Overview

See [ARCHITECTURE.md](ARCHITECTURE.md) for the package inventory and
[SCANCORE.md](SCANCORE.md) for scan safety details. This document records the
current dependency direction and typed analysis flow.

## Module graph

```text
SafetyCore (no module dependencies)
  ↑                 ↑
ScanCore          Persistence
  ↑  ↑                ↑
  │  └── FileRules ────┘
  ├── AppDiscovery
  └── IntegrityCore

SystemMetrics (native Foundation/Darwin providers)
DesignSystem (SwiftUI presentation primitives)

CoreTendApp → ScanCore, FileRules, SafetyCore, Persistence,
              AppDiscovery, IntegrityCore, SystemMetrics, DesignSystem
```

`SafetyCore` owns path approval and destructive-operation checks. `ScanCore`
owns typed read-only analysis contracts and filesystem scan engines. The app
and inventory modules depend on those lower-level contracts; the engines do
not depend on SwiftUI or persistence. `Package.swift` is the source of truth
for exact target edges.

## Typed analysis flow

Each engine returns an `AnalysisReport` with requested roots, start/end times,
status, stable issue codes, and best-known output. Limits bound visited items,
retained results, depth, concurrency, and hash chunks. A missing root, denied
read, unsupported link, metadata/content error, cancellation, or reached cap
cannot silently become a complete empty result. UI adapters retain partial
status; Applications, App Updates, Leftovers, Protection, Cleanup, Duplicates,
Similar Images, and Space Lens show an incomplete-results warning where
applicable. App Updates also retains issue codes for its view-model boundary.

`ScanEngine`, `DuplicateEngine`, `SimilarImagesEngine`, and `SpaceLensEngine`
keep their existing `AsyncStream` APIs as adapters. Completion tests assert one
and only one terminal event (`finished` or `cancelled`) per stream. Stream
termination still cancels the underlying task.

Byte provenance stays explicit. Logical lengths, known local allocated bytes,
unavailable measurements, and remote-only placeholders are separate values.
Space Lens shows cloud placeholders with no local allocation claim; its legacy
`size` accessor returns zero for a remote-only or unknown local size. Cloud
cleanup summaries count local bytes only.

System metrics use `MetricMeasurement<Value>` with optional value, source,
sample time, and typed unavailable reason. Mach, sysctl, volume metadata,
interface counters, and ProcessInfo each have injectable providers. Disk free
and total capacity come from one volume sample. The first network sample is
unavailable because no previous counter exists. Dashboard, Performance, the
menu bar, and sidebar show unavailable values without turning failed reads
into zero or healthy status; sample source and time appear in supporting or
accessibility detail.

## Inventory policies stay separate

`DuplicateEngine` and `SimilarImagesEngine` share issue/result contracts, but
not traversal policy, so they do not share a generic inventory walker.
Duplicate search includes hidden entries, skips package descendants, and
ignores cloud placeholders. Similar-image search skips hidden entries and
package descendants, additionally skips `.photoslibrary` descendants, and
ignores cloud placeholders. Both reject symlinks. Space Lens intentionally
keeps cloud placeholders visible as remote-only nodes. App discovery and
Integrity also have distinct root, hidden-file, depth, and parsing policies.
Capability-specific tests cover shared invariants and selected policy edges;
not every inventory-policy difference has its own fixture. Making one walker
authoritative would change user-visible inventory scope. Walks are
not filesystem snapshots: a concurrent external removal that happens before an
enumerator yields an item may be indistinguishable from an item that was never
in the observed walk. Errors actually encountered while reading an item are
reported as partial results.

## Cleanup scan-to-Trash flow

1. `CleanupView` builds `ScanConfiguration` from `FileRules` and persisted
   exclusions.
2. `ScanCore.ScanEngine` walks roots in a detached task and streams progress
   through the compatibility adapter while the view model uses typed status.
3. Findings are evidence only. The user reviews and explicitly confirms.
4. `SafetyCore.SafetyCenter` revalidates the path immediately before moving it
to Trash. Approval requires a durable, redacted audit event.
5. `Persistence.Store` records the result. Moving an item to Trash does not
   mean its storage has been freed.

Integrity remains read-only. It reports native download metadata, code-signing
validation and login-item metadata; it does not claim malware detection.

## Verification record — 2026-09-26

- `Scripts/test.sh --disable-sandbox --skip-update`: 431 Swift Testing cases
  passed across 12 test runs after temporarily excluding only
  `CoreTendUITests` from `Package.swift`; the manifest was restored byte-for-byte.
  The Xcode UI-test target was not run. Deterministic child metadata failure and
  cancellation at a full-hash chunk boundary pass. Synthetic remote-placeholder
  fixture confirms duplicate analysis skips hashing; live iCloud provider behavior
  remains untested.
- `swift build --disable-sandbox --skip-update -c release --target CoreTendApp`:
  passed. Full executable Release build compiled and linked, then `dsymutil`
  failed with `Operation not permitted`; dSYM generation is an environment
  limitation, not a Swift compile diagnostic.
- `Scripts/repository-doctor.sh`: all checks passed.
- `python3 Scripts/check-copy-honesty.py`: passed, 8 critical EN/FR keys.
- Localization key parity: 585 Base and 585 French keys.
- `git diff --check`: passed at the recorded check point.
