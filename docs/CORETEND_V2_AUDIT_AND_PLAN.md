# CoreTend 2.0 — audit and execution plan

Written 2026-09-21, before implementing. Scope: security (repository, CI,
application, website), development quality, test strategy, debug/dev build
tiers, file and code hierarchy, repository organisation.

Two kinds of statement live here and are never mixed:

- **FINDING** — observed, with the evidence that produced it. A finding with
  no reproduction is not a finding.
- **PROPOSAL** — a decision this plan asks for. Not done yet.

Nothing below is implemented unless its line says so.

---

## Part 0 — What was verified clean

Stated first, because an audit that only lists problems invites the reader to
assume everything unmentioned is broken.

| Surface | Checked | Result |
|---|---|---|
| CI workflows (7) | action pinning, `permissions:`, expression injection, dangerous triggers | **Clean.** Every action pinned to a full SHA; every workflow declares `contents: read`; no `${{ github.event.* }}` reaches a `run:` block; `release-preflight.yml` has its own forbidden-trigger list |
| Hardened Runtime entitlements | `Configuration/CoreTend.entitlements` | **Clean, and deliberately so.** Empty dict: no `com.apple.security.cs.*` exception, no disabled library validation, no unsigned executable memory, no DYLD variables |
| App Store entitlements | `Configuration/CoreTend-AppStore.entitlements` | **Clean.** Sandboxed; user-selected files + app-scope bookmarks only; no network client, no Apple Events, no blanket Downloads grant |
| Update path | `UpdateChecker.swift`, `UpdatesView.swift` | **Clean.** HTTPS enforced at construction (`init?` returns nil otherwise); ephemeral session, no cookies, 15 s ceiling; manifest URLs re-checked for `https`; SHA-256 format validated; **nothing is downloaded or executed** — the release URL is handed to `NSWorkspace.open` on an explicit click |
| SQL | `Sources/Persistence/*.swift` | **Clean.** No string interpolation reaches any statement; every value is bound |
| Website headers | `vercel.json` | **Strong.** `script-src 'self'` with no `unsafe-inline`, `object-src 'none'`, `base-uri 'none'`, `form-action 'none'`, `frame-ancestors 'none'`, HSTS 2 y + preload, COOP/CORP `same-origin`, `Referrer-Policy: no-referrer` |
| Website resources | `Website/*.html` | **Clean.** No external script, style or font; every `target="_blank"` carries `noopener` |
| Process execution | `Sources/**` | **Clean.** No `Process`, `NSTask`, `posix_spawn`, `system()` or `popen()` anywhere in the app |
| Repository hygiene | `Scripts/repository-doctor.sh` | **Green as of `9d3faf7`/`8cc7ffd`** (was failing before this session) |

---

## Part 1 — Security findings

### S-01 — CONFIRMED · `PathValidator` protected roots defeated by case

> **Severity corrected after measuring it, 2026-09-21.** This was first written
> up as HIGH. That label described the *guard*, not the *outcome*, and the
> outcome is what a severity is for. Measured on a real machine: SIP is
> enabled, `/System/Library/CoreServices` is `restricted` and root-owned, and
> CoreTend only ever moves to the Trash. So macOS itself refuses the operation
> the bypass would reach, and CoreTend records a failure. The honest reading is
> a **defence-in-depth failure with low real-world impact** — worth fixing
> exactly as urgently as it was fixed, worth describing accurately.
>
> It is present in **every release ever published**, from the first public
> source commit (`7bf18bb`) through `v1.2.0-beta.1`, including the current
> stable `v1.0.1`. See "Historical exposure" below.

**Evidence.** `Tests/SafetyCoreTests/PathValidatorTests.swift`
`protectedRootIsNotDefeatedByCase` — currently **red**, by design, committed as
the reproduction:

```
/system/Library/CoreServices  was not treated as a protected root
/SYSTEM/Library/CoreServices  was not treated as a protected root
/Bin/ls                       was not treated as a protected root
/usr/BIN/whoami               was not treated as a protected root
```

**Mechanism.** `PathValidator.isPath(_:under:)` compares with `hasPrefix`,
which is case-sensitive. macOS volumes are case-**insensitive** by default, so
`/system/Library` and `/System/Library` are the same directory while only the
second is recognised as protected. `standardizedFileURL` removes `..`, `.` and
trailing slashes; it does not normalise case.

**Reachability.** The allowlist is the only remaining barrier: a mis-cased
system path still has to fall under an `allowedRoots` entry. It does the moment
a root at or above `/` is chosen — which the folder picker permits. So this is
a defence-in-depth failure rather than a one-click exploit, in the single most
safety-critical type in the codebase, where defence in depth is the entire
point.

**Second observation from the same work.** The pre-existing `systemRejected`
test passed **for the wrong reason**: its validator's allowlist is a temp
directory, so `/System/…` is rejected as `.outsideAllowedRoots` and the
protected-root branch is never reached. `protectedRootRejectedEvenWhenTheAllowlistWouldPermitIt`
(added, green) now isolates that branch.

**PROPOSAL P-01.** Case-insensitive comparison in `isPath`, preserving the
component-boundary rule that `prefixBoundaryNotConfused` already guards. Both
new tests green, and the existing sixteen stay green.

### S-01b — Historical exposure, measured

Both protected-root defects were checked against every tag in the repository.

| | |
|---|---|
| **Introduced** | `7bf18bb` — "Foundation: SafetyCore, ScanCore, FileRules, app shell". The guard was written this way from the first day it existed |
| **Affected releases** | every one. `v0.9.0` → `v0.9.1-rc.1…rc.6` → `v1.0.0` → **`v1.0.1`** → `v1.1.0-beta.1` → `v1.2.0-beta.1`, plus `pre-coretend-rebrand-0.8.0` and all seventeen `backup/*` tags |
| **Currently downloadable** | `v1.0.1` — signed, notarized, stapled, stable |
| **Fixed on `develop/v2`** | `139b6db`, `1fb566e` |
| **Backported to `maintenance/1.x`** | `ed7f4db` — hand-applied, four regression tests, 346 tests green. **Not tagged, not released** |

**Impact, measured on a real machine rather than asserted.** SIP is enabled by
default; `/System/Library/CoreServices` is `restricted` and `root:wheel`. So
macOS refuses the operation the bypass would reach, and CoreTend records a
failure. CoreTend only ever moves to the Trash — it never deletes — and the
allowlist must already contain an ancestor of a system root, which requires
the user to have pointed a scan at `/` or similar.

A guard that did not guard, behind two other barriers that do. It was fixed
with the urgency a broken guard deserves; it is described with the accuracy
the outcome deserves.

**What is not established:** whether any user ever pointed a scan at a root
broad enough to reach this. Nothing in the product reports scan roots
anywhere, by design — there is no telemetry — so that question has no
answer and will not get one.

### S-02 — TO INVESTIGATE · protected-root list completeness

`protectedRoots` omits `/Library/LaunchDaemons`, `/Library/LaunchAgents`,
`/private/etc`, `/usr/local` and `/opt`. Some omissions are certainly
deliberate (`/Applications` must be reachable for uninstall). Whether the
launch-daemon directories should be reachable at all is a product question, not
a bug to fix silently.

**PROPOSAL P-02.** Decide each omission explicitly and record the reason next
to the list, so the next reader does not re-derive this. No path added or
removed without a stated reason.

### S-03 — TO INVESTIGATE · `/System/Volumes/Data` firmlink

On modern macOS, `/System/Volumes/Data/Users/…` is the same file as
`/Users/…`. Today it is refused as a protected root — safe, but it means a
legitimate path spelled that way is rejected with a misleading reason.
Confirm whether any real caller can produce that spelling.

### S-04 — ACCEPTED RISK, DOCUMENTED · TOCTOU window

`validate()` returns the *unresolved* standardized path, so a component could
in principle be swapped between validation and use. Mitigated in practice:
`SafetyCore.execute()` re-validates every operation immediately before acting
(`SafetyCore.swift:273`), and `symlinkSwappedAfterApprovalRejected` tests
exactly that sequence. An attacker would already need write access to the
user's own directories. **No change proposed** — recorded so it is not
rediscovered as new.

### S-05 — INFORMATIONAL · `style-src-attr 'unsafe-inline'`

The one relaxation in an otherwise strict CSP. It permits inline `style=`
attributes, not inline `<script>`. Low risk with `script-src 'self'` and no
user-generated content on the site. **No change proposed**; recorded.

### S-06 — RESOLVED THIS SESSION · private path in a public repository

Three `.claude-flow/` files committed by accident in `033037c`, one carrying
the developer's absolute home path. Untracked and ignored in `9d3faf7`. **The
path remains in git history** — rewriting shared history is a decision for the
repository owner, not a side effect of an audit.

**PROPOSAL P-06.** Decide: leave it (a home directory name is low-value), or
rewrite history and force-push, which breaks every existing clone and needs
explicit authorisation.

### S-07 — RESOLVED THIS SESSION · secret gate that cried wolf

The secret regex matched `let token = NotificationCenter.default…` on every
run while missing quoted JSON keys, single-quoted literals and uppercase
env-style assignments. Rewritten and verified in both directions in `9d3faf7`.

---

## Part 2 — Correctness findings

### C-01 — RESOLVED · Reduce Motion ignored at five call sites

`6dbca74`. The motion audit had checked durations, never whether an animation
was allowed to play at all.

### C-02 — RESOLVED · Integrity truncated its own honesty statement

`27c31e5`. Also closed the matrix gap that let it go unseen.

### C-03 — RESOLVED · settings matrix documented two deleted settings

`8cc7ffd`.

### C-04 — TO INVESTIGATE · `Documentation/PROJECT_STATE.json` is stale

Declares `phase: patch-pending`, `branch: hotfix/v1.0.1-launch-crash`,
`release.tag: v1.0.0`, `tests: 418`. Reality: `develop/v2`, tag `v1.0.1`
published, 677 tests. Unknown whether the file is generated or hand-maintained,
and whether it is meant to describe v1 only.

**PROPOSAL P-04.** Establish which, then either regenerate it or state in the
file itself that it tracks the published release and not the working branch.

### C-05 — OPEN DECISION · `graphify-out/` and `.gitignore`

`.gitignore` excludes only `graphify-out/cache/`, `manifest.json` and the
marker files — implying `graph.json` (7.5 MB) and `graph.html` (531 KB) are
*meant* to be committed, to a public repository.

**PROPOSAL P-05.** Either ignore the directory wholesale (the graph is derived
and rebuilt on demand) or commit it deliberately and say why. Not decided
unilaterally.

---

## Part 3 — Test strategy

### Current state, measured

| Target | Files | `@Test` | LOC |
|---|---|---|---|
| CoreTendAppTests | 50 | 405 | 5 603 |
| PersistenceTests | 4 | 66 | 1 092 |
| DesignSystemTests | 4 | 60 | 1 107 |
| ScanCoreTests | 9 | 52 | 1 351 |
| SafetyCoreTests | 2 | 36 | 437 |
| AppDiscoveryTests | 1 | 22 | 230 |
| IntegrityCoreTests | 1 | 20 | 368 |
| FileRulesTests | 1 | 8 | 92 |
| CoreTendAccessibilityTests | 1 | 5 | 106 |
| **CoreTendIntegrationTests** | 1 | **1** | 27 |
| **CoreTendPerformanceTests** | 1 | **1** | 43 |
| **SystemMetricsTests** | 1 | **1** | 23 |
| **CoreTendUITests** | 1 | **0** | 153 |
| **UIAutomation** | 1 | **0** | 134 |

Modules with **no test target at all**: `CoreTendCLI` (a shipped binary),
`CoreTendAppStore`, `CoreTend`.

### T-01 — FINDING · the integration target is a placeholder

One test, 27 lines, for the target whose name promises end-to-end coverage of
scan → review → approve → execute → record. Every part is unit-tested in
isolation; the seam between them is not.

**PROPOSAL.** Real integration tests over the actual pipeline on a temp
fixture tree: a scan producing findings, an approval batch, an execution, and
the resulting `safety_log` and Record rows — including the partial-failure path
(one file vanishes mid-batch) and the refusal path (a protected path in the
batch).

### T-02 — FINDING · `FileRules` is thin for what it decides

186 lines of rules deciding what may be moved to the Trash, 8 tests.

**PROPOSAL.** Property-based coverage: for every rule, a path that matches, a
path that nearly matches (boundary), a path under a protected root, a symlink,
and a path with Unicode/space/newline characters.

### T-03 — FINDING · `SystemMetrics` has one test

A module reading live CPU, memory pressure and thermal state — now
load-bearing for the menu-bar and Performance attention policy unified in
`68bbc83`.

**PROPOSAL.** Test the pure interpretation layer (token → verdict) exhaustively
over every documented macOS token, including unknown tokens, which must degrade
to "no verdict" rather than to a false all-clear.

### T-04 — PROPOSAL · a per-function test tier

What the user asked for, made concrete. Three tiers, named so a failure says
where it is:

1. **Unit** (`*Tests`) — one function, pure, no I/O. Fast, run on every save.
2. **Contract** (`*ContractTests`, the convention this repo already uses) —
   a boundary's promise: menus, context menus, module sub-nav, window focus.
3. **Integration** (`CoreTendIntegrationTests`) — several modules over a real
   temp filesystem.

### T-05 — PROPOSAL · coverage measurement, not coverage belief

`swift test --enable-code-coverage` plus `llvm-cov` into a per-module report,
so "thin" stops being a judgement call. Wired into a script, not a one-off.

---

## Part 4 — Debug and development build tiers

Requested: debug builds, dev builds, concrete test builds per area/file/function.

### What already exists, measured

Nineteen `CORETEND_*` environment switches, all read at runtime:

| Switch | Purpose |
|---|---|
| `CORETEND_TEST_MODE`, `CORETEND_TEST_STORE_DIR`, `CORETEND_TEST_HOME` | isolated store and home, so no test touches real data |
| `CORETEND_TEST_MODULE`, `_TAB`, `_APPEARANCE`, `_WINDOW`, `_SETTINGS`, `_ONBOARDING`, `_AUTOSTART` | drive the capture harness |
| `CORETEND_HITTEST_HUD`, `CORETEND_SIDEBAR_DIAG`, `CORETEND_FOCUS_PROBE`, `CORETEND_TRACE_FOCUS` | interaction instruments |
| `CORETEND_APP_STORE` (compile-time `-D`) | the sandboxed build |

Build entry points: `Scripts/build.sh [release]`, `Scripts/package-local.sh`,
`Scripts/package-dmg.sh`, `Scripts/test.sh`.

**This is already a strong debug tier.** The gap is not switches — it is that
they are undiscoverable and unenumerated.

### D-01 — PROPOSAL · `Scripts/dev.sh`, one door

A single entry point wrapping what exists rather than adding a parallel system:

```
Scripts/dev.sh run      [module] [light|dark] [WxH]   # launch on a seeded, isolated store
Scripts/dev.sh hud      [module]                      # launch with the hit-test HUD
Scripts/dev.sh shot     <module> [...]                # one capture
Scripts/dev.sh test     [filter]                      # Scripts/test.sh, narrowable
Scripts/dev.sh cover                                  # coverage report (T-05)
Scripts/dev.sh doctor                                 # repository-doctor + private-data + licences
Scripts/dev.sh env                                    # print every CORETEND_* switch and what it does
```

`dev.sh env` reads the switches out of the source rather than from a
hand-kept list, so it cannot drift — the same discipline
`generate-settings-matrix.py` already applies to settings.

### D-02 — PROPOSAL · a debug configuration that is not the release one

`swift build` today produces the same feature set as release. Proposal: a
`CORETEND_DEBUG_TOOLS` compile-time define gating the instruments, so the
release binary cannot contain them at all — replacing the current runtime
guard, which ships the code and trusts an environment variable. The acceptance
doc's "no debug HUD reachable without `CORETEND_HITTEST_HUD=1`" becomes "not
present in the binary".

---

## Part 5 — Architecture, hierarchy and organisation

### Measured state

`Sources/` — 12 modules, 1 686 symbols in the code graph, 11 928 edges.
`CoreTendApp` holds 1 221 of them (72 %) across **78 flat files**.

Hubs: `L()` 183 edges · `ModuleID` 71 · `Store` 58 · `mcFormatBytes()` 53 ·
`PathValidator` 39. No orphaned symbol found.

Largest files: `OverviewScreen` 960 · `SpaceLensView` 952 ·
`ApplicationsView` 883 · `DuplicatesView` 882 · `RecordView` 781.

### A-01 — FINDING · `CoreTendApp` is one flat directory of 78 files

`App/` (5 files) and `Shell/` (2) exist; the other 71 sit at the root, mixing
screens, view models, formatting helpers, diagnostics instruments and system
plumbing. Finding "everything Duplicates touches" means knowing the names
already.

The existing backlog records this as *deliberately deferred* (~110 files, real
regression risk, no product gain). **That judgement stands for a move of
everything.** What it does not cover is a move of a clearly separable subset.

**PROPOSAL A-01.** One conservative split, `git mv` only, no code edits:

```
Sources/CoreTendApp/
  App/           (exists)     app lifecycle, window, routing, catalogue
  Shell/         (exists)     menus, menu bar, sidebar, sidebar footer
  Modules/       new          one directory per destination, eight of them
  Support/       new          formatting, paths, icons, environment, L10n
  Diagnostics/   new          HitTestHUD, FocusProbe, FocusTrace,
                              SidebarHoverDiagnostics, SidebarV1Control,
                              CaptureHarness, VisualBeta*
```

`Diagnostics/` first and on its own: seven files, no product code depends on
them, and it is the set D-02 would gate out of the release binary — so the
move and the compile-time gate are the same piece of work. Modules/ and
Support/ follow only if that lands cleanly.

`SourceTree.swift` already exists in the test helpers precisely because a
previous split silently blinded the source-scanning tests. Every one of them
must be re-run and *seen to still see everything* after each move.

### A-02 — PROPOSAL · a written reasoning strategy

Requested explicitly. The conventions are currently spread across
`CLAUDE.md` (11 interface principles), `DEVELOPMENT.md`, `DESIGN.md`, the
masterplan and the acceptance doc. Proposal: one `docs/ENGINEERING_RULES.md`
that states the decision procedure rather than repeating the rules —

- what evidence each class of claim requires (visual / interaction / functional),
- when a check is worth adding and how it must be verified negatively,
- what makes a rectangle, an abstraction, or an animation justify itself,
- where a new file goes, and what forbids a new top-level directory,
- what may never be decided by an agent alone (safety posture, release, history).

It links to the existing documents; it does not copy them. One page.

### A-03 — FINDING · five view files over 780 lines

Not automatically wrong — a screen is a screen. But `OverviewScreen` at 960
lines mixes masthead, capacity band, signal tiles, activity list, context rail
and first-run recomposition.

**PROPOSAL.** Split by band into `Modules/Overview/` once A-01 lands, extracting
whole `private var` sections without changing them. Measured by the same rule
as everything else: if the split does not make a specific question easier to
answer, it is not done.

---

## Part 6 — Execution order

Safety first, then the things that make the rest verifiable, then structure.

| # | Item | State |
|---|---|---|
| 1 | **P-01** `isPath` direction-of-safety per caller | **done** — `139b6db` |
| 2 | **P-02** protected-root list reasoned, each entry justified | **done** — `1fb566e`, and it found a second, worse defect (below) |
| 3 | **S-03** firmlink / alias spelling | **done** — `1fb566e` |
| 4 | **T-05** coverage measurement | **done** — `7df1ac6` |
| 5 | **T-01/T-02/T-03** integration, FileRules, SystemMetrics | **done** — `45698aa`, `65ee9bc`, `c0e4a7f` |
| 6 | **D-01** `Scripts/dev.sh` | **done** — `0f5be8f` |
| 7 | **D-02** `CORETEND_DEBUG_TOOLS` gate | **DROPPED — see below** |
| 8 | **A-01** `Diagnostics/` move | **done** — `a5d6e2f` |
| 9 | **A-02** `ENGINEERING_RULES.md` | **done** |
| 10 | **A-03** Overview split | still open |

### What execution changed about the plan

Three items were reversed by evidence. Recorded here because a plan that only
records its successes teaches nothing.

- **D-02 is dropped, not deferred.** It proposed compiling the instruments out
  of release builds. `package-local.sh` builds `-c release`, and
  `hit-test-evidence.sh`, `capture-module.sh`, `capture-matrix.sh` and
  `audit-accessibility.sh` all run against that packaged release app. The gate
  would have destroyed the evidence pipeline this project judges itself by.
  Shipping the instruments behind a runtime switch is what makes a release
  build auditable.
- **P-02 reversed on `/Library/LaunchAgents` and `/Library/LaunchDaemons`.**
  Adding them looked obvious and would have silently disabled app
  uninstallation: `ApplicationsView` grants exactly those two in a
  per-operation allowlist so an app's own `<bundleID>.plist` can be removed,
  and a protected root outranks any allowlist.
- **T-02 was not what it looked like.** `FileRules` was called under-tested on
  a test count; its eight tests already cover matchers, scoping and root
  coverage. Two specific invariants were genuinely missing, and those were
  added instead of padding.

### S-01 grew a second finding while being fixed

Checking the protected-root list against resolved paths revealed that it had
**never** been checked against them: `/var/db/SystemPolicy` — Gatekeeper's own
database — and `/etc/passwd` validated cleanly, because macOS ships `/etc`,
`/var` and `/tmp` as symlinks into `/private`, the list is written in
`/private` form, and only the as-written path was ever tested. Both obvious
canonicalisations were wrong (`resolvingSymlinksInPath` normalises *away* from
`/private`; `realpath` returns NULL for a path that no longer exists), so the
fix normalises deterministically and offline. `1fb566e`.

New finding, recorded rather than acted on: `swift-testing` now emits a
deprecation — it ships in the Swift 6 toolchain, so removing the package
dependency would leave this project with **zero dependencies of any kind**.
Worth doing deliberately, not as a side effect: it touches `Package.swift`,
`Package.resolved` and the CommandLineTools flags `Scripts/test.sh` carries.

Decisions this plan asks of the user, which it does not take:
**P-06** (rewrite history or accept the home-directory name),
**P-04** (what `PROJECT_STATE.json` is for),
**P-05** (commit the 7.5 MB graph or ignore it),
and the standing ones: hover P0, the generational verdict, and release.

---

## What this plan does not claim

No claim is made about runtime behaviour under Reduce Transparency or
Increase Contrast (not testable on this machine — the setting is system-wide
and its domain is not writable here), about hover routing (synthetic pointer
automation cannot drive `.onHover`), or about how any of this looks to someone
who has used 1.0.1. Those close with a person, not a pass.
