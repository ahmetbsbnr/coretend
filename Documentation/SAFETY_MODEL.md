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

## Not yet implemented (planned)
Quarantine, restore manifests, reinforced confirmation for non-reversible ops,
hard-link and open-file checks, volume identity checks.
