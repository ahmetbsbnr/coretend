# Deep Scan — Execution safety

The boundary between **analysis** and **a real filesystem change**, and every
gate in between.

## The four stages, and where each one can say "no"

```
 analysis            recommendation        selection             execution
 ────────            ──────────────        ─────────             ─────────
 DeepScanEngine  ->  Detector          ->  user ticks a      ->  DeepScanExecutor
 + detectors        produces a            row in the GUI        │
 (read only)        CleanupCandidate      (never pre-ticked     ├─ DeepScanExecutionGate      ⟵ off ⇒ stop
                    with evidence,        this phase — see      ├─ ExecutableSubsetPolicy     ⟵ not in subset ⇒ skip
                    risk, confidence      §20)                  ├─ ExecutionRevalidator       ⟵ world changed ⇒ skip
                    — cannot delete)                            ├─ SafetyCenter.approve       ⟵ PathValidator ⇒ skip
                                                                ├─ SafetyCenter.execute       ⟵ re-validates again ⇒ skip
                                                                └─ trashItem + audit journal
```

There is **one** path to a change: `DeepScanExecutor` → `SafetyCore.SafetyCenter`
→ `FileManager.trashItem`. `DeepScanCore` contains no `rm`, no `removeItem`
except SafetyCenter's own temp-path fallback, and no detector-owned deletion.

## Stage 0 — feature gate (`DeepScanExecutionGate`)

- `isEnabled` is a process-wide `Bool`, **default `false`**.
- Env override `CORETEND_DEEPSCAN_EXEC=1` for controlled QA only.
- Gate off ⇒ `DeepScanExecutor.execute` returns immediately: `gated == true`,
  `executed == []`, every candidate listed as skipped at stage `"gate"`.
- The GUI shows "Cleanup execution is disabled in this build" and the
  Move-to-Trash button is disabled.
- **Normal CoreTend builds ship with the gate off.**

## Stage 1 — executable subset (`ExecutableSubsetPolicy`, spec §18)

A candidate is eligible only if **all** hold:

| Check | Requirement |
|---|---|
| detector | one of `developer-storage`, `temp-files`, `ai-storage` |
| ai-storage subcategory | `runtimeCache`, `tempFiles`, or `updatePayload` only |
| risk | `safe` |
| confidence | `strong` or `confirmed` |
| activeState | `idle` |
| reconstructability | `regeneratesLocally` |
| category | `developer`, `temporaryFiles`, or `aiAndLLM` (never git / cloud / apps / system / storage / installers) |
| evidence | none of `userStateMarker, cloudBacked, sharedVendorDir, gitState, gitClean, mountBoundary, subtreeIncomplete, runningProcess, duplicateRemote` |

Everything else stays **read-only / review**.

## Stage 2 — execution revalidation (`ExecutionRevalidator`, spec §17)

Immediately before SafetyCenter, each still-eligible candidate is re-checked
against the live filesystem (only `lstat` + read-only `git status`). It is
**skipped, with a journalled reason**, if:

- it is protected or `unknown` confidence (should never have got here)
- the path no longer exists
- the path is now a symlink or a special file
- the file identity `(st_dev, st_ino)` changed (path swapped)
- the mtime moved within the last 5 s (being written)
- the owning app is now running
- an enclosing git repository is now RED (dirty / stash / unpushed / no verified remote)

Adversarial coverage (`adversarialExecutionAllSkipWithTruthfulReasons`,
`revalidator*` tests): path vanished, owner launches, inode replaced, symlink
swap, repo goes dirty — all produce `executed == []` and a truthful reason.

## Stage 3 — SafetyCenter (unchanged, pre-existing)

- `approve(url:logicalSize:ruleID:risk:)` runs `PathValidator`: rejects the
  protected system roots, anything outside the allow-list, and symlink escapes.
  `ruleID` is `deepscan:<detector>:<subcategory>` so provenance is in the journal.
- `execute([ApprovedFileOperation])` re-validates every path a **second** time,
  then `trashItem`. A path that changed between approve and execute is skipped.

## Journal & restore

Every stage emits a `SafetyAuditEvent` to the app's `Store` sink — `approved`,
`executed`, `skipped`, `error` — each with operation id, stage, path,
`deepscan:` ruleID, risk, size, timestamp, and result string. These appear in
the existing **Safety Log** / activity feed. Restore uses the existing Restore
Center (Trash → original path). The GUI restore round-trip is
**HUMAN VERIFICATION REQUIRED**; the Trash move + journal round-trip is covered
by `executionGateOnTrashesEligibleCandidateAndJournals` and by the
`DeepScanQA --controlled-cleanup` harness (real fixture → real Trash → journal).

## Default selection (spec §20/§21)

`DefaultSelectionPolicy.preselectionEnabled` is **`false`** for this
productization phase: nothing is pre-ticked, even candidates that clear
`meetsBar` (safe + strong + fully-observed + locally-regenerable + no veto).
Real-Mac read-only QA: **0 of 233** candidates pre-selected. Flip only after
the maintainer reviews real execution behaviour.

## What is NOT enabled

- Broad automatic cleanup — no.
- Execution for normal users — no (gate off).
- Any detector outside the three-detector subset — no.
- Repo deletion, cloud deletion, app-leftover deletion, system-file deletion —
  never routed to the executor at all.
