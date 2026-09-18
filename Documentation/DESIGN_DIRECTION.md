# CoreTend — design direction and redesign programme

Date: 2026-09-18 · Status: direction agreed, execution in progress

This document exists because the brief is "everything, to a majestic level".
That is a programme, not a change. Written down so nothing in it is forgotten,
and so what is *done* is distinguishable from what is *claimed*.

---

## 0. The one thing that is not being rewritten, and why

`ScanCore`, `SafetyCore`, `Persistence`, `FileRules`, `SystemMetrics`,
`IntegrityCore` — the engines — stay. 439 tests cover them, including
`PathValidator`'s 26 cases (symlink swapped after approval, file vanished
between approval and execution, boundary-correct prefix matching), pause/resume
starvation, cancellation, concurrency-invariance and a 10k-file stress run.

That suite is the reason this app can be trusted to move a user's files to the
Trash. Rewriting it would trade a proven asset for an unproven one and would
consume the whole budget without changing a single pixel. **The presentation
layer is where the upside is, and that is what is being rebuilt.**

This is the only part of the brief being scoped down, it is stated here rather
than done quietly, and it is reversible on request.

---

## 1. Inventory — the actual surface, counted

| Surface | Count | Source |
|---|---|---|
| Module views | 20 | `Sources/CoreTendApp/*View*.swift` |
| Design-system components | 10 | `MCCard`, `MCScanButton`, `MCEmptyState`, … |
| Localized strings | 560 × 2 languages | `Localizable.strings` |
| Sheets / dialogs / alerts / panels | 6 / 7 / 2 / 6 | grep over `Sources/CoreTendApp` |
| Menu-bar commands | 3 groups, 9 items | `CoreTendHelpCommands` |
| Brand assets generated | 28 | `Resources/Brand/Generated` |
| Website | 1 page, 1867 lines + build script | `Website/` |
| Tests | 439 | `Tests/` |

Nothing below is planned against memory; every item traces to a file.

---

## 2. Direction

**Slate ground, teal accent, one owned appearance.** Decided and shipped
(`Sources/DesignSystem/Colors.swift`). The app no longer follows the system
light/dark switch; the palette is fixed, and its contrast ratios are recomputed
by tests rather than trusted from comments.

Three principles the rest of the work is held to:

1. **Colour carries meaning on one axis.** Teal is action. Amber is caution.
   Coral is irreversible. Everything else is structure. A module does not get a
   hue.
2. **State is never colour alone.** The sidebar's selection is a shape *and* a
   wash; a refused permission is an icon *and* a sentence saying what breaks.
3. **Nothing on screen describes something that does not exist.** Four pieces
   of interface were removed for failing this (see §4).

---

## 3. Done

- **Cancel works in five modules.** `AsyncStream` exits the loop before the
  `.cancelled` event, so every `case .cancelled: phase = .idle` was dead code.
  `CancellableScan` resets synchronously. 8 tests, 6 verified negatively.
- **Blank sidebar.** Not the documented `TabView` hazard — a
  `.fixedSize(horizontal: false, vertical: true)` on a long `Text` propagating
  its unwrapped ideal width as the detail column's minimum, collapsing the
  sidebar to zero. Rows stayed in the accessibility tree the whole time, which
  is why every existing gate passed. `Scripts/check-sidebar-rendered.py` is the
  pixel gate that catches it.
- **One sub-navigation idiom** (`ModuleSubNav`) replacing three.
- **The app owns its appearance, palette and sidebar.** The selected row was
  the user's *system* accent — green on this Mac, pink on another — while the
  brand is teal.
- **Per-capability authorization model** replacing one boolean.
- **Update check and download verification**, with the automatic check that was
  specified in the strings tables and never implemented.
- **Help menu localized**; Keyboard Shortcuts shows shortcuts (⌘/).
- **A shipped localization bug**: a `|||||||` merge-conflict marker in both
  tables silently truncated the parser, so every key after it resolved to its
  own name in a released build.

## 4. Removed for describing what does not exist

- "Privileged helper — Unavailable", whose explanation stopped being true when
  the app started shipping signed.
- The Appearance section, whose only line said there was nothing to configure.
- `PlaceholderView` / "This module is under construction" — unreachable.
- The Notifications permission row. Worse than dead UI: onboarding *requested*
  notification authorization for a feature that posts no notification anywhere
  in `Sources/`.

---

## 5. Remaining — the programme

Ordered by user-visible value. Each lands as its own commit with tests and a
verified capture.

### A. Correctness still outstanding
1. `AppEnvironment.swift:23` — `try? Store(path: (try? Store.defaultPath()) ?? ":memory:")`.
   A failed store makes the user's **exclusion list silently empty**, so folders
   they explicitly protected are rescanned and re-offered for trashing. Highest
   remaining risk in the project.
2. Approval rejections are invisible to `ExecutionOutcome`: 40 files rejected
   reports "Moved 0 bytes" with no skip line — the exact failure its own doc
   comment says it prevents.
3. `SafetyCore` reports every execution failure as `.fileVanished`, including
   permission denied.
4. Applications' nested split view; typed sub-screens.

### B. Visual system
5. Component pass: buttons, cards, rows, empty states, dialogs — against the
   new palette and elevation ladder.
6. Motion: one timing scale, one easing family, Reduce Motion honoured at a
   single choke point (`MCMotion` exists; call sites are inconsistent).
7. Typography: the scale is 10 styles with no documented rhythm.
8. Iconography: SF Symbols audited for weight and optical alignment.

### C. Liquid Glass
9. macOS 26 introduced Liquid Glass; the deployment target is macOS 14 and the
   app adopts none of it. Adoption is `if #available(macOS 26, *)` around
   `glassEffect` on the navigation layer only — Apple's guidance is that glass
   belongs to chrome floating above content, never to content. Below 26 the
   current material stays. **Not started.**

### D. Brand
10. 28 generated assets derive from one mark. The mark itself, the Dock icon,
    the DMG background and the favicons are one decision, not eleven.
11. Website: one 1867-line page. Its in-page app mockup already shows a
    *different* sidebar from the real app — the two have drifted.

### E. Distribution
12. The App Store question (§6) must be answered before the icon set and the
    update surface are finalised, because it changes both.

---

## 6. The App Store constraint — unresolved, and it is a decision

The stated goal is the App Store. Two structural conflicts:

1. **Sandboxing.** Scanning `~/Library/Caches`, enumerating `/Applications`,
   uninstalling apps and moving files to the Trash are largely incompatible
   with the App Store sandbox. Full Disk Access is not available to sandboxed
   apps.
2. **Self-updating.** Apple handles updates for App Store apps; `UpdateChecker`
   and `DownloadVerification` would have to be compiled out of that target.

Three viable answers:

- **Developer ID only** (today). Full capability, no App Store.
- **Two targets.** App Store build scoped to what the sandbox allows — Space
  Lens, Duplicates and Large & Old over folders the user grants via
  `NSOpenPanel` and security-scoped bookmarks — alongside the full Developer ID
  build.
- **App Store only**, accepting the reduced scope.

This is a product decision with a large engineering consequence, so it is
surfaced rather than assumed.

---

## 7. What is verified, and how

- `bash Scripts/test.sh` — 439 tests. Never raw `swift test`.
- `zsh Scripts/capture-module.sh <out.png> <module>` — launches on a module via
  a test-marker-gated variable and captures by CoreGraphics window id.
- `python3 Scripts/check-sidebar-rendered.py <captures>` — fails when a
  sidebar region is one flat colour. Verified against the pre-fix capture.

Claims in this document that are not backed by one of those three are marked
as such in the text.
