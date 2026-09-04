# CoreTend — Complete Project Audit

**Status: session 3 of 3, closing this audit pass.** Sections 1-14 were completed in sessions 1-2 (kept
as originally written below — commit references there predate session 3, not re-verified line-by-line
except where §17-20 explicitly re-verify distribution). Sections 15-24 (design/UI, localization,
distribution re-check, website, CI/GitHub, scripts, technical/product debt, public-readiness scorecard,
evidence appendix, next-phase recommendations) were completed this session with real, evidence-backed
content. All items from the session-3 brief's priority list (1-10) were reached. See §25-38 and the
Conclusion at the bottom for what remains honestly un-covered.

**Session-4 update (requirements-compliance audit, separate vocabulary from this file)**: a distinct,
later audit pass (sessions 2-4 of the *requirements-reconciliation* effort, not this file's 3
sessions) built a sourced 69-requirement baseline
(`Documentation/MASTER_REQUIREMENTS_BASELINE.md`) and scored it against the codebase using a
different status vocabulary (COMPLIANT_VERIFIED / COMPLIANT_PARTIAL / IMPLEMENTED_UNVERIFIED /
NON_COMPLIANT / BLOCKED_* — not this file's VERIFIED_COMPLETE / VERIFIED_PARTIAL /
IMPLEMENTED_UNVERIFIED used in §9/§11 below). **These are two different audits answering two
different questions**: this file (`PROJECT_COMPLETE_AUDIT.md`) asks "does each of the 41 named
features in `FEATURE_INVENTORY.md` exist and work?" (41 features, 31 VERIFIED_COMPLETE). The
requirements audit asks "does the product meet each of 69 requirements sourced from
SAFETY_MODEL.md/SECURITY_AUDIT/LICENSE/README/design docs/etc?" (69 requirements, 54 MUST). Do not
quote one audit's numbers as if they were the other's. **Final requirements-compliance verdict:
MOSTLY_CONFORMING** — see `Documentation/FINAL_COMPLIANCE_SCORECARD.md` for the full scoring and
`Documentation/REQUIREMENTS_COMPLIANCE_SUMMARY.md` for the rollup. This supersedes any verdict
language below in §4 that predates the requirements audit.

**Compliance-hardening update**: the "41 features, 31 VERIFIED_COMPLETE" figure above is now stale —
`feature-inventory.json` had grown to 42 entries (34 VERIFIED_COMPLETE, 4 VERIFIED_PARTIAL, 4
IMPLEMENTED_UNVERIFIED) without the summary line above or `FEATURE_INVENTORY.md` ever being
regenerated to match, the exact kind of drift `Scripts/check-feature-inventory.sh` now catches. See
`Documentation/CURRENT_PROJECT_STATE.json` for the current figure; the "41/31" sentence above is left
as originally written (this file's own historical record of what session 3 concluded), not rewritten.

**v0.7.1 closeout update (2026-07-21, this session)**: re-verified against `git rev-parse HEAD`
(`4c36e90143e628b2dc79f634034adcb93fb0c5a5`) rather than trusting the figures above. Findings: (1) test
count is 114 passing in 30 suites (real `Scripts/test.sh` run, see `Documentation/test-inventory.json`),
not the 86 recorded in older snapshots; (2) `Documentation/FEATURE_MATRIX.md` incorrectly listed Privacy
Cleaner, App Updater, and Similar Images as absent/not-started when `Sources/` shows all three shipped
and tested — corrected this session; (3) the requirements-traceability baseline (69 requirements, 54
MUST) was spot-checked against `Sources/` for the same modules and found already correctly scored, so
its historical `auditedSourceCommit` field was left as an honest historical record with a new
`reverifiedAt` block added rather than overwritten; (4) built a new audit ZIP superseding both prior
`AuditPackages/` archives, with `AUDIT_PACKAGE_README.md`/`AUDIT_PACKAGE_SHA256SUMS`/
`AUDIT_PACKAGE_FILELIST.txt` added (previously missing) and `AUDIT_PACKAGE_COMMIT` populated
(previously null). See `Documentation/CURRENT_PROJECT_STATE.json` and `Documentation/CURRENT_AUDIT_STATE.json`
for the current authoritative fields.

## 0. Cover page

- Product: CoreTend (SwiftUI macOS app)
- Audited commit: `b33c06b8d68b9b03316821c3f6cfb17252f35011`
- Branch: `feat/public-distribution`
- Audit date: 2026-07-20
- Audit type: evidence-based. Written incrementally across 3 sessions (see the status note
  at the top of this file and `Documentation/CONTINUATION.md` for what each session covered)

## 1. Date / environment

- macOS host, Swift 6.3.2 toolchain (per prior-session note, used via `bash Scripts/test.sh` this
  session; not independently re-verified with `swift --version` this session — should be in session 2
  if precision matters).
- Working directory at the time of this audit: `~/Documents/MACCLEAN`
  (since moved to `WEBSITE/products/coretend/app`).

## 2. Version / commit

- HEAD: `b33c06b8d68b9b03316821c3f6cfb17252f35011` — "release: prepare v0.7.0 public distribution"
- No git tags exist (local or remote). No remotes configured. Nothing has been pushed anywhere.
  **"v0.7.0" is a string in commit messages/manifests, not a published release.**

## 3. Executive summary

CoreTend is a single-author, single-day-committed (2026-07-19 → 2026-07-20, 115 commits), local-only
macOS cleanup/protection utility built as a 9-target SwiftPM package with zero external dependencies.
This session verified: the git repository is clean and un-pushed; all 86 automated tests pass in under
1 second of test-run time; the architecture is a straightforward layered SwiftPM package with actor-isolated
mutable state and AsyncStream-based scan engines; and the release/distribution shell scripts reveal two
real, reproducible defects (a stale SHA256SUMS manifest and a 3-byte dmgSize mismatch) plus one documented
pre-existing limitation (repo path leakage in the binary, said not to affect runtime).

## 4. Verdict

**Historical note (session 1 wrote this section):** at the time this paragraph was written, the
public-readiness scorecard (security, privacy, legal/license, design/UI, localization, distribution,
website, CI, scripts, and technical-debt audits) had not yet been reached. Sessions 2-3 subsequently
delivered `SECURITY_AUDIT_CURRENT.md`, `PRIVACY_AUDIT_CURRENT.md`, `LEGAL_AND_LICENSE_STATUS.md`,
`DISTRIBUTION_AUDIT.md`, `WEBSITE_AUDIT.md`, `TECHNICAL_DEBT.md`, `PRODUCT_DEBT.md`, and
`PUBLIC_READINESS_SCORECARD.md` — see those files and `Documentation/DOCUMENT_INDEX.md` for the current
verdict, not this paragraph.

**Current canonical verdict (session 4 of the requirements-reconciliation effort, supersedes both the
paragraph above and this file's own §22 INTERNAL_READY label for compliance purposes)**: per the
sourced 69-requirement traceability matrix, scored per the original brief's §23 formula, the verdict
is **MOSTLY_CONFORMING** — zero MUST requirement is NON_COMPLIANT or BLOCKED_*, weighted MUST score
81.9% (44.25/54), but 15 of 54 MUST requirements are below COMPLIANT_VERIFIED (6 COMPLIANT_PARTIAL, 9
IMPLEMENTED_UNVERIFIED), which rules out FULLY_CONFORMING_VERIFIED per the brief's own capping rule.
Full breakdown: `Documentation/FINAL_COMPLIANCE_SCORECARD.md`.

## 5. What CoreTend is / is not (from evidence gathered this session)

- **Is**: a local, offline, SwiftUI macOS app for disk cleanup, duplicate/similar-image detection, app
  uninstall with leftover detection, ancien scanner externe-based malware scanning with reversible quarantine, cloud
  storage footprint analysis (without triggering downloads), and system performance metrics — all backed
  by an actor-isolated local SQLite store, no external SwiftPM dependencies.
- **Is not (yet, per this session's evidence)**: publicly published (no tags, no remotes, nothing
  pushed); confirmed secure/private/legally-cleared (all deferred to session 2); confirmed to have a
  working, internally-consistent release manifest (two real defects found this session, see §9).

## 6. History

See `Documentation/PROJECT_HISTORY_FROM_ZERO.md` — real chronology built from `git log` + spot-checked
diffs, not from trusting commit messages alone.

## 7. Statistics

See `Documentation/repository-statistics.json`. Headline numbers: 283 tracked files, 59 Swift files,
8296 Swift lines, 16 test files, 22 shell scripts, 82 markdown docs, 27 website HTML files, 2
localizations (en/fr, 372 lines each), 0 external dependencies, 3 GitHub workflows.

## 8. Architecture

See `Documentation/ARCHITECTURE_INVENTORY.md` — 9 SwiftPM targets, 4 Mermaid diagrams (global
architecture, scan flow, delete/restore/quarantine flow, Smart Care orchestration), concurrency posture
(18 files use `@MainActor`, 4 use `AsyncStream`, 1 `Process()` shell-out at
`Sources/LegacyScanner/LegacyScanner.swift:56`).

## 9. Module inventory (partial — target-level only, not full public-API inventory)

See `Documentation/ARCHITECTURE_INVENTORY.md` "Key public types" section for the target-level inventory
gathered in session 1. **Still genuinely not done** as of this reconciliation pass: a full per-view,
per-service public-API inventory. Session 2 grep-verified (not line-by-line read) the 15 `CoreTendApp`
view files and marked them `IMPLEMENTED_UNVERIFIED` in `FEATURE_INVENTORY.md` rather than claiming full
verification — that gap is real and still open, not resolved by a later session. See
`Documentation/CONTINUATION.md` session-2 entry for the exact file list.

## 9b. Test audit (real evidence, this session)

See `Documentation/TEST_INVENTORY.md` and `Documentation/test-inventory.json`. Headline: **86/86 tests
passed, 27 suites, 0.938s test-run time.** Shell-level scripts: `test-uninstall.sh` PASS (4/4);
`test-distribution.sh` 9/10 checks OK (1 known pre-existing limitation); `test-release-manifest.sh` 2
real FAILs found this session (SHA256SUMS drift, dmgSize 3-byte mismatch); `check-private-data.sh` PASS.

## 10. Repository / git state

See `Documentation/REPOSITORY_MAP.md` and `Documentation/AUDIT_COMMANDS.log`. Headline: clean working
tree, single author, no tags, no remotes, 115 commits, 7 stray `worktree-agent-*` branches left over
from prior sessions (not cleaned up, flagged only).

---

## 11. Feature-by-feature functional inventory (module-by-module)

**Done this session** — see `Documentation/FEATURE_INVENTORY.md` + `feature-inventory.json`/`.csv`. 41
entries across app shell, SafetyCore, ScanCore (4 engines), all 7 real cleanup rules from
`UserCleanupRules.swift`, Smart Care, Protection/LegacyScanner, Performance/SystemMetrics,
Applications/AppDiscovery, My Clutter, Space Lens, Cloud Cleanup, My Activity/Persistence, and every
Settings toggle. Status breakdown: mostly VERIFIED_COMPLETE, 5 VERIFIED_PARTIAL (in-memory-only audit
log, restore edge cases, App Updates deep-link-only, Cloud Cleanup view logic not fully traced), 5
IMPLEMENTED_UNVERIFIED (My Clutter/Duplicates/Similar Images/Space Lens view-layer logic — engines
themselves confirmed real and wired, but the surrounding view code wasn't read line-by-line this
session). Real findings: `AppUpdatesView` only deep-links to the App Store's Updates pane rather than
checking for updates itself; no test exercises the actual ancien scanner externe `Process()` invocation (only its
output parser and quarantine round-trip); no dead/unwired Settings toggle found.

## 12. Security audit (threat model around the `Process()` shell-out, path validation coverage, sandboxing)

**Done this session** — see `Documentation/SECURITY_AUDIT_CURRENT.md`. The single `Process()` call
(`LegacyScanner.swift:56`) uses an argument array, never a shell — no injection surface; binary path
restricted to 3 known install locations. `PathValidator` (`SafetyCore.swift`) provides protected-root
blocklist + allowlist + symlink-escape resolution + re-validation at execute time, backed by 13 passing
tests. Exactly 4 force-unwraps in the whole codebase, all on safe compile-time-constant inputs; zero
`as!`; zero actual `sudo` invocations. Sub-scores: deletion safety 9/10, system security 8/10, repo
security 8/10; distribution/website/workflow security left UNKNOWN pending session-3 depth.

## 13. Privacy audit (data handling, telemetry, local-only claims verification)

**Done this session** — see `Documentation/PRIVACY_AUDIT_CURRENT.md`. Zero `URLSession`/network-
framework/socket usage found anywhere in `Sources/`; zero telemetry, analytics, crash reporters, or
account systems found. The only external-facing action is a user-initiated `macappstore://` deep link
(system handoff, not the app's own network call). Website text-level tracker sweep found no analytics
script tags in the 27 tracked HTML files (shallow check; full website audit still queued for session 3).
**Local-only claim holds up under this session's evidence.**

## 14. Legal / license audit (LICENSES/, THIRD_PARTY_NOTICES.md, contact info accuracy)

**Done this session** — see `Documentation/LEGAL_AND_LICENSE_STATUS.md`. `LICENSE`, both texts in
`LICENSES/`, `TRADEMARKS.md`, and `Documentation/{THIRD_PARTY,ASSET_PROVENANCE,DEPENDENCIES}.md` all
verified to actually exist and be internally consistent (Apache-2.0 code / CC-BY-4.0 docs-art split,
zero SwiftPM deps, ancien scanner externe GPL-2.0 external-subprocess-only, no bundled fonts/stock imagery). **Real
defect found**: `LICENSE` itself references two files that don't exist in the tree
(`Documentation/LICENSING.md`, `THIRD_PARTY_NOTICES.md` — the real file is `Documentation/THIRD_PARTY.md`).
Not fixed this session (content edit, not requested); flagged for follow-up. Zero SPDX headers in
`Sources/` (flag only, not necessarily a defect since a root `LICENSE` is legally sufficient).

## 15. Design / UI audit

**Done this session.** All 9 SwiftUI module views checked for `accessibilityReduceMotion`/
`accessibilityReduceTransparency` handling: centralized in design-system components
(`Sources/DesignSystem/FragmentView.swift`, `OverlapView.swift` — reduce motion; `DesignSystem.swift:10`
`MCCard` — reduce transparency) rather than duplicated per screen; `SpaceLensView.swift:86` and
`MyActivityView.swift:119` additionally read reduce-motion for their own transitions. Protection's
`MCMeshView` (`Sources/DesignSystem/MeshView.swift`, the containment-mesh motif from commit `f31e993`)
is a real state-driven `Canvas` draw — `completeness` (0...1) reflects actual engine-ready state, 4
named `Style` cases, VoiceOver `accessibilityDescription` for all 4 — and correctly has no reduce-motion
code because it has no animation (no `@State`, no timers, confirmed by full-file read). **Real
environment finding**: `screencapture` succeeded this session, meaning a display *is* reachable in this
specific environment — the "no display attached" `BLOCKED_ENVIRONMENT` claim from the v0.4.0-era
`VISUAL_AUDIT.md` note does not universally hold; it's environment-dependent. Did not re-run
`Scripts/capture.sh` to refresh screenshots (the live screen had unrelated foreground content at capture
time; re-driving the real desktop via AppleScript for a fresh capture was judged out of scope for a
non-interactive audit pass). Existing dated screenshots in `Documentation/VisualAudit/After/` (2026-07-20,
committed at `b8c587d`) remain the most recent on-file evidence. See `AUDIT_EVIDENCE.md`
EVIDENCE-PROTECTION-001, EVIDENCE-A11Y-001, EVIDENCE-ENV-001.

## 16. Localization audit

**Done this session.** 327 keys in `Base.lproj`/`fr.lproj` `Localizable.strings`, **100% EN/FR key
parity** (`diff` of sorted key sets → 0 lines different), **zero unused keys** (every one of the 327
base keys found referenced somewhere in `Sources/CoreTendApp` outside the Resources dir), **exactly one**
non-localized `Text("...")` literal in the whole app and it's the correct exception — the product name
(`OnboardingView.swift:57`). `Localizable.xcstrings` (the newer Xcode string-catalog format) exists but
contains only 1 key — the real localization surface is the older `.strings` pair, not the catalog.
See `AUDIT_EVIDENCE.md` EVIDENCE-L10N-001/002.

## 17. Distribution audit

**Done this session** — see `Documentation/DISTRIBUTION_AUDIT.md` (new, full doc). Fresh from-scratch
re-verification (not just re-reading session-2's fix): checksums recomputed via `shasum -a 256` and match
`latest.json` exactly; arm64 confirmed via `file`/`lipo -info` (single-arch, not fat); zip extracted +
app launched + quit cleanly in a scratch temp dir outside the repo; dmg mounted/detached cleanly; license
files (`LICENSE`, `NOTICE`, `THIRD_PARTY_NOTICES.md`) confirmed present inside the zip via `unzip -l`.
Session-2's `88bbb9a` checksum/size auto-sync fix holds. Real remaining blockers (all pre-existing, not
new): unsigned/unnotarized, no public GitHub release, single-machine/single-arch tested only.

## 18. Website audit

**Done this session** — see `Documentation/WEBSITE_AUDIT.md` (new, full doc). Static HTML/CSS, no
framework, single Python stdlib generator script (`website/generate.py`). 13 pages per locale, exact
FR/EN filename parity confirmed. Zero tracker/analytics script tags found (9-signature grep sweep + zero
external `src`/`href` URLs anywhere). Legal-identity placeholders (`LEGAL_NAME_TO_DEFINE` and its
neighbours) were unresolved at the time of this audit and were honestly self-marked in the page text,
not hidden; they were resolved in the later 0.9.0 launch phase. `lang=`/viewport meta present;
zero `<img>` tags exist site-wide so the alt-text question is moot; no automated a11y scanner run (no
browser tooling in this environment).

## 19. CI / GitHub audit

**Done this session.** 3 workflows (`ci.yml`, `release-draft.yml`, `security.yml`), all declare
`permissions: contents: read` at the top level, all trigger only on `pull_request`/`push: [main]`/
`workflow_dispatch` (no `pull_request_target`), none reference `secrets.` anywhere. `release-draft.yml`
is manual-only, uploads artifacts (never publishes a GitHub Release), and self-checks it never emits a
`signed:true`/`notarized:true` claim. `security.yml` runs a grep-based secret scan (self-documented via
a `ponytail:` comment as an intentional simplification, upgrade path named: gitleaks/trufflehog), a
curl-pipe-to-shell check, an absolute-developer-path check, and a forbidden-file-type check. Also present:
`CODEOWNERS`, `PULL_REQUEST_TEMPLATE.md`, `dependabot.yml`, 5 issue-template YAML files. **Every workflow
is marked `IMPLEMENTED_UNVERIFIED`, not `VERIFIED_COMPLETE`** — none has ever run on real GitHub Actions
(`git remote -v` remains empty across all 3 sessions; nothing has ever been pushed). Actions are pinned to
version tags (`@v4`), not commit SHAs — acceptable but not maximal supply-chain hardening. See
`AUDIT_EVIDENCE.md` EVIDENCE-CI-001/002.

## 20. Scripts audit

**Done this session** for error-handling posture across all 22 scripts (prior sessions exercised several
individually via their outputs — `test.sh`, `test-distribution.sh`, `test-release-manifest.sh`,
`test-uninstall.sh`, `check-private-data.sh` — cited in §9b/§10). This session: 22/22 scripts declare at
least `set -e` (10 plain, 11 `set -eu`, 1 `set -euo pipefail`) — none silently continue after an
unchecked failure, but only 1/22 has the strict `pipefail` form, meaning a failure on the left side of a
pipe (e.g. `ci.yml`'s `swift build ... | tee log`) could be masked. See `TECHNICAL_DEBT.md` #4 and
`AUDIT_EVIDENCE.md` EVIDENCE-SCRIPTS-001. Full per-script role/argument/idempotence table not built this
session (budget); the `set`-flag sweep and this session's direct executions (test.sh, distribution
extract/mount, checksum verify) are the real evidence gathered.

## 21. Technical / product debt inventory

**Done this session** — see `Documentation/TECHNICAL_DEBT.md` and `Documentation/PRODUCT_DEBT.md` (both
new, full docs), consolidating findings from all 3 sessions with severity/category/evidence/effort.

## 22. Public-readiness scorecard

**Done this session** — see `Documentation/PUBLIC_READINESS_SCORECARD.md` (new). 16 independently scored
axes, no misleading single aggregate. **Overall verdict: INTERNAL_READY** — solid engineering artifact,
not yet tester/beta/stable-ready pending signing, a live repo/website, and multi-machine verification.

## 23. Evidence appendix

**Done this session** — see `Documentation/AUDIT_EVIDENCE.md` (new), 15 structured EVIDENCE-XXX-### blocks
covering this session's most load-bearing claims (session 1/2's own docs already contain their own
inline evidence and aren't re-duplicated here).

## 24. Next-phase recommendations

**Done this session** — see `Documentation/NEXT_PHASE_RECOMMENDATIONS.md` (new). Three trajectories
(cautious/security-first, public-beta-first, full-product-polish-first), none prescribing a version
number, each grounded in this session's actual findings rather than a generic roadmap.

## 25-38. Remaining brief items

Everything the original 38-section brief called for across the priority list in this session's
instructions (items 1-10) has now been addressed at real, evidence-based depth: distribution, website,
design/UI, localization, CI/GitHub, scripts, technical debt, product debt, public-readiness scorecard,
evidence appendix, and next-phase recommendations. Items not explicitly itemized above (e.g. a full
per-script argument table, a full per-view public-API inventory, a live external-repo/CI dry run, an
automated accessibility tool run, translation-quality review of the French strings) remain honestly
un-covered — see `CONTINUATION.md` for what's carried forward. No section here should be read as claiming
more depth than its evidence actually supports.

## Conclusion

Across three audit sessions, CoreTend's core engineering (86/86 tests, clean security posture,
zero telemetry, real localization parity, working packaging pipeline, honest CI that's never actually
run) is in genuinely good shape for a project of this age. What separates it from a public release is
almost entirely human-gated (legal identity, code signing) or requires resources this audit
environment doesn't have (a second physical Mac, a live GitHub remote, a browser for automated a11y
scanning) — not undiscovered engineering defects. See `PUBLIC_READINESS_SCORECARD.md` for the honest
per-axis breakdown and `NEXT_PHASE_RECOMMENDATIONS.md` for what to do about it.
