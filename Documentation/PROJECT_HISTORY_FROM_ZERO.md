# Project History From Zero — Audit Session 1

Evidence: `git log --reverse --oneline --all` (115 commits total on this branch's history), commit
messages cross-checked against actual diffs for the milestones below (`git show --stat`).

## Timeline (single day of commit history: 2026-07-19 → 2026-07-20, single author `ahmetbsbnr`)

1. **`7bf18bb` — "Foundation: SafetyCore, ScanCore, FileRules, app shell with working Cleanup module"**
   First commit. Establishes the multi-target SwiftPM layout (SafetyCore = path-validation primitives,
   ScanCore = filesystem scanning engine, FileRules = declarative cleanup rule definitions) plus a
   minimal SwiftUI app shell wired to a working Cleanup flow. This is the architectural spine the rest
   of the app is built on.

2. **`0dcdc5a` — "Update PROJECT_STATE after release packaging verification"** — docs-only state update.

3. **`bc73c86` — "feat(persistence): add sqlite actor with schema migrations, activity, exclusions, settings"**
   Introduces the `Persistence` target: an actor-isolated SQLite store with versioned migrations. This
   becomes the backing store for activity history, user exclusions, and settings referenced by later
   features.

4. **`ed39d7a`, `04a0a55`, `c11a038`, `f9b2b41`, `5610dd3`** — Cleanup/Smart Care/Duplicates buildout:
   grouped cleanup findings by rule, dry-run Smart Care orchestration, Large & Old Files clutter
   analysis, staged duplicate-hashing pipeline with hard-link detection, and a duplicates review UI with
   keeper suggestion. Confirmed by diff: these commits add real engine code (`ScanCore`, `FileRules`)
   plus corresponding SwiftUI views, not stub UI.

5. **`5e0763f`, `5c9f470`** — Performance metrics (live CPU/memory/disk gauges) and Space Lens (sized
   directory tree + treemap) engines land as separate `SystemMetrics` groundwork and `ScanCore`
   extensions.

6. **`4797aa7`, `c0349c1`** — Application inventory (`AppDiscovery` target) with Trash-based uninstall,
   leftover-file detection, and a menu-bar status extra with live metrics.

7. **`727f8b5` — "feat(onboarding): first-launch sheet with real Full Disk Access probe and honest capability notes"**
   Onboarding flow that actually probes Full Disk Access rather than assuming it — consistent with the
   project's stated "honest" self-description convention seen throughout commit messages and test names
   (e.g. "never invent data", "never a guess" test titles).

8. **`2c3978b` — "feat(protection): ancien scanner externe wrapper with honest unavailable state, findings review and reversible quarantine"**
   Introduces `LegacyScanner`: wraps the system/bundled ancien scanner externe binary via `Process()`
   (`Sources/LegacyScanner/LegacyScanner.swift:56`, the only `Process()` shell-out in the codebase per
   this session's grep), with output parsing, a findings-review UI, and a reversible quarantine
   mechanism (confirmed present in `Tests/LegacyScannerTests/LegacyScannerTests.swift`:
   `quarantineAndRestoreRoundTrip`, `deleteRemovesPermanently`).

9. **`9fc7b2f` — "feat(cloud): local footprint analysis for iCloud/Dropbox/Drive/OneDrive without triggering downloads"**
   Cloud Cleanup feature; corresponding `CloudSyncStateTests` in `MyActivityGroupingTests.swift` verify
   that placeholder (not-yet-downloaded) files are classified correctly and never merged with real
   local bytes.

10. **`530827f` — "feat(performance): user LaunchAgent inspection with broken-program detection"**

11. **`0a77c6f` — "feat(images): on-device similar image grouping via Vision feature prints with lazy thumbnails"**
    Uses Apple's Vision framework on-device (no network calls implied by the description); confirmed by
    `SimilarImagesGroupTests` asserting "highest real pixel count wins, never a guess."

12. **`c56df6c` — "feat(privacy): browser profile analysis with cache-only cleaning and honest scope limits"**

13. **`c2dff93` — "feat(design): Orbital Ecology design system — tokens, semantic colors, Core Bloom, HeroCore, grouped sidebar, Smart Care hero, Performance metric cards"**
    Introduces the `DesignSystem` target (887 lines, largest non-app-shell target); `DesignSystemTests`
    confirm spacing-scale monotonicity, radius ordering, motion-duration sanity, and reduce-motion
    suppression are actually asserted, not just present as named types.

14. **`4b837d2`, `5e9f681`** — Localization infrastructure (SwiftPM `defaultLocalization: "en"` +
    `fr.lproj`) and first French strings.

15. **`4e642e0` — "feat(activity): day-grouped timeline, real/simulated split, quarantine restore logging"**
    `MyActivityGroupingTests` confirms "real vs simulated cleanup bytes never merge" is an actual
    assertion, not just a comment.

16. **`8a86220` — "fix(smart-care): separate real totals from the 5000-row display cap"**
    A real bug fix referenced in this session's brief as prior-session context; confirmed present in
    history and covered by `ScanEngineTests.engineStreamsAllFindingsUncappedAt5001`
    (`Tests/ScanCoreTests/ScanEngineTests.swift`), which passed this session.

17. **`f31e993`, `f5ad530`, `f1ec7d4`** — "Protection mesh containment visual motif," progress/state docs,
    and CONTINUATION.md consolidation, most recent pre-audit commits before `b8266a2` "release: prepare
    v0.7.0 public distribution" (current HEAD).

## What this history does NOT establish (left for session 2 / not verifiable from log alone)

- Whether "v0.7.0" as a version number has any external meaning (no tags, no releases published —
  confirmed separately: `git tag` is empty, no remotes configured).
- Whether commit dates (`2026-07-19`/`2026-07-20`) reflect real elapsed development time or are
  compressed/backdated — not something git history alone can prove or disprove.
