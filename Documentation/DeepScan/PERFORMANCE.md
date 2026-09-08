# Deep Scan — Performance

Measured with `Tests/DeepScanCorePerfTests` (spec §12/§13/§23). Re-run:

```
bash Scripts/test.sh --filter DeepScanCorePerfTests
```

## Machine / build

| | |
|---|---|
| Model | Apple M1, 8 cores |
| RAM | 8 GB |
| macOS | 26.6.2 (25G83) |
| Toolchain | Apple Swift 6.3.3, SwiftPM debug build |
| Storage | internal APFS SSD |

Numbers below are debug builds. A release build is materially faster; these
are the conservative figures the budgets are set against.

## Methodology

- **Synthetic graphs** — `syntheticGraph(target:)` builds a deterministic
  balanced tree (√N directories × N/√N files) entirely in memory. No real
  files are created for the 100k–1M runs (writing 1M inodes would wear the SSD
  for no extra signal). This measures the "whole graph held in RAM" path:
  `DiskGraph` index construction, `descendants`, `subtreeFullyObserved`.
- **SQLite index** — real on-disk `DeepScanIndex` in `NSTemporaryDirectory`.
  Measures bulk `apply`, a second `apply` of the identical graph
  (upsert/no-op path), file size, and `largestNodes(limit:200)` latency.
- **Real filesystem subset** — 6,000 real files (40 dirs × 150), full
  `DeepScanEngine.scan`, plus a cancel-mid-flight latency measurement.
- Peak RSS via `task_info(MACH_TASK_BASIC_INFO)`.

## Results

### Synthetic graph (in-memory)

| nodes | build DiskGraph | `descendants(root)` | `subtreeFullyObserved` | RSS delta |
|------:|----------------:|--------------------:|-----------------------:|----------:|
| 100,000 | 144 ms | 78 ms | 104 ms | +135 MiB |
| 500,000 | 818 ms | 523 ms | 616 ms | +405 MiB |
| 1,000,000 | 1,487 ms | 1,177 ms | 1,486 ms | +690 MiB |

Scaling is ~linear in node count. ~0.7 KiB resident per node for the full
value-type graph + two lookup dictionaries.

### SQLite index (on disk)

| nodes | `apply` (bulk) | `apply` again (no-op path) | file size | `largestNodes(200)` |
|------:|---------------:|---------------------------:|----------:|--------------------:|
| 100,000 | 350 ms | 357 ms | 18.2 MiB | 0.9 ms |
| 500,000 | 1,798 ms | 2,229 ms | 92.1 MiB | 0.7 ms |
| 1,000,000 | 3,837 ms | 5,012 ms | 184.6 MiB | 9.3 ms |

~260k rows/s bulk insert. Paged queries stay interactive (<10 ms) even at 1M
rows thanks to `idx_node_size`.

**Honest caveat on "incremental".** Re-`apply` of an *unchanged* full graph is
not faster — it still executes one `INSERT … ON CONFLICT` per row (the
`content_hint` guard skips the write but not the statement). The real
incremental win comes from **scanning fewer nodes**: `FSEventIncrementalEngine`
coalesces a burst of FSEvents into a minimal set of changed directories
(`EventCoalescer`, unit-tested), then runs `DeepScanEngine.scan` on just those
directories and `index.apply` + `pruneUnder` on that scope. A rescan after
adding/removing one file walks the containing directory only — tens of nodes,
not a million. `incrementalEngineScopedRescanPicksUpNewFileAndPrunesDeleted`
exercises the full add + delete + prune round-trip end-to-end in ~1.5 s
including the debounce window.

### Real filesystem walk

| metric | value |
|---|---|
| 6,041 nodes | 47 ms |
| throughput | ~127,000 nodes/s (debug, warm cache) |
| cancel latency (cancel → return) | 0.1 ms |

The earlier real-Mac read-only QA walked **128,183 nodes in ~2.8 s** across
`~/.claude ~/.codex ~/.cache ~/Library/Caches ~/Developer ~/Downloads` — the
same order of magnitude.

## Engineering budgets (grounded in the above)

| Budget | Target | Basis |
|---|---|---|
| Interactive filesystem walk | ≥ 50,000 nodes/s sustained | measured 127k/s debug; real-Mac 128k nodes / 2.8 s |
| Full in-RAM graph ceiling | ≤ 1 GiB RSS for ≤ 1M nodes | measured +690 MiB at 1M |
| Prefer not to hold > ~500k nodes in RAM | UI reads pages from `DeepScanIndex` | build+traverse at 1M is ~4 s combined — acceptable for a one-off, too slow per interaction |
| SQLite bulk apply | ≤ 5 s per 1M nodes | measured 3.8 s |
| Paged list query | ≤ 20 ms | measured ≤ 9.3 ms at 1M |
| Cancellation | return ≤ 2 s (target ≤ 500 ms) | measured 0.1 ms |
| Incremental rescan | ≥ 20× faster than full when < 5% of tree changed | scoped-subtree apply is O(changed), not O(total) |

## UI responsiveness (spec §28)

The GUI never binds a SwiftUI `ForEach` to the raw node list or the raw
candidate list. `DeepScanResultsModel` exposes a filtered/sorted **page**
(default 200 rows) over the candidate set; scrolling advances the page.
Candidate counts of 10k / 50k were exercised in
`DeepScanPresentationTests.pagingStaysBoundedAtFiftyThousandCandidates`
(filter + sort + page slice, ~63 ms for 50k).

## Regression check (after the GUI + localization + FSEvents work)

Re-run of the full `DeepScanCorePerfTests` + the 50k presentation benchmark,
same M1 / 8 GB machine:

| metric | baseline | now | verdict |
|---|---:|---:|---|
| build DiskGraph 100K | 144 ms | 139 ms | no regression |
| build DiskGraph 500K | 818 ms | 755 ms | no regression |
| build DiskGraph 1M | 1,487 ms | 1,459 ms | no regression |
| index.apply 1M | 3,837 ms | 3,620 ms | no regression |
| SQLite size 1M | 184.6 MiB | 184.6 MiB | identical |
| paged query 1M | 9.3 ms | 0.7 ms | no regression |
| real walk | 127k n/s | 137k n/s | no regression |
| cancel latency | 0.1 ms | 0.1 ms | no regression |
| 50k filter+sort+page | 72 ms | 63 ms | no regression |

The GUI, localization and FSEvents changes do not touch `DeepScanEngine` /
`DiskGraph` / `DeepScanIndex` hot paths, so this is expected.

## Memory analysis (spec §17) — 1M-node RSS

The 1M synthetic-graph RSS delta is **high-variance across runs** (measured
+690 / +798 / +911 MiB on three runs). The perf test builds 100K → 500K → 1M
in one process, so the 1M figure carries allocator slack and fragmentation
from the two earlier graphs; it is an upper bound, not a steady-state cost.

Where the bytes go, for 1M `ScanNode`s held in RAM:

| consumer | approx | note |
|---|---:|---|
| `[ScanNode]` array | ~200 MiB | ~200 B/struct: 3 String slots (2 usually share one buffer), ~6 optionals, 3 `Date?`, enums |
| path string buffers | ~50 MiB | one heap buffer per node; `path` and `canonicalPath` are handed the **same** `String` value in the common case, so they share storage (no double-copy) |
| `byCanonicalPath: [String:Int]` | ~55 MiB | inherent to O(1) node lookup |
| `childrenOf: [String:[Int]]` | ~45 MiB | inherent to O(1) child lookup + per-parent `[Int]` |
| Array/dict capacity slack + malloc fragmentation | ~100–350 MiB | the run-to-run variance |

**Decision: no engine rewrite.** Rationale:

1. It is not the normal path. Real-Mac scans are ~125k nodes ≈ **+180 MiB**
   RSS — comfortable on 8 GB. 500k ≈ +460–640 MiB, acceptable.
2. The architecture already routes large results through `DeepScanIndex`
   (paged SQLite reads), and the budget below says *prefer not to hold >
   ~500k nodes in RAM*. The GUI binds to `DeepScanResultsModel` pages and to
   `DeepScanIndex.largestNodes`, never to the raw 1M-node array.
3. The one "free" win — sharing the `path`/`canonicalPath` buffer — is
   **already in place** (`DeepScanEngine.node(fromLstat:)` passes the same
   `canon` value to both fields).
4. Dropping `path` entirely, or interning path components, would touch
   `DiskGraph` / engine / index / presentation / QA and add complexity for a
   ceiling that is not hit in practice — explicitly out of scope for this
   phase ("Do not prematurely rewrite the engine").

If a future phase needs 1M+ nodes resident, the low-risk step is a streaming
`apply` that never materialises the full `[ScanNode]` (feed the walker's
output straight into SQLite), keeping only the lookup dictionaries the
detectors need.
