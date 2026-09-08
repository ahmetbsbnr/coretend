# Deep Scan — Human review log

Honest record of what was and was not verified in the beta-hardening phase.
No fabricated manual QA.

## What was actually done (automated / headless, this environment)

| Area | How | Result |
|---|---|---|
| Build | `swift build`, `swift build -c release` | clean |
| Full test suite | `bash Scripts/test.sh` | all passing (see final report for count) |
| DeepScanCore unit + adversarial | `--filter DeepScanCoreTests` | 49 passing incl. revalidation, executor, adversarial skips, AI-protection regressions, dep-dir exclusion |
| Presentation / view-model logic | `DeepScanPresentationTests`, `DeepScanViewModelTests` | passing; 50k-candidate filter+sort+page ≈ 63 ms |
| Localization parity | `DeepScanLocalizationTests` | Base/fr key-set parity for every `deepscan.*` key; prose keys translated |
| Large-scale performance | `DeepScanCorePerfTests` (100k/500k/1M synthetic + 6k real walk) | no material regression vs baseline; numbers in `PERFORMANCE.md` |
| Memory (1M-node RSS) | analysis in `PERFORMANCE.md` | ~0.7–1.0 GiB upper bound, high variance; decision: no engine rewrite, page from SQLite past ~500k |
| FSEvents real churn | `DeepScanQA --fsevents-churn` (real `FSEventStream`) | npm-install / next-build / dir-replace / `rm -rf` / rename / rapid-write / git-checkout bursts; coalescing confirmed (1 rescan per burst); **found + fixed** a directory-removal prune gap; dropped-event → STALE → full rescan → FRESH; index never FRESH while a rescan pending; details in `FSEVENTS_REAL_QA.md` |
| Index corruption recovery | `--fsevents-churn` step 7 + `indexCorruptionIsRecovered` test | non-SQLite file discarded, rebuilt empty (0 rows ⇒ no stale candidate can survive) |
| Controlled cleanup (non-GUI) | `DeepScanQA --controlled-cleanup` with `CORETEND_DEEPSCAN_EXEC=1` on a disposable fixture | real `.next` fixture → `ExecutableSubsetPolicy` → `ExecutionRevalidator` → `SafetyCenter.approve` → `execute` → **moved to Trash**; audit journal recorded `deepscan:developer-storage:.next` `approved` + `executed`; original verified gone |
| Adversarial execution | `adversarialExecutionAllSkipWithTruthfulReasons` + `revalidator*` tests | path vanished / owner running / inode replaced / symlink swap / repo now dirty → all SKIP with truthful journalled reason |
| Real-Mac read-only findings | `DeepScanQA` over `~/.claude ~/.codex ~/.cache ~/Library/Caches ~/Developer ~/Downloads ~/Library/LaunchAgents` | 157 candidates; LM Studio weights = review; 90 AI stores PROTECTED; `~/.claude/projects`+`history`+`.credentials.json`+`.codex/sessions` PROTECTED; 8 git repos classified; **0 default-selected**; **1** in the executable SAFE subset |
| Preselection audit | read-only report | 233→157 candidates after excluding dependency-internal build dirs; SAFE/STRONG bar 70→1 |

## What was NOT done (still HUMAN VERIFICATION REQUIRED)

The interactive GUI review could not be performed in this run: the machine's
computer-use control was held by another session for the whole phase, so the
CoreTend app was **not launched or clicked** here.

Not verified:

- **Real app launch** — the built `CoreTend` binary was not run interactively;
  Deep Scan reachability from the live sidebar was confirmed only by the
  `SidebarGroup` / `MainWindow` switch in code + `CommandPaletteTests`.
- **GUI visual review** — window sizing (narrow / large), light vs dark,
  sidebar navigation, category switching, result paging scroll behaviour,
  search/sort/filter interaction, protected-row rendering, Git rows, AI/LLM
  grouping, app-leftover rows, System & Settings rows, the Cleanup Plan sheet,
  the Settings sheet, long-path truncation, large-size formatting, zero-result
  / permission-denied / partial-scan / scan-error empty states. **None clicked.**
- **Keyboard navigation** — Tab / Shift-Tab / Space / Return / Escape / arrows
  through the Deep Scan screens. **Not tested.**
- **VoiceOver** — not run; enabling VoiceOver is a system-wide change not made
  autonomously. Accessibility labels exist in code (`.accessibilityIdentifier`
  on the root; standard controls) but were **not** audited with the screen
  reader.
- **Full Disk Access toggle QA** — toggling FDA for CoreTend.app in System
  Settings is a security-settings change and was **not** performed. The
  permission probe logic and the four-state banner are covered by
  `FULL_DISK_ACCESS_QA.md` from the read-only run (state observed: *Partial*),
  but the live Full ⇄ Partial switch after a real grant/revoke was not seen.
- **Pause / Resume / Cancel feel** — the engine's pause/resume/cancel are
  covered by `DeepScanCorePerfTests` (cancel 0.1 ms) and unit tests; the
  *interactive* feel during a multi-second real scan, and the progress UI
  updating live, were not observed.
- **GUI Trash → Restore round trip** — the Cleanup Plan → Move to Trash →
  Safety Log → **Restore Center** flow was verified end-to-end **only in
  code** (`DeepScanQA --controlled-cleanup` proves candidate → revalidator →
  SafetyCenter → Trash → journal; the Restore Center reinstates from the
  journal). The maintainer must click this through once in the running app to
  close the blocker.
- **State-change GUI QA** — the "Skipped — changed since scan" outcomes are
  proven by unit tests against `ExecutionRevalidator`; they were not
  reproduced through the actual Cleanup Plan sheet.
- **Detector-generated sentences in French** — the fixed UI chrome, enum
  labels, phases, permission states and skip reasons are localized EN+FR;
  per-candidate `rationale` / `ifRemoved` / `protectedReason` / evidence text
  are composed in `DeepScanCore` from tool names + byte counts + paths and
  remain **English**. A localization-callback design for those is deferred.

## Bottom line

Every headless / code-verifiable item in the phase is done and green, and two
real bugs were found and fixed by the QA (FSEvents directory-removal prune;
dependency-internal build-dir false positives). The **interactive running-app
review and the GUI Trash/Restore round trip remain unperformed**, so the
phase's exit condition for "BETA APPROVAL READY" is **not** met by this run.
