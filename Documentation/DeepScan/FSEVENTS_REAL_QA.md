# Deep Scan — FSEvents real-churn QA

Spec §7 / §8. The live incremental watcher (`FSEventIncrementalEngine`) driven
against a disposable fixture under developer-representative churn, using the
**real `FSEventStream`** (not synthetic `ingest`).

## Harness

```
swift run DeepScanQA --fsevents-churn
```

`Sources/DeepScanQA/main.swift` (`--fsevents-churn` branch). It:

1. creates `NSTemporaryDirectory()/coretend-fsevents-churn-<uuid>/proj` with a
   `package.json`,
2. `openIndexRecovering()` → fresh SQLite index,
3. `FSEventIncrementalEngine.start()` (initial full scan → index → FSEventStream
   with `kFSEventStreamCreateFlagFileEvents | NoDefer | WatchRoot`),
4. runs the churn bursts below, each followed by a 1.6 s settle (400 ms debounce
   + scoped rescan),
5. injects a dropped-event and checks `STALE → rescan → FRESH`,
6. corrupts a second index file and checks recovery,
7. tears the fixture down.

Nothing outside the temp fixture is touched.

## Machine

Apple M1, 8 cores, 8 GB, macOS 26.6.2, SwiftPM debug build.

## Workload and measured results

| Burst | Workload | Wall | Index nodes after | Health | scanVersion |
|---|---|---:|---:|---|---:|
| start | initial full scan (6 nodes) | 0.01 s | 6 | `fresh` | 1 |
| npm install | 40 dirs × 50 files = **2,000 files** created in `node_modules/` | 2.06 s | 2,047 | `fresh` | 3 |
| next build | `.next/cache/` + 200 chunks created | 1.70 s | 2,249 | `fresh` | 5 |
| next rebuild | `rm -rf .next` then recreate with 220 chunks (**generated-output dir replaced**) | 1.70 s | 2,269 | `fresh` | 7 |
| rm -rf node_modules | delete the whole 2,000-file subtree | 1.74 s | **228** | `fresh` | 9 |
| rename + rapid writes | `a.txt`→`b.txt`, then 50 rewrites of `b.txt` | 1.66 s | 229 | `fresh` | 11 |
| git checkout | create 300 `src/*.swift`, then mtime-storm all 300 | 1.79 s | 530 | `fresh` | 13 |
| dropped event | inject `UserDropped`-equivalent | 2.5 s | 530 | `fresh` | 14 |

`corruption recovery: reopened, nodeCount=0` — a non-SQLite file at the index
path is discarded and rebuilt clean.

## What was observed

- **Event coalescing** — a 2,000-file `npm install` burst produced **one**
  scoped rescan (`scanVersion` 1→3, i.e. one delete pass + one apply), not
  2,000. Every burst advanced `scanVersion` by exactly 2.
- **Deleted paths / directory removal** — `rm -rf node_modules` dropped the
  index from 2,269 → 228. **This required a fix found by this QA**: a removed
  directory can't be pruned by rescanning *itself* (it's gone), so the
  coalescer now also rescans the **parent**, letting `pruneUnder(parent,
  keeping:)` drop the whole gone subtree. Before the fix the stale rows
  lingered until an unrelated parent rescan (a latent over-report, not a
  safety issue — `ExecutionRevalidator` rejects vanished paths — but wrong).
- **Renames** — `a.txt`→`b.txt` reconciled via the containing-dir rescan; the
  old name disappeared, the new name appeared.
- **Generated-output replacement** — `rm -rf .next && recreate` handled as a
  delete + re-add in one settle window.
- **MustScanSubDirs** — the coalescer routes it to a scoped (or full) rescan;
  not reproduced as a real flag in this run (macOS did not drop), covered by
  `coalescerCollapsesNestedDirsAndExtractsDeletes` + the dropped-event path.
- **Dropped events** — injected; `EventCoalescer` returns
  `requiresFullRescan = true, health = .stale`; the engine published `stale`,
  ran a full rescan, returned to `fresh`. `health transitions` ends `… stale
  -> fresh`; `STALE seen: true`.
- **Index health during churn** — every burst showed `fresh → (stale while
  coalescing) → fresh`. The index never reported `fresh` while a rescan was
  pending; the UI is instructed never to present `stale`/`rebuilding` data as
  a current scan (see `GUI.md` / `ARCHITECTURE.md` — Index health).
- **Corruption recovery** — `openIndexRecovering()` discarded the bad file and
  returned a usable empty index; no stale candidate can survive because the
  row table is empty until the next scan.

## Unit coverage

`coalescerDroppedEventsForceFullRescanAndStale`,
`coalescerRootChangeIsError`,
`coalescerCollapsesNestedDirsAndExtractsDeletes`,
`incrementalEngineScopedRescanPicksUpNewFileAndPrunesDeleted`,
`indexCorruptionIsRecovered` — all green.

## HUMAN VERIFICATION REQUIRED

- The **index-health badge in the running app** switching FRESH ⇄ STALE ⇄
  REBUILDING live while the user edits files — the watcher was exercised
  headlessly here; the GUI binding was not driven interactively.
- Behaviour under a genuine kernel event-drop (`KernelDropped`) on a very
  busy machine — only the injected/user-dropped path was reproduced.
- Multi-hour stability of the `FSEventStream` dispatch queue.
