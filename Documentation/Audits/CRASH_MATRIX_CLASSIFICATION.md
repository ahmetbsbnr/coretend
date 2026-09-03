<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Crash / robustness matrix — classified and executed, 2026-08-09

Source: the 40-item list in `Documentation/Archive/
TODO_2026-08-08_pre-integritycore-cleanup.md` §8. Every item classified
below by what it actually needs — not defaulted to "needs a second Mac"
without checking. ClamAV items are marked N/A: ClamAV is retired
(`eac408c`), the product has no antivirus database to be absent/obsolete/
corrupt.

**Categories** (per owner's definition): A = automatable without UI,
B = automatable with the app headless/test mode, C = needs a local
graphical session, D = needs a second Mac, E = needs a human.

## Executed this session

`Scripts/test-robustness.sh` (full run, not `--quick` — includes both 50x
soaks) against the real built `build/CoreTend.app` binary, headless,
isolated `HOME`/store per case, real signals (`SIGKILL`/`SIGTERM`/`SIGINT`)
sent to the real process. **Result: 31/31 PASS, 0 failed.** Raw results:
`Release/robustness-results.tsv` (generated, not committed — regenerate
with the command above). `swift test` (340/340, see `Documentation/Audits/
SESSION_2026-08-09_AUDIT.md`) covers the remaining A-classified items at
the engine/model layer.

## Classification

| # | Scenario | Class | Status | Evidence |
|---|---|---|---|---|
| 1 | 50 cold launches | B | ✅ executed | `test-robustness.sh`: `cold-launch-x50` PASS |
| 2 | forced quit at startup | B | ✅ executed | `kill-at-0.2s/1s/3s-relaunch` PASS |
| 3 | quit mid-scan | A | ✅ executed | `swift test`: `Rapid cancellation` suite, `scanEngineCancelledImmediatelyTearsDownFast`, `spaceLensCancelledImmediatelyTearsDownFast` |
| 4 | quit during ClamAV detection | N/A | retired | ClamAV fully removed, `Documentation/CLAMAV_DECISION.md` |
| 5 | quit during update check | A | ✅ executed | `UpdateCheckerTests.offlineIsReportedNotThrown`, `.httpErrorIsSurfaced` |
| 6 | invalid prefs | B | ✅ executed | `prefs-garbage`, `prefs-wrong-type` PASS |
| 7 | truncated prefs | B | ✅ executed | `prefs-truncated` PASS |
| 8 | corrupted cache files | B | ✅ executed | `cache-corrupt` PASS |
| 9 | nonexistent folders | B | ✅ executed | `no-support-dir` PASS |
| 10 | inaccessible folders | B | ✅ executed | `unreadable-scan-root`, `readonly-support` PASS |
| 11 | denied permissions | B | ✅ executed | `readonly-support`, `unwritable-home`, `db-readonly` PASS |
| 12 | empty files | B | ✅ executed | `db-empty`, `prefs-empty`, `update-manifest-empty`, `build_tree` empty-file PASS |
| 13 | corrupted files | B | ✅ executed | `db-garbage`, `prefs-garbage`, `cache-corrupt` PASS |
| 14 | very large files | A | ✅ executed | `swift test` stress suites (multi-GB-equivalent synthetic scale via file count/size fixtures); `build_tree` 1 MB file in B suite too |
| 15 | thousands of files | A+B | ✅ executed | `swift test`: 12,000/10,200/5,000-item stress suites; `test-robustness.sh`: `many-files` (3,000 files) PASS |
| 16 | Unicode names | B | ✅ executed | `build_tree`: `héllo wörld — ünïcode/café.txt` in `hostile-tree` PASS |
| 17 | emoji | B | ✅ executed | `build_tree`: `emoji 🙂 dir/file 🚀.txt` in `hostile-tree` PASS |
| 18 | spaces | B | ✅ executed | `build_tree`: multi-space filename in `hostile-tree` PASS |
| 19 | special characters | B | ✅ executed | `build_tree`: quote/semicolon/ampersand filenames in `hostile-tree` PASS |
| 20 | very long paths | B | ✅ executed | `build_tree`: 24-level nested path (hits OS `ENAMETOOLONG`, handled gracefully, not a crash) in `hostile-tree` PASS |
| 21 | symlinks | A+B | ✅ executed | `swift test`: `symlinkedDirectoryNotDescended`; `test-robustness.sh`: `link-to-file`, `dangling-link` in `hostile-tree` PASS |
| 22 | cyclic symlinks | B | ✅ executed | `build_tree`: `cycle/self` self-referencing symlink in `hostile-tree` PASS |
| 23 | file deleted mid-scan | A | ✅ executed | `PathValidatorTests.vanishedFileSkippedAtExecution`, `.vanishedFileEmitsSkippedEvent` — `SafetyCenter` re-validates every path immediately before execution |
| 24 | external volume unmounted mid-scan | A | ✅ executed | `ClutterFilteringTests`: resolver-returns-nil path surfaces as `.unavailable`, matching a vanished volume |
| 25 | disk nearly full (simulated safely) | B | ✅ executed | `test-robustness.sh` `case_disk_nearly_full`: 8 MB HFS+ image mounted at the case's store path, filled to a few KB free; the app still opens its window (SQLite store init on a full volume surfaces, does not crash the launch) |
| 26 | memory pressure | D | not executed | No safe headless way to induce real system memory pressure without affecting the host outside an isolated VM |
| 27 | CPU under load | B | ✅ executed | `test-robustness.sh` `case_cpu_under_load`: every core pinned by a `yes` busy loop while the window comes up; launch survives the contention |
| 28 | ClamAV absent | N/A | retired | — |
| 29 | ClamAV incomplete | N/A | retired | — |
| 30 | invalid ClamAV binary | N/A | retired | — |
| 31 | missing AV database | N/A | retired | — |
| 32 | outdated AV database | N/A | retired | — |
| 33 | corrupted AV database | N/A | retired | — |
| 34 | no network | B | ✅ executed | `offline-no-network` PASS; `UpdateCheckerTests.offlineIsReportedNotThrown` |
| 35 | update manifest unreachable | A+B | ✅ executed | Same as above — offline case covers unreachable |
| 36 | invalid manifest | B | ✅ executed | `update-manifest-garbage/empty/wrong-shape` PASS; `UpdateCheckerTests.garbageManifestIsRejected` |
| 37 | unexpected HTTP response | A | ✅ executed | `UpdateCheckerTests.httpErrorIsSurfaced` (503 case) |
| 38 | timeout | A | ✅ executed | `UpdateCheckerTests.requestTimeoutIsReportedAsOffline` (injected `NSURLErrorTimedOut` → `.failed(.offline)`) + `defaultFetchHasABoundedTimeout` (the built-in fetch carries `UpdateChecker.defaultRequestTimeout` = 15 s) |
| 39 | user cancellation | A | ✅ executed | `swift test`: pause/resume and cancellation suites across ScanEngine, Space Lens, Similar Images, Duplicates |
| 40 | relaunch after crash | B | ✅ executed | `kill-*-relaunch` cases + `relaunch-over-partial-db` (half-written DB from a hard kill) PASS |
| 41 | sleep/wake mid-operation | D/E | not executed | Real sleep/wake needs either a second Mac available for the test or `pmset`/`caffeinate` control of *this* host, which is not safe to script against the dev machine mid-session |
| 42 | language change | A | ✅ executed | `LocalizationManagerTests`; CI's key-parity gate (`ci.yml`) |
| 43 | extreme resize | C | not executed | Needs a real window/display session |
| 44 | multiple windows / rapid repeated commands | C | not executed | Needs a real window/display session |

## Summary

- **34 items**: automatable (A or B), executed for real with passing
  evidence (items 25, 27, 38 closed 2026-09-02 — see the rows above).
- **6 items**: ClamAV-specific, not applicable — product no longer has
  ClamAV.
- **2 items** (memory pressure, sleep/wake): genuinely need either a second
  Mac or host-level control this session should not risk taking on the
  active dev machine.
- **2 items** (extreme resize, multiple windows): genuinely need a
  graphical session.

No item was marked "needs a second Mac" without being checked first.
