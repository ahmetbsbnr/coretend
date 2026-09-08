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
incremental win comes from **scanning fewer nodes**: the FSEvents scoped
rescan (see `FSEventIncrementalEngine`) feeds `apply` only the changed subtree,
so a typical rescan touches hundreds of rows, not a million. Measured: a
1,000-node changed subtree re-applies in single-digit ms.

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
(filter + sort + page slice < 30 ms).
