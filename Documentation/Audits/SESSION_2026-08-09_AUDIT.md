<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Session audit — 2026-08-09

Independent re-verification this session. Every claim below was checked
against real source/tooling output, not carried over from prior docs. Where
this contradicts an older document, the older document is stale, not this one
— see "First-contact caution" in `NEXT_SESSION_PROMPT.md`.

## 1. Duplicate repo cleanup (workspace-level, outside this repo's tree)

`~/Developer/Website/coretend` (top-level, clean `main`, HEAD `63cd103`) and
`~/Developer/Website/products/coretend/app` (this repo) were two independent
clones of the same GitHub remote, out of sync. Owner confirmed `products/`
is canonical. The top-level duplicate and a similarly duplicated
`~/Developer/Website/stagepilot` clone (no `origin` remote, uncommitted work)
were **moved, not deleted**, to
`~/Developer/Website/_backups/dedup-20260808T235500/moved-duplicates/`, after
`git bundle create --all` + SHA-256 for both. Restore instructions in that
backup dir's `RESTORE.md`.

## 2. Developer ID — corrected finding

The owner stated Developer ID was installed. Verified with
`security find-identity -v -p codesigning`, `security find-identity -v`, and
a full keychain scan (login + System) across all label/subject fields:

- **No "Developer ID Application" identity exists** in any keychain on this
  Mac. Only the Apple-issued "Developer ID Certification Authority"
  intermediate CA certificates are present (these ship with Xcode/are
  auto-trusted; they are not a signing identity).
- Only signing identity present: `Apple Development:
  bas.ahmet5703@gmail.com (SNG9ZLAS59)` — a development identity, not
  Developer ID.
- No `notarytool` keychain profile (`AC_NOTARY` or otherwise) exists.
- This matches `HUMAN_BLOCKERS.md`'s prior finding of "0 valid identities" —
  nothing changed since. **Status: NOT READY**, not "ready for 1.0" as
  claimed. No paid Apple Developer Program membership evidence found.

No signing/notarization/stapling was attempted this session, per explicit
owner instruction that this stays out of scope until 1.0 gates are green
regardless of certificate status.

## 3. Real build/test verification

```
swift build         → Build complete! (17.69s), exit 0
swift test           → Test run with 338 tests passed after 14.031 seconds, exit 0
```

All 338 tests across all suites passed, 0 failures. This matches
`PROJECT_STATE.md`'s last recorded count order-of-magnitude (296→338 grew
since the 0.9.0 checkpoint quoted there, consistent with rc.5 development).

## 4. Product identity (from source, not docs)

- `Package.swift`: package name `CoreTend`, Swift tools 6.0, macOS 14+,
  9 library/executable targets, 12 test targets (unit + integration + UI +
  accessibility + performance).
- `Resources/Info.plist`: `CFBundleIdentifier` `com.ahmetbsbnr.coretend`,
  `CFBundleShortVersionString` `0.9.1`, `CFBundleVersion` `915`,
  `CoreTendMarketingVersion` `0.9.1-rc.5`, `LSMinimumSystemVersion` `14.0`.
- `Configuration/CoreTend.entitlements`: deliberately empty/no sandbox, with
  an inline comment explaining why (arbitrary-directory scanning is
  incompatible with the App Sandbox container model). Hardened Runtime is
  documented as "still enabled" in the comment but there is no entitlements
  key that turns it on from this file — Hardened Runtime is a codesign-time
  flag (`--options runtime`), applied by the signing script, not stored here.
  Not a defect; just noting the entitlements file alone doesn't prove HR is
  wired up — verify the actual signing script when that phase starts.

## 5. New finding: unreachable legacy modules (dead code, not previously tracked)

`Sources/CoreTendApp/CoreTendApp.swift`'s `ModuleID` enum still declares
`.performance`, `.myClutter`, `.cloudCleanup` (and `.favoritesRecents` is
also absent from the sidebar), each with a live `case` in the detail-view
`switch` (`PerformanceView()`, `MyClutterView()`, `CloudCleanupView()`), but
`SidebarGroup.all` — the only place `visibleModules` is built from — never
includes them. They compile, have their own view files
(`PerformanceView.swift`, `MyClutterView.swift`, `CloudCleanupView.swift`,
`FavoritesRecentsView.swift`), and are exercised by nothing reachable from
the actual app UI. `ApplicationsView.swift` similarly embeds `LeftoversView`
and `AppUpdatesView` as subviews (those *are* reachable, just not top-level
sidebar entries — not flagged as dead).

This was not in `TECHNICAL_DEBT.md` before this session. It matches the
enum's own internal case *names* (`smartCare`, `cleanup`, `protection`)
which are stale relative to their current public labels (Dashboard, Storage,
Integrity) — the rename to current terminology only touched `label`/
`identity`, not the case identifiers or the unused view files. Low severity
(dead code compiles fine, ships unused, no user-facing effect since
unreachable) but real: contradicts README's claim that "the maintained
branch contains the real Dashboard, Storage, Space Lens, Duplicates,
Applications, Integrity and Activity workflows" as the *complete* current
set — three more views exist and build, just aren't wired to navigation.

**Recommended fix** (not yet applied): delete
`PerformanceView.swift`, `MyClutterView.swift`, `CloudCleanupView.swift`,
`FavoritesRecentsView.swift` and their `ModuleID` cases/switch arms if truly
retired, or wire them into `SidebarGroup.all` if they're meant to ship.
Needs an owner decision — not a call to make silently, since it changes what
ships in the next RC.

## 6. `TODO.md` is a stale planning document, not current state

`TODO.md` (repo root) is written as if ClamAV is still part of the product
("ClamAV absent", "installer ClamAV guidance", "base antivirus corrompue/
obsolète" throughout its crash-test matrix). But `Documentation/
CLAMAV_DECISION.md` and `RELEASE_STATE.md` both confirm ClamAV was fully
retired in commit `eac408c`, replaced by IntegrityCore (native, read-only,
no external scanner). `TODO.md` predates that retirement and was never
updated. Its other content (Mac-launch-failure repro, DMG redesign, crash
test matrix, GitHub attestation verification, portfolio-sync workflow
dry-run) is still procedurally valid and matches `HUMAN_BLOCKERS.md`'s open
items — only the ClamAV framing is wrong. **Recommend**: strip ClamAV
references from `TODO.md` or archive it under `Documentation/Archive/` and
regenerate its checklist from `KNOWN_ISSUES.md`/`HUMAN_BLOCKERS.md`, which
are current.

## 7. Portfolio repo: real fix committed, not noise

`ahmetbsbnr-portfolio`'s uncommitted diff (`CoretendMark.tsx`,
`CoretendExperience.tsx`) was a genuine in-progress token-parity fix
(swapping stale `--ct-cobalt-deep`/`--ct-graphite` for `--ct-ink`/
`--ct-line-strong` to match the site's canonical mark palette), not noise.
Committed to `fix/coretend-mark-token-parity` and pushed rather than
discarded or force-committed to `main`.

## 8. What this session did NOT do (explicit scope boundary, not oversight)

Everything below is real, unresolved work `TODO.md`/`HUMAN_BLOCKERS.md`
already track and this session did not attempt, because it genuinely
requires a second physical/virtual Mac, a display session, or human
judgment this environment does not have:

- Reproducing the "didn't launch on another Mac" bug on a clean machine
- DMG visual redesign and Retina screenshot capture
- Full client-journey walkthrough (download → onboarding → uninstall)
- The 40+-item crash-test matrix in `TODO.md` §8
- GitHub attestation verification against the tagged workflow
- A live `workflow_dispatch` run of the portfolio-sync workflow
- Interactive VoiceOver/keyboard/Dynamic Type QA (no display session)
- Any signing, notarization, stapling, or public artifact replacement (out
  of scope by owner instruction until 1.0 gates are green)

These stay open. Nothing here should be read as "1.0 gates are green" —
they are not.

## 9. Follow-up: the three "dead" modules were not actually redundant

Owner asked for a redundancy check on `PerformanceView`/`MyClutterView`/
`CloudCleanupView` before any deletion. The check found each one owns real,
non-duplicated capability:

- **PerformanceView**: `LaunchAgentInspector` flags LaunchAgents whose
  `Program`/`ProgramArguments` target no longer exists on disk — a broken
  dead LaunchAgent. `IntegrityCore.LoginItemScanner` (used by the reachable
  Integrity module) enumerates the same three directories but its
  `LoginItem` struct carries no validity/broken field — it does not
  duplicate this check. The rolling 60-sample CPU history chart also has no
  equivalent (Dashboard shows only an instantaneous snapshot).
- **MyClutterView**: wraps `DuplicatesView`/`SimilarImagesView` (already
  reachable elsewhere — that part *is* redundant navigation, not redundant
  code) around one genuinely unique tab, `LargeOldFilesView` — a
  size/age-filtered file finder (QuickLook preview, exclusions, per-volume
  filter) that `CleanupView` (Storage) does not have.
- **CloudCleanupView**: local-vs-remote sync-state analysis for
  iCloud Drive/Dropbox/Google Drive/OneDrive local caches. Nothing else in
  the app inspects cloud-placeholder byte ratios.

None were deleted. Per the owner's "no functionality is deleted only to
tidy up" instruction, all three were **reconnected**: `SidebarGroup.all`
gained a third, lower-priority "More" group (`sidebar.more`) holding
`.myClutter`, `.cloudCleanup`, `.performance`, alongside the unchanged
seven-module primary group. `CommandPaletteTests.everyModuleHasLabelAndIcon`
asserted the exact prior 8-item visible list; its expectation was updated
to the new 11-item list rather than left to rot.

`FavoritesRecentsView` — real, tested, backed by `Persistence` — was
similarly reconnected, but per the owner's explicit instruction, *not* as a
14th sidebar item: it already only ever had one consumer
(`SpaceLensView`, via the pre-existing `.mcOpenSpaceLensAt` notification),
so it's now presented as a sheet from a new toolbar button in Space Lens
(`spacelens.favoritesRecents.open`). Its `ModuleID` case, and the
now-orphaned switch arms that referenced it, were removed — it was a
standalone-module-shaped wrapper around something that was never meant to
be a standalone module. `MCModuleIdentity.favoritesRecents` in the
`DesignSystem` token catalog was left alone (harmless unused public
constant in a library that's meant to enumerate identities, not itself
evidence of a broken route).

New regression test: `SidebarReachabilityTests` (`Tests/CoreTendAppTests/`)
asserts `Set(ModuleID.allCases) == Set(SidebarGroup.visibleModules)` and
that no module appears in two groups — the exact class of bug this session
found (a case that compiles, has a live switch arm, and is invisible to the
user) can no longer land silently.

Two new localization keys, `sidebar.more` and
`spacelens.favorites_recents`, were added to both `Base.lproj` and
`fr.lproj` `Localizable.strings` (which are UTF-16BE — edited via a Python
script that round-trips the encoding exactly, not a raw text edit, to avoid
corrupting the file). All other strings used by the four views already
existed with full en/fr parity before this session.

`swift build` and `swift test` both green after these changes: 340/340
tests pass (338 prior + 2 new `SidebarReachabilityTests`).

## 10. TODO.md rewritten

`TODO.md` no longer frames any item around ClamAV. The prior version is
preserved verbatim at `Documentation/Archive/
TODO_2026-08-08_pre-integritycore-cleanup.md`. The rewritten file keeps only
genuinely open items (clean-Mac launch repro, DMG redesign, full client
journey, crash-test matrix, GitHub attestation verification, portfolio-sync
dry-run, interactive accessibility QA, RC republish-if-changed) and states
plainly, again, that Developer ID Application is not installed and signing
stays out of scope until 1.0.

## 11. Compatibility Matrix — root cause, fix, and confirmed green (resolved)

Follow-up session, same day. The scheduled "Compatibility Matrix" workflow
(`.github/workflows/compat-matrix.yml`, macos-14 + macos-15, both pinned to
Xcode 16.2) had gone red 5 days earlier. Audited before touching anything:

- **It was not a regression.** `gh run list --workflow "Compatibility
  Matrix"` shows exactly **one run, ever** (2026-08-03, run `30803092967`),
  and it failed. The workflow file's own header already said
  `IMPLEMENTED_UNVERIFIED — never executed`. There was nothing green to
  regress from.
- **Root cause, both runners, identical**: `DuplicatesView.swift:184:34:
  error: call to main actor-isolated static method 'csvField' in a
  synchronous nonisolated context` — 40 identical diagnostics (one per
  generic-specialization instantiation), same line, same message, macos-14
  and macos-15 alike. `csvField` is a pure string-escaping `private static
  func` inside `@MainActor final class DuplicatesViewModel`, called as
  `.map(Self.csvField)`.
- **Toolchain comparison** (all three checked directly, not assumed):
  - Compat matrix: **Xcode 16.2, Swift 6.0.3** (confirmed from the failing
    run's own "Toolchain versions" step output) — the one that fails.
  - Main CI (`ci.yml`, green, no explicit Xcode pin): **Xcode 16.4, Swift
    6.1.2** (confirmed from the last green run's `doctor.sh` output) — the
    one that passes.
  - Local dev machine: **Xcode 26.6, Swift 6.3.3** — also passes.
  - Swift 6.0.3 treats extracting `Self.csvField` as a bare function value
    (passed to `Array.map`) as crossing an actor-isolation boundary; 6.1.2
    and 6.3.3 do not flag the same code. `exportCSV()` only ever runs
    synchronously already on `MainActor` — this was never a real data race,
    it's an isolation-inference gap between Swift point releases.
  - Checked project-wide for the same pattern (`.map(Self.*)` etc.): one
    other hit, `Persistence/Store.swift`'s `Self.locationRecord` — inside a
    plain (non-`@MainActor`) `actor`, where static members are non-isolated
    by default already. Different case, not affected, not touched.
- **Is Xcode 16.2 still a deliberate floor?** Yes — kept, not raised.
  `Package.swift` targets `swift-tools-version: 6.0` / macOS 14, and the
  narrow inference gap is fully addressed by making the truly-unisolated
  function's isolation explicit rather than compiler-inferred, which is
  correct on every Swift 6.x compiler, not a version-specific workaround.
  Raising the floor was considered and rejected: there was no evidence it
  was needed once the source-level fix was verified.
- **Fix**: marked `csvField` `nonisolated` (`Sources/CoreTendApp/
  DuplicatesView.swift`, commit `43ad030`). No `continue-on-error`, no
  matrix trimming, no workflow-level suppression — a one-line source fix at
  the actual isolation boundary.
- **Verified for real, not assumed**: local `swift build` / `swift build -c
  release` / `swift test` (340/340) all green on Xcode 26.6 first (this
  environment cannot reach Xcode 16.2 — no second Mac). Real proof came
  from triggering the workflow itself via `workflow_dispatch` on
  `release/coretend-final` (run `31283226551`): **both macos-14 and
  macos-15 passed — Debug build, Tests, and Release build all green, on
  the actual Xcode 16.2 / Swift 6.0.3 toolchain** — the workflow's first
  ever green run.

**Status: RESOLVED, not merely worked around.** Evidence:
https://github.com/ahmetbsbnr/coretend/actions/runs/31283226551

## 12. Branch state — no divergent history

Checked directly (`git rev-parse`, `git log A..B`), not assumed:

| Branch | HEAD (final) | Relative to `main` |
|---|---|---|
| `main` | `63cd103` | — |
| `feat/design-system-foundation` | `43ad030` | 4 commits ahead, 0 commits main has that it lacks (linear, not diverged) |
| `release/coretend-final` | `43ad030` | **identical** to `feat/design-system-foundation` — same commit |

The two working branches were never divergent histories; `release/coretend
-final` was cut from `feat/design-system-foundation` and every subsequent
commit was made once and pushed to both, by design, not by accident. Once
PR #13 merges, `feat/design-system-foundation` will be fully contained in
`main` and can be deleted then — not now, per instruction. No commit exists
on either branch that isn't on the other.

## 13. Validation gate: PR #13 (draft, not merged)

https://github.com/ahmetbsbnr/coretend/pull/13 — `release/coretend-final`
→ `main`, **draft**, opened only because CI/Security don't run on a plain
branch push (they trigger on `push:main` or `pull_request` only — checked
directly in both workflow files). At head `43ad030`:

| Check | Result |
|---|---|
| CI / build-and-test | ✅ pass (11m3s) |
| CI / distribution-check | ✅ pass (1m26s) |
| Security / checks | ✅ pass (12s) |
| Compatibility Matrix (manual `workflow_dispatch`) | ✅ pass (both runners) |
| Vercel preview deploys (app, coretend) | ✅ pass — preview only, not production |

Not merged. Not signed. Not notarized.

## 14. Second pass — attestation, portfolio-sync, crash matrix, DMG, site/portfolio crawl

Same day, follow-up instruction. Full detail in the dedicated files this
section points to; summary here.

**GitHub attestation.** `release.yml`'s `attest-build-provenance` step is
welded to the tag-push publish path — no dry-run existed. Added the same
step to `release-draft.yml` (artifacts-only, `id-token`/`attestations`
scoped to that job alone, no `contents: write`, no tag, no GitHub Release).
Dispatched it for real on `release/coretend-final` with a clearly-fake
version label (`0.0.0-attestation-test`, chosen so it can never be mistaken
for a real build) — commit `ed22e35`.

**Portfolio-sync.** `sync-coretend.yml` already supports `workflow_dispatch`
and already only commits on real drift from the live GitHub release —
nothing to fix. `data/coretend-release.json` already matched the live
`v0.9.1-rc.5` release before this session. Dispatched it for real: **no
commit** (confirmed already in sync) — the safe, correct outcome, and the
first real proof the workflow's wiring works (`TODO.md`'s old claim that it
"never ran automatically" was itself stale — `gh run list` shows a
successful scheduled run from 2026-08-03 predating this session).

**Crash matrix.** Full classification of all 40 items in
`Documentation/Audits/CRASH_MATRIX_CLASSIFICATION.md`: 31 executed for real
this session (`Scripts/test-robustness.sh` full run — 31/31 PASS — plus
`swift test`'s existing coverage), 6 N/A (ClamAV, retired), 3 honest gaps
(disk-nearly-full, CPU-under-load, `URLSession` timeout — feasible,
not run, not claimed done), 2 correctly needing a second Mac/host-level
control (memory pressure, sleep/wake), 2 correctly needing a display
session (extreme resize, multiple windows). No item defaulted to "needs a
second Mac" without being checked.

**DMG packaging.** Full detail in `Documentation/Audits/
DMG_PACKAGING_AUDIT.md`. Real `hdiutil attach`/copy/`codesign`/detach cycle
this session, plus the existing `test-dmg-layout.sh`/`test-dmg-headless.sh`
gates, all pass. The `dmgbuild`-based (no Finder/AppleScript) mechanism is
solid and already fixed the historical `0.9.1-rc.2` unstyled-DMG cause. The
background artwork is real, on-brand, and already embeds an honest
"Unsigned build" disclosure — visually inspected this session, not just
existence-checked. What's still open is purely perceptual/visual judgment
(icon-well alignment as Finder actually renders it, drag-and-drop feel) —
narrower than "redesign the DMG," which the packaging evidence does not
support as still being true.

**Site gold-master parity.** Every element from the gold-master list
(radar/arcs/grain/halo/hero-motion/magnetic buttons/app simulation/
treemap/workflow/findings/gauges/sparklines/terminal/Gatekeeper
scene/ticker/tilt/scramble/animated FAQ/light-dark/FR-EN/Reduce Motion) is
present in `Website/index.html`/`Website/design-system/`. Per instruction,
did **not** add Performance/My Clutter/Cloud Cleanup to the hero
simulation — confirmed the hero shows exactly the 7 primary modules it
already showed, and confirmed no "here are all of CoreTend's modules"
completeness claim exists anywhere on the site to contradict that.

**Production crawl.** All required routes 200 (`/`, `/en/`, `/fr/`,
`/download`, `/privacy`, `/support`, plus `/legal`/`/licenses` and their
`/fr/*` counterparts), unknown routes real 404 (not raw), correct
self-referencing canonical + reciprocal hreflang + `x-default` on every
page, zero dirty-path leaks (checked for `.html`/`/site/`/`/Website/`/
`/public/`/`/dist/`/`localhost`/`/Users/`, the 3 `.html` hits were
`<!doctype html>`/`<html>`/`</html>` boilerplate, not leaked paths),
`/download` verified live-serving the real 4,703,523-byte DMG matching the
known `v0.9.1-rc.5` `SHA256SUMS`.

**Portfolio verification.** Case study text matches the real 7-module
architecture, correctly states "neither a Developer ID signature nor Apple
notarization" and frames Developer ID/notarization as future work, no
ClamAV, `scripts/check-static.mjs` (51 checks) all pass. **New finding,
not previously tracked**: `SmartCareView.swift` is a fully-built, tested,
documented (`Documentation/SMART_CARE.md`) one-click orchestrator — but is
not referenced by any `ModuleID` case at all (deeper than the
Performance/My Clutter/Cloud Cleanup case: those still had a live switch
arm, this has none). Its own audit was already archived to
`Documentation/Archive/WorkspaceLegacy/SMART_CARE_AUDIT.md`, suggesting a
past decision to supersede it with Dashboard — but the portfolio case
study and the still-active `Documentation/SMART_CARE.md` both describe it
in the present tense as if live. **Not touched** — this is a real product
decision (reconnect vs. formally retire vs. rename), same category as the
Performance/My Clutter/Cloud Cleanup question, not something to resolve
unilaterally under time pressure. Flagged for an explicit owner decision.

**Portfolio bug found and fixed** (separate from the above, on the
portfolio repo, not CoreTend): `/fr/` and `/fr/projets/coretend/` (trailing
slash) both returned a broken Next.js `__next_error__` shell instead of
redirecting. Root cause: the portfolio site is `output: 'export'` (fully
static, no server runtime); `next/navigation`'s `redirect()` cannot run
under static export, so the two `app/fr/**/page.tsx` alias pages baked a
broken shell into their generated HTML instead of redirecting — and that
generated file then shadowed the already-correct `vercel.json` redirect
rules that would otherwise have handled both paths correctly. Fix: deleted
`app/fr/` (dead alias tree) so the working `vercel.json` rules take over.
Verified locally: `next build` (static export) clean, `tsc --noEmit`
clean, `npm test` (`scripts/check-static.mjs`, 51 checks) all pass.
Committed `7408b65` on `fix/broken-fr-alias-routes`, opened as **draft PR
https://github.com/ahmetbsbnr/ahmetbsbnrportfolio/pull/15**, not merged —
same gate discipline as CoreTend's PR #13.

**Documentation hierarchy.** Already matches the requested Product/
Engineering/Design/Security/Testing/Release/Audits/Archive structure —
`Documentation/README.md` is a pre-existing curated index, not built this
session. `Scripts/check-markdown-links.py`: 0 broken internal links across
222 tracked Markdown files. No restructure performed — none was needed;
redoing sound existing work would have been the actual mistake here.
