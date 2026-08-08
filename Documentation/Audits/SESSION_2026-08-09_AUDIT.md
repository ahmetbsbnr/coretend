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
