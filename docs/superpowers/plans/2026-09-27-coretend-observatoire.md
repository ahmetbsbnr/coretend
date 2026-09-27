# CoreTend Observatoire Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild CoreTend macOS and bilingual public website front ends in approved Observatoire visual direction while preserving all domain, access, and safety behavior.

**Architecture:** Keep SwiftUI native app views as owners of interaction and state; centralize semantic appearance, type and motion roles in `DesignSystem`. Keep the generated static website pipeline, export matching semantic color tokens from the Swift palette, and rebuild all current English and French pages from the existing Python generator. Use existing data flows; design states must never invent scan results.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Foundation, Python 3, static HTML, CSS, progressive CSS motion.

**Spec:** `docs/superpowers/specs/2026-09-27-coretend-observatoire-redesign-design.md`

## Global Constraints

- Default visual direction is deep slate with ivory text and mineral cyan for actions/data; copper signals caution; coral signals error and destructive action.
- App supports macOS system, light and dark appearances; default follows macOS appearance. The selected Observatory reference uses slate/dark appearance.
- Navigation groups: “Votre Mac” (Overview, Explore, Cleanup, Duplicates) and “Understand” (Applications, Integrity, Performance, History); Settings stays at sidebar bottom.
- Scans remain read-only. File changes require explicit selection, review, confirmation and macOS Trash.
- Keep current domain, persistence, CLI, access scope, exclusions and release contracts unchanged.
- Keep website pages readable without JavaScript; honor keyboard focus, reduced motion, semantic HTML and WCAG contrast targets in spec.
- Work stays in existing linked worktree `/Users/ahmetbasbunar/Developer/Website/products/coretend/next` on branch `feat/reconstruction-open-musts`; preserve all pre-existing modifications and untracked files.
- Do not add or run automated tests unless user explicitly asks.
- Use one scoped implementer, followed by one scoped reviewer, per task; never run implementation tasks concurrently.

---

## File Map

| Files | Responsibility |
|---|---|
| `Sources/DesignSystem/Palette.swift`, `Motion.swift`, new `Typography.swift` | Semantic adaptive app roles and repeatable type/motion choices. |
| `Sources/AppShell/CoreTendPreferences.swift`, `Destination.swift` | Persisted app appearance and destination grouping/copy. |
| `Sources/CoreTendApp/CoreTendApp.swift`, `SettingsView.swift`, `CommandPaletteView.swift`, `MenuBarMetricsView.swift` | Native shell, primary navigation, settings, command palette and menu-bar appearance. |
| `Sources/CoreTendApp/SavedFilesView.swift`, `SystemSnapshotView.swift`, `RecordView.swift` | Overview, performance measures and activity history surfaces. |
| `Sources/CoreTendApp/ExploreScanView.swift`, `CleanupView.swift`, `DuplicateScanView.swift` | File review/search/map and guarded move flows. |
| `Sources/CoreTendApp/ApplicationsView.swift`, `IntegrityView.swift` | App inventory and local signature/integrity signals. |
| `Scripts/export_design_tokens.py`, generated `Website/design-tokens.css` | Export the canonical Swift palette as light/dark CSS variables. |
| `Scripts/build_site.py`, `Website/index.html`, `Website/site.css`, new `Website/site.js` | Bilingual page generation, visual system, navigation and progressive product-scene motion. |
| `Website/en/*.html`, `Website/fr/*.html` | Generated complete public site pages. |
| `Website/assets/` | Verified actual app captures used by the public site; no generated fake product captures. |
| `design-preview/` | Separate comparison prototype, never copied to the product website or app. |

## Tasks

### Task 1: Establish adaptive Observatoire design tokens

**Files:**
- Modify `Sources/DesignSystem/Palette.swift`
- Modify `Sources/DesignSystem/Motion.swift`
- Create `Sources/DesignSystem/Typography.swift`

**Interfaces:**
- Keep existing `Palette.canvas`, `ink`, `secondaryInk`, `accent`, `onAccent`, `caution`, and `danger` public names so current views continue to compile.
- Add semantic `surface`, `raisedSurface`, `separator`, and `focus` roles, each with light/dark values and the same `PaletteRole.color` interface.
- Keep `MotionToken.quick`, `.standard`, `.gentle` and `View.motion(_:value:)`; use direct feedback and content-change timings within 300 ms.
- Expose `CoreTendTypography.pageTitle`, `.sectionTitle`, `.body`, `.secondary` and `.measurement` as Dynamic Type-friendly app text styles.

- [ ] Map contrast pairs for every role in light and dark appearance; set mineral cyan as the action accent, copper as caution and coral as danger.
- [ ] Implement semantic surface/separator/focus roles while preserving existing role call sites.
- [ ] Update motion token timing and ensure `withMotion` still returns immediate state change when Reduce Motion is enabled.
- [ ] Add typography styles using San Francisco system fonts and Dynamic Type-friendly text styles.
- [ ] Review the prototype tokens beside the native palette; keep dark appearance matching selected screenshot.

### Task 2: Rebuild app shell, navigation and appearance settings

**Files:**
- Modify `Sources/AppShell/Destination.swift`
- Modify `Sources/AppShell/CoreTendPreferences.swift`
- Modify `Sources/CoreTendApp/CoreTendApp.swift`
- Modify `Sources/CoreTendApp/SettingsView.swift`
- Modify `Sources/CoreTendApp/CommandPaletteView.swift`
- Modify `Sources/CoreTendApp/MenuBarMetricsView.swift`

**Interfaces:**
- Add `Destination.sectionTitleKey` and preserve existing `Destination.allCases`, `route`, `titleKey`, `symbol`, raw values and persistence compatibility.
- Add validated appearance preference `system | light | dark` and save/load functions to `CoreTendPreferences`; fixture appearance continues to override host state only in declared fixture mode.
- Shell consumes destination groups and preference, while the view body signatures already used by destinations stay intact.

- [ ] Group sidebar destinations into two labeled native sections, preserve last destination restoration, and add visible selected-row treatment.
- [ ] Use native `NavigationSplitView` adaptive collapse behavior at compact window widths without losing the selected route.
- [ ] Keep Settings at sidebar bottom with system-native command/menu access and maintain ⌘K routing.
- [ ] Add appearance picker (System, Light, Dark); persist it without reading/changing appearance in fixture mode.
- [ ] Restyle command palette, settings sheet, onboarding and menu-bar extra using shared semantic tokens and readable loading/error/help states.
- [ ] Use `CoreTendTypography` and `MotionToken`; respect Reduce Motion at view transitions.

### Task 3: Redesign overview, performance and history surfaces

**Files:**
- Modify `Sources/CoreTendApp/SavedFilesView.swift`
- Modify `Sources/CoreTendApp/SystemSnapshotView.swift`
- Modify `Sources/CoreTendApp/RecordView.swift`

**Interfaces:**
- Keep current model and persistence APIs and current view initializers unchanged.
- New layout consumes only data already provided by these views; no derived “health” score or fake system measurement.

- [ ] Recompose Overview as measured system summary, recent activity, measured-storage visualization when actual scan data exists, and clear next actions.
- [ ] Give every system measurement its source and measured timestamp; distinguish unavailable from zero.
- [ ] Restyle activity with searchable/filterable chronology and visible export/clear controls; preserve existing confirmation and private-data notices.
- [ ] Add clear empty, first-run, loading, partial, denied, unavailable and failure presentations only where backed by existing state.
- [ ] Keep charts and diagrams legible without color-only meaning and allow labels to grow under Dynamic Type.

### Task 4: Redesign folder, cleanup and duplicate review flows

**Files:**
- Modify `Sources/CoreTendApp/ExploreScanView.swift`
- Modify `Sources/CoreTendApp/CleanupView.swift`
- Modify `Sources/CoreTendApp/DuplicateScanView.swift`

**Interfaces:**
- Keep scanner, exclusion, Quick Look, Trash, cancellation, revalidation, result and event APIs unchanged.
- Compose presentation around existing view state; no new filesystem access or automatic selection.

- [ ] Build Explorer around selected volume/folder, search/sort, size-proportional space map and a clear file detail/review region.
- [ ] Visually distinguish measured values, unknown values, exclusions, partial scans, stale previews and permission failures.
- [ ] Present cleanup rules as explicit choices with risk label plus text, exact-folder check and zero preselection.
- [ ] Present exact-duplicate groups with conservative suggestion, per-item selection and comparison context.
- [ ] Preserve explicit review and confirmation before any move; keep errors, partial results, cancellation and success distinct.
- [ ] Keep keyboard selection/preview and focus behavior apparent; ensure action targets remain at least 44 pt.

### Task 5: Redesign inventory and integrity views

**Files:**
- Modify `Sources/CoreTendApp/ApplicationsView.swift`
- Modify `Sources/CoreTendApp/IntegrityView.swift`

**Interfaces:**
- Preserve current metadata inspection, signature, quarantine, launch-agent and single-bundle move APIs.
- Continue placing safety limits next to the particular signal they qualify.

- [ ] Make chosen-folder inventory searchable and scannable with stable app identity, version/metadata and explicit limitations.
- [ ] Group signature, quarantine and configured login item evidence into separate signal sections; never combine signals into safe/malicious status.
- [ ] Design unavailable, malformed, partial and no-candidate states with specific next steps.
- [ ] Keep app-bundle review and Trash confirmation isolated from associated-data claims.

### Task 6: Share palette with static website and rebuild bilingual pages

**Files:**
- Create `Scripts/export_design_tokens.py`
- Create generated `Website/design-tokens.css`
- Modify `Scripts/build_site.py`
- Modify `Website/index.html` and `Website/site.css`
- Create `Website/site.js`
- Regenerate `Website/en/*.html` and `Website/fr/*.html`

**Interfaces:**
- Keep the static site build driven by Python and preserve every current route: index, features, privacy, developer and support in English/French.
- Generated CSS role names mirror the Swift semantic palette; only the exporter writes canonical color values.
- `site.js` is progressive enhancement only; page copy and main navigation work without it and site CSP permits only same-origin scripts (`script-src 'self'`).

- [ ] Export named light/dark semantic tokens from `Palette.swift` to deterministic `Website/design-tokens.css`; no duplicated hand-maintained palette in pages.
- [ ] Rework Python page templates with a stable header/language picker/download action, page-specific main content, footer, canonical metadata and skip link.
- [ ] Rebuild Home, Features, Privacy, Developer and Support in both languages, preserving honest product/release status and existing safety descriptions.
- [ ] Create responsive dark/slate content scenes with actual app captures, precise section rhythm and a product showcase; use cyan for action and copper only for caution.
- [ ] Add one progressive scroll-driven product scene with CSS animation timelines and a nonanimated fallback; preserve all text and images without script support.
- [ ] Add mobile navigation interaction only if needed; keep it keyboard accessible and reflect open/closed state.
- [ ] Keep CSP self-hosted and add alt text, image dimensions, reduced-motion rules, visible focus, mobile wrapping and print/readability fallback.

### Task 7: Capture actual product screens and close design gaps

**Files:**
- Create privacy-reviewed, version-labeled images in `Website/assets/`
- Modify relevant image references in `Scripts/build_site.py` and site pages.
- Keep `design-preview/` outside generated website output.

**Interfaces:**
- Captures show the app build being delivered, use a synthetic non-private fixture, and include exact app/version provenance and alt descriptions.

- [ ] Build and open exactly one app instance with isolated fixture data; close older CoreTend builds before launching, and close this instance before any different build.
- [ ] Capture Overview, Explorer map/review, Cleanup rules, Duplicate review, Applications, Integrity, Performance and History at usable window size.
- [ ] Review each capture for private paths, inaccurate state, clipped labels and contrast; document version and provenance.
- [ ] Replace prototype-drawn device UI with verified captures in public pages; retain CSS-drawn details only for diagrams that explain interaction.

### Task 8: Final visual/manual acceptance and handoff

**Files:**
- Modify only presentation files identified in Tasks 1–7 if a defect is found.
- Update `Documentation/Project/` design/usage record and `passation.md` with completed surfaces and any blocked release work.

**Interfaces:**
- Final app and site continue to use their existing data, domain, filesystem and build interfaces.

- [ ] Open the local app once; step through all eight destinations, Settings, ⌘K and menu-bar extra using fixture data.
- [ ] Check light, dark and system appearance, narrow/wide windows, keyboard-only navigation, VoiceOver labels and Reduce Motion.
- [ ] Open locally generated French and English pages at desktop and mobile widths; check navigation, language switch, page links, hero/product scene and no-script content.
- [ ] Confirm no prototype files are copied into the generated public site or package and no fake sample metrics appear in app UI.
- [ ] Record verified scope and remaining non-visual release work in `passation.md` without discarding existing content.

## Plan self-review

- **Spec coverage:** tokens/motion/type Task 1; shell and settings Task 2; all eight app areas Tasks 3–5; all ten locale pages Task 6; true screenshots Task 7; responsive, accessibility and handoff Task 8.
- **Placeholder scan:** no `TODO`, `TBD`, lorem copy or undefined implementation target. Every referenced destination, file, color role and tool exists or is explicitly created above.
- **Type/interface consistency:** existing destination raw values and initializer APIs are preserved; added section role and appearance preference are declared in the owning files before shell consumption; website exporter output path is fixed as `Website/design-tokens.css`.
- **Isolation:** current checkout is already a linked Git worktree. Existing modified and untracked user files stay untouched unless named by an approved task.
- **Execution mode:** sequential task-scoped implementation and review. Automated tests are excluded pending an explicit test/verification request.
