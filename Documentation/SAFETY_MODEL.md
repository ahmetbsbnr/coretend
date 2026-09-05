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

## Not yet implemented (planned)
Quarantine, restore manifests, reinforced confirmation for non-reversible ops,
hard-link and open-file checks, volume identity checks.
