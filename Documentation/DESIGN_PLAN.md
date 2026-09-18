# CoreTend — design follow-through plan

Date: 2026-09-18 · Supersedes the action lists in `DESIGN_RESEARCH.md` and
`DESIGN_RESEARCH_MACOS27.md`

Research is complete: macOS 27 Golden Gate reviews, the current HIG read
directly (its JavaScript rendering defeats plain fetching, so the pages were
read in a browser), and every API claim checked against `MacOSX27.0.sdk` on
this machine rather than taken from a report.

This is the plan. It separates what is decided from what needs your taste, and
it is honest about three places where the HIG and your instructions disagree.

---

## 0. Where Apple and your instructions conflict

These are not mistakes to fix. They are deliberate product decisions that
depart from the platform, and they should be departed from *knowingly*.

### 0.1 The sidebar accent — HIG says the opposite of what we built

Sidebars, HIG, **updated 8 June 2026**:

> "By default, sidebar icons use your app's accent color. In macOS, people can
> change the system accent color, which applies to all apps. **When they do
> this, they expect all sidebar icons to appear in that color**, so make sure
> your sidebar icons display the color people choose."

The green selection you objected to was the system working as designed, and
the platform-native fix would have been to make the *icon* follow the accent
too — not to take the accent away. We took it away.

**Consequence if unchanged:** on a Mac with a pink or red accent, every app
except CoreTend honours it. That reads as an app that ignores the user, and it
is the kind of thing raised in App Store review.

**Recommendation:** honour the system accent for the sidebar *selection*, keep
teal everywhere the app genuinely owns the pixels. HIG explicitly allows fixed
colours "if you use them sparingly… to clarify the meaning of an icon or draw
attention to it".
**Your call.** You said the app owns its colours; I am not overriding that
silently.

### 0.2 Light appearance

`AppAppearance` pins darkAqua. HIG assumes an app follows the system. The cost
is recorded in that file and is real for users who run Light for visual
comfort. Standing decision, yours, noted.

### 0.3 The custom sidebar lost a system behaviour

HIG, macOS:

> "A sidebar's row height, text, and glyph size depend on its overall size…
> people can also change it by selecting a different sidebar icon size in
> General settings."

Replacing `List` with a hand-built sidebar lost that. CoreTend's rows are fixed
at 13 pt text and a 14 pt glyph and do not respond to that setting. This is a
regression I introduced and did not notice, and it is an accessibility one:
someone who enlarged their sidebar icons system-wide gets no change here.

**Not optional.** Fix regardless of direction (item 1.7).

---

## 1. Phase 1 — complete

All thirteen items attempted. **Nine shipped, three rejected on measurement,
one blocked.** The rejections are the useful part: each was recommended by
Apple's own guidance and each failed when measured in place.

| # | Item | Outcome |
|---|---|---|
| 1.1 | App icon through Icon Composer | **Shipped** — rendered by `ictool`; true squircle; system effects |
| 1.2 | Layered icon (`Assets.car`) | **Blocked** — see below |
| 1.3 | `ModuleSubNav` → `.pickerStyle(.tabs)` | **Shipped**, gated on macOS 27 |
| 1.4 | `swipeActions` on file rows | **Shipped**, with a context menu beside it |
| 1.5 | `.glassProminent` for buttons | **Rejected** — 11.13:1 in isolation, 2.61:1 in place |
| 1.6 | `backgroundExtensionEffect()` | **Rejected** — 0 of 45,085 pixels changed |
| 1.7 | Sidebar follows the system row size | **Shipped** — an accessibility regression I had introduced |
| 1.8 | Settings out of the sidebar's bottom | **Shipped** — it is a `Settings` scene now |
| 1.9 | `reveal` under the 300 ms threshold | **Shipped**, plus `ambient` for the one decorative case |
| 1.10 | Every command in the menu bar | **Shipped** — Go and Scan menus |
| 1.11 | Navigation transition between modules | **Rejected** — see below |
| 1.12 | `reorderable()` on favourites | **Shipped**, after reversing a schema migration |
| 1.13 | Sidebar customisation | **Shipped** |

### Why 1.11 was rejected

`CrossFadeNavigationTransition` and `ZoomNavigationTransition` are both
`@available(macOS, unavailable)`. Only `.automatic` — the default — exists on
macOS. Apple made these explicitly unavailable on the Mac, and a hand-rolled
cross-fade would be inventing a transition the platform has decided against.

### Why 1.2 is blocked

`actool` produces no `Assets.car`, no warning and no error from a hand-authored
`.icon` placed in an asset catalog, at either deployment target tried. It
appears to compile layered icons only as part of a full Xcode project build.

The shipped `.icns` is already rendered by `ictool` from that same document, so
it has the correct squircle and the system's own effects at every size. What is
missing is runtime per-appearance re-rendering — dark, clear and tinted
variants. Reaching it means either an Xcode project or a route that is not yet
identified.

### Excluded before starting, with reasons

- **Card radius**: stays at 8 pt. Golden Gate made windows *less* round.
- **Glass opacity**: not hand-tuned. macOS 27 gives users a transparency
  slider and `glassEffect` tracks it.
- **Sidebar icon tint**: blocked on §0.1, which is yours to decide.

## 2. Undecided — the visual direction

None of §1 changes the finding that matters:

> CoreTend has no visual idea. It has a competent, consistent, well-tested
> implementation of a generic layout. Crop the name out of a screenshot and it
> is not recognisable as anything.

Three directions, unchanged from `DESIGN_RESEARCH.md` §4.2, now with what
Golden Gate does to each:

**A — The map.** Space Lens becomes the app. Duplicates, large files and caches
become *lenses* over one canvas rather than separate screens. Eleven sidebar
rows collapse to one surface plus a filter bar.
*Golden Gate helps this most:* sidebars returned to the window edge and
toolbars returned to being bars, so the OS moved away from floating chrome and
back toward structure. And `backgroundExtensionEffect` exists precisely for
content that runs under the chrome.

**B — The ledger.** The product is the record of what changed and what is safe.
The Safety Log stops being a hidden screen and becomes the spine.
*The only one that is true of this codebase* — 26 `PathValidator` tests,
symlink-swap-after-approval, execution-time re-validation, refusals that carry
their reasons. That work exists and is invisible.

**C — The workbench.** Keep the modules; replace the permanent sidebar with a
switcher. One task at a time, full-bleed.
*Lowest risk, smallest gain.*

**My recommendation is still B**, and A is now a closer second than it was
before the Golden Gate research.

---

## 3. Sequence

**Phase 1 — platform currency (no direction needed).** §1.2 through §1.12.
Each lands as its own commit with tests and a verified capture, the way the
previous eighteen did. Outcome: an app that looks current on macOS 27 rather
than a year stale. This does not make it distinctive.

**Phase 2 — direction.** Three static HTML mockups of the *same screen* in the
chosen direction, side by side, before any Swift. You compare and choose. No
Swift changes until you have.

**Phase 3 — build it.** The chosen direction, module by module, against the
existing test suite. The engines do not change.

**Phase 4 — the words.** All 560 strings reviewed as copy, not as keys. Never
done; not started.

**Phase 5 — the site.** Rebuilt to show the one idea in the first screenful.
Currently it cannot, because there is no one idea to show.

**Phase 6 — the two products.** App Store submission needs a signed Installer
package and a different release pipeline; `sign-and-notarize.sh` knows one
entitlements file and one flow.

---

## 4. What I will not do without you

- Choose the direction (§2).
- Resolve the sidebar accent conflict (§0.1).
- Reverse the dark-only decision (§0.2).

Everything else in §1 and §3 Phase 1 I can carry alone, and will, on your word.
