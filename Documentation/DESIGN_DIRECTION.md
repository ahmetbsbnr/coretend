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

### Correctness
- **Cancel works in five modules.** `AsyncStream` exits the loop before the
  `.cancelled` event, so every `case .cancelled: phase = .idle` was dead code.
  8 tests, 6 verified negatively.
- **An unreadable exclusion list is no longer the same value as an empty one.**
  `(try? …) ?? []` made a failed store produce zero exclusions, so folders the
  user had explicitly protected came back *already ticked* for deletion.
- **A run that did nothing no longer reports as a quiet success.** Validator
  refusals were dropped by `try? await center.approve(…)` before reaching the
  result, so forty refused files rendered as "Moved 0 bytes to Trash".
- **Execution failures say what happened.** Every `trashItem` failure was
  reported as `.fileVanished`, including permission denied.
- **Store failure is a reportable state**, not two stacked silent `try?`s that
  could leave the app writing the user's history to RAM.

### Visual system
- **One owned appearance.** Fixed palette, contrast ratios recomputed by tests
  rather than trusted from comments, four-step elevation ladder.
- **The app owns its accent.** The selected sidebar row was the user's *system*
  accent — green on this Mac, pink on another — while the brand is teal.
- **The primary action was white on teal: 1.87:1.** Now 9.65:1. "Move to Trash"
  was also rendered in the primary style, identical to "Scan".
- **Four motion tokens** replacing eight durations across four curve families,
  with a Reduce Motion choke point that cannot be forgotten.
- **Typography named for what text is**, not how big it is. `.font(.caption)`
  appeared 56 times while `MCFont.caption` sat unused; zero numeric font
  literals remain.
- **One surface implementation.** `MCCard` was used eleven times while the
  Dashboard hand-rolled five more.
- **Liquid Glass** on the two navigation-layer surfaces, gated on macOS 26 and
  disabled under Reduce Transparency.
- **One Pause/Resume/Cancel cluster** instead of seven, two of which had lost
  their accessibility identifiers entirely.

### Four app-to-website contracts, all silently broken
- **Design tokens.** The exporter parsed a format the palette no longer used,
  exported zero colours and exited 0. The site's `var(--ct-…)` fallbacks then
  hid it by resolving to the previous palette's literals.
- **Brand artwork.** The generator restated the palette under a comment
  promising it mirrored `MCColor.Canonical`. The app icon, DMG background and
  Open Graph card were regenerated while all seven brand files the site serves
  stayed in the old palette.
- **No publish step existed** between generated artwork and the website.
- **The demo's navigation** invented a group the app does not have.

All four now fail loudly, three of them in CI.

### Removed for describing what does not exist
- "Privileged helper — Unavailable", whose explanation stopped being true when
  the app started shipping signed.
- The Appearance section, whose only line said there was nothing to configure.
- `PlaceholderView` — and its removal was claimed once before it happened.
- The Notifications permission row. Worse than dead UI: onboarding *requested*
  notification authorization for a feature that posts no notification anywhere.

### Two false reports, corrected
- `capture-module.sh` passed identifiers that did not resolve, so eleven
  screenshots of eleven modules were eleven screenshots of the Dashboard, and
  every check against them passed. "11/11 modules verified" was false.
- A commit claimed `PlaceholderView` was removed. The replacement had not
  matched. The view remained, calling a localization key that same commit had
  deleted.

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
  a test-marker-gated variable and captures by CoreGraphics window id. It
  prints the title of the window it captured, and that line is the evidence: an
  earlier version silently captured the Dashboard eleven times, because the
  identifiers it passed ("spaceLens") are not `ModuleID`'s raw values
  ("Space Lens") and the lookup fell through. Every check run against those
  screenshots passed, since the Dashboard renders correctly. Reports of
  "11/11 modules verified" made before 2026-09-18 were therefore false;
  `ModuleIdentifierTests` now makes the mapping an asserted contract.
- `python3 Scripts/check-sidebar-rendered.py <captures>` — fails when a
  sidebar region is one flat colour. Verified against the pre-fix capture.

Claims in this document that are not backed by one of those three are marked
as such in the text.
