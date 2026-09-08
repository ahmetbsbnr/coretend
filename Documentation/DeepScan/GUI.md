# Deep Scan — GUI

Source: `Sources/CoreTendApp/DeepScanView.swift`. Presentation model:
`Sources/DeepScanCore/DeepScanPresentation.swift` (framework-free, unit-tested).

Built entirely on the existing DesignSystem (Porcelain / Slate / Teal,
`MCCard` / `MCStatusBadge` / `MCFont` / `MCColor` / `MCSpacing`). No new design
language.

## Navigation

New sidebar module **Deep Scan** (`ModuleID.deepScan`,
`MCModuleIdentity.deepScan`, icon `magnifyingglass.circle`) in the **More**
group. `MainWindow` routes it to `DeepScanView`.

## Screens

### 1. Entry
- Plain-language description; "Nothing is deleted during analysis."
- **Permission banner** — truthful, four states (`DeepScanPermissionProbe`):
  - **Full Disk Access** — whole home volume analysable.
  - **Partial Access** — "some folders are hidden by macOS; grant Full Disk
    Access in System Settings › Privacy & Security for a complete picture."
  - **Protected by macOS** — some locations reported as such.
  - **Scan error** — last scan hit a read error.
  The scan never claims full coverage when access is partial.
- Volume scope line (home only unless external volumes opted in).
- **Start Deep Scan** + **Scan Options…**.
- If the execution gate is off: a caution line that Move-to-Trash is disabled.

### 2. Progress
- The nine real phases (`DeepScanPhase`) listed with check / active / pending
  glyphs — an **ordinal** position, never a fabricated percentage.
- Live counters: items, bytes observed, folders blocked by permissions, elapsed.
- **Pause / Resume / Cancel.** Pause parks the engine between directory
  batches (`DeepScanCancellation.pause/resume`). Cancel yields a **Partial
  scan** and the results are labelled reduced-confidence.

### 3. Results
- **Category rail** (left, 260 pt): Overview + the ten categories, each with
  item count, "≈ N reviewable", and protected count.
- **Row list** (right): a **page of 200** rows (`DeepScanResultsModel.page`),
  "Show more" to extend — never a `ForEach` over the whole candidate set (see
  PERFORMANCE.md §28; 50k candidates filter+sort+page ≈ 72 ms).
- **Toolbar**: search (path / owner / kind), Risk filter, Sort
  (size / risk / last activity / confidence), Protected-only toggle,
  **Review Cleanup Plan (n)**.
- **Row** (`DeepScanRowView`) — disclosure:
  - collapsed: checkbox *or* a **Protected** badge (protected rows have no
    checkbox and cannot be selected), the "what", the path (truncated middle),
    size, a risk badge.
  - expanded: the full evidence trail as check-bullets, then Where / Size (+
    allocated) / Reclaimable (`—` when protected) / Confidence / Rebuild /
    Last activity / Owner / If removed, and the protected reason if any.
  - All labels are humanized (`RiskClass.displayName` etc.) — no raw enum
    names, no fear language.

### 4. Cleanup Plan sheet
- Selected count, logical bytes, estimated reclaimable.
- Risk summary and rebuild-cost summary.
- **Skipped — changed since scan**: from a fresh `ExecutionRevalidator` pass
  run when the sheet opens ("App is now running", "Repository became dirty",
  "File identity changed", "Path disappeared", …) — never a generic failure.
- Count of selected-but-protected items held back.
- List of the items that will move to Trash.
- **Move n to Trash** — disabled unless `DeepScanExecutionGate` is on and the
  list is non-empty. After execution, an outcome line ("Moved n to Trash · m
  skipped" or "Execution is disabled — nothing was moved").

### 5. Scan Options sheet
- `DeepScanSettings`: external volumes (opt-in), developer / AI / system /
  cloud analysis toggles, Git network verification (opt-in).
- Footer: "Safety protections, the protected-path policy, and Trash-only
  execution are not configurable."

## Search / filter / sort (spec §29)

`DeepScanFilter`: search text, category, `maxRisk`, `minConfidence`,
`minBytes`, `protectedOnly`, `reviewableOnly`. `DeepScanSort`: `size`, `risk`,
`lastActivity`, `confidence`. All applied inside `DeepScanResultsModel.page`,
so filtering/sorting never materialises the full list in a view.

## Scan history (spec §30)

`DeepScanIndex.recordScanRun` / `recentScans` — id, started, finished, scope,
permissions, node count, candidate count, logical + allocated bytes,
partial/full, error count. Diagnostic session metadata, **not** reclaimed-space
accounting (the Timeline owns that).

## HUMAN VERIFICATION REQUIRED

Everything that needs the app actually running:

- Visual layout, spacing, dark/light, window resizing, the category rail split.
- Scroll performance of the paged list with a real large result set.
- VoiceOver / keyboard traversal / focus order.
- Pause/Resume/Cancel feel during a live multi-second scan.
- The Cleanup Plan → Move to Trash → Safety Log → **Restore Center** round
  trip end to end.
- The permission banner against a real "Full Disk Access denied" state.

These were **not** performed — see `HUMAN_REVIEW.md` for the exact
done/not-done list. The view models, grouping, filtering, paging, plan
building, phase model, permission probe, and settings persistence are covered
by `DeepScanPresentationTests` + `DeepScanViewModelTests`; `swift build`
compiles the whole GUI.

## Localization status

Fixed UI chrome, enum labels (risk / confidence / rebuild / category),
scan phases, permission-state banners, filter/sort labels, the Cleanup Plan,
settings, and skip reasons are localized **EN + FR** (`deepscan.*` keys,
`DeepScanLocalizationTests` enforces parity). Per-candidate
`rationale` / `ifRemoved` / `protectedReason` / evidence sentences are composed
in `DeepScanCore` from tool names + byte counts + paths and remain **English**;
a localization-callback for those is deferred to a later phase.
