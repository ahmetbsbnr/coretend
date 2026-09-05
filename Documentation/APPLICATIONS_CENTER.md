# Applications Center 2.0

A read-only inspection layer answering, per installed app: how much storage
does it really use, where is its associated data, how confident is CoreTend
in that association, how was it installed, how does it update, who signed
it, what architecture is it, does it have launch items, and is it currently
running. See `Documentation/FEATURE_MATRIX.md` → "Applications Center 2.0"
for the sub-capability status table and `Documentation/SAFETY_MODEL.md` →
"Applications Center" for why none of this becomes a new destructive surface
or a new Recovery Plan input.

## Architecture

`ApplicationInspection` (`Sources/CoreTendApp/ApplicationInspection.swift`) is
a composition of narrow sub-models, not one growing struct — each piece
(storage, associated items, provenance, signature, architecture, launch
items, runtime state) is computed and tested independently, and a failure in
one never blocks the others:

```
InstalledApp (AppDiscovery, pre-existing)
   → ApplicationInspectionService
       ├── ApplicationStorageBreakdown   (AssociatedItem sums, by kind)
       ├── [AssociatedItemAssociation]   (confidence + shared flag)
       ├── InstallationSource / UpdateMechanism (AppDiscovery)
       ├── CodeSignInfo?                 (IntegrityCore.CodeSignInspector)
       ├── ApplicationArchitectureDetail (existing detection + slice sizes)
       ├── [LaunchItemAssociation]       (IntegrityCore.LoginItem + confidence)
       └── ApplicationRuntimeState       (NSWorkspace, no subprocess)
```

Nothing new here calls a subprocess. `CodeSignInspector`/`ProvenanceScanner`/
`LoginItemScanner` (`IntegrityCore`) and `AppDiscovery`'s existing
architecture/update-mechanism detection are reused, not reimplemented.

## Installation source vs. update mechanism

These are two different questions, deliberately modeled as two separate
types (`InstallationSource`, `UpdateMechanism`) computed from the same
underlying signals rather than one being derived from the other:

| Signal | Installation source | Update mechanism |
|---|---|---|
| Mac App Store receipt | App Store | App Store |
| Homebrew Cask metadata | Homebrew Cask | Homebrew Cask |
| `kMDItemWhereFroms` (download origin) | Downloaded | — (says nothing about updates) |
| Sparkle framework/feed | — (says nothing about how it arrived) | Sparkle |
| none of the above | Unknown | No known automatic mechanism |

An app downloaded directly and updated via Sparkle correctly reports
**Installed via: Direct download** and **Updates via: Sparkle** — never
"Installed via Sparkle", which the product brief explicitly calls out as
wrong (Sparkle answers only the update question).

## Associated item confidence

Every associated item carries a confidence (reusing `AdvisorConfidence`
as-is — no new taxonomy) and the method that produced it:

- **Exact** — the item's directory/plist name is an exact match of the app's
  own bundle identifier (`AppDiscovery.associatedItems(for:)`, unchanged from
  before this phase).
- **Probable** — a Group Container matched only by vendor-prefix heuristic
  (see below). Never `.exact`: CoreTend does not read the app's
  `com.apple.security.application-groups` entitlement, so this is a real
  signal, not a verified identity.

A launch item is associated with an app only via a genuinely reliable
signal — its program path resolving inside the app's own bundle (`.exact`),
or its Label exactly matching (or being prefixed by) the app's bundle
identifier (`.high`, Apple's own helper/agent Label convention). A launch
item that merely *resembles* the app by name is not surfaced at any
confidence level at all — omitted, not shown with a misleadingly low one.

## Group Containers — heuristic, never exclusive ownership

`AppDiscovery.groupContainerCandidates` matches a `Library/Group Containers`
folder to installed apps by vendor prefix (the bundle identifier's first two
dot-components, with a leading `group.` stripped first) — the only signal
available without parsing an app's actual entitlements, which this pass does
not attempt. Every match carries `sharingAppCount`: how many installed apps
share that same vendor prefix. When `> 1`, the item is flagged `isShared` and
is:

- **never preselected** for anything (the existing preselection rule already
  only auto-selects `.caches`/`.savedState`, and Group Containers are outside
  that rule entirely — see below),
- **never selectable for uninstall at all in this pass** — Group Container
  candidates render in the Applications detail's Associated Data list purely
  for visibility (confidence + "Shared" badge when applicable), with no
  Toggle. The existing, tested uninstall path (`ApplicationsViewModel
  .uninstall()`) is completely unchanged and still only ever sees
  exact-bundle-id items — Group Containers cannot reach `SafetyCenter`
  through any path added in this pass.

## Storage: "Known associated storage", never "Total"

`ApplicationStorageBreakdown.knownAssociatedStorageBytes` sums only the fixed
set of locations `AppDiscovery.associatedItems` actually looks in
(Application Support, Caches, Preferences, Logs, Saved Application State,
Containers, Launch Agents/Daemons, plus the new Group Containers). CoreTend
never claims this is exhaustive — an app could leave data anywhere else on
disk, and this feature does not attempt to discover every possible location.
The UI label is "Known associated storage", not "Total", specifically to
avoid implying completeness the product cannot verify.

## Signed ≠ safe, unsigned ≠ malicious

`CodeSignInfo.tier` (Apple-signed / team-signed / ad-hoc-or-unsigned, from
the pre-existing `IntegrityCore.CodeSignInspector`) is shown as a plain
technical fact in the new Security & Provenance section. Nothing in this
pass reinterprets a signing tier as a safety verdict, attaches a risk level
to it, or treats an unsigned app as suspicious. `IntegrityCore`'s own module
comment already states this is not malware detection; this pass does not
change that boundary.

## Architecture and universal binary slice sizes

`ApplicationArchitectureDetail` wraps `InstalledApp.architectures` (existing
detection, unchanged) with optional per-slice sizes for a genuinely universal
binary, via `UniversalBinaryAnalyzer` — a fail-closed parser over the fat
Mach-O header (`FAT_MAGIC`/`fat_arch`), never a `lipo` subprocess. It:

- only recognizes the standard 32-bit `fat_arch` form (`FAT_MAGIC`), which is
  what real arm64/x86_64 macOS universal binaries use; `FAT_MAGIC_64` is not
  attempted — a documented limitation, not silently mishandled;
- bounds the claimed slice count (≤ 64) before looping, and verifies every
  slice's `offset + size` against the file's *real* size before trusting it
  — a corrupt or adversarial header fails closed (`nil`) rather than reading
  out of bounds or returning a fabricated figure;
- reports `slices: nil` for a thin binary or any unparseable header — never
  a fabricated even split of the app's total size across two architectures.

No binary thinning, rewriting, or slice removal exists anywhere — this is
inspection-only, and stays that way; a future "remove unused slice" feature
would need its own, separately reviewed safety model, exactly like a future
Snapshot Manager would (see `Documentation/APFS_INTELLIGENCE.md`).

## Running state

`ApplicationRuntimeState` (running/not running/unknown) comes from
`NSWorkspace.shared.runningApplications` — a public API snapshot of live
running applications, matched by bundle identifier. No process listing, no
`ps`/`lsof` subprocess, no elevated access. This pass is purely
informational: it does not block uninstall of a running app, does not
force-quit anything, and does not change the existing uninstall confirmation
flow at all.

## Performance and concurrency

`ApplicationInspectionService.inspect(app:...)` runs for **one app at a
time**, triggered only when that app is selected in the list — never for
CoreTend's whole app inventory at launch. Login items are scanned once per
list load (a handful of directory reads) and reused across every selection,
not rescanned per app. Selecting a new app while a previous inspection is
still in flight cancels the outstanding `Task` and every result assignment
is guarded by "is this still the selected app" — a slow inspection for an
app the user has since navigated away from can never overwrite what's on
screen. (Some of the sub-inspectors are dispatched via `Task.detached`
inside `inspect`, matching the existing codebase-wide idiom for offloading
synchronous file I/O; a cancelled outer selection does not force those
already-dispatched detached units of work to stop early — they may still run
to completion in the background even though their result is discarded. This
is a wasted-CPU characteristic, not a correctness issue: the UI never shows
a stale result.)

## What is explicitly NOT done in this pass

- **Receipts / PKG installer detection**: beyond the pre-existing Mac App
  Store receipt check, no PKG receipt database inspection was added — that
  would require a `pkgutil` subprocess, avoided for the same reason APFS
  Intelligence avoided its first subprocess (see
  `Documentation/APFS_INTELLIGENCE.md`). A PKG-installed app simply reports
  `InstallationSource.unknown`.
- **Search/filter extensions** (architecture, installed-via, running, etc.):
  the existing name-based search is unchanged; new filters were judged not
  worth the added surface this pass, per the brief's own "don't prioritize
  this over the business model" guidance.
- **Leftovers/Applications Center abstraction unification**: the one
  concrete, low-risk win (reusing the vendor-prefix concept for Group
  Container shared-detection, mirroring `LeftoversAmbiguity`'s own vendor
  logic) was taken; a deeper shared engine between "associated data for an
  installed app" and "leftover detection for a removed one" was not
  attempted — left as a documented future refactor, not a silent gap.
- **Recovery Plan integration**: deliberately absent — see
  `Documentation/SAFETY_MODEL.md` → "Applications Center".
- **Any launch item mutation** (disable/enable/load/unload/remove) and
  **any binary thinning**: not present anywhere, not even unwired.
