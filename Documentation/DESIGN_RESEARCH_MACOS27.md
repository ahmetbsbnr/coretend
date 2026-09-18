# macOS 27 Golden Gate — research, and what it reverses

Date: 2026-09-18 · Supersedes the macOS 26 findings in `DESIGN_RESEARCH.md`

This machine runs macOS 27.0 and builds against `MacOSX27.0.sdk`. The previous
research document was written against Tahoe 26 guidance, and **Golden Gate
reverses two of its four actionable findings**. Everything below that concerns
API is checked against the SDK on this machine, not against a report.

Sources: [Six Colors review](https://sixcolors.com/post/2026/09/macos-27-golden-gate-review-bridging-the-tahoe-gap/) ·
[MacStories review](https://www.macstories.net/stories/macos-27-the-macstories-review/2/) ·
[Liquid Glass, revision history](https://en.wikipedia.org/wiki/Liquid_Glass) ·
[WWDC26 SwiftUI guide](https://developer.apple.com/wwdc26/guides/swiftui/) ·
[9to5Mac announcement](https://9to5mac.com/2026/06/08/apple-announces-macos-golden-gate-27/)

---

## 1. What Golden Gate changed, and why

Tahoe's Liquid Glass drew sustained criticism: transparency made text harder to
read, effects pulled attention away from content, and the application was
inconsistent between Apple's own apps. Golden Gate is the correction.

### 1.1 Sidebars: reverted, and icons are coloured again

> "Floating glass sidebars that previously inset from window edges have been
> reverted. Sidebars now sit at the left edge of windows, with a darker
> background for contrast and **coloured icons**."

**This reverses `DESIGN_RESEARCH.md` §1.1.** The Tahoe rule — sidebar icons
black in light, white in dark, never the accent — lasted one release. On macOS
27 a coloured sidebar icon is the current convention.

**Consequence for CoreTend: the teal selected icon is correct.** It was the
right answer for the wrong reason, and it would have been wrong for a year.
The lesson is not "I got lucky"; it is that a single-release guidance change is
not a foundation, and the sidebar's *structure* — a darker ground, contrast,
its own edge — matters more than the tint rule that keeps flipping.

### 1.2 Windows are less round, not more

> "Windows feature more consistent corner treatments and **reduced** border
> radius curves. The overall effect feels a bit more square, reducing visual
> complexity from Tahoe's aggressive curvature."

**This reverses `DESIGN_RESEARCH.md` §1.3**, which said to revisit
`MCRadius.card = 8` against rounder windows. Golden Gate went the other way.
8 pt is defensible as it stands, and a *larger* card radius would now read as
last year's.

### 1.3 Transparency is the user's decision now

Appearance settings gain a slider running from "highly transparent" to "nearly
solid colour", with live preview. Apple's own acknowledgement that one
transparency cannot suit everyone.

**Consequence: do not hand-tune glass opacity.** `glassEffect(.regular)` tracks
the slider; a hand-rolled material with a fixed alpha does not, and would
ignore a setting the user deliberately moved. CoreTend uses `glassEffect`, so
this works — but it means the right answer to "is our glass too transparent?"
is no longer a design opinion.

### 1.4 Toolbars are bars again

Flattened, ghostly floating button regions become discrete bars with real
shading, and **a continuous bar appears beneath controls automatically when
content scrolls under them**. Photos specifically stopped needing artificial
shading to stay legible.

### 1.5 Icons: better compositing, same shame box

Layered icon compositing improved — narrower 3D borders, refined effects,
"edges darker, highlights brighter, adding a greater sense of depth". But the
grey box for non-squircle icons persists.

**`DESIGN_RESEARCH.md` §1.5 stands unchanged and is the single highest-value
visual fix available.** CoreTend ships a hand-built `.icns` whose shape is a
circular-arc rounded rect, ~43 px off Apple's continuous curve at 1024. Icon
Composer is at `/Applications/Xcode.app/Contents/Applications/Icon Composer.app`.

### 1.6 Restraint in menus

Revised HIG: use SF Symbols in menus "sparingly and with purpose" — a reversal
of the Liquid Glass proliferation of the previous cycle.

### 1.7 Apple silicon only

Golden Gate drops x86_64. CoreTend already ships arm64-only, so nothing to do —
but it removes any remaining argument for a universal binary.

---

## 2. The API surface, verified on this machine

Read out of
`MacOSX27.0.sdk/…/SwiftUI.swiftmodule` and `SwiftUICore.swiftmodule`, because
several secondary sources were wrong about availability.

### 2.1 Glass — macOS 26.0, unchanged in 27

```
struct Glass                     // SwiftUICore, not SwiftUI
  static var regular, clear, identity
  func tint(_:), func interactive()
glassEffect(_:in:)  glassEffectID(_:in:)  glassEffectUnion(id:namespace:)
glassEffectTransition(_:)        GlassEffectContainer
GlassEffectTransition: .identity, .matchedGeometry, .materialize
```

Two corrections to the secondary sources:

- `Glass.interactive()` is **available on macOS**, not iOS-only as one widely
  cited reference claims.
- `Glass` is declared in **SwiftUICore**. Searching `SwiftUI.swiftinterface`
  for `glassEffect` returns nothing, which is how a reasonable check can
  conclude the API is absent when it is not.

### 2.2 Buttons — the guidance CoreTend is currently against

WWDC26: *"for a glass button, you should use `glassButtonStyle` (or
`glassProminent`) rather than applying a raw `glassEffect`."*

Verified present: `.buttonStyle(.glass)`, `.glass(_ glass: Glass)`,
`GlassProminentButtonStyle`.

**CoreTend built `MCPrimaryButtonStyle` instead**, for a real reason: the
system prominent style paired the tint with a white label at 1.87:1. Whether
`.glassProminent` repeats that or fixes it is **unmeasured**, and it is the
first thing to check — if it reads correctly, a system style that tracks the
user's transparency slider beats a hand-rolled fill that cannot.

### 2.3 New in macOS 27.0 — checked, not reported

| API | Relevance to CoreTend |
|---|---|
| `PickerStyle.tabs` / `TabsPickerStyle` | **Directly replaces** `ModuleSubNav`'s `.segmented`. This is now the idiom for exactly what that component does. |
| `swipeActions(edge:)`, `swipeActionsContainer()` | New on macOS this cycle. Exclude, reveal, trash on a file row without a context menu. The single biggest interaction upgrade available to a file-list app. |
| `reorderable()`, `reorderContainer(for:)` | Favourites and exclusions become drag-ordered. |
| `CrossFadeNavigationTransition`, `ZoomNavigationTransition`, `AnyNavigationTransition` | Module switching stops being an instant cut. |
| `Document` / `ReadableDocument` / `WritableDocument` | Not applicable. |

`visibilityPriority` and `toolbarOverflowMenu` are **macOS 26.1**, not 27 — one
source dated them wrong.

---

## 3. Corrected action list

Superseding `DESIGN_RESEARCH.md` §4.1:

| # | Action | Status vs previous research |
|---|---|---|
| 1 | Sidebar icons keep the accent colour | **Reversed** — was "remove the tint" |
| 2 | Card radius stays at 8 pt | **Reversed** — was "revisit, windows are rounder" |
| 3 | `.icon` via Icon Composer, true squircle, no baked margin | Unchanged, highest value |
| 4 | `reveal` split: sub-300 ms ease-out for user-triggered | Unchanged |
| 5 | `ModuleSubNav` → `.pickerStyle(.tabs)` behind a 27 gate | **New** |
| 6 | Measure `.glassProminent` against the 4.5:1 floor; adopt if it passes | **New** |
| 7 | `swipeActions` on every file row | **New** |
| 8 | Navigation transition between modules | **New** |
| 9 | Do not hand-tune glass opacity — the slider is the user's | **New** |
| 10 | Sidebar row affordance always visible | Unchanged |

Items 1 and 2 are the reason this document exists: acting on the previous one
would have made the app look like last year's while believing it was current.

---

## 4. What does not change

The finding in `DESIGN_RESEARCH.md` §3 is untouched by any of this:

> CoreTend has no visual idea. It has a competent, consistent, well-tested
> implementation of a generic layout.

None of the ten items above fixes that. They are the difference between an app
that looks current and one that looks a year stale — worth doing, and not the
same thing as a design direction. The three directions in `DESIGN_RESEARCH.md`
§4.2 (**the map**, **the ledger**, **the workbench**) still need a decision,
and macOS 27 does not make it for us.

What Golden Gate *does* change about that choice: with sidebars back at the
window edge and toolbars back to being bars, the OS has moved **away** from
floating chrome and back toward structure. Direction **A, the map** — one
canvas, minimal chrome — is more aligned with 2026 macOS than it would have
been under Tahoe.
