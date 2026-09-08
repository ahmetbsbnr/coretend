# Deep Scan — Human review log

Honest record of what was and was not verified. No fabricated manual QA.

---

## Interactive GUI acceptance — MAINTAINER VERIFIED (v1.2.0-beta.1 prep)

The maintainer performed the interactive acceptance review on real
CoreTend.app and reported the following as acceptable / working. Recorded here
verbatim from the maintainer's report — Claude did not observe these directly.

| Item | Status |
|---|---|
| Real app launch, Deep Scan reachable from navigation | **VERIFIED** |
| Light / dark UI | **VERIFIED** (acceptable) |
| Window resize | **VERIFIED** (acceptable) |
| Keyboard interaction | **VERIFIED** (acceptable) |
| VoiceOver spot-check | **VERIFIED** (acceptable) |
| Full Disk Access OFF / ON behaviour truthful | **VERIFIED** |
| Pause / Resume / Cancel (interactive) | **VERIFIED** |
| AI / LLM classifications look correct | **VERIFIED** |
| Git classifications look correct | **VERIFIED** |
| Cleanup Plan | **VERIFIED** |
| Controlled GUI cleanup | **VERIFIED** |
| SafetyCenter / PathValidator / Trash / Journal | **VERIFIED** |
| Restore Center restores the disposable fixture | **VERIFIED** |
| State-change protection behaves correctly | **VERIFIED** |
| French UI | **VERIFIED** (acceptable) |
| Critical GUI blocker | **NONE FOUND** |

The maintainer approved the conservative beta policy on the basis of this
review. The primary remaining blocker from the previous phase (GUI Trash →
Restore round trip) is therefore **closed**.

Not separately attested by the maintainer's summary, still open: exhaustive
per-screen visual pass of every empty/error/partial state, and a screen-reader
audit beyond the spot-check (full accessibility certification is not claimed).

---

## Interactive GUI acceptance gate — earlier attempt log (Claude)

**App build under review:** `feat/deep-scan-cleanup-v1.2` @ `c66… (see git log; HEAD at time of this run)`, debug + release both clean, 398 tests passing.

**Result of this run: NOT PERFORMED.** The interactive acceptance work
(§1–§14, §17 of the acceptance-gate spec) requires computer-use control of
this Mac to launch and drive the CoreTend GUI. Computer-use was held by
another Claude session (`fe1857ff…`) for the entire session; access was
requested 6 times across two phases and denied every time. There is no
headless substitute for "review every screen in light/dark", "turn VoiceOver
on", "click Restore in the Restore Center", "toggle Full Disk Access", or
"capture QA screenshots".

**Prepared for whoever runs the acceptance pass:**

- Disposable fixture created at `/tmp/coretend-deepscan-gui-qa/`:
  - `myapp/` — `package.json` declaring `next`, `.next/cache/` with 40 × 4 KiB
    chunks (≈160 KiB), `src/page.tsx`. Aged to 2026-01-01 so the
    just-modified guard won't fire.
  - `repo/` — a git repo with an `origin` remote and one commit, clean, for
    the state-change skip test (dirty it after scanning).
- **New GUI affordance** (compile-verified only, not run): the Deep Scan entry
  screen now has **"Scan a specific folder…"** (`NSOpenPanel`, dir-only) which
  sets `DeepScanViewModel.overrideRoot`; the scan is then limited to that path
  while the detector context still uses the real home. This is what makes the
  `/tmp` fixture reachable from the GUI without a full home scan. "Scan whole
  home folder" clears it. Strings `deepscan.scan_folder*` are EN+FR.
- **QA execution gate mechanism** (source default unchanged): launch with
  `CORETEND_DEEPSCAN_EXEC=1 ./.build/debug/CoreTend` — `DeepScanExecutionGate.
  isEnabledResolved` honours that env var; `DeepScanExecutionGate.isEnabled`
  stays `false` in source and `DefaultSelectionPolicy.preselectionEnabled`
  stays `false`.

**Still HUMAN VERIFICATION REQUIRED (unchanged, none closed this run):**
real app launch · light/dark/resize visual pass of every screen · keyboard
traversal · VoiceOver spot-check · FDA OFF→ON toggle QA · interactive
Pause/Resume/Cancel · GUI Cleanup Plan → Confirm → Trash · Restore Center
round trip · interactive state-change skip · French UI visual pass ·
QA screenshots.

---

## v1.2.0-beta.1 prep — headless QA (Claude, this run)

| Check | How | Result |
|---|---|---|
| Final real-Mac read-only scan | `DeepScanQA` over 7 real roots | 127,195 nodes / 3.1 s; **158 candidates**; **0 default-selected**; 1 in the executable SAFE subset (a real `.next`); 8 git repos all protected & not auto-selected; `~/.claude/projects` + `~/.codex/sessions` `protected/unknown`; LM Studio `models` `highRisk/weak` (review); 90/99 AI candidates PROTECTED |
| Safe-subset + negative-safety QA | `DeepScanQA --safe-subset-qa` (disposable fixtures, gate on) | **PASS** — developer build output executes end-to-end (approve → executed → Trash → journal `deepscan:developer-storage:.next`); **all 11 dangerous shapes blocked** from the executable subset: git repo root, AI model weights, Claude memory, Codex sessions, credentials/auth, unknown AI data, app leftover, system settings, cloud, protected-risk, below-strong-confidence. Aged-temp and AI-runtime-cache are policy-allowed but did not reach the executable subset (temp fixture not enumerated in this run; AI runtime cache requires SAFE+STRONG evidence it rarely reaches — conservative by design). |
| FSEvents real churn | `DeepScanQA --fsevents-churn` (real FSEventStream) | coalescing (1 rescan/burst); `rm -rf` prune 2,269 → 228; dropped-event → STALE → full rescan → FRESH; corrupt index rebuilt empty |
| Performance regression | full `DeepScanCorePerfTests` + 50k presentation | no material regression vs baseline (100k 132 ms, 1M 1,399 ms, 1M RSS Δ 637 MiB, 1M apply 3,431 ms, SQLite 184.6 MiB, real walk 146k n/s, cancel 0.1 ms, 50k page 73 ms) |
| Version consistency | `Scripts/check-version-consistency.sh` | OK (1.2.0-beta.1) |
| Localization parity | `DeepScanLocalizationTests` | Base/fr key-set parity for every `deepscan.*` key incl. all structured detector reasons; every key emitted by a full pipeline run exists in both files |

## Earlier phase — headless / code verification (all done, all green)

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
