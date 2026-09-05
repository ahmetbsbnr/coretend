# SAFETY MODEL

## Core invariants
1. Scans never delete. Deletion is a separate, explicit step.
2. Deletion engines accept only `ApprovedFileOperation` (produced by `SafetyCenter.approve`),
   never raw URLs from UI.
3. Default deletion method: `FileManager.trashItem` (reversible). No `rm -rf` anywhere.
4. Every destructive surface shows a reviewed selection and asks for explicit
   confirmation immediately before execution.
5. Every path validated twice: at approval and again at execution (defends against
   symlink swaps / moved files between scan and action).

## PathValidator
- Rejects: empty, relative, `/`, home directory itself, protected roots
  (/System, /bin, /sbin, /usr/{bin,sbin,lib,libexec,share}, /private/var/db,
  /Library/Apple, /Volumes/Recovery), anything outside the per-operation allowlist,
  symlinks resolving outside the allowlist.
- Path-under check respects component boundaries ("/a/bc" not under "/a/b").
- User content roots (Documents, Desktop, Pictures, Music, Movies) are never
  auto-selected by rules (enforced by FileRulesTests).

## Audit
SafetyCenter emits structured lifecycle events per operation. Persistence
stores redacted approved/executed/skipped/error rows in SQLite; current activity
records only completed actions as reclaimed space.

## Advisor

`AdvisorService` (`Sources/CoreTendApp/AdvisorService.swift`) turns a scan
result into a structured, localized explanation (`AdvisorFinding`: title,
summary, reason, consequence, risk, confidence, reversibility, reclaimable
bytes, category, source, an optional recommendation, and what's explicitly
not touched). It sits strictly upstream of Safety:

Advisor **is**: deterministic, local, read-only, rules-based. Every field
comes from a verified domain value (a `RiskLevel` from `SafetyCore`, a byte
count already computed by the scan, a `Localizable.strings` lookup by a
fixed key) — never templated from unverified input.

Advisor **is not**: malware detection, AI/LLM, cloud analysis, or autonomous
cleanup. It has no filesystem or network access and cannot call
`SafetyCenter.approve`/`execute` or write to the Store — `AdvisorServiceTests`
asserts a file it's given a `ScanFinding` for is never touched.

Risk and Confidence are deliberately separate axes: Risk is the danger of
*acting* on a finding (reused from `SafetyCore.RiskLevel`, not a new
taxonomy); Confidence (`AdvisorConfidence`: exact/high/probable/uncertain) is
how sure CoreTend is the finding itself is correct. A verified content hash
(Duplicates) or a live Info.plist bundle ID is `.exact`; a fixed path/age
rule (Cleanup) is `.high`; a leftover match with a known ambiguity (a shared
vendor prefix, a `group.`-prefixed container) is `.probable`.

Reversibility (`AdvisorReversibility`) states only guarantees the product
actually has today: every current mapping (Cleanup, Duplicates, Leftovers,
Privacy cache) resolves to `.trash`, because every one of them goes through
`SafetyCenter.execute`'s Trash path. `.restorableByCoreTend` exists in the
enum for a real future Restore Center, but no mapping produces it yet — a
dedicated test (`noCurrentMappingClaimsARestoreCenterThatDoesNotExistYet`)
guards against a future change accidentally claiming it early.

## Recovery Plan

`RecoveryPlanService` (`Sources/CoreTendApp/RecoveryPlanService.swift`)
orchestrates the four wired engines toward a user-set byte goal:
Goal → eligible findings → conservative plan → review → user selection →
existing safe execution path. It is an orchestrator, not a second
implementation of Safety:

- **No new scanning code.** It calls the exact same `ScanEngine`,
  `DuplicateEngine`, `AppDiscovery.leftovers`, and `BrowserCatalog.detect`
  entry points `CleanupView`/`DuplicatesView`/`LeftoversView`/
  `PrivacyCleanerView` already call.
- **No new destructive path.** Execution constructs the same
  `PathValidator`(allowed roots) + `SafetyCenter` pair each of those views
  already constructs, with the same rule IDs and risk levels. `DuplicateSafety
  .safeSelection` (staleness check + never-remove-the-last-copy) and
  `PrivacyCleanerViewModel.isRunning` (re-check a browser is still closed) were
  extracted from those views into shared, tested, pure functions specifically
  so Recovery Plan reuses the identical guarantee rather than a second,
  hand-copied one that could drift.
- **Never atomic.** Each selected source executes sequentially through its
  own `SafetyCenter`; a failure in one source never rolls back another.
  `RecoveryPlanExecutionResult` reports each source's real outcome
  (processed/skipped counts and bytes) — never the plan's predicted total.
- **Eligibility is a real rule**, not `risk != .high`: evaluated from
  `AdvisorFinding`'s structured fields only (risk, confidence, reversibility,
  reclaimable bytes) — never from Advisor's display text. High risk is
  always excluded from automatic planning; `.uncertain` confidence,
  `.readOnly`, and non-Trash reversibility are excluded with a specific,
  shown reason; anything needing a real human decision (Duplicates' "which
  copy", an ambiguous Leftover) lands in "Review required" and is never
  preselected, regardless of how large its goal contribution would be.
- **Anti-double-counting is structural, not best-effort.** Cleanup's
  `user.caches` rule reads all of `~/Library/Caches` recursively, which
  overlaps two other wired sources at the filesystem level (Privacy's
  browser caches and Leftovers' Caches-location items both live under that
  same tree). With no shared per-file identifier to subtract the overlap,
  `user.caches` is unconditionally excluded from planning (shown, with its
  real bytes, reason "overlaps another source") rather than risking the same
  bytes counted toward one goal twice.
- **Staleness is re-validated, never trusted from the plan.** A plan is a
  snapshot; `SafetyCenter.approve`/`execute` still re-validate every path at
  execution time exactly as they do for every other destructive surface, and
  Duplicates' `DuplicateSafety.safeSelection` re-checks each file's
  modification date against scan time before any path is even approved.
  Recovery Plan never introduces a "trusted because the plan selected it"
  shortcut.
- **Recovery Plan never writes to Timeline.** Timeline measures what a real
  scan finds after the fact; Recovery Plan only predicts. Writing a Timeline
  snapshot from "bytes a plan expected to reclaim" would let a failed or
  partial execution report a measurement that never actually happened.

## APFS Intelligence

`APFSVolumeInspector`/`APFSIntelligenceService`
(`Sources/SystemMetrics/APFSVolumeInspector.swift`,
`Sources/CoreTendApp/APFSIntelligenceService.swift`) is a read-only
measurement layer, not a Safety surface:

- **No filesystem mutation, ever.** Every function reads
  `URLResourceValues` or calls Darwin `statfs()`. There is no
  `FileManager.removeItem`/`trashItem`, no `Process`, no `tmutil`/`diskutil`
  invocation anywhere in this vertical. No snapshot deletion, volume
  modification, or privileged operation exists in the codebase — not behind
  a flag, not unwired, not marked "future use".
- **Never Recovery-Plan-eligible, by construction, not by a filter.** Recovery
  Plan only ever consumes `AdvisorFinding` values produced by
  `AdvisorService`. APFS Intelligence never constructs an `AdvisorFinding` —
  its concept explanations (logical vs. physical, availability semantics,
  storage sharing, snapshots) are plain localized strings rendered directly
  by `APFSIntelligenceView`, not routed through Advisor at all. There is
  therefore no APFS-derived value for `RecoveryPlanEligibility` to accept or
  reject; the existing rule that checks `.readOnly` reversibility first would
  also exclude one if it ever existed, so this is defense in depth, not the
  only guarantee.
- **`SafetyCore.RiskLevel` is not used here.** Risk describes the danger of
  *acting* on a finding; a read-only volume metric has no action to be
  dangerous, so no `RiskLevel` value would be meaningful — `.low` would
  wrongly imply "safe to act on" for something there is nothing to act on.
  Rather than force a meaningless field, APFS Intelligence's types simply
  don't have a risk field.
- **Unavailable is not "safe to assume": it means the value cannot be
  measured.** `APFSMetric<Value>` only has `.measured`/`.unavailable` —
  never a fabricated number standing in for a real one. See
  `Documentation/APFS_INTELLIGENCE.md` for the exact meaning, source, and
  measured/derived/unavailable status of every field.

## Applications Center

`ApplicationInspectionService` and its sub-models
(`Sources/CoreTendApp/ApplicationInspection.swift`) add read-only inspection
depth to the existing Applications module. Same discipline as APFS
Intelligence:

- **No new destructive path.** Nothing here calls `FileManager.removeItem`/
  `trashItem`, `launchctl`, or any binary-rewriting API. The existing,
  tested `ApplicationsViewModel.uninstall()` — approve/execute through
  `PathValidator`/`SafetyCenter`, Trash-only — is completely unchanged and
  still only ever sees exact-bundle-id associated items. Group Container
  candidates (a heuristic, `.probable`-at-best match) are shown for
  visibility only and have no selection Toggle anywhere in this pass — they
  cannot reach `SafetyCenter` through any path this feature added.
- **Never Recovery-Plan-eligible.** `RecoveryPlanService` was not modified in
  this phase and carries zero references to any Applications Center 2.0
  type (`ApplicationInspection`, `AssociatedItemAdvisory`,
  `GroupContainerCandidate`, `InstallationSource`) — verified by inspection,
  not merely asserted. Recovery Plan's wired sources remain exactly
  {Cleanup, Duplicates, Leftovers, Privacy}.
- **`AssociatedItemAdvisory` is not an `AdvisorFinding`.** It reuses
  `RiskLevel`/`AdvisorConfidence`/`AdvisorReversibility` verbatim so the
  vocabulary never drifts, but `AdvisorFinding.category` is a
  `TimelineScope`, and Applications Center does not participate in Timeline
  (no scan, no snapshot, no comparison) — giving an associated item a
  `TimelineScope` would claim a relationship that doesn't exist. A shared
  item (Group Container matching more than one installed app) is always
  `.high` risk in this advisory regardless of its kind, since removing
  storage another app may depend on is exactly the failure this feature
  exists to prevent.
- **Signed is not safe; unsigned is not malicious.** `CodeSignInfo.tier` is
  shown as a plain technical fact (Apple-signed / team-signed /
  ad-hoc-or-unsigned) in the new Security & Provenance section — never
  reinterpreted as a safety verdict or attached to a risk level.
- **Running state is informational only.** Nothing in this pass force-quits
  a running app or blocks/gates uninstall on running state; the existing
  uninstall confirmation flow is unchanged.
- **No binary mutation.** `UniversalBinaryAnalyzer` only reads a fat Mach-O
  header to report slice sizes; there is no thinning, rewriting, or slice
  removal anywhere, not even unwired.

## Privacy Lab

`ImageMetadataInspector` / `PrivacyLabService` / `PrivacyLabViewModel`
(`Sources/SystemMetrics/ImageMetadataInspector.swift`,
`Sources/CoreTendApp/PrivacyLabService.swift`,
`Sources/CoreTendApp/PrivacyLabView.swift`) inspect the metadata embedded in
one user-selected image file. Same discipline as APFS Intelligence and
Applications Center — a read-only measurement layer, not a Safety surface:

- **No filesystem mutation, ever.** The inspector calls only ImageIO reads
  (`CGImageSourceCreateWithURL`, `CGImageSourceCopyPropertiesAtIndex` with
  `kCGImageSourceShouldCache: false`). There is no `CGImageDestination`,
  no `FileManager` write/`removeItem`/`trashItem`, no in-place EXIF strip,
  no `Process` — not behind a flag, not unwired. The pixel buffer is never
  even decoded.
- **Never Recovery-Plan-eligible, by construction.** Privacy Lab never
  constructs an `AdvisorFinding`. Its per-category explanations are plain
  localized strings rendered directly by `PrivacyLabView`. `RecoveryPlan
  Service` is untouched and carries zero references to any Privacy Lab type,
  so there is no Privacy-Lab-derived value for `RecoveryPlanEligibility` to
  accept or reject.
- **`SafetyCore.RiskLevel` is not used here.** A read-only metadata fact has
  no action to be dangerous; `.low` would wrongly imply "safe to act on".
  Privacy Lab's types simply have no risk field — and no privacy *score*:
  `PrivacyLabSummary` reports counts and an honest headline only.
- **Three states kept distinct.** `MetadataPresence` is
  `present` / `notDetected` / `unavailable(reason:)`. "Not detected" is
  never rendered as "safe" or "clean": it means no *supported* field was
  found, nothing more.
- **Metadata is treated as sensitive and is not persisted.** No GPS
  coordinates, filenames, paths, author names, comments, device identifiers
  or free-form values reach the Store, Timeline, activity history, logs or
  analytics. Inspection data lives in memory for the current image only.
  Precise GPS coordinates are shown only behind an explicit opt-in
  disclosure; there is no reverse geocoding and no network call.
- **Photos Library boundary.** Only a single `NSOpenPanel`-selected file URL
  is read. The Photos framework is not used; no library is enumerated or
  modified.
- **Sanitized-copy is not implemented.** The layering leaves a clean seam
  for a future *original → read → sanitized copy → verify → compare →
  preserve original* flow, but no mutation exists today. A future operation
  must prefer **create sanitized copy** over **modify original**.

See `Documentation/PRIVACY_LAB.md` for the full field/format coverage and
measured limitations.

## Restore Center

`RestoreValidator` / `RestoreManifestRecord` / `RestoreManifestSink`
(`Sources/SafetyCore/RestoreManifest.swift`), `Store` restore-manifest
methods + v7 migration (`Sources/Persistence/Store.swift`), and
`RestoreService` (`Sources/CoreTendApp/RestoreService.swift`) let a user move
CoreTend-Trashed items back where they came from.

- **Capture at the source of truth.** `SafetyCenter.execute` now reads the
  `resultingItemURL` from `FileManager.trashItem(at:resultingItemURL:)` and,
  when its sink also conforms to `RestoreManifestSink` (`Persistence.Store`
  does), emits one `RestoreManifestRecord` per **successful Trash move**.
  The permanent `removeItem` fallback (temporary paths) is in the `catch`
  branch and emits nothing — a permanently removed item is never recorded as
  restorable. Every existing `SafetyCenter(validator:sink: store)` call site
  gets capture with no change; there is no second execution path.
- **No parallel raw-move path.** Restore is a single, guarded
  `FileManager.moveItem` from the recorded Trash URL to the recorded
  original path, pinned by `RestoreValidator`: destination must equal the
  recorded original exactly (never an arbitrary path), must not be a
  protected root, its parent must exist and be writable, and **nothing may
  already occupy it** — a collision is refused, never renamed or
  overwritten. The source must be an existing item inside a `.Trash` /
  `.Trashes` directory.
- **Revalidated at execution time.** `RestoreService.restore` re-reads each
  manifest row, recomputes live availability (inode + volume UUID +
  directory-ness against the Trash item; parent/occupancy against the
  destination), and runs `RestoreValidator` immediately before the move.
  The review list is a snapshot; the filesystem is not.
- **Per-item, never atomic.** Each item is validated and moved
  independently; a skip/failure never rolls back another. The result reports
  real per-item outcomes (restored / conflict / unavailable / failed) — never
  a predicted count.
- **`safety_log` stays redacted.** A restore writes a redacted `.executed`
  `SafetyAuditEvent` (`rule_id` = `restore.<original rule>`); the real paths
  live only in `restore_manifest`. The coarse `.restore` `ActivityRecord`
  carries counts and bytes, no path.
- **Advisor reversibility depends on a real manifest.** `RestoreReversibility
  .of(_:)` is the only producer of `.restorableByCoreTend`, and only for a
  live `.available` item. Scan-result Advisor findings are unchanged
  (`.trash`); Recovery Plan eligibility is unchanged.
- **Privacy boundary.** `restore_manifest` is the one table holding
  unredacted paths — local only, never synced/transmitted, excluded from
  `DiagnosticReport`, Timeline, and audit exports; "Forget Restore History"
  clears it in one action and never touches the Trash; bounded retention
  (90 days, 30 for terminal states).

See `Documentation/RESTORE.md` for the user-facing model and the
external-volume `HUMAN VERIFICATION REQUIRED` note.

## macOS integrations (App Intents / notifications / scheduled scans / WidgetKit / Finder)

`Sources/CoreTendApp/CoreTendIntents.swift`, `NotificationService.swift`,
`ScheduledScanService.swift`, `MacIntegrations.swift`, `AppRouter.swift`.
The first integration layer — and it is **read-only by dependency
structure**, not by a runtime flag:

- **No destructive App Intent.** There is no intent to clean, empty the
  Trash, delete duplicates/caches, restore, or disable a launch item.
  `CoreTendIntents.swift` / `CoreTendIntentText.swift` do not import
  `FileRules` and reference no `SafetyCenter` / `CleanupExecution` /
  `RecoveryPlanService` / `RestoreService` symbol. `MacIntegrationsSafety
  Tests` greps the comment-stripped source and fails if that changes. The
  image-metadata intent reuses `ImageMetadataInspector` and contains no
  persistence call — the selected file URL is used for one call and never
  stored.
- **Scheduled scans are scan-only, by construction.** `ScheduledScanService`
  imports only `ScanCore` (a read-only engine that *emits* findings) and
  `Persistence` (Timeline). It never imports `FileRules`; the rule catalog
  is passed in as inert `[ScanRule]` data. It has no code path to
  `SafetyCenter.execute` / `CleanupExecution` / `RecoveryPlanService.execute`
  / `RestoreService.restore` / any launch-item mutation. Proven
  behaviourally: `aScheduledScanNeverDeletesOrMovesAnything` runs a real
  scheduled scan over deletable fixtures and asserts every file survives.
  A cancelled or incomplete scan writes **no** Timeline snapshot and **no**
  Activity record — only `ScanEvent.finished` produces history
  (`trigger = "scheduled"`, `cleanup` scope, same engine/rules/mapping as
  interactive Cleanup so comparability is preserved).
- **Notifications carry aggregates only.** No file path, filename, location,
  GPS value, browser profile name, or restore-manifest path ever enters a
  notification title, body, or `userInfo` — only a total (e.g. "8.4 GB
  potentially recoverable") and a `ModuleID` rawValue for the tap route.
  Permission is requested only from an explicit user action, never
  automatically. Rate-limited and coalesced (`NotificationPolicy`, pure);
  the only persisted state is one `settings` timestamp row per category.
- **One deep-link router.** `AppRouter` reuses the existing `.mcNavigate`
  `NotificationCenter` routing; notifications and App Intents share it.
- **Scheduler.** `NSBackgroundActivityScheduler` (native, entitlement-free,
  system-condition-aware). Reuses the single `AppEnvironment.shared.store`;
  an `inProgress` guard prevents overlapping runs; no Full Disk Access is
  assumed or prompted.
- **The WidgetKit widget cannot scan or delete — by dependency structure.**
  The `CoreTendWidget` extension target
  (`WidgetExtension/CoreTendWidget.swift`) links **only** the `WidgetShared`
  package product. It does not import `ScanCore` / `SafetyCore` /
  `FileRules` / `Persistence` / `AppDiscovery` / `IntegrityCore` /
  `CoreTendApp`, and references no `ScanEngine` / `SafetyCenter` /
  `RestoreService` / `RecoveryPlanService` / `DeveloperCenterService` /
  `trashItem` symbol
  (`XcodeHostHygieneTests.theWidgetSourceLinksNothingThatCouldScanOrDelete`
  greps comment-stripped source). The provider reads exactly one JSON file
  from the App Group container and never opens the SQLite/WAL store
  cross-process. The host publishes a tiny **aggregates-only**
  `WidgetSnapshot` (free/total bytes, optional reclaimable / delta /
  last-scan-date / activity-kind — never a path, filename, GPS value,
  restore-manifest entry, browser-profile name, image metadata value, or
  security finding), written atomically, only on meaningful events, never on
  a timer. Corrupt / partial / future-version / stale / missing snapshots
  degrade to an honest "unavailable" placeholder, never a fabricated `0`.
- **The Finder Sync extension cannot scan, inspect, or delete — by
  dependency structure.** The `CoreTendFinder` extension target
  (`FinderExtension/CoreTendFinder.swift`) links **only** the `FinderShared`
  package product (Foundation-only). It does not import `ScanCore` /
  `SafetyCore` / `FileRules` / `Persistence` / `AppDiscovery` /
  `IntegrityCore` / `CoreTendApp`, and references no `trashItem` /
  `removeItem` / `SafetyCenter` / `RecoveryPlanService` / `RestoreService` /
  `CleanupExecution` / `PathValidator` symbol, nor any content-inspection
  API (`ImageMetadataInspector` / `CodeSignInspector` / `CGImageSource` /
  `contentsOfDirectory`) — `FinderExtensionSafetyTests` enforces this at the
  dependency and source level. The extension reads **no file contents**: it
  classifies the Finder selection using bounded single-item attributes and hands one
  path to the host as a `coretend://` URL. The host re-validates that path
  against the live filesystem with a purpose-built **read-only**
  `SelectionValidator` (deliberately not `PathValidator`, whose
  destructive-selection rules would wrongly reject a user's own
  `~/Documents` file) before routing to Space Lens (read-only size scan),
  Privacy Lab (in-memory metadata inspection), or the Integrity inspector
  (off-main-actor code-signature read). Consumption revalidates the path,
  rejects selected symlinks/incompatible kinds, clears the one-shot URL, and
  shows EN/FR rejection guidance. Finder scans skip persistent path history.
  No Finder action deletes, trashes, cleans,
  restores, or uninstalls anything.

See `Documentation/MACOS_INTEGRATIONS.md`.

## Not yet implemented (planned)
Quarantine, reinforced confirmation for non-reversible ops, hard-link and
open-file checks, automatic conflict resolution on restore (deliberately not
built — collisions are refused), verified real external-volume restore,
image-metadata sanitized-copy export.
