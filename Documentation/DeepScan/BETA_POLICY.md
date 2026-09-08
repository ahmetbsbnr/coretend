# Deep Scan — proposed beta configuration

**Status: PROPOSAL for maintainer approval. Not activated in code.**
`DeepScanExecutionGate.isEnabled` and `DefaultSelectionPolicy.preselectionEnabled`
remain `false` on this branch.

## Recommended beta configuration

| Setting | Recommendation | Where it lives |
|---|---|---|
| Deep Scan module | **Visible** in the sidebar | `ModuleID.deepScan` (already wired) |
| Analysis (scan + detectors) | **Enabled** | always on; read-only |
| Execution gate | **Enabled for the narrow SAFE subset only** | flip `DeepScanExecutionGate.isEnabled = true` — this alone does **not** broaden categories; `ExecutableSubsetPolicy` still restricts to `developer-storage` / `temp-files` / `ai-storage`(runtimeCache\|tempFiles\|updatePayload) at risk `safe`, confidence ≥ `strong`, idle, locally-regenerable, no protected/shared/incomplete evidence |
| Automatic preselection | **Off** | keep `DefaultSelectionPolicy.preselectionEnabled = false`; nothing is pre-ticked |
| Git repository deletion | **Review only** | `GitProjectDetector` never routes a repo to the executor; repo is never default-selected; RED ⇒ PROTECTED |
| AI model-weight deletion | **Review only** | `modelWeights` excluded from `ExecutableSubsetPolicy.allowedAISubcategories`; never auto-selected |
| AI memory / history / auth / config / unknown | **Protected** | `AIDataType.isProtected`; shown with size + rebuild cost, no checkbox |
| App-leftover weak matches | **Protected / High-risk** | `OrphanedAppDetector`: name-only ⇒ REVIEW, not-idle or system-level ⇒ HIGH_RISK; never in the executable subset |
| System-level cleanup (launch agents, prefs) | **Review only** | `SystemSettingsDetector` is detection-only; not in the executable subset |
| Cloud data | **Protected / provider-eviction only** | `CloudStorageDetector` ⇒ PROTECTED + `evictCloudCopy`; CoreTend never deletes a cloud-backed path |

## What "Enable the execution gate" actually exposes in beta

From the current real-Mac read-only QA (157 candidates):

- **1** candidate is in the executable SAFE subset — a single real `.next`
  directory in an actual project.
- **0** candidates are pre-selected.
- The user must open **Cleanup Plan**, tick an item, and confirm; then
  `ExecutionRevalidator` + `SafetyCenter` run, and the item goes to **Trash**
  with a journal entry, restorable from the Restore Center.

So even with the gate on, the beta surfaces a review-and-plan tool that can
move a handful of provably-rebuildable build dirs to the Trash on explicit
user action — nothing automatic, nothing broad.

## Rollout guard rails

1. Do not flip the gate without the maintainer having personally run the GUI
   Trash → Restore round trip (see `HUMAN_REVIEW.md` — still open).
2. Ship the gate as a build flag / hidden preference, not a user-visible
   toggle, for the first beta.
3. Keep `preselectionEnabled = false` until a later phase with its own review.
4. No merge to `main`, no Production deploy, no release tag from this branch
   without maintainer sign-off.

## Not in this proposal

- Broadening `ExecutableSubsetPolicy` beyond the three detectors.
- Any automatic / scheduled cleanup.
- Enabling execution for `appsAndLeftovers`, `systemAndSettings`, `gitProjects`,
  `cloud`, `storage`, or `installers`.
