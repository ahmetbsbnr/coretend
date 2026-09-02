# Code-technique audit — 2026-08-31

Scope: the Swift package (`Sources/`, ~13k LOC, 9 modules), triggered by a
request to "review the coding techniques and recode them." Ran alongside the
Porcelaine identity change (`Documentation/Audits/` sibling notes; DS 1.1.0).

## Verdict

**No rewrite is warranted.** The codebase already applies the techniques a
rewrite would aim for:

- Pure logic is separated from SwiftUI and unit-tested — `OnboardingLogic`
  (`SecurityConfig`, `LaunchLocation.detect`, `SystemCheck`), `ClutterFiltering`,
  `MenuBarIconModel.needsAttention` (`nonisolated static`, directly testable),
  `paletteMatches`.
- Swift 6 strict concurrency is handled deliberately, not with escape hatches:
  **0** `@unchecked Sendable`, **0** `nonisolated(unsafe)`, **0** `try!` / `as!`
  / `fatalError` in `Sources`. Blocking filesystem work is consistently pushed
  off the main actor via `Task.detached(priority: .utility)`, with
  `ScanEngine bounded concurrency` + `Rapid cancellation` suites proving
  bounded fan-out and prompt teardown.
- `@preconcurrency import` is used only on three genuinely un-annotated Apple
  SDKs (UserNotifications, QuickLookThumbnailing).
- Destructive paths route through `SafetyCore.PathValidator` (enforced by
  `PathValidator` + `SafetyCenter` suites); confirmed-removal-to-Trash is the
  only deletion mechanism.
- Design tokens funnel through one namespace (`MCColor` / `MC*`); motion has a
  single Reduce-Motion choke point (`MCMotion.animation(_:reduce:)`).
- 340 tests / 57 suites; release build is **0 warnings**.

## Findings

### F1 — Fixed (this session)

- `OnboardingView.openFullDiskAccessSettings()` used `URL(string:)!` on a
  literal. Replaced with `guard let … else { return }`. It was the **only**
  force-unwrap in `Sources`; not a real-user-data path, but the codebase's own
  rule is "no force-unwraps that can run against real user data" and a `guard`
  costs nothing.

### F2 — Fixed (this session)

Semantic token names predated two identity changes and misled: `MCColor.coreMint`
**was teal**, `ionViolet` was graphite, `novaMagenta` / `glacierBlue` /
`mossGreen` were teal/graphite tonal steps. Renamed across 11 files (`Sources`
+ `DesignSystemTests`), including the `adaptive("…")` NSColor name-string
arguments and the `MCTheme.accent` / `.accentSecondary` / `.warning` / `.danger`
aliases:

| was | now |
|-----|-----|
| `coreMint` | `teal` |
| `ionViolet` | `graphite` |
| `solarAmber` | `amber` |
| `pulseCoral` | `coral` |
| `novaMagenta` / `glacierBlue` / `mossGreen` | `cellTealDeep` / `cellGraphite` / `cellTealPale` |

`Canonical.*` names are unchanged, so the exported `--ct-*` web tokens and
`check-design-tokens.py` are unaffected. Verified: debug + release build 0
warnings, `Scripts/test.sh` 340/340, `check-design-tokens.py` still matches.

### F3 — Decision needed (pre-existing, TODO.md #8)

`SmartCareView` / `SmartCareViewModel` are fully built and tested
(`SmartCareSafetyTests`) but **instantiated nowhere** — `ModuleID.smartCare`'s
detail case renders `DashboardView()`. `Documentation/SMART_CARE.md` and the
portfolio case study still describe it as live. This audit does not delete it
(not its call): decide reconnect / retire-the-docs / rename.

### F4 — Not a defect, noted

`AppDiscovery` (17), `BrowserDetection` (8) etc. use `try?` densely on
filesystem probes (`contentsOfDirectory`, `resourceValues`, plist reads). For a
read-only inspector walking `/Applications` and `~/Library`, "unreadable →
skip" is the correct semantic, not a swallowed error. A diagnostic log sink for
these misses would be a pure enhancement.

## Verified

- `swift build` (debug) — green
- `swift build -c release` — green, 0 warnings
- `Scripts/test.sh` — 340/340 (1 pre-existing skip: Developer-ID signature test)
