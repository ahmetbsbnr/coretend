# Deep Scan — Competitive research (clean room)

**Purpose.** Behavioural reference only, to inform CoreTend's own independent
design. **No source code, algorithms expressed as source, tests, strings,
assets, or implementation structure were copied from any project listed here.**
Everything in `Sources/DeepScanCore` was written from first principles against
the CoreTend spec.

**License note.**
- `tw93/Mole` — **GPL-3.0**. Copying its code into CoreTend (Apache-2.0) would
  be a license violation. Reference for *behaviour* only.
- `alienator88/Pearcleaner` — **Commons Clause** on top of its OSS license,
  which restricts commercial "selling". Reference for *behaviour* only.
- Others below are looked at only as widely-known macOS-cleaner behaviour.

Where a row describes internal behaviour we could not verify by observation
this session, it is marked _(unverified — confirm before relying on it)_.

---

## tw93/Mole  (GPL-3.0)  — https://github.com/tw93/Mole

| Feature | Observed behaviour | Safety lesson | CoreTend opportunity |
|---|---|---|---|
| Full-disk size view | Fast recursive sizing of a chosen root, tree/treemap style | Sizing ≠ deletion; a size view must not imply "safe to delete" | CoreTend keeps sizing (`DiskGraph`) strictly separate from `CleanupCandidate`; the graph never carries a "delete me" flag |
| App uninstall | Groups an app's support files/caches/prefs by app | Grouping by *name* over-matches; needs bundle-ID anchoring | `AppOwnershipResolver` uses exact bundle-ID (self + embedded helpers), never substring |
| Cache cleaning | Offers common cache dirs for removal | "It's a cache" is not always true for AI tooling dirs | `AIStorageDetector` refuses to call a whole tool dir a cache; buckets by data type, fails closed to PROTECTED |
| Speed | Uses low-level enumeration for throughput _(unverified)_ | Low-level traversal can skip symlink/mount guards | CoreTend's engine is `FileManager` + `lstat`, with explicit symlink-no-descend, `(dev,ino)` de-dup, mount-boundary stop |

## alienator88/Pearcleaner  (Commons Clause)  — https://github.com/alienator88/Pearcleaner

| Feature | Observed behaviour | Safety lesson | CoreTend opportunity |
|---|---|---|---|
| Orphaned-file finder | Finds leftover support files for apps no longer installed | Must explain *why* a folder is thought orphaned | Every `OrphanedAppDetector` candidate carries `bundleIDNoInstall` + `noSiblingOwner` + `lastActivityDays` evidence and a plain-language "appears to belong to X" line |
| Sentinel / file monitor | Watches for app deletion, offers to clean up | Cleaning right after deletion races running helpers | `ExecutionRevalidator` re-checks "owner running" immediately before SafetyCenter acts |
| Dev / Xcode junk | Removes DerivedData, archives, simulators | Some of these are long-recompiles, not free | `DeveloperStorageDetector` tags reconstruction cost (`longCompile` / `networkRedownload`) so the UI can warn |
| Undo | Moves to a holding area, supports restore | Reversibility is the safety net | CoreTend reuses the existing `SafetyCenter` Trash + Journal + Restore path; no `rm` |

## Other macOS cleaners (general, well-known behaviour)

| Tool / class | Behaviour worth noting | Safety lesson | CoreTend stance |
|---|---|---|---|
| "One-click clean" utilities | Pre-select large amounts by default | Default selection is where accidents happen | `DefaultSelectionPolicy` pre-selects only SAFE + STRONG + fully-observed + locally-regenerable, with an evidence veto list; real-Mac QA shows **0** of 233 candidates default-selected |
| Homebrew `cleanup` | Removes old downloads/versions it *owns* | Owning the data makes it safe | CoreTend treats package-manager stores as `networkRedownload` risk, never default-selected |
| iCloud "Optimize Storage" | Evicts local copy, keeps cloud object | Deleting a cloud file deletes it everywhere | `CloudStorageDetector` is PROTECTED + `evictCloudCopy` recommendation; CoreTend never deletes a cloud-backed path |
| `git clean` / repo tools | Powerful, easy to lose uncommitted work | Never touch a dirty repo | `GitProjectAnalyzer` classifies GREEN/YELLOW/RED from read-only `git`; a repo is **never** default-selected; RED ⇒ PROTECTED |

---

## What CoreTend deliberately does differently

1. **Observation and decision are different layers.** The scanner produces a
   truthful `DiskGraph` (logical vs allocated bytes, per-node completeness).
   Detectors turn that into `CleanupCandidate`s carrying *evidence*. Nothing in
   either layer can delete.
2. **Deterministic risk model, no AI in the loop.** `RiskConfidenceModel` is a
   pure function of the evidence set. UNKNOWN attribution fails closed to
   PROTECTED; nothing reaches CONFIRMED without a fully-observed subtree.
3. **User state is sacred.** AI memory / conversation history / auth / config
   and anything unclassified is PROTECTED and shown-but-unselectable, with size,
   tool, data type, and rebuild cost.
4. **One executor.** Only the pre-existing `SafetyCore.SafetyCenter` acts, via
   Trash, with a Journal and working Restore. `ExecutionRevalidator` re-checks
   the world between scan and click.
