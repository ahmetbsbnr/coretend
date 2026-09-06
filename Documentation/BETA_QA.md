# CoreTend v1.1.0-beta.1 — Beta QA Log

Living record of the release-hardening QA pass. Statuses:

- **PASS** — verified here with evidence.
- **FAIL** — reproducible defect (fix + regression test required before beta).
- **BLOCKED** — cannot be checked in this environment and is not purely a human-visual item.
- **HUMAN VERIFICATION REQUIRED** — code is complete and statically sound; only on-device visual / interaction / assistive-tech confirmation is outstanding.
- **EXTERNAL CONFIGURATION REQUIRED** — depends on an Apple Developer portal / signing-credential action outside this repo.

## Environment

| | |
|---|---|
| Date | 2026-09-05 |
| macOS | 26.6.2 (25G83) |
| Architecture | arm64 (Apple Silicon) |
| Toolchain | Swift 6.3.3 (swiftlang-6.3.3.1.3), Xcode 26.6 (17F113) |
| Branch | `feat/v1.1-smart-scan-polish` |
| HEAD at QA start | `1a95e37` |
| Build under test | `build/CoreTend.app` from `Scripts/build-xcode.sh` (unsigned, ad-hoc / linker-signed Release), rebuilt this pass |
| GUI automation | not used — no interactive visual pass performed; items needing a running window are marked HUMAN VERIFICATION REQUIRED |

## Automated gates (this pass, at HEAD `e0662ef`+)

| Gate | Result | Evidence |
|---|---|---|
| `Scripts/build.sh` | **PASS** | Build complete, 0 compiler warnings |
| `Scripts/build.sh release` | **PASS** | BUILD SUCCEEDED (35 s) |
| `Scripts/test.sh` | **PASS** | 797 passed / 0 failed |
| `Scripts/repository-doctor.sh` | **PASS** | all checks passed (EN/FR parity, Xcode-project drift, no absolute paths) |
| `Scripts/build-xcode.sh` | **PASS** | BUILD SUCCEEDED; both `.appex` embedded; 7 App Intents / 6 App Shortcuts; FR localizations; no absolute developer path |

`Suite`/`Test` swift-testing deprecation notices in the test target and the
codesign `Specifying ':' in the path is deprecated` line are pre-existing
tooling diagnostics, not compiler warnings.

## Launch smoke

| Item | Status | Notes |
|---|---|---|
| Beta build launches without crash | **PASS** | `open build/CoreTend.app` → process runs; no CoreTend crash report dated 2026-09-05 (`~/Library/Logs/DiagnosticReports`). Clean quit. |

## Bugs found & fixed this pass

| # | Severity | Bug | Fix | Regression test |
|---|---|---|---|---|
| 1 | **P0** | `SmartScanModel` built its `SmartScanCoordinator` + `SmartScanRecoveryCandidates` once at init and reused them, so "New Smart Scan" replayed the first scan's memoised disk snapshot instead of re-scanning. | `start()` now builds a fresh coordinator + candidate cache every run (production path); injected-coordinator tests unaffected. | `eachRunBuildsAFreshCoordinatorSoNewSmartScanReallyRescans` (`SmartScanModelTests`) |
| 2 | P2 | Space Lens bubble canvas rendered up to 40 circles; past ~14 the radial packer runs out of clear on-canvas slots and bubbles pile off-screen. | Canvas render bound lowered to 14; overflow rolls into the on-canvas "Other" bubble; the precise list (bound 120) still shows the tail. Domain model's 40-node ceiling and its tests unchanged. | covered by existing `SpaceLensAggregatorTests` bounds |
| 3 | P2 | Space Lens list-row double-click used `.onTapGesture(count:2)` on the row inside a `List(selection:)` — risk of stealing the native single-click selection / the row's borderless buttons. | switched to `.simultaneousGesture(TapGesture(count: 2))` (additive). | — (visual; HUMAN VERIFICATION) |
| 4 | P2 | Space Lens "Other" bubble stayed visible under a category filter, showing aggregate bytes computed before category filtering (misleading). | `applyCategory` now drops "Other" whenever a category filter is active. | — |

### UI/UX polish pass — `6247549`

| # | Severity | Bug | Fix | Regression test |
|---|---|---|---|---|
| 5 | P1 | French UI showed byte values with a period + ASCII units ("3.9 GB") even for a user who chose French in-app — `ByteCountFormatter` ignores locale and the in-app language override does not change `Locale.current`. | `mcFormatBytes` → `ByteCountFormatStyle().locale(MCFormatting.locale)`; `MCFormatting.locale` (DesignSystem) set from `LocalizationManager.locale` at launch + on every language change. FR now renders "3,9 Go" / "664,7 Mo" (with the correct U+202F thin space); EN unchanged. | `ByteFormattingTests` (5), `RecoveryPlanPolishTests.mcFormatBytesFollowsTheInAppLanguageNotTheProcessLocale`, `…appLanguageMapsToTheRightFormattingLocale` |
| 6 | P1 | `advisor.reversibility.trash` badge read "Moved to Trash" / "Déplacé vers la Corbeille" (past tense) and is shown on every candidate row *before* the user confirms anything — implied a destructive action had already happened. | Reworded to tense-neutral "Recoverable from Trash" / "Récupérable depuis la Corbeille" (describes the mechanism, true in every state). Genuine post-execution strings (`cleanup.done.moved`, `leftovers.finished.moved`, `privacy.finished.moved`, `apps.uninstall.result`) untouched — still past-tense. | `RecoveryPlanPolishTests.theTrashReversibilityBadgeIsNotWordedAsACompletedAction`, `…postExecutionStringsRemainPastTense` |
| 7 | P1 | Recovery Plan primary "Confirm" action lived in the top-right `.toolbar` (a prominent button detached from the content it acts on); the last content row could sit against the window's bottom edge. | Moved the action into a `confirmBar` in the content area via `.safeAreaInset(edge: .bottom)` (which reserves its height) + `.contentMargins(.bottom, .md, for: .scrollContent)`. The final row now scrolls fully clear with a comfortable margin; the top-right chrome holds only the `⌘` palette button. | — (layout; HUMAN VERIFICATION) |
| 8 | P2 | Recovery Plan transient states (`preparing`, `executing`) rendered a bare `ProgressView(label)` with no width cap / horizontal padding — a long FR string sat close to the window edge. | Shared `transientState(_:)` — `MCSize.readableTextWidth` (460) cap, `fixedSize` wrap, `MCSpacing.xl` horizontal padding, centred. Applied to `MCSuccessState` and `startState` too. | — (layout; HUMAN VERIFICATION) |
| 9 | P2 | Recovery Plan rows and the Advisor badge trio could clip / overflow at narrow widths and with French strings. | `candidateRow` / `notIncludedSection`: title + description `fixedSize` wrap, flexible content column, real min `Spacer`, and a shared `rowBytes` that pins the byte value to its natural width (`fixedSize` + `layoutPriority(1)`). New `MCFlowLayout` (DesignSystem) wraps the Advisor badges and the goal presets onto a second line instead of clipping. | `MCFlowLayoutTests` (4, pure `arrange` geometry) |
| 10 | P2 | Recovery Plan summary card put two large byte metrics in a fixed `HStack` — they could collide at compact widths. | `ViewThatFits(in: .horizontal)` — side-by-side when there is room, stacked when not; mild `minimumScaleFactor(0.7)` safety net only. | — (layout; HUMAN VERIFICATION) |
| 11 | P2 | Command palette (`CommandPaletteView`) had only an implicit Escape handler and no visible dismiss control — on the macOS sheet (no outside-click dismiss) it felt stuck. | Added an explicit close button with `.keyboardShortcut(.cancelAction)` (binds Escape) that also clears the query; kept `.onKeyPress(.escape)`; height is now adaptive. | — (interaction; HUMAN VERIFICATION) |

**Observed, out of scope (not fixed):**
- `ApplicationsView.sizeBucket` returns hard-coded English grouping labels ("Under 50 MB" …) that are also sort-order keys — a pre-existing localization gap in Applications Center, unrelated to Recovery Plan / this pass.
- `WidgetShared/WidgetSnapshotDisplay` uses `ByteCountFormatter` — correct for a widget (own process, follows the *system* locale; no in-app override applies there). Non-goal: do not touch the widget without a regression.

---

## VISUAL QA — interactive pass, 2026-09-06

**Environment:** real GUI. The `computer-use` MCP was blocked all session (every click hit-tested as "Centre de notifications" — a stuck system click-catcher / coordinate mismatch), so the repo's own tooling was used instead: `Scripts/package-local.sh` (SwiftPM release → ad-hoc-signed `build/CoreTend.app`) + AppleScript System Events to drive the sidebar + `screencapture` of the window rect, with the PNGs inspected directly. Build under test: `feat/v1.1-smart-scan-polish` HEAD, macOS 26.6.2 (25G83), arm64, dark mode, French. Screenshots (contain the real disk free-space number → **gitignored**, not committed): `Documentation/VisualAudit/_capture_2026-09-05_sidebar/`.

**Coverage this pass:** Dashboard (FR/dark), Recovery Plan (idle / preparing / bisected states), the sidebar across Dashboard / Stockage / Doublons / Applications / Développement / Évolution / APFS / Plan de récupération, command palette (open / type / dismiss attempts), window resize (900×632 → 1320×820). **Not covered** (budget was consumed by the P0 sidebar root-cause hunt): the full light/dark × EN/FR × 4-size matrix, Space Lens interaction, Smart Scan run, Storage/Applications/Developer/Privacy/Integrity/Restore/Activity/Settings deep walks, VoiceOver, Reduce Motion, Finder/Widget/Shortcuts/Notifications live — these stay HUMAN VERIFICATION REQUIRED (list at the end of this doc).

### V-1 — Sidebar scrolls off-screen on Recovery Plan  ·  **P0**  ·  **FIXED + retested**

| | |
|---|---|
| Screen / state | Plan de récupération — idle (`startState`) **and** completed (`finishedView` / `MCSuccessState`) |
| Window / theme / lang | reproduced at 900×632 **and** 1320×820, dark, FR (theme/lang independent) |
| Steps | Dashboard → click "Plan de récupération" in the sidebar |
| Expected | sidebar keeps its position; the selected row is visible; upper groups stay visible |
| Actual (before) | the sidebar `List` scrolls to an out-of-range offset (**−1252 pt**, measured via AX on row 1). Compact window → sidebar entirely blank; larger window → only the last "Système" group visible — **exactly the reported screenshot**. Recovers when navigating to any other module. |
| Root cause | A `.borderedProminent` button is the window's default control. In a `NavigationSplitView` **detail with no ScrollView of its own**, AppKit's "reveal the default / first-responder control" pass walks up for an enclosing `NSScrollView` and finds the **sidebar's** list, then scrolls it. Every other module's detail root is a `ScrollView` or `List`, so only Recovery Plan (bare-`VStack` `startState`, and `MCSuccessState` for `finishedView`) triggers it. Pre-existing — reproduces back to the original Recovery Plan commit `fd6eb41`; the recent screenshot merely surfaced it. **Not** caused by `MCFlowLayout`, the goal-card `TextField`, or the `6247549` polish (each ruled out by isolation rebuild). |
| Fix | `55d184c` — give each centred detail state its own scroll host: `MCSuccessState` + `MCEmptyState` (DesignSystem) bodies wrapped in `ScrollView` + `.scrollBounceBehavior(.basedOnSize)`; `RecoveryPlanView.startState` + `transientState` likewise. `readyView` was already a `ScrollView`. Content still fits without visible scrolling; no `scrollTo(.top)` hack. The `MCSuccessState` fix also removes the same latent bug from every other success screen (Cleanup / Duplicates / Restore …). |
| Retest | **PASS.** `AFTER-01…04`, `AFTER-13`, `AFTER-14` — sidebar fully intact on Recovery Plan idle at 900×632 and 1320×820 (whole list incl. "Centre de restauration" / "Réglages"), and across navigate-away-and-back; no regression on Dashboard / Doublons / Stockage / Applications / Timeline / APFS. |
| Regression test | `SidebarStructureTests.centredDetailStatesWithADefaultButtonAreScrollHosted` (structural). |
| Still HUMAN VERIFICATION | the `.finished` state itself (needs a real destructive execute to reach — same `MCSuccessState` mechanism, code-verified only). |

### V-2 — French byte formatting  ·  **PASS**

`mcFormatBytes` fix from `6247549` **verified live**: Dashboard storageGlance "6,54 Go libres sur 245,11 Go", status pill "Espace libre 6,45 Go", APFS "245,11 Go" / "7,88 Go" / "Zéro ko" — all French conventions (comma decimal, "Go"/"Mo"/"ko"), no "GB"/"MB". *(A `git` accident in `55d184c` had reverted the `MCFormatting.locale` wiring in `CoreTendApp.swift`; restored in `b57b86f` — see V-4.)*

### V-3 — Command palette  ·  **partial**

- ✕ close button present and visible in the search row (`6247549`) — **PASS** (visual). List renders (Tableau de bord / Stockage / …); type-to-filter works ("dev" → Développement, "res" → Centre de restauration).
- **Escape does not dismiss the palette** in testing — but the automated harness cannot deliver a testable Escape into the SwiftUI `.sheet` (typed characters reach the field; `osascript key code 53` does not trip `.onExitCommand` / `.onKeyPress`). Could not distinguish "harness limitation" from "app bug". `76dd84b` adds belt-and-suspenders handling (`.onKeyPress(.escape)` on the focused field + container `.onExitCommand` + the ✕ button's `.cancelAction`). **HUMAN VERIFICATION REQUIRED** — physical Escape keypress on device.
- Palette sheet renders in the lower-centre of the window (macOS sheet placement); readable, not clipped. Outside-click dismissal not testable via the harness — HUMAN VERIFICATION.

### V-4 — Git-history correction  ·  **fixed**

`55d184c` (the V-1 fix commit) inadvertently also committed a **stale `CoreTendApp.swift`** — a leftover `git checkout <old> -- <path>` from the root-cause bisect had left the pre-`6247549` version staged, and `git commit` writes the whole index. That silently reverted the `MCFormatting.locale` wiring + the `CommandPaletteView` improvements from `6247549`. All other `6247549` files were unaffected. Restored in `b57b86f`. No feature lost on disk; the running QA build always had the correct file.

### ⌘ command-palette trigger button  ·  **P2 note**

The circular `⌘` button sits in the top-right, hard against the rounded window corner (standard SwiftUI `.toolbar` trailing placement). It does not overlap the page title or any action. Visually a touch corner-stuck but within macOS chrome norms — left as-is (P2, not a defect).

### `mcFormatBytes(0)` in French → "Zéro ko"  ·  **P2 note**

APFS "Disponible (usage opportuniste)" shows "Zéro ko" (from `ByteCountFormatStyle` for a 0 value in FR). Grammatically fine, matches the formatter's locale output; not changed.

---

## TARGETED UI FIX pass — 2026-09-06 (command palette + ⌘ trigger)

Scope: the two user-facing items left unresolved after the visual-QA pass — V-3
(outside-click dismissal) and the ⌘-trigger P2 note. No other module touched.

### T-1 — Command palette is now a transient overlay, not a `.sheet`  ·  **IMPLEMENTED**

- **Old presentation:** `.sheet(isPresented: $showCommandPalette)` on the detail
  `Group`. A document-modal sheet on macOS treats an outside click as a no-op —
  the interaction the user asked for was structurally impossible in that
  primitive.
- **New presentation:** `CommandPaletteOverlay` in a `.overlay { if
  showCommandPalette { … } }` on `MainWindow`, `.transition(.opacity)`. A
  `ZStack(alignment: .top)`:
  - a full-window `Rectangle().fill(Color.black.opacity(0.18)).ignoresSafeArea()
    .contentShape(Rectangle()).onTapGesture { close() }` backdrop — the outside
    click lands on this, is **consumed** (never reaches the control beneath), and
    closes the palette;
  - the `CommandPaletteView` panel above it, with opaque chrome
    (`MCColor.elevatedBackground` in `RoundedRectangle(MCRadius.card)` + stroke +
    shadow) and its own `.contentShape(RoundedRectangle(…))`, so any click on the
    panel — including empty regions — is consumed there and does **not** fall
    through to the backdrop.
- **Click-through protection:** by construction. The backdrop is an opaque
  hit-testing view spanning the window; the dismissal click cannot reach a
  background control (e.g. Recovery Plan's "Préparer le plan").
- **Escape — one owner:** `.onExitCommand { close() }` on the overlay `ZStack`,
  and nowhere else. Removed the previous pass's competing handlers: the search
  field's `.onKeyPress(.escape)`, the ✕ button's `.keyboardShortcut(
  .cancelAction)`, and `CommandPaletteView`'s container `.onExitCommand`.
  `.onExitCommand` handles `cancelOperation:` from anywhere in the responder
  chain, including the focused `TextField`.
- **Explicit close paths:** ✕ button → `dismiss()`; result selection →
  `activate()` → `dismiss()`; Escape → `close()`; outside click → `close()`. All
  set `isPresented = false` inside `withAnimation` (respecting Reduce Motion).
- **Focus:** panel `.onAppear { searchFocused = true }`. On close the entire
  overlay leaves the view tree, so no invisible keyboard focus can remain inside
  a dismissed palette. Restoring focus specifically to the ⌘ trigger is not
  wired (would need a `MainWindow`-level `FocusState`); acceptable since the
  dismissed subtree is gone.
- **HUMAN VERIFICATION REQUIRED — physical gesture only:** the GUI-automation
  route (AppleScript System Events + `screencapture`) is not functioning in this
  environment this session — `CoreTend` launches but its window is not reliably
  accessible to System Events (0 windows reported), same blocker noted in prior
  passes. The state machine and structure are unit-tested (see below); a human
  must confirm on device: open palette → click outside → closes immediately, no
  second click, no bonk; click on "Préparer le plan" underneath while palette is
  open → palette closes, button does **not** execute; Escape from the focused
  field → closes; ✕ → closes; result click → navigates + closes.

### T-2 — ⌘ trigger moved out of the window corner  ·  **IMPLEMENTED**

- **Old ownership:** a global `.toolbar { ToolbarItemGroup { Button … Label(
  L("palette.open"), systemImage: "command") } }` — extreme trailing titlebar
  slot, hard against the rounded window corner.
- **New ownership:** `MainWindow` injects `.safeAreaInset(edge: .top, spacing: 0)
  { paletteHeader }` on the detail `Group` (before `.mcCanvasBackground()`), so
  it applies to **every** module, not one view. `paletteHeader` is an `HStack`
  with a trailing `Spacer` and a 26 pt circular `⌘` button
  (`MCColor.elevatedBackground` fill + `MCColor.separator` stroke), padded
  `.trailing MCSpacing.page`, `.top MCSpacing.sm`, `.bottom MCSpacing.xs` — all
  design tokens, no arbitrary pixel offsets. The trigger now sits inside the
  visible content region, comfortably clear of the corner, aligned to the page
  gutter.
- The old toolbar item is removed entirely. `⌘K` is unchanged — still owned by
  the `CoreTendHelpCommands` menu command that posts `.mcShowCommandPalette`; the
  header button is not re-bound (avoids a duplicate-shortcut conflict).
- **HUMAN VERIFICATION REQUIRED — visual only:** confirm on device at 900×632 and
  1320×820 that the header band does not visually crowd page titles on
  Dashboard / Recovery Plan / Storage / Space Lens / Duplicates / Applications /
  Developer / Timeline / APFS / Large Files / Privacy / Integrity / Activity /
  Settings, and that at compact width the page title stays readable and the ⌘
  stays visible. (Structure is identical across modules by construction —
  single `.safeAreaInset` at `MainWindow` level.)

### T-3 — Sidebar fix (`55d184c`) preserved  ·  **verified structurally**

`SidebarStructureTests.centredDetailStatesWithADefaultButtonAreScrollHosted`
still passes: `MCSuccessState` / `MCEmptyState` / `RecoveryPlanView` `startState`
/ `transientState` remain `ScrollView`-hosted. Adding `.safeAreaInset(edge:
.top)` to the detail `Group` does not remove those local scroll hosts, so the
AppKit "reveal the default control" pass still stays local. Live re-confirmation
of the Dashboard → Recovery Plan → other-module → Recovery Plan walk at compact
and large sizes is **HUMAN VERIFICATION REQUIRED** (same automation blocker).

### T-4 — `mcFormatBytes(0)` "Zéro ko"  ·  **not changed**

Left as the existing P2 note above. Foundation's `ByteCountFormatStyle` spells
zero as a word in FR ("Zéro ko"); there is no clean formatter switch, and the
pass brief de-prioritised it ("do not spend significant time on this").

### T-5 — Accessibility

- Trigger: `.help` + `.accessibilityLabel` = `L("palette.open.a11y")` — EN "Open
  command palette" / FR "Ouvrir la palette de commandes" (new keys, EN+FR
  parity).
- ✕ + backdrop: `L("palette.close.a11y")` — EN "Close command palette" / FR
  "Fermer la palette de commandes" (new keys, EN+FR parity). Backdrop also gets
  `.accessibilityAddTraits(.isButton)`.
- Search field: `.accessibilityLabel(L("palette.placeholder"))`.
- Panel: `.accessibilityElement(children: .contain)`.

### T-6 — Tests (new: +5, suite 812 → 817, all pass via `Scripts/test.sh`)

`Tests/CoreTendAppTests/CommandPaletteTests.swift`:
- `paletteIsAnOverlayNotASheet` — no `.sheet(isPresented: $showCommandPalette)`;
  `CommandPaletteOverlay` presented via `.overlay { if showCommandPalette }`.
- `backdropConsumesTheDismissalClickAndCloses` — `CommandPaletteOverlay` has a
  filled `Color.black.opacity(0.18)` backdrop with `.contentShape(Rectangle())`
  + `.onTapGesture { close() }` + id `commandPalette.backdrop`.
- `escapeHasExactlyOneOwner` — exactly one `.onExitCommand { close() }`; no
  `.onKeyPress(.escape)` anywhere.
- `triggerLivesInAHeaderBandNotTheToolbarCorner` — trigger in `.safeAreaInset`
  with `MCSpacing.page` trailing padding, id `commandPalette.trigger`; old
  toolbar `Label(L("palette.open"), …)` gone.
- `newKeysExistInBothLanguages` — `palette.open.a11y` / `palette.close.a11y`
  present with expected EN + FR values.

### T-7 — Gates (all green, this checkpoint)

| Gate | Result |
|---|---|
| `Scripts/build.sh` | Build complete |
| `Scripts/build.sh release` | Build complete (32 s) |
| `Scripts/test.sh` | **817 tests passed**, 0 failures (~24 s) |
| `Scripts/repository-doctor.sh` | all checks passed |
| `Scripts/build-xcode.sh` | OK — unsigned Release `build/CoreTend.app` |

---

## DUPLICATES SIDEBAR REGRESSION — 2026-09-06 (P0, FIXED + retested)

A real screenshot showed the **Duplicates** landing state blanking the sidebar
(only the top chrome remained). Same class as the Recovery Plan P0.

### D-1 — Root cause (measured, same mechanism as Recovery Plan)

`DuplicatesView.idleView` was a bare centred `VStack` —
`.frame(maxWidth: .infinity, maxHeight: .infinity).padding(MCSpacing.xl)`, no
local scroll host — whose only focusable control is the `MCScanButton`
("Rechercher les doublons"). In a non-scrolling `NavigationSplitView` detail,
AppKit's "reveal the first-responder / default control" pass walks up, finds the
**sidebar's** `List` `NSScrollView`, and scrolls the navigation column out of
range.

**Every peer module already avoided this** — `CleanupView`, `SpaceLensView`,
`MyClutterView` all wrap their `idleView` in `GeometryReader { ScrollView { … } }`.
Duplicates' idle state was the one that never got the treatment. `scanningView`
had the same bare structure.

Measured with AX (`position` of scroll area vs. row 1), the same method that
caught Recovery Plan at `row1Y = -1252 pt`:

| Navigation into Doublons | sidebar `row1Y − scrollAreaTop` | rows |
|---|---|---|
| Dashboard → Doublons | **0** | 21 |
| Space Lens → Doublons | **0** | 21 |
| Recovery Plan → Doublons | **0** | 21 |
| Applications → Doublons | **0** | 21 |
| (large 1240×780) Dashboard → Doublons | **0** | 21 |
| (large) Recovery Plan → Doublons | **0** | 21 |
| palette → Doublons | **0** | 21 |
| Doublons + palette open + Escape | **0** | 21 |

`delta = 0` ⇒ the sidebar scroll view is never moved off its origin.
(Pre-fix this would be a large negative `row1Y`.)

### D-2 — Fix — reusable DesignSystem primitive

New `MCCenteredScrollState` in `Sources/DesignSystem/Components.swift` + a
`.mcCenteredScrollState()` `View` extension:

```swift
GeometryReader { proxy in
    ScrollView {
        content
            .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .center)
            .padding(MCSpacing.xl)
    }
    .scrollBounceBehavior(.basedOnSize)
    .scrollIndicators(.hidden)
}
```

It formalises the pattern the peers already hand-rolled: a **local** scroll host
so AppKit's first-responder reveal stays inside the detail; content still centres
in the viewport when it fits, scrolls instead of clipping when the window is
short. **Not** applied to normal data `List`s / `ScrollView`s — they are already
their own scroll host.

### D-3 — Similar-state audit (all 17 modules + sub-views)

| Screen / state | Before | Action |
|---|---|---|
| `DuplicatesView.idleView` | bare centred + `MCScanButton` | **migrated** → `.mcCenteredScrollState()` |
| `DuplicatesView.scanningView` | bare centred + pause/resume/cancel | **migrated** |
| `DuplicatesView.emptyView` / `finishedView` | `MCEmptyState` / `MCSuccessState` | already scroll-hosted |
| `CleanupView.scanningView` | bare centred + pause/resume/cancel | **migrated** |
| `CleanupView.idleView` / `doneView` | `GeometryReader+ScrollView` / `MCSuccessState` | already safe |
| `SpaceLensView.scanningView` | bare centred + pause/resume/cancel | **migrated** |
| `SpaceLensView.idleView` | `GeometryReader+ScrollView` | already safe |
| `MyClutterView.scanningView` | bare centred + pause/resume/cancel | **migrated** |
| `MyClutterView.emptyView` | bare centred + "change criteria" button | **migrated** |
| `MyClutterView.idleView` | `GeometryReader+ScrollView` | already safe |
| `CloudCleanupView.providerPicker` (landing) | bare centred + provider buttons | **migrated** |
| `CloudCleanupView.scanning` state | bare centred + pause/resume/cancel | **migrated** |
| `CloudCleanupView.noProviders` | `MCEmptyState` | already safe |
| `StorageTimelineView.noHistoryAtAllState` | bare centred + scope buttons | **migrated** |
| `StorageTimelineView.perScopeEmptyState` | inside `readyView`'s `ScrollView` | already safe |
| `SimilarImagesView` `.scanning` / `.empty` (hosted under MyClutter tab) | bare centred + buttons | **migrated** |
| `SimilarImagesView` `.idle` | `MCEmptyState` | already safe |
| Dashboard / Applications / Developer / APFS / Privacy Lab / Integrity / Activity / Restore Center / Settings / Performance | `ScrollView` / `List` / `Form` root, or button-less text states | already safe — no change |
| `RecoveryPlanView` start / transient / ready | prior P0 fix (`ScrollView` hosts) | **untouched**, retested |
| `CleanupView.failed` / `MyActivityView.emptyState` | centred text/image, **no focusable control** | not vulnerable — left as-is |

### D-4 — Regression tests (`SidebarStructureTests`, +3; suite 817 → **820**)

- `duplicatesCentredStatesOwnALocalScrollHost` — `idleView` + `scanningView`
  contain `.mcCenteredScrollState()`; `emptyView`/`finishedView` delegate to the
  shared primitives; no `NavigationSplitView` / `TabView` / `NavigationStack`.
- `mcCenteredScrollStateIsAScrollHost` — the primitive really wraps a
  `GeometryReader` + `ScrollView`.
- `allCentredDetailStatesWithControlsAreScrollHosted` — broad guard across
  Duplicates / Cleanup / Space Lens / My Clutter / Cloud Cleanup / Storage
  Timeline / Similar Images: every centred start/scanning/empty state with a
  focusable control resolves to a local scroll host (`MCCenteredScrollState`,
  own `ScrollView`/`GeometryReader`, or `MCEmptyState`/`MCSuccessState`).

### D-5 — Visual retest (real running app, `package-local` bundle)

- **Duplicates idle, 900×632** — full 17-row sidebar, "Doublons" selected, idle
  screen renders. Screenshot `Documentation/VisualAudit/_capture_2026-09-06_dupes/06-dupes-after-palette.png`.
- **Duplicates idle, 1240×780** — full sidebar, idle screen renders. `10-dupes-idle-LARGE.png`.
- **Recovery Plan, 900×632** — full sidebar, start state + "Préparer le plan"
  renders (§13 regression PASS). `12-recovery-compact.png`.
- Navigation stress (Dashboard→Doublons→Space Lens→Doublons→Recovery→Doublons
  →Applications→Doublons→Dashboard) and palette-navigation: sidebar `delta = 0`
  throughout (table in D-1).
- Screenshots gitignored (`_capture_*/`) — contain real disk paths, no user data
  beyond the standard idle copy.
- **HUMAN VERIFICATION REQUIRED:** a physical mouse retest of the Duplicates
  *scanning* and *results/empty* states (a real scan touches the filesystem and
  was not driven here), plus the light-theme variant. Structure is covered by
  D-4; the AX offset for idle/navigation is measured `0`.

### D-6 — Gates (this checkpoint)

| Gate | Result |
|---|---|
| `Scripts/build.sh` | Build complete (12.8 s) |
| `Scripts/build.sh release` | Build complete (33 s) |
| `Scripts/test.sh` | **820 tests passed**, 0 failures (~19 s) |
| `Scripts/repository-doctor.sh` | all checks passed |
| `Scripts/build-xcode.sh` | OK — unsigned Release `build/CoreTend.app` |

---

## 3. Smart Scan — idle state

| Check | Status | Notes |
|---|---|---|
| Smart Scan is the primary Dashboard experience | **PASS (static)** | `DashboardView` leads with `SmartScanDashboardSection`; old storage hero demoted to a small `storageGlance` card below it. `dashboard.primary_action` string no longer referenced. |
| Title not clipped; EN + FR fit | **HUMAN VERIFICATION REQUIRED** | Hero CTA text uses `lineLimit(2)` + `layoutPriority(1)` + `fixedSize(vertical:)` — same pattern that fixed the prior FR "Analyser le stockage" clip. Needs a look at 3 widths in both languages. |
| Module coverage understandable | **PASS (static)** | Idle hero lists all six modules with icon + localized name + a tagline ("One scan. Several CoreTend modules. One structured review." / FR equivalent). |
| `storageGlance` does not compete with the hero | **HUMAN VERIFICATION REQUIRED** | It is a single-row `MCCard` button; visually smaller, but relative weight needs eyes. |
| No fake health metric / misleading byte total | **PASS (static)** | No score anywhere. Idle shows no totals. |
| Light + dark, multiple widths | **HUMAN VERIFICATION REQUIRED** | uses `MC*` design tokens (theme-aware); not visually confirmed. |

## 4. Smart Scan — running state

| Check | Status | Notes |
|---|---|---|
| All six modules appear | **PASS (static + test)** | `moduleList` iterates `SmartScanModuleID.ordered` (6). `everyConnectedModuleReachesCompleted…` covers state coverage. |
| Queued → Scanning → Completed transitions | **PASS (test)** | `SmartScanServiceTests`, `SmartScanModelTests` — start-to-completion, per-module states. |
| Unavailable / Failed render | **PASS (static + test)** | `SmartScanStateDisplay` maps every case to label + glyph + tint + detail; `moduleFailureIsIsolated`, `permissionLimitedModuleIsUnavailable`. |
| Elapsed updates sanely (1 s cadence) | **PASS (static + test)** | `tickElapsed()` publishes whole-second values only; `elapsedTextIsMinutesAndSeconds`. |
| No fake percentage | **PASS (static)** | indeterminate `ProgressView` only. |
| No layout jumping | **HUMAN VERIFICATION REQUIRED** | module snapshot only re-assigned on change; rows are fixed structure. Visual confirmation outstanding. |
| Cancel works | **PASS (test)** | `cancellationYieldsAPartialReport`, `cancelYieldsCancelledNeverCompleted`. |
| Leave Dashboard & return preserves the scan | **PASS (static) / HUMAN VERIFICATION REQUIRED (visual)** | `smartScan` is `@State` on `MainWindow`; the driver `Task` lives on the model, not the view. Structurally preserved; not visually confirmed. |
| No duplicate scan starts | **PASS (test)** | `startWhileRunningDoesNotRestart`, `startWhileRunningReturnsTheSameRun`. |
| No stale state from a previous scan | **PASS (test)** | Bug #1 fixed: `eachRunBuildsAFreshCoordinatorSoNewSmartScanReallyRescans`; `reset()` clears modules/report/elapsed. |

## 5. Smart Scan — result

| Check | Status | Notes |
|---|---|---|
| Four dimensions kept separate | **PASS (static + test)** | `categorySummary` renders recoverable-bytes / review-bytes / attention-count / informational-count as distinct rows; `aggregateSeparatesTheFourBuckets_neverOneNumber`. |
| Bytes vs counts never mixed | **PASS (static)** | recoverable/review use `mcFormatBytes`; attention/informational use `smartscan.count_items` (`%lld items`). |
| Exact recoverable total truthful | **PASS (test)** | `antiDoubleCounting`, `theProvidersFileHasNoDestructiveDependency`; `.notIncluded` never re-summed. |
| Non-exact mode shows per-category, not an inflated headline | **PASS (static + test)** | `isGlobalRecoverableExact == false` → `perCategoryRecoverableText` + `smartscan.recoverable.inexact_note`. |
| Overlap explanation understandable | **HUMAN VERIFICATION REQUIRED** | copy present EN + FR; readability judgement outstanding. |
| Module drill-ins work | **PASS (static + test)** | `SmartScanModuleID.sidebarModule` → `.mcNavigate`; `moduleDrillTargetsMapToRealSidebarModules`. |
| Partial-failure banner | **PASS (static)** | `resultView` shows `smartscan.result.partial` when any module is `.failed`. |
| Cancelled cannot look complete | **PASS (static + test)** | `phase == .cancelled` → `cancelledView` (no CTA, no totals); `hasCompletedReport == false`. |
| New Smart Scan resets | **PASS (test)** | `resetReturnsToIdleAfterAFinishedRun` + Bug #1 fix. |

## 6. Recovery Plan handoff

| Check | Status | Notes |
|---|---|---|
| Plan opens from "Review Recovery Plan" | **PASS (static)** | CTA → `navigate(.recoveryPlan)`; `RecoveryPlanView.task` auto-prepares on a fresh handoff. |
| Handoff note appears | **PASS (static)** | `recovery.from_smartscan` shown when `model.fromSmartScan`. |
| No unexpected second scan | **PASS (test)** | `preparePlan()` reads `SmartScanHandoff.freshCandidates()` first; `aCompletedScanPublishesTheExactCandidatesToTheHandoff`. |
| Candidate counts / categories match; Recommended/Review Required/Optional/Not Included preserved | **PASS (test)** | `SmartScanHandoffTests` asserts `handed.map(\.candidate.category) == [.recommended, .reviewRequired, .notIncluded]` — same objects, no reclassification. |
| No duplicated bytes | **PASS (test)** | handoff reuses the exact `RecoveryPlanCandidateData`; no re-sum. |
| Stale handoff not used | **PASS (test)** | `staleHandoffIsNotUsed` (10-min freshness). |
| Destructive execution during QA | **NOT PERFORMED** | deliberately — no synthetic destructive run in this pass. Recovery Plan execution path itself is unchanged this branch and covered by existing `RecoveryPlanExecutionTests`. |

## 7–8. Storage semantics & live progress

| Check | Status | Notes |
|---|---|---|
| Detected/reclaimable cannot be confused with selected | **PASS (static + test)** | `CleanupView.reviewView` labels the big figure `cleanup.reclaimable_metric`; CTA is `cleanup.move_selected` (selected bytes) or `cleanup.move_to_trash`. `StorageScanSummaryTests` proves `inspected != detected != reclaimable != selected != recovered` + partial-selection CTA math. |
| Empty / partial / review-required selection | **PASS (test)** | `emptySelectionMeansNoDestructiveCTA`, `partialSelectionCtaMathMatchesTheTickedItemsOnly`, `displayTruncationInflatesReclaimableNotReviewRequired`. |
| Phase labels / elapsed / friendly location in scanningView | **PASS (static)** | `CleanupView.scanningView` shows `phaseLabel` (Scanning/Paused/Finalizing/Cancelled/Failed) + `cleanup.elapsed` + `cleanup.scanning_at` (last-3-components, tilde). |
| No fabricated percentage | **PASS (static + test)** | `StorageScanProgress` has no fraction field — `thereIsNoPercentageField` (Mirror assertion). |
| Pause visibly stops traversal | **PASS (engine test) / HUMAN VERIFICATION REQUIRED (UX)** | `ScanPauseController` is a real actor suspension; `pausedScanEmitsNoFindingsUntilResume` proves zero findings while paused. Visual "Paused" state + button behaviour needs eyes. |

## 9. Duplicates sidebar — P0

| Check | Status | Notes |
|---|---|---|
| DuplicatesView owns no nested navigation container | **PASS (static + test)** | `SidebarStructureTests.duplicatesViewHasNoNestedSplitViewOrTabView` — no `NavigationSplitView` / `TabView` / `NavigationStack`. |
| MainWindow pins column visibility | **PASS (static + test)** | `mainWindowStillPinsColumnVisibilityToAll` — `columnVisibility` `.all` + onChange guard + `.navigationSplitViewStyle(.balanced)`. |
| Sidebar stays present across Dashboard→Duplicates→other→Duplicates, on resize, on focus change | **HUMAN VERIFICATION REQUIRED** | The structural guard is in place and asserted; the rendered behaviour on macOS 26 must be reproduced by a human (Dashboard → Duplicates → Space Lens → Duplicates; select rows; resize narrow↔wide; Tab through controls). |

## 10. Sidebar focus regression

| Check | Status | Notes |
|---|---|---|
| Content focus/selection never greys the sidebar module / removes the teal marker / changes selection | **PASS (static) / HUMAN VERIFICATION REQUIRED (visual)** | Sidebar rows use `.listRowBackground(Color.clear)`; the only selection indicator is `sidebarRow`'s own teal marker driven by `selection == module`. `SmartScanDashboardSection` uses no `List(selection:)` (`smartScanModuleRowsDoNotOwnListSelection`). Space Lens selection lives in `model.selectionID`, independent of the sidebar `List(selection:)`. Visual confirmation outstanding. |

## 11–20. Space Lens 2.0

| Check | Status | Notes |
|---|---|---|
| Bounded computation at scale | **PASS (test)** | `SpaceLensAggregatorTests.fiveHundredThousandChildrenStayBoundedAndFast` — ≤41 visual / ≤121 list nodes, exact byte conservation, single pass < 5 s. |
| Partial results appear progressively | **PASS (engine test)** | `SpaceLensTests.emitsGrowingPartialRootsForTopLevelFoldersThenAFinalRoot` — non-shrinking partial child counts, final count exact. |
| ~8/s publication throttle | **PASS (test)** | `SpaceLensExplorerTests.partialUpdatesAreThrottledByTheInjectedClock` (clock-driven). |
| Stable identity / deterministic layout | **PASS (test)** | `stableIdentityAcrossRuns`; `RadialPack` slot is fixed by input order (bytes desc, path asc). |
| Real-world scan feel (`~/Library`, `~/Developer`): progressive, non-jittery, stable, responsive, bounded memory, responsive cancel | **HUMAN VERIFICATION REQUIRED** | scan against a large real read-only directory and observe. |
| Canvas: enough space, readable bubbles, large nodes dominate, Other understandable, labels not overlapping, list usable, resize, light/dark | **HUMAN VERIFICATION REQUIRED** | canvas `minHeight 340 / maxHeight 460`; render bound 14; `RadialPack` gap 6; label shown only when radius ≥ 30. Visual judgement outstanding. |
| Selection: click bubble ⇄ list row sync; subtle, no layout shift, no bounce; sidebar independent | **PASS (static) / HUMAN VERIFICATION REQUIRED (visual)** | one shared `model.selectionID`; selection = stroke + halo only, no scale. |
| Double-click: dir bubble drills; dir row drills; file does not; Other does not | **PASS (state test) / HUMAN VERIFICATION REQUIRED (gesture in a real window)** | `drillByIDRefusesFilesAndUnknownIDs`, `drillByIDRefusesTheSyntheticOtherBucket`. Row uses `.simultaneousGesture(TapGesture(count:2))`; bubble uses `onTapGesture(count:2)` then `count:1`. |
| Keyboard: Return / →Right drills, Esc / ⌘[ Back, search + breadcrumb reachable, visible focus | **PASS (static) / HUMAN VERIFICATION REQUIRED (focus visuals)** | `.onKeyPress(.return/.rightArrow/.escape)` on the focusable list; `⌘[` on the Back button. |
| Breadcrumb / Back multi-level; no unnecessary rescan; no stale selection | **PASS (test)** | `SpaceLensNavigationTests` (`currentFollowsPathStackThenRoot`, `popToIndexAndToRoot`), `drill…ClearsSelection`; navigation reads the cached tree, no rescan. |
| Search / filter: filters current scope, list+bubbles synced, selection cleared if hidden, category filter, clear restores | **PASS (test)** | `filterKeepsOnlyMatchingRealChildren` variant; `.task(id: searchText)` debounces 200 ms then drops an off-screen selection; no filesystem rescan (all in-memory `SpaceLensAggregator`). |
| Pause / Resume visual; repeated toggles no deadlock; Cancel while paused | **PASS (engine test) / HUMAN VERIFICATION REQUIRED (UX)** | `pausedSpaceLensScanResumesAndFinishes`, `manyPausedWaitsResumeWithoutExecutorStarvation`, `breakingOutWhilePausedStillTearsDownFast`. |
| Cancel: task stops, state cancelled, no completed Timeline snapshot, no "Scan complete", partial clearly partial | **PASS (static + test)** | `SpaceLensViewModel.cancel()` cancels the task + resumes the pause controller; `.cancelled` event → `phase = root == nil ? .idle : .ready`; Timeline snapshot only written on `.finished`. |

## 21. Reduce Motion

| Check | Status | Notes |
|---|---|---|
| Smart Scan + Space Lens honour `accessibilityReduceMotion` | **PASS (static) / HUMAN VERIFICATION REQUIRED (appearance)** | Space Lens: selection is stroke/halo only (no scale) regardless; hover scale gated `&& !reduceMotion`; hover state change skips `withAnimation` under reduce motion. Dashboard `Reveal` modifier is a no-op under reduce motion (pre-existing). Functionality identical either way. |

## 22–23. VoiceOver

| Check | Status | Notes |
|---|---|---|
| Smart Scan module rows announce module + state + detail + button trait when actionable | **PASS (static) / HUMAN VERIFICATION REQUIRED (assistive tech)** | `SmartScanModuleRow` is `.accessibilityElement(children: .combine)` with a composed label and `.isButton` only when openable. |
| Space Lens bubbles announce "Name, Size, N percent of this folder, directory/file" — never "Circle" | **PASS (static) / HUMAN VERIFICATION REQUIRED (assistive tech)** | `bubbleA11y` = `spacelens.bubble_a11y` (`%@, %@, %lld percent of this folder, %@`); bubble is `.accessibilityElement()` + `.isButton`/`.isSelected` + drill hint. Canvas exposes a summary; the List is the primary representation. |
| List / breadcrumb / Back / search reachable under VoiceOver | **HUMAN VERIFICATION REQUIRED** | — |

## 24–25. Localization (FR / EN)

| Check | Status | Notes |
|---|---|---|
| EN/FR key parity (whole catalogue) | **PASS (test)** | `shippedEnglishAndFrenchCataloguesHaveExactKeyParity` + `repository-doctor` + independent count (1074 keys each). |
| New Smart Scan / Space Lens / Storage strings translated | **PASS (test)** | `LocalizationParityTests.smartScanAndSpaceLensKeysAreAllTranslatedInBothLanguages`. |
| No English leftovers in new Swift UI | **PASS (static)** | grep for `Text("…")` / `Button("…")` literals in new files → none; only punctuation-glued composites of already-localized values. |
| Truncation / grammar / accents / pluralization / wrapping in FR at real widths | **HUMAN VERIFICATION REQUIRED** | FR strings deliberately not shortened; layout uses wrapping + `layoutPriority`. Needs a look. |

## 26–27. Window-size matrix / light-dark

| Check | Status | Notes |
|---|---|---|
| Compact / MacBook / desktop widths across Dashboard, Smart Scan result, Storage, Space Lens, Duplicates, Recovery Plan — no clipped CTA, usable canvas, no collapsed sidebar | **HUMAN VERIFICATION REQUIRED** | window `minWidth`/`minHeight` enforced by `MCSize`; sidebar column-visibility pinned. Not visually confirmed. |
| Light + dark: contrast, selection, badges, bubbles, sidebar, disabled controls, focus rings | **HUMAN VERIFICATION REQUIRED** | all colours via theme-aware `MC*` tokens; no `data-theme`-only assumptions. Not visually confirmed. |

## 28–29. Finder extension

| Check | Status | Notes |
|---|---|---|
| Extension embedded, sandbox-only entitlements, correct bundle id / extension point | **PASS (static)** | `build-xcode.sh` verifies `CoreTendFinder.appex` (`com.apple.FinderSync`, `com.ahmetbsbnr.coretend.finder`), ad-hoc entitlements exactly `{app-sandbox: true}`. Finder source unchanged this branch. |
| Enable in System Settings; folder → Scan Folder; image → Inspect Image Metadata; `.app` → Inspect Application Integrity | **HUMAN VERIFICATION REQUIRED** | (carried from the Finder vertical — `FINDER_EXTENSION_VALIDATION.md`) |
| Empty / multiple / missing / symlink / unsupported selection produce no unsafe action | **PASS (test) / HUMAN VERIFICATION REQUIRED (live)** | `FinderHandoffTests`, `SelectionValidator` tests cover the logic. |
| Cold / warm / background / closed-window handoff; consume-once | **PASS (test) / HUMAN VERIFICATION REQUIRED (live)** | `AppRouter` consume-once + cold-launch buffer tested. |
| Allowed / disallowed locations (Desktop, Documents, Downloads, external volume, protected); host revalidates; extension stays read-only | **PASS (static) / HUMAN VERIFICATION REQUIRED (live)** | host re-runs `SelectionValidator` at receipt and consumption; extension has no destructive API. |

## 30. Widget

| Check | Status | Notes |
|---|---|---|
| Embedded, sandbox + App Group only, correct id / extension point, FR localization | **PASS (static)** | `build-xcode.sh` verifies `CoreTendWidget.appex` (`com.apple.widgetkit-extension`, `com.ahmetbsbnr.coretend.widget`, FR bundle). Widget source unchanged this branch. |
| Small + medium render; aggregate-only info; no paths / private metadata; not stale; read-only; light/dark | **HUMAN VERIFICATION REQUIRED** | `WidgetPublisherTests` proves a path-bearing activity summary reduces to a bare kind; `WidgetSharedTests` covers snapshot formatting + staleness. Rendering + gallery add is human. |

## 31. Shortcuts / App Intents

| Check | Status | Notes |
|---|---|---|
| 7 App Intents present | **PASS (static)** | `GetFreeDiskSpaceIntent`, `GetCoreTendSummaryIntent`, `GetStorageChangeIntent`, `GetReclaimableDeveloperStorageIntent`, `GetIntegritySummaryIntent`, `InspectImageMetadataIntent`, `OpenCoreTendModuleIntent`. `Metadata.appintents` in the built app reports 7. |
| 6 App Shortcuts present | **PASS (static)** | all of the above except `GetIntegritySummaryIntent`. Built app reports 6. |
| No destructive intent | **PASS (test)** | `MacIntegrationsSafetyTests` greps comment-stripped source — no `FileRules` import, no `SafetyCenter`/`CleanupExecution`/`RecoveryPlanService`/`RestoreService` reference. |
| Shortcuts app actually discovers + runs them; FR phrases | **HUMAN VERIFICATION REQUIRED** | needs the Shortcuts app. |

## 32. Notifications

| Check | Status | Notes |
|---|---|---|
| Scheduled-scan options are Off / Daily / Weekly only | **PASS (static)** | `ScheduledScanService` `enum { off, daily, weekly }`. |
| Aggregate-only bodies, rate-limited, 3 toggleable categories, in-context permission | **PASS (test)** | `NotificationPolicy` + `NotificationService` tests (in the 797). |
| Real OS permission prompt + delivery | **HUMAN VERIFICATION REQUIRED** | cannot confirm OS-level delivery here. |

## 33. Launch / relaunch

| Check | Status | Notes |
|---|---|---|
| Cold launch of the beta build | **PASS** | see Launch smoke above. |
| Smart Scan in-memory state does not survive a full relaunch | **PASS (static)** | `SmartScanModel` is `@State` on `MainWindow`; `SmartScanHandoff.shared` is an in-memory singleton. No `@AppStorage` / `UserDefaults` / `Store` write for Smart Scan state (grep-verified). |
| No crash from missing Website / Community backend config | **PASS (static)** | see §34. |
| Warm nav / close / reopen / quit / relaunch | **HUMAN VERIFICATION REQUIRED** | not exercised interactively. |

## 34. No network dependency for the core product

| Check | Status | Notes |
|---|---|---|
| Storage / Space Lens / Smart Scan / Privacy / Integrity / Applications / Recovery / Restore usable with no Contact/Community deployment | **PASS (static)** | The only `URLSession` in the entire app is `UpdateChecker.swift` (ephemeral, read-only version check; fails closed to reported states, never a crash). **Zero** references to `postgres`, `Resend`, `@vercel`, or the Community/Contact backend in `Sources/`. |

## 35. Restore Center regression

| Check | Status | Notes |
|---|---|---|
| Restore Center code intact | **PASS (static)** | this branch touches no file under `Sources/SafetyCore/`, `Sources/Persistence/`, `RestoreService.swift`, `RestoreCenterView.swift`, `RestoreManifest.swift`, or `RecoveryPlanService.swift` execution. All existing Restore + SafetyCore tests green in the 797. |
| Real move → Trash → manifest → restore, collision protection, stale handling | **HUMAN VERIFICATION REQUIRED (with disposable content)** | carried from the Restore vertical; not re-exercised this pass. |

## 36. Release version audit

Everything is consistently **`1.0.0` / build `1000` / channel `stable`** today. The bump to `1.1.0-beta.1` is an **atomic release-branch change** gated by `Scripts/check-version-consistency.sh` (runs in `ci.yml`, `release.yml`, `release-draft.yml`, `final-launch-gate.sh`). **Not performed in this pass** — bumping one location without the others fails the gate, and this is not the release branch.

Exact bump locations:

| File | Key(s) today | Beta.1 value |
|---|---|---|
| `Configuration/PublicIdentity.example.json` (**source of truth**) | `marketingVersion: "1.0.0"`, `buildNumber: "1000"`, `channel: "stable"` | `"1.1.0-beta.1"`, `"1100"` (or next), `"beta"` (or `"prerelease"`) — decide the beta channel label with the updater semantics below |
| `Resources/Info.plist` | `CoreTendMarketingVersion "1.0.0"`, `CFBundleShortVersionString "1.0.0"`, `CFBundleVersion "1000"` | `CoreTendMarketingVersion "1.1.0-beta.1"`, `CFBundleShortVersionString "1.1.0"` (Apple: digits only), `CFBundleVersion "1100"` |
| `project.yml` | `MARKETING_VERSION "1.0.0"`, `CURRENT_PROJECT_VERSION "1000"` | `"1.1.0"`, `"1100"` — then regenerate `CoreTend.xcodeproj` (repository-doctor drift check) |
| `Documentation/PROJECT_STATE.json` | `version "1.0.0"` (+ the `release` block describing the published v1.0.0) | `version "1.1.0-beta.1"`; leave the `release` block until beta.1 is actually published |
| `Release/latest.template.json` | hand-authored channel / min-OS / URLs | review `channel` + release-notes pattern for the beta |

**Do NOT touch** `Configuration/published-release.json` in this pass — it records the currently-live v1.0.0 stable release and is updated by `Scripts/sync-published-release.sh` only after a real publication.

No hidden `1.0.0` string was found in a place beta packaging must override, beyond the audited locations above. The built `build/CoreTend.app/Contents/Info.plist` carries `1.0.0 / 1000 / 1.0.0` — it will pick up the bump from `project.yml` + `Resources/Info.plist` automatically.

## 37. Release channel

- The app's `UpdateChecker` reads a published `latest.json` manifest and offers an update when `SemanticVersion(latest) > SemanticVersion(current)`, filtered by `UpdateChannel` (`stable` never sees a prerelease; `prerelease` sees betas/RCs). A `1.0.0` **stable** user must NOT be auto-nudged to `1.1.0-beta.1` — so the published beta manifest must carry `prerelease: true` and a non-stable `channel`, and stable users' `UpdateChannel` stays `stable`.
- **Final publication must update** (out of scope for this pass): the GitHub release (tag `v1.1.0-beta.1`, marked *pre-release*), the published `latest.json` / `SHA256SUMS` beside the DMG/ZIP, `Configuration/published-release.json` via `sync-published-release.sh`, and — separately, per the brief — any `Website/api` release manifest. Do **not** change the Website manifest in this pass.

## 38. Signing architecture

**PASS (static).** `Scripts/sign-and-notarize.sh` signs inside-out: nested executables → `CoreTendFinder.appex` (`CoreTendFinder.entitlements`, sandbox only) → `CoreTendWidget.appex` (`CoreTendWidget.entitlements`, sandbox + App Group) → `CoreTend.app` host **last** (`CoreTend.entitlements`, hardened runtime + App Group, no sandbox), sealing `CodeResources` over the already-signed appexes. Verifies `--deep --strict`, asserts the widget carries the App Group and the Finder entitlements are *exactly* `{app-sandbox: true}`. Requires a real `DEVELOPER_ID` from `security find-identity` — **fails closed if absent; does not fabricate signing**. Hardened Runtime on; entitlements not weakened.

## 39. App Group external prerequisite

**EXTERNAL CONFIGURATION REQUIRED.** `group.com.ahmetbsbnr.coretend` is declared in `CoreTend.entitlements` and `CoreTendWidget.entitlements`. For a real Developer ID + notarization run with WidgetKit, this App Group **must be registered on the Apple Developer portal** (Identifiers → App Groups) and associated with both the host and widget App IDs. Not verifiable locally. `Documentation/PROJECT_STATE.json` already records this.

## 40. Entitlements

**PASS (static).**

| Bundle | Entitlements | Verdict |
|---|---|---|
| Host `CoreTend.app` | `com.apple.security.application-groups = [group.com.ahmetbsbnr.coretend]` only; not sandboxed (documented, deliberate); Hardened Runtime on; no `com.apple.security.cs.*` exceptions | as designed |
| `CoreTendFinder.appex` | `com.apple.security.app-sandbox = true` only | as designed (sandbox only) |
| `CoreTendWidget.appex` | `app-sandbox = true` + `application-groups = [group.com.ahmetbsbnr.coretend]` | as designed (sandbox + App Group) |

No accidental broad entitlement. No network / iCloud / push / automation / privileged-helper / `cs.*` anywhere.

## 41–42. Release build & static bundle audit

**PASS.** `Scripts/build-xcode.sh` produces `build/CoreTend.app` (unsigned Release) with:

- correct layout: `Contents/{MacOS/CoreTend, PlugIns/{CoreTendFinder.appex, CoreTendWidget.appex}, Resources/{CoreTend_CoreTendApp.bundle, CoreTend_FinderShared.bundle, CoreTend_WidgetShared.bundle, Metadata.appintents}}`
- **no `/Users/...` absolute path, no build-machine account name** anywhere in the bundle
- no test fixtures, `.xctest`, debug assets, `.env` / secret / `.pem` / `.key` files
- `Metadata.appintents` present with 7 App Intents / 6 App Shortcuts
- FR localization bundles for host, FinderShared, WidgetShared
- `coretend://` URL scheme registered
- Info.plist carries no absolute developer path (asserted by the script)

Built products were not hand-patched.

## 46. Release-script audit / public-vs-internal artifact policy

`Scripts/build-release.sh` (+ `package-dmg.sh` / `package-zip.sh` / `sign-and-notarize.sh` / `generate-public-release.py`) produce, all gitignored under `dist/` mirrored to `Release/`:

| Artifact | Class | Notes |
|---|---|---|
| `CoreTend-<ver>-arm64[-unsigned].dmg` | **USER-FACING** — primary beta download (DMG-first) | signed + notarized + stapled in `CORETEND_RELEASE_SIGNED=1` mode |
| `CoreTend-<ver>-arm64[-unsigned].zip` | **USER-FACING** — alternate download | |
| `latest.json` | **MACHINE-CONSUMED** — the app's `UpdateChecker` reads it; CI gates cross-check it | must be published for beta users to be told a newer version exists |
| `SHA256SUMS` | **MACHINE-CONSUMED** (release-integrity gates, CI cross-check) **+ USER-FACING** (optional `shasum -c`) | keep published |
| provenance fields in `latest.json` (`sourceCommit`, `releaseTag`, `treeState`, build id) | **INTERNAL / audit** | |
| `AUDIT_PACKAGE_SHA256SUMS` (`build-audit-package.sh`) | **INTERNAL** — tamper-detection for the audit ZIP | |
| Minisign `.minisig` + `minisign.pub` | **USER-FACING optional verification** — produced only by the external signing runner; **not consumed by the app updater** | see §47 |
| SBOM / SLSA attestation | **INTERNAL / supply-chain** — produced by the external signing runner (`PROJECT_STATE.json` `releaseWorkflow.nextRelease`), absent locally | |

No internal verification step was removed or weakened.

## 47. Minisign / checksum audit

- `SHA256SUMS` and `latest.json`'s `dmgSHA256`/`zipSHA256` **are machine-consumed** — by `test-release-manifest.sh`, `test-public-release-gate.py`, `final-launch-gate.sh`, `sync-published-release.sh`, and cross-checked in CI. **Preserve.**
- The app's native `UpdateChecker` **does not download or verify artifacts** — it only reads `latest.json` for the version + notes and opens the release page. It never consumes `minisign.pub` / `.minisig`.
- **Minisign** is produced only by the external "dedicated self-hosted signing runner" and serves **manual end-user verification** only.
- **Recommendation for beta.1 public assets:** publish DMG (primary) + ZIP + `latest.json` + `SHA256SUMS`. Minisign `.minisig` + `minisign.pub` add publication surface for a benefit (manual verification) that most beta testers will not exercise and the updater does not need — **defer them to the stable 1.1.0 release** unless the maintainer wants them for the beta. Keep every internal gate (`SHA256SUMS` verification, provenance manifest, audit package) intact. **Do not delete any release-security script.**

---

## Outstanding — HUMAN VERIFICATION REQUIRED (interactive, on device)

1. Smart Scan idle / running / result visual polish; title not clipped; `storageGlance` weight; light + dark; compact / MacBook / desktop widths; FR + EN.
2. Smart Scan: leave Dashboard mid-scan and return — scan still running, no restart, no layout jump.
3. Recovery Plan handoff: open via "Review Recovery Plan", confirm the note + no second scan + category/count match; stop at the confirmation boundary.
4. Storage: Pause/Resume/Cancel/Finalizing UX; friendly-location readability.
5. **Duplicates sidebar (P0):** Dashboard → Duplicates → Space Lens → Duplicates; select rows; resize narrow↔wide; Tab through controls — sidebar always present, active module marked, no empty/phantom column.
6. Sidebar focus independence while selecting Space Lens bubbles / Duplicates rows / Smart Scan rows.
7. Space Lens against a large real read-only directory (`~/Library`): progressive partials, non-jittery ~8/s, stable layout, no flicker, responsive UI + cancel, sane memory.
8. Space Lens canvas visual quality; selection ⇄ list sync; double-click drill (bubble + row) in a real window; file / Other do not drill; keyboard drill + visible focus; breadcrumb / Back multi-level.
9. Space Lens search/filter sync + deterministic selection handling.
10. Reduce Motion appearance across Smart Scan + Space Lens.
11. VoiceOver: Smart Scan module rows; Space Lens bubbles ("… percent of this folder, directory", never "Circle") + list + breadcrumb + Back + search.
12. French QA across Dashboard / Smart Scan / Storage / Space Lens / Duplicates / Recovery Plan — no English leftovers, no truncation, wrapping OK.
13. Finder extension: enable in System Settings; folder / image / `.app` actions; empty / multiple / missing / symlink / unsupported selections; cold / warm / background / closed-window; consume-once; allowed vs protected locations.
14. Widget: add from gallery; small + medium; aggregate-only; no paths; light/dark; read-only.
15. Shortcuts app: discovers the 7 intents / 6 shortcuts; run a read-only one; FR phrases.
16. Notifications: real OS permission prompt + delivery; Off/Daily/Weekly; no spam.
17. Restore Center: real move → Trash → Restore with disposable synthetic content; collision protection; external-volume restore.
18. Warm nav / close / reopen / quit / relaunch — no stale Smart Scan state, no crash.

## Outstanding — EXTERNAL CONFIGURATION REQUIRED

- **App Group `group.com.ahmetbsbnr.coretend`** registered on the Apple Developer portal and associated with the host + widget App IDs — required before a real Developer ID + notarization run with WidgetKit.
- **Developer ID signing identity** present in the keychain for `Scripts/sign-and-notarize.sh` (it fails closed without one).
- **Notary profile** for `xcrun notarytool`.

## Version bump — NOT performed here (release-branch action)

See §36 for the exact file/key list. Bumping must be atomic across `PublicIdentity.example.json` + `Resources/Info.plist` + `project.yml` (+ regen `CoreTend.xcodeproj`) + `PROJECT_STATE.json`, or `check-version-consistency.sh` fails.
