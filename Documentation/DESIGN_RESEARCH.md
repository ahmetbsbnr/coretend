# Design research — what current, and what CoreTend gets wrong

Date: 2026-09-18 · **Partly superseded — see `DESIGN_RESEARCH_MACOS27.md`**

> This document was researched against macOS Tahoe 26 guidance. This machine
> runs macOS 27 Golden Gate, which **reverses §1.1 (sidebar icon tinting) and
> §1.3 (window corner radius)**. §1.5 (the app icon) and §2 (motion) stand.
> §3 — that the app has no visual idea — is unaffected by any OS release.
> Read `DESIGN_RESEARCH_MACOS27.md` before acting on anything here.

Status: research complete, direction not yet chosen

Written because the previous pass systematized the existing design instead of
reimagining it. This is the research that should have come first.

Every finding below is sourced and, where it applies to CoreTend, checked
against the code rather than recalled.

---

## 1. macOS Tahoe 26 — what actually changed

Sources: [Apple, Liquid Glass announcement](https://www.apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/) ·
[MacStories, macOS Tahoe review](https://www.macstories.net/stories/macos-26-tahoe-the-macstories-review/2/) ·
[WWDC25 — Build a SwiftUI app with the new design](https://developer.apple.com/videos/play/wwdc2025/323/) ·
[Icon Composer](https://www.developer.apple.com/icon-composer/)

### 1.1 Sidebar icons must not be accent-tinted

> "Since the translucent glass sidebar now visually floats over the main
> content, any tinted icons would clash with the sidebar's colorful background,
> which is why accent color icons should be avoided. Instead, in macOS Tahoe,
> the default tint for icons in the sidebar is now black in light mode and
> white in dark mode."

**CoreTend does the opposite.** `Sidebar.swift` paints the selected row's icon
`MCColor.teal`. That was an improvement over the previous state — a teal glyph
sitting inside the *system* accent's pill — but it is now a second wrong
answer, arrived at without checking the current guidance. This was decided in
this session, three days after adopting Liquid Glass on the same surface.

### 1.2 Transparency: follow Finder and Safari, not Music and Photos

The review's criticism is specific: Music and Photos use transparency heavy
enough that "controls in Photos often get lost in your sea of images", while
Finder and Safari keep controls moderately opaque. Maps and Reminders succeed
by *reducing* transparency on overlay controls.

**CoreTend applies `.glassEffect(.regular)` to the sidebar and the sub-nav
bar.** The direction is right — those are navigation-layer surfaces — but the
material was chosen without a legibility check against the busiest screen the
app has (the Space Lens treemap). Untested.

### 1.3 Windows are rounder

Concrete and cheap. CoreTend inherits the system window shape and does nothing
here, which is correct; but `MCRadius.card = 8` was chosen against the previous
OS. A card radius that reads as sharp inside a much rounder window looks dated
in a way nobody can name.

### 1.4 Control groupings are always visible, not hover-only

Tahoe shows button groupings permanently rather than on hover. CoreTend's
sidebar reveals a row background only on hover — the current convention is that
the affordance is always there.

### 1.5 The app icon is the wrong shape, and the wrong format

Two separate problems, both measured:

**Shape.** `generate-brand-assets.swift:246` draws
`CGPath(roundedRect:cornerWidth:cornerHeight:)`. That is a **circular-arc**
rounded rectangle. Apple's icon shape is a **continuous-curvature squircle**.
At the icon's effective radius of 185 px on a 1024 px canvas, the two curves
diverge by roughly **43 px** at the 45° point. That is not subtle.

**Format.** macOS 26 uses a layered `.icon` produced by Icon Composer, which
compiles to an `Assets.car` plus a backwards-compatible `.icns`. CoreTend ships
only a hand-built `.icns`, and the review is blunt about the consequence:
third-party apps not updated are "shrunken to fit against the backdrop of a
gray squircle" — the **icon shame box**.

Icon Composer is present at
`/Applications/Xcode.app/Contents/Applications/Icon Composer.app`, so this is
available, not aspirational.

**Also:** the generator bakes in its own 9.8% margin and its own corner. On
macOS 26 the system supplies the shape and the mask; an icon that draws its own
is masked twice and reads as inset.

---

## 2. Motion — the numbers

Sources: [Emil Kowalski, animation principles](https://emilkowal.ski/ui/great-animations) ·
[Rauno Freiberg, craft](https://rauno.me/craft)

The rules that are actually numeric:

- **Ease-out is the default for anything the user triggered.** Ease-in reads as
  sluggish because the motion starts slowly *after* the click.
- **Under 300 ms.** "180 ms feels more responsive than 400 ms" — perceived
  performance, not raw duration.
- **Transform and opacity only.** Anything animating layout thrashes.
- **Interruptible.** An animation the user cannot cut through is a wait.

**CoreTend's tokens, checked against this:**

| Token | Value | Verdict |
|---|---|---|
| `response` | `easeOut` 150 ms | Correct |
| `transition` | `smooth` 250 ms | Correct |
| `reveal` | `smooth` 400 ms | **Over 300 ms.** Defensible for content arriving unprompted; wrong for anything the user triggered, and it is used for both. |
| `settle` | spring 0.45 / 0.85 | Fine |

The four tokens are named by intent, which is right. But `reveal` at 400 ms is
applied to results appearing after a user pressed Scan — a user-triggered
transition wearing an ambient duration.

---

## 3. The category — what the competition actually does

Sources: [TheSweetBits comparison](https://thesweetbits.com/daisydisk-vs-cleanmymac/) ·
[MacPaw's own comparison](https://macpaw.com/cleanmymac/cleanmymac-vs-daisydisk)

Two poles, and CoreTend currently sits between them without committing:

**DaisyDisk** — one idea, executed completely. A sunburst chart, drag-to-collect,
almost no chrome. Its identity *is* the visualization. You could recognise a
screenshot with the name cropped out.

**CleanMyMac** — a "control station". Many modules, a guided flow, heavy
illustration, a strong marketing voice. Its identity is the experience of being
walked through something.

**CoreTend today** is a sidebar with eleven modules, a hero card and a grid of
feature cards. That is the shape of a settings window, not a product. Crop the
name out and it is not recognisable as anything.

This is the most important finding in this document, and it is not a defect
anyone can file: **the app has no visual idea.** It has a competent, consistent,
well-tested implementation of a generic layout.

---

## 4. What is possible

### 4.1 Cheap and unambiguous — do regardless of direction

1. Sidebar icons follow the system convention, not the brand accent (§1.1).
2. `.icon` via Icon Composer, with the squircle shape and no baked-in margin
   (§1.5). Escapes the shame box.
3. `reveal` split: an ambient duration for unprompted content, a sub-300 ms
   ease-out for anything the user triggered (§2).
4. Card radius revisited against the rounder window (§1.3).
5. Sidebar row affordance always visible (§1.4).
6. Glass legibility checked against the treemap, and reduced if it fails (§1.2).

### 4.2 The real decision — what CoreTend's one idea is

Three directions. Each is a different answer to "what do you see when you open
it", and each implies different structure, not just different paint.

**A. The map.** Space Lens becomes the app, not a module. You open CoreTend and
see your disk. Everything else — duplicates, large files, caches — is a *lens*
over that same map rather than a separate screen. Eleven sidebar rows collapse
to one canvas plus a filter bar.
*Closest to DaisyDisk's discipline. Highest risk, highest recognisability.*

**B. The ledger.** The product is the record of what changed and what is safe.
The Safety Log stops being a hidden screen and becomes the spine: every scan,
every approval, every refusal, reversible and legible. Cleanup becomes an
append-only history you can read backwards.
*Nobody in this category does this. It is the one that fits a product whose
strongest engineering is its safety model.*

**C. The workbench.** Keep the modules, but replace the sidebar with a
document-like window: one task at a time, full-bleed, with the module list as a
switcher rather than a permanent column. More room for the data, far less
chrome.
*Lowest risk. Modernises without repositioning.*

### 4.3 The site

Untouched by the previous pass beyond rewiring its variables. It is a
long-scroll marketing page with an embedded interactive demo. Whatever
direction the app takes, the site's job is to show that one idea in the first
screenful — which it currently does not, because there is no one idea to show.

---

## 5. Recommendation

**B, the ledger.** Not because it is safest, but because it is the only one of
the three that is *true* of this codebase: 26 `PathValidator` tests covering
symlink-swap-after-approval, an append-only audit trail, execution-time
re-validation, refusals that carry their reasons. That work already exists and
is invisible in the current design.

A and C are both defensible. This is a taste decision and it is yours.

**Next step, once chosen:** three static HTML mockups of the same screen in the
chosen direction, side by side, before any Swift changes.
