# Stress / Performance Test Report

Step 11 of the Functional Completion plan. Reproducible, no-personal-data
(all synthetic) fixtures added to the normal `bash Scripts/test.sh` suite.

## Method & honesty notes

- **What is asserted (stable pass/fail):** result *counts* (findings, groups,
  scans, rows) and generous wall-clock ceilings ("completes under N seconds"
  with wide margin). These are deterministic on any machine.
- **What is informational only:** exact durations, printed via
  `ContinuousClock` as `[stress] …` lines, never asserted against a tight
  threshold (would flake in CI).
- **Duration** is measurable from within a Swift Testing test (wall-clock via
  `ContinuousClock`) and is what we report below.
- **CPU/memory** are *not* directly measurable from inside a Swift Testing
  process without extra instrumentation, so where the concern is memory it is
  addressed structurally (proving the code path is metadata-only / keyed by a
  bounded set) and stated qualitatively, not with fabricated byte numbers.

Numbers below are representative wall-clock on the dev machine (Apple Silicon,
CommandLineTools toolchain); treat them as order-of-magnitude, not guarantees.

## Results by area

| Area | Fixture | Measured (duration) | Memory/CPU | Finding |
|------|---------|--------------------|------------|---------|
| 1. Cleanup | 12,000 files / 2 rules | ~0.1–0.3 s scan | qualitative | Engine streams all 12k findings uncapped; `.finished` totals exact. Confirms the 5001 case extends to a realistic >2× cap scenario. |
| 2. Duplicates | 10,200 files: 9,000 unique same-size + 500 dup pairs + 100 hard-link pairs + 2 sparse | ~1.5–3.4 s | qualitative | Worst-case single size bucket forces every file through partial+full hash. Exactly 500 groups; hard links collapse (never grouped); sparse files don't crash the hasher. Sub-quadratic — duration scales ~linearly, generous 45 s ceiling would catch an O(n²) regression. |
| 3. Similar Images | 157 images incl. 4 at 5000×5000 | ~1.0–4.0 s | metadata-only, memory-bounded | `pixelCount` reads dimensions from image metadata (`CGImageSourceCopyPropertiesAtIndex`), never a full decode; asserted it returns the true 25M-pixel dimension. Large images stay cheap; identical copies group. |
| 4. Space Lens (wide) | 5,000 siblings in one dir | ~1.0 s | qualitative | Traversal + sort + "Other" bucketing completes fast; bytes roll up exactly. |
| 4. Space Lens (deep) | 60 nested levels | ~1.4 s | qualitative | No stack overflow / hang past `maxDepth` (6); bytes below the cap summed via `shallowSize`. |
| 5. SQLite / history | 8,000 activity + 8,000 safety-log rows | insert ~2 s; **read 3×200 ~0.01 s** | qualitative | The measured concern is *read* performance: bounded `LIMIT` reads (safety_log index-backed on `date`) stay ~flat regardless of backlog. Ordering (newest-first) and kind-filter correct. |
| 6. FSEvents burst | 20,000 events / 50 distinct paths | ~0.06 s | bounded by distinct paths | Debounce window collapses the burst to exactly 50 scans. `lastEvaluated`/`fingerprints` maps are keyed by path, so memory is inherently bounded by distinct paths, not event count — no unbounded growth under burst. |
| 7. Rapid cancellation | Space Lens & ScanEngine, 4,000 files each, cancel on first event | ~0.3–0.8 s to return | qualitative | Breaking the consumer loop terminates the stream → `onTermination` cancels the detached task; returns in well under a full walk. Proves prompt, clean teardown. |

## Suite impact

- Tests: 191 → 200 (9 stress tests added).
- Full `bash Scripts/test.sh` wall clock: ~7 s → ~12 s real (internal test-run
  ~6 s). No single fixture exceeds ~15 s; heaviest fixtures are file-creation
  bound (duplicates, cleanup) and the 8k×2 store inserts (~2 s).

## Bugs found

None. All engines held correctness at scale. One test-authoring nuance: two
all-zero sparse files of identical length legitimately grouped as duplicates
(correct engine behaviour) — the fixture now gives them distinct sizes so the
group count stays exact.
