# Deep Scan — Gap report

CoreTend vs. `tw93/Mole` (GPL-3.0) and `alienator88/Pearcleaner` (Commons
Clause), plus general macOS-cleaner behaviour. Behavioural comparison only —
no code was copied (see `COMPETITIVE_RESEARCH.md`).

Columns: **THEY HAVE** — what the reference tools do · **CORETEND CURRENT** —
what shipped before this branch · **CORETEND NEW** — added on
`feat/deep-scan-cleanup-v1.2` · **SAFER / DIFFERENT** — where CoreTend
deliberately diverges.

| Capability | THEY HAVE | CORETEND CURRENT | CORETEND NEW | SAFER / DIFFERENT |
|---|---|---|---|---|
| Full-disk size map | Yes (tree / treemap) | SpaceLens on chosen roots | `DeepScanEngine` + `DiskGraph`: canonical paths, `(dev,ino)`, logical vs allocated, per-node completeness, mount-boundary stop | Size layer physically cannot mark anything for deletion |
| App uninstall / leftovers | Yes, name + path grouping | Rule-based cache finder | `AppInventory` (Info.plist + Team ID + embedded helpers), `AppOwnershipResolver`, `OrphanedAppDetector` | Exact bundle-ID match only; `com.apple.*` and toolchains excluded; weak matches ⇒ REVIEW, never auto-selected |
| AI / LLM storage | Treated as generic caches | Not modelled | `AIStorageDetector` with 14-way data-type taxonomy across Claude Code, Codex, LM Studio, Ollama, HF, MLX, llama.cpp, Cursor | Whole-tool-dir is **never** "cache"; memory / history / auth / config / unknown ⇒ PROTECTED and shown-but-unselectable |
| Developer junk | DerivedData, node_modules, caches | Some cache rules | `DeveloperStorageDetector` with sibling-manifest proof + reconstruction-cost tags (`regeneratesLocally` / `longCompile` / `networkRedownload`) | Won't call a dir regenerable without a manifest/lockfile next to it |
| Git repo awareness | Minimal / none | None | `GitProjectAnalyzer` (read-only `git`): remotes, dirty, staged/unstaged/untracked, stashes, worktrees, local-only commits, GREEN/YELLOW/RED; `GitProjectDetector` + stale-worktree sub-candidates | A repo is **never** default-selected; RED ⇒ PROTECTED; deletion always explicit review + confirm |
| Duplicate project clones | Rare | None | `DuplicateProjectsDetector` groups by normalised remote, compares dirty / local-only commits / activity | **Never "newest wins"**; a duplicate with its own local-only work ⇒ PROTECTED |
| Orphaned launch agents / login items | Some tools | None | `SystemSettingsDetector` (detection only) | Operates on the exact plist, not a whole preference domain; `com.apple.*` skipped; no undocumented perf claims |
| Installers / disk images | By extension | None | `InstallerDetector` (`.dmg/.pkg/.mpkg/.xip/.iso`) with size + age + mount state | Never removed by extension alone; always REVIEW |
| Cloud-backed files | "locally cached" often deletable | `CloudFile.isRemoteOnly` used elsewhere | `CloudStorageDetector` | PROTECTED + `evictCloudCopy`; CoreTend never deletes a cloud-backed path |
| Risk / confidence scoring | Ad hoc or none | `ScanFinding.confidence: Double` + `risk` | `RiskConfidenceModel` (deterministic) + `Evidence` list + `DefaultSelectionPolicy` | No AI/LLM in scoring; UNKNOWN fails closed; no CONFIRMED without a fully-observed subtree |
| Execution safety | Undo / holding area | `SafetyCenter` → PathValidator → Trash → Journal → Restore | `ExecutionRevalidator` inserted before `SafetyCenter` | Re-checks path identity, symlink swap, active write, owner-running, repo-now-dirty between scan and click; Trash-only, no `rm` |
| Persistence / incremental rescan | Varies | App store DB | `DeepScanIndex` (versioned SQLite, incremental upsert, paged queries) | — |
| Live file watching (FSEvents) | Some (Pearcleaner Sentinel) | — | **Not implemented** (index supports the diff; watcher is future work) | — |
| Large-scale perf proof (100 k–1 M nodes) | Claimed | Stress suite to ~10 k | **Not yet added** for Deep Scan | — |
| GUI | Yes | Yes (other features) | **None for Deep Scan** | Deliberately not reachable until the model is reviewed |

## Genuine product differences (not just feature parity)

1. **Evidence-first.** Every proposed removal ships a machine-checkable reason
   list and two plain-language lines ("why" / "if removed"). The reference
   tools mostly show a size and a checkbox.
2. **User state is a protected class.** AI memory and conversation history are
   first-class PROTECTED categories, surfaced with rebuild cost so the user
   understands the footprint without being able to delete it by accident.
3. **Git-aware by construction.** Repo safety is computed from read-only `git`,
   not guessed from directory names, and gates both default-selection and
   execution-time revalidation.
4. **Two independent gates.** `ExecutionRevalidator` (identity / active-write /
   owner-running / repo-state) runs *before* `SafetyCenter`, which then
   re-validates the path again itself.
