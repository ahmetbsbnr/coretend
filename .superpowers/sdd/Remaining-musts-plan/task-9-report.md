# Task 9 report — cloud placeholder local-byte classification

## Change

- Added the `Sendable` `UbiquitousItemMetadataReading` interface and a Foundation implementation that reads only `.isUbiquitousItemKey` resource metadata.
- `LocalScanEngine(metadataReader:)` defaults to that reader, preserving `LocalScanEngine()` call sites. The scanner now injects only the ubiquitous-item flag read; logical size and modification date use their existing Foundation metadata path.
- A cloud-backed fixture proves the logical size remains known, allocated local bytes are unknown, and file data is unchanged. A default-reader local fixture proves allocated bytes remain measured and known.
- Updated UserGuide and Traceability. `cloud.detect` remains `PARTIEL`; File Provider and real cloud behavior remain unqualified.
- No hydration, downloading, network requests, or file content reads were added to production ScanCore metadata handling.

## Verification

1. `swift test --filter ScanCoreTests > /tmp/coretend-task9-red.log 2>&1; result=$?; rg -m 10 'error:|Executed [0-9]+ tests|failed' /tmp/coretend-task9-red.log; exit $result` after adding the tests and before implementation: exit 1 as expected; compilation reported `cannot find type 'UbiquitousItemMetadataReading' in scope`.
2. `swift test --filter ScanCoreTests > /tmp/coretend-task9-focused-final.log 2>&1; result=$?; rg 'error:|Test Suite .ScanCoreTests. passed|Executed 18 tests, with [0-9]+ failures' /tmp/coretend-task9-focused-final.log | tail -8; exit $result` after implementation and normalizing the fake reader's URL path: exit 0; 18 tests, 0 failures. An earlier focused run caught the fixture fake's path-normalization mismatch (1 failing cloud allocation assertion); normalizing both stored and read paths fixed the test fixture.
3. `make qualify > /tmp/coretend-task9-qualify.log 2>&1; result=$?; rg 'Static site checks passed|Traceability complete|Safety audit passed|Install smoke test passed|Executed [0-9]+ tests, with [0-9]+ failures|Build complete!|error:|failed' /tmp/coretend-task9-qualify.log | tail -36; exit $result`: exit 0. Static site checks passed; traceability reported 40 FR/NFR + 51 capabilities; safety audit and install smoke test passed; all test groups passed, including 18 ScanCore, 27 Persistence, 19 Domain, and 11 AppShell tests; app and CLI builds completed.
4. `git diff --check`: exit 0; no output.

Implementation commit: `338b887` (`feat(scan): classify cloud-backed file allocation`). The pre-existing untracked `Documentation/Project/Remaining-musts-plan.md` was left untouched. No manual qualification gate is claimed complete.

Scoped review: no concrete bug or regression found. Reviewer confirmed the default initializer preserves `LocalScanEngine()` call sites, only ubiquitous metadata is injected/read for cloud classification, and `cloud.detect` stays partial pending real provider qualification.
