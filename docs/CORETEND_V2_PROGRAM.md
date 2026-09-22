# CoreTend 2.0 — the development programme

Written 2026-09-21. This is the plan for taking CoreTend from a pre-alpha
rebuild to a macOS cleaner people choose on purpose, shipped on two channels.

It is built on three things, in this order: **what the code actually is**
(measured, not assumed), **what the field already offers** (researched, with
sources), and **what this product has decided to be** (the direction documents
that already exist). Where those three disagree, the disagreement is written
down rather than resolved quietly.

Two kinds of statement, never mixed — the same rule as
`CORETEND_V2_AUDIT_AND_PLAN.md`: a **FINDING** is observed with its evidence;
a **PROPOSAL** is a decision being asked for.

---

## Part 0 — Where CoreTend actually stands

Measured this session, not recalled.

| | |
|---|---|
| Build | `swift build` and `-c release` — **0 warnings** |
| Tests | **687** across 13 suites, 0 failures |
| Coverage | engines 80–98% (ScanCore 96.7, IntegrityCore 98.6, FileRules 94.6, SystemMetrics 93.1, AppDiscovery 86.6, Persistence 86.1, **SafetyCore 80.4**) |
| Gates | `repository-doctor` 37 checks green; site gate 32/32 |
| Destinations | 8, feature-grouped under `Sources/CoreTendApp/Modules/` |
| Runtime dependencies | **zero** |
| Languages | **2** (en, fr) — 701 keys |
| Published release | `v1.0.1`, Developer ID signed, notarized, stapled, Minisign |
| Distribution channels | DMG/ZIP from GitHub + the product site. **No Homebrew cask.** |
| App Store build | exists (`CORETEND_APP_STORE`), sandboxed, **ships 5 of 8 destinations** |

### F-01 — The App Store build is a cleaner that cannot clean

`AppCapabilities.of(.appStore)` sets `canReachSystemLocations: false`,
`canManageApplications: false`, `canInspectIntegrity: false`. `supports(_:)`
therefore removes **Cleanup, Applications and Integrity** from the sidebar.

What ships on the App Store today: Overview, Record, Performance, Duplicates,
Explore. A disk map, a duplicate finder and an audit log — with no cleanup,
no uninstaller and no integrity report.

This is the single most important strategic fact in this document, and the
engineering is not the problem: the filtering is deliberate, documented and
tested (`DistributionTests` asserts no route reaches a removed module). The
problem is that nobody has decided what the App Store *product* is.

---

## Part 1 — The field, researched

Sources at the end. Figures as of September 2026.

### F-02 — The open-source benchmark is PureMac

[PureMac](https://github.com/momenbasel/PureMac) — **6.6k stars, 364 forks**,
MIT, native SwiftUI. It is the app a person lands on when they search
"open source CleanMyMac alternative", and it is the bar CoreTend is measured
against whether or not it wants to be.

What it has that CoreTend does not:

| | PureMac | CoreTend |
|---|---|---|
| Languages | 10 (en, ar, es, ja, pl, pt-BR, ru, uk, zh-Hans, zh-Hant) | **2** |
| Homebrew cask | yes, with `lsregister` icon refresh | **none** |
| Scheduled auto-clean | yes | no |
| In-app auto-update | requested, tracked (#94) | check-only, no install |
| Xcode / Homebrew / Docker cleanup | yes, named categories | Xcode yes; Homebrew/Docker no |
| A comparison table on the README | yes — it is the marketing | no |
| CLI | yes | read-only inspector only |

What CoreTend has that PureMac does not, and should stop being shy about:

- **An audit trail as a product surface.** PureMac's security section is about
  path validation. CoreTend's Record makes *every* scan, move and refusal a
  first-class readable entry. Nothing else in the field does this.
- **A refusal is a record, not an error.** Same idea, and it is rarer.
- **687 tests with contract tests over the UI**, a capture matrix that refuses
  a mismatched state, and an accessibility audit that walks every module.
- **Honest quantities enforced mechanically.** `SafetyLedgerSummaryTests` fails
  if a "freed" total reappears. PureMac markets "honest about purgeable space";
  CoreTend *tests* it.

### F-03 — What the field's users actually ask for

From PureMac's own acknowledgements and issue list, which is the most honest
demand signal available (these are features contributors built or requested):
search and filter · app uninstaller with system-app protection · onboarding ·
in-app auto-update · per-category size and date filter presets · translations ·
**app icon design**. Plus the security reports: symlink/TOCTOU races,
checkbox interaction bugs.

CoreTend already has: search/filter, uninstaller with protection, onboarding,
and it fixed its own symlink class this session. It lacks: presets,
translations, auto-update install.

### F-04 — The App Store is viable but narrow

Cleaner utilities do ship on the Mac App Store — CleanMyMac has a listing, and
Cleaner One Pro is cited as the sandbox-friendly example offering "basic junk
cleaning and disk analysis". Apple's stated posture is that apps in crowded
categories are rejected unless they offer a *unique, high-quality experience*.

So the App Store question is not "can a cleaner ship" — it is "what does the
sandboxed CoreTend do that is unique". See P-01.

---

## Part 2 — The visual programme

### F-05 — The original reference and the current direction disagree, and both are right about something

The first visual reference (a glossy dashboard: four metric cards, a rainbow
storage bar, a teal gradient "Run Smart Scan", a right rail with Quick Actions
and a Pro Tip, glass cards throughout) is superseded on three points that are
checkable, not matters of taste:

1. Its sidebar is **v1's information architecture** — Storage, My Clutter,
   Cloud Cleanup, Activity, Settings. Those destinations no longer exist.
2. Its storage bar is a **rainbow**, which
   `CORETEND_VNEXT_VISUAL_DIRECTION.md` forbids by name ("tonal steps of teal
   plus graphite/amber neutrals — never a rainbow").
3. Its **glass cards** are the "card soup" v2 deleted.

But it is right about something the current build has not answered: it *feels
like a product*. Depth, richness, a sense that care was taken. The v2
direction chose sobriety and delivered rigour; what it has not yet delivered
is the moment where someone says "this is beautiful".

**That gap is the visual programme.** Not a return to cards — a way to be
majestic *within* the discipline.

### P-V1 — The three moves that make v2 feel majestic without card soup

1. **Material and depth where the system already provides it.** macOS 26's
   Liquid Glass is a system material, not a hand-rolled blur. The direction
   doc already permits material on chrome, popovers and inspectors. The
   sidebar samples the desktop; the toolbar is continuous with the titlebar.
   What is missing is *deliberate* use of it in the inspector rails and the
   scan-in-progress states.
2. **One signature moment per module, earned by data.** Explore's treemap is
   already that. Overview has no equivalent. Performance's dual curves are
   close. The programme: give each module one thing a screenshot would be
   taken of — always a real quantity, never an ornament.
3. **Motion that reports.** The five `MCMotion` tokens are correct and
   measured. What does not exist yet is arrival choreography: a scan
   completing, a treemap settling, a record row landing. Within the existing
   bands, honouring Reduce Motion.

### P-V2 — The brand assets to rebuild

| Asset | State | Programme |
|---|---|---|
| App icon | `.icns` generated by `Scripts/build-app-icon.sh`; the layered `.icon` → `Assets.car` path is **⊘ blocked** (`actool` produces nothing, documented) | Resolve or formally abandon. macOS 26 icons want the layered format for Liquid Glass treatment — this is the one asset where the blocked item has become load-bearing |
| Favicon | passes its gate again, re-anchored on measurement this session | Keep; add the dark-mode variant |
| Wordmark / logo | `Resources/Brand/Generated/` | Review against the macOS 26 icon grid |
| Screenshots | 64-image capture matrix, self-verifying | **Reuse for the App Store listing** — this is an asset nobody else has |
| Marketing video | `VIDEO_PRODUCTION_GUIDE.md` exists, no video | Programme item, after the visual pass |

### P-V3 — References to work from

The direction doc's identity line stands: *sober · precise · premium ·
technical · calm · macOS · contemporary*. The references that serve it are
**Apple's own** — Disk Utility, Console, Time Machine, Activity Monitor — plus
the Mail/Console list-and-inspector idiom the Record already borrows. For the
site: the existing `REFERENCE_SITE_ANALYSIS.md` and the Vercel/Linear register
already recorded there.

**Not** CleanMyMac. Its visual language is the one this product defined itself
against, and matching it would undo the one thing that makes CoreTend legible
as a different kind of tool.

---

## Part 3 — MoSCoW

Against what exists. Every "Must" that is already done says so.

### MUST — ship-blocking for a real v2

| # | Item | State |
|---|---|---|
| M-01 | The safety model: Trash-only, protected roots, append-only log, explicit confirmation | **done** |
| M-02 | Protected-root bypasses fixed on both lines | **done** (`139b6db`, `1fb566e`, `ed7f4db`) |
| M-03 | **Decide whether `maintenance/1.x` ships the security patch** | **open — user** |
| M-04 | **`Store.recordSafetyEvent` stops dropping audit entries silently** | **open — posture decision** |
| M-05 | Hover routing validated by a human | **open — user only** |
| M-06 | The generational-difference verdict | **open — user only** |
| M-07 | Zero runtime dependencies preserved | **done**, and now a README badge |
| M-08 | Every module's states designed and captured | **done** — the no-results states closed today |
| M-09 | Accessibility: named controls, keyboard reach, Reduce Motion honoured | **done**, audited 0 failures |
| M-10 | 0 warnings, green suite, green doctor before any release | **done**, gated |

### SHOULD — the difference between "correct" and "chosen"

| # | Item | Why |
|---|---|---|
| S-01 | **Homebrew cask** | The single highest-leverage distribution gap. PureMac's install story is one command; CoreTend's is a DMG download |
| S-02 | **Languages beyond en/fr** — start with es, de, zh-Hans, ja | 701 keys, parity-tested infrastructure already exists. This is throughput, not design |
| S-03 | **A comparison table on the README** | The field markets this way. CoreTend's differentiators are real and currently invisible |
| S-04 | **Per-category size and date filter presets** | Demanded in the field (F-03), and CoreTend's rules already carry `minimumAgeDays`/`minimumSizeBytes` |
| S-05 | **The visual programme P-V1** | The reason someone chooses it |
| S-06 | **Scheduled scans** (never scheduled *deletion*) | The field expects it. The safety posture says a scan may be unattended; a move may not |
| S-07 | Public **threat model** document | Recommended in the audit; a security-adjacent open-source app without one is unusual |
| S-08 | SafetyCore coverage from 80.4% toward the other engines | It is the lowest and the most critical |

### COULD — real value, not on the critical path

| # | Item |
|---|---|
| C-01 | In-app update **install** (currently check-and-open-browser) |
| C-02 | Homebrew / Docker / npm cache categories |
| C-03 | A richer CLI (currently read-only inspection) |
| C-04 | Quick Look generator for the Record's exports |
| C-05 | Menu-bar quick-scan |
| C-06 | Marketing video |

### WON'T — this release, and the reason

| # | Item | Reason |
|---|---|---|
| W-01 | Any "freed" or "reclaimed" total | Structurally unknowable. Tested against |
| W-02 | A health score, a trend, a simulated figure | Same |
| W-03 | Permanent deletion | Trash-only is the product |
| W-04 | Telemetry, analytics, crash reporting | Zero-network is the promise |
| W-05 | Browser history/cookie deletion | Live-profile DB corruption risk, already recorded |
| W-06 | A privileged helper | Not required by any current feature |
| W-07 | Rewriting git history | Breaks published release provenance |

---

## Part 4 — The App Store track

### P-01 — Decide the sandboxed product before building for it

Three honest options. This needs a decision, not an implementation.

**(a) Ship the narrow build as its own product.** Rename the value
proposition to what it actually is: a disk explorer, duplicate finder and
cleanup *record* — user-selected folders only. Apple's "unique, high-quality
experience" test is met by the Record and the treemap, not by cleaning.
*Cost: low. Risk: a reviewer or a user expects a cleaner.*

**(b) Widen the sandbox with user-selected scopes.** `requiresUserSelectedFolders`
already exists. Cleanup could run on folders the user grants through an open
panel with security-scoped bookmarks. Applications and Integrity cannot follow —
they need locations the sandbox forbids.
*Cost: medium. Gain: the App Store build can clean what the user points at.*

**(c) Do not ship on the App Store.** Direct distribution is where this
product's posture lives — Full Disk Access, an uninstaller, integrity reading.
*Cost: zero. Loss: discoverability.*

**Recommendation: (b), then (a)'s honest naming.** The engineering exists;
the decision does not.

### P-02 — The `.xcodeproj` question, stated plainly

`CLAUDE.md` carries a hard constraint: **"No `.xcodeproj`, ever. The package
is the build system."** An App Store submission wants an archive with the
right Info.plist, entitlements and provisioning, which is conventionally an
Xcode project — and `Tests/UIAutomation/CoreTendUIAutomation.xcodeproj`
already exists, so the constraint is about the *app*, not the repository.

Options: keep SwiftPM and drive `xcodebuild -archive` against a generated
wrapper; or add one `.xcodeproj` scoped to App Store submission only.

**This is a decision for the maintainer.** The constraint is explicit and
this document will not route around it. What is certain: the constraint was
written before an App Store channel was real, and a rule that blocks a
shipped decision is worth re-reading rather than obeying by reflex.

---

## Part 5 — The website

Renewed this session where it was broken; the programme is what is left.

| | |
|---|---|
| **Done** | tokens re-exported (motion, `chartHeight`, `windowMinWidth` were all pre-v2); first-paint contract restored *and* its check made able to match; 40 WCAG contrast violations fixed via `webTextQuiet`; three stale vocabulary tests aligned; favicon anchor re-measured; 45 KB of dead CSS removed. Site gate **32/32** |
| **P-W1** | The site still shows v1 screenshots and v1 vocabulary in places the tests do not cover. Regenerate from the capture matrix |
| **P-W2** | No comparison table, no "why not CleanMyMac" page. The field markets this way |
| **P-W3** | Install story is a DMG. With S-01 it becomes `brew install --cask coretend` |
| **P-W4** | Languages: the site is en/fr like the app. Follows S-02 |

---

## Part 6 — Tooling, tests and scripts

### Already built, and what each is for

`dev.sh` is the door. `graph.sh` keeps the code graph in step. `coverage.sh`
measures per module. `generate-architecture.py` derives the architecture and
gates it. `task-model.py` renders the queue and checks it is well-formed.
`capture-matrix.sh` produces self-verifying evidence. `audit-accessibility.sh`
walks every module. `repository-doctor.sh` runs 37 checks.

### P-T1 — What is still missing

| # | Item | Why |
|---|---|---|
| T-01 | **A release rehearsal script** | `release-preflight.sh` exists and gates; nothing rehearses the whole path on a throwaway tag |
| T-02 | **Mutation testing on SafetyCore** | 80.4% line coverage says lines ran, not that assertions would catch a change. On the safety-critical engine, that distinction matters |
| T-03 | **A localisation throughput script** | S-02 needs adding a language to be mechanical, not a project |
| T-04 | **Performance regression gate** | `CoreTendPerformanceTests` has one test. Scans over a large home are the product's felt quality |
| T-05 | **A public threat model** (S-07) | |

### P-T2 — Skills and capabilities to have loaded

No new language and no new dependency. What the work needs is knowledge, not
packages: Apple's HIG and the macOS 26 material/icon guidance for P-V1 and
P-V2; Swift Testing and Swift concurrency references for T-02; App Store
review guidance for Part 4. All of these are already available as skills in
this environment — the programme should name them at the point of use rather
than install anything.

---

## Part 7 — Sequencing

Ordered so that each stage makes the next one verifiable.

**Stage 1 — close what is open (decisions).** M-03, M-04, P-01, P-02. None of
these is engineering; all four block engineering.

**Stage 2 — make the product choosable.** S-01 (cask), S-03 (comparison
table), S-02 first wave (es, de), P-W1. This is the stage that changes whether
anyone finds CoreTend.

**Stage 3 — the visual pass.** P-V1's three moves, P-V2's icon question,
module by module in the existing queue order, against the existing bar: a
generational difference visible without a changelog.

**Stage 4 — depth.** S-04, S-06, S-08, T-02, T-04.

**Stage 5 — the App Store**, once P-01 has an answer.

**Stage 6 — release.** Only ever with the maintainer's explicit authorisation.

---

## What this programme does not claim

It does not claim to know what the user will judge beautiful — P-V1 is a
direction, and the bar stays "a generational difference visible without a
changelog", which only a person renders. It does not claim the App Store will
accept anything. And it does not claim the field research is exhaustive: it is
one benchmark competitor read in depth and a survey of the category, which is
enough to plan against and not enough to be certain about.

## Sources

- [PureMac — GitHub](https://github.com/momenbasel/PureMac)
- [Open Source CleanMyMac Alternatives — AlternativeTo](https://alternativeto.net/software/cleanmymac/?license=opensource&platform=mac)
- [Best Mac Cleaner Software 2026 — Macworld](https://www.macworld.com/article/673271/best-mac-cleaner-tested-compared.html)
- [Are Mac Cleaner Apps Safe? — Cindori](https://cindori.com/reviews/are-mac-cleaner-apps-safe)
- [App Store Review Guidelines overview — AppFollow](https://appfollow.io/blog/app-store-review-guidelines)
- [CleanMyMac on the Mac App Store](https://apps.apple.com/us/app/cleanmymac/id1339170533?mt=12)
