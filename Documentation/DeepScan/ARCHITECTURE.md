# Deep Scan + Cleanup Intelligence 2.0 — Architecture

Module: `Sources/DeepScanCore` (library target `DeepScanCore`).
Status: **read-only architecture landed on `feat/deep-scan-cleanup-v1.2`. Not
wired into the GUI. No production cleanup enabled.**

## Layering (strict, one direction)

```
   observe            evidence                decide                 execute
┌────────────┐   ┌──────────────────┐   ┌──────────────────┐   ┌──────────────────────┐
│DeepScanEngine│→ │ Detector(s)       │→ │ RiskConfidence    │→ │ ExecutionRevalidator │→ SafetyCore.SafetyCenter
│  → DiskGraph │   │ → CleanupCandidate│   │ Model + Default   │   │  (re-check world)    │   (Trash + Journal + Restore)
└────────────┘   └──────────────────┘   │ SelectionPolicy   │   └──────────────────────┘
   never deletes      never deletes       └──────────────────┘        never deletes         the ONLY deleter
```

Nothing left of `SafetyCenter` performs a filesystem mutation. There is no
`rm` path anywhere in `DeepScanCore`; the only removal verb is the existing
`SafetyCenter.execute` → `trashItem`.

## Components

### `DeepScanEngine` / `DiskGraph`
Bounded-concurrency BFS walk. Guarantees:
- Symlinked directories are **recorded but not descended** — no loops.
- Files are keyed by `(st_dev, st_ino)`; a second hard link contributes **0
  bytes** so totals are never inflated.
- Descent stops at a **mount boundary** (`st_dev` change) unless
  `followMountBoundaries` is set.
- A directory we cannot read is `completeness = .permissionDenied` with **0
  bytes** (never guessed); its root is added to `deniedRoots`.
- **Cancellation** and the **wall-clock deadline** both return a partial graph:
  `wasCancelled` / `hitTimeout` set, affected directories `.partial`,
  un-visited ones `.notEnumerated`. No stale or fake-complete data.
- `logicalBytes` (`st_size`) and `allocatedBytes` (`st_blocks*512`) are kept
  separate. On APFS "reclaimable" is always an **estimate** — labels say so.
- `subtreeFullyObserved(path)` is the hard precondition for CONFIRMED
  confidence.

### `CleanupCandidate` + `Evidence`
First-class model. A candidate has: path, canonical path, category,
subcategory, detector id, logical/allocated/estimated-reclaimable bytes, owner,
`Confidence`, `RiskClass`, recoverability, `Reconstructability`, last activity,
`ActiveState`, `[Evidence]`, `protectedReason`, `RecommendedAction`,
`defaultSelected`, and two plain-language lines (`rationale`, `ifRemoved`).
`Evidence` is an additive list of machine-checkable reasons.

### `RiskConfidenceModel` (deterministic — no LLM, no network)
- `userStateMarker` or `cloudBacked` evidence ⇒ **PROTECTED**.
- `gitSafety == .red` ⇒ PROTECTED. `activeState == .activelyWritten` ⇒ PROTECTED.
- No attribution evidence at all ⇒ confidence `.unknown` ⇒ PROTECTED (fail closed).
- CONFIRMED requires `subtreeComplete && strong && a reconstruction marker`.
- Risk is derived from `Reconstructability` then raised for shared-vendor /
  running-process / incomplete-subtree / mount-boundary / YELLOW-git evidence.

### `DefaultSelectionPolicy` (extremely conservative)
Pre-selects **only** when: risk `.safe`, confidence ≥ `.strong`, subtree fully
observed, reconstruction `.regeneratesLocally`, and none of a veto set
(`userStateMarker, cloudBacked, sharedVendorDir, gitState, gitClean,
mountBoundary, subtreeIncomplete, runningProcess, duplicateRemote`). Real-Mac
read-only QA: **0 of 233** candidates default-selected.

### Detectors (all pure, deterministic, read-only)
| Detector | Category | Notes |
|---|---|---|
| `AIStorageDetector` | aiAndLLM | Per-tool data-type taxonomy. `~/.claude/projects/**`, `**/memory`, `history`, `.credentials.json`, `.codex/sessions`, … ⇒ PROTECTED. Anything a profile doesn't positively classify ⇒ `.unknownData` ⇒ PROTECTED. Model weights ⇒ review-only, never selected. Protected AI stores are still listed with size + rebuild cost. |
| `OrphanedAppDetector` | appsAndLeftovers | Exact bundle-ID ownership (self + embedded helpers). `com.apple.*` and first-party toolchains skipped. Weak/name-only ⇒ REVIEW; not-idle or system-level ⇒ HIGH_RISK. Never default-selected. |
| `DeveloperStorageDetector` | developer | `.next/dist/build/.build/target/DerivedData/node_modules/.venv/coverage`. Regenerable only when a sibling manifest/lockfile is present; reconstruction cost tagged. |
| `GitProjectDetector` | gitProjects | Emits one candidate per repo (always `review`, never default-selected) + stale-worktree-registration sub-candidates. GREEN needs clean tree + verified remote. |
| `DuplicateProjectsDetector` | gitProjects | Groups clones by normalised remote. Canonical = clone with local-only work / most recent commit — **never "newest directory wins"**. Duplicates with their own local-only work ⇒ PROTECTED. |
| `SystemSettingsDetector` | systemAndSettings | Orphaned `~/Library/LaunchAgents/*.plist` whose bundle ID has no installed app. `com.apple.*` skipped. Detection only; no undocumented perf claims. |
| `TempFilesDetector` | temporaryFiles | `/private/tmp` + user temp, idle ≥ 48 h. Even temp is opt-in (not default-selected). |
| `InstallerDetector` | installers | `.dmg/.pkg/.mpkg/.xip/.iso`. Never by extension alone without review. |
| `CloudStorageDetector` | cloud | iCloud / `Library/CloudStorage`. PROTECTED + `evictCloudCopy`. CoreTend never deletes a cloud-backed path. |
| `LargeOldFileDetector` | storage | ≥ 512 MB and ≥ 180 days idle. Overview only, `weak` confidence, never selected. |

### `ExecutionRevalidator`
Last gate before `SafetyCenter`. Drops a selected candidate if: it is
PROTECTED/UNKNOWN, path vanished, path became a symlink / special file, file
identity `(dev,ino)` changed, mtime moved within the last 5 s, the owning app
is now running, or an enclosing repo is now RED. Each drop yields a
journalled reason. Performs only `lstat` + read-only `git status`.

### `DeepScanIndex`
Self-contained SQLite index (`Persistence.Database` is module-internal).
Schema is versioned (`schema_version`). `apply(graph)` is an incremental
upsert keyed on canonical path with a `(mtime,size)` fingerprint so unchanged
rows are skipped. `largestNodes(limit:offset:)` pages the UI without loading
the whole graph into RAM.

### `DeepScanPipeline`
Runs engine → gathers context (installed apps, running processes, git repos) →
runs all detectors → de-dups by path keeping the highest-risk verdict →
returns `DeepScanResult` (graph + candidates + per-path `(dev,ino)` for the
revalidator). **Has no execution method.**

### `DeepScanQA` (executable target)
Read-only harness for spec §25. `swift run DeepScanQA [root …]` scans real
directories and prints a discoveries report + a safety self-check. Contains no
delete/trash code path.

## Full-disk permission (FDA) behaviour
The engine reports four states per root, surfaced by the QA harness today and
intended for the GUI:
- **Full access** — root and subtree `.complete`.
- **Partial access** — some children `.permissionDenied`; totals marked
  `.partial`; the scan never claims it covered everything.
- **Protected by macOS** — root in `deniedRoots`; shown as such.
- **Scan error** — `.error` completeness on I/O failure mid-read.
Without FDA the scan still runs and degrades to Partial; it does not pretend.

## Known limitations (as of this branch)
- FSEvents-based live incremental rescan is **not implemented**; `DeepScanIndex`
  supports the incremental *diff* but the watcher is future work.
- Volume classification is coarse (`.dataVolume` for everything descended);
  a DiskArbitration-backed UUID map belongs in the GUI layer.
- The AI data-type taxonomy is intentionally over-conservative — many real
  subtrees (`lm-studio/bin`, `server-logs`, `.internal`) resolve to
  `.unknownData` ⇒ PROTECTED. Tightening these is safe, incremental work.
- Stress fixtures exercise up to ~10 k nodes in the existing suite; 100 k /
  500 k / 1 M-node performance runs (spec §23) are **not yet added**.
- No GUI. Deep Scan is not reachable by an end user.
