# Document Index

> **0.8.1 Final Canonical Audit Resync (2026-07-25).** Entries touched this
> phase, all verified against the filesystem rather than carried forward:
>
> | Path | What changed |
> |---|---|
> | `CURRENT_PROJECT_STATE.json` | Rewritten for 0.8.1 (schemaVersion 2). Real branch, real commit identities, 274/57, 46 features, human + environment blockers, defects fixed |
> | `CURRENT_AUDIT_STATE.json` | Rewritten for 0.8.1 (schemaVersion 2). Per-commit binary/bundle/site/audit impact table, real gate results, publication gate red with reasons |
> | `AuditHistory/0.8.0/` | **New.** Frozen 0.8.0 snapshots of `CURRENT_PROJECT_STATE.json`, `CURRENT_AUDIT_STATE.json`, `PROJECT_STATE.json`. Never rewritten to match the present |
> | `CORETEND_DATA_MIGRATION_REPORT.md` | **New.** The migration as delivered and executed |
> | `RebrandHistory/PRE_IMPLEMENTATION_MIGRATION_*.md` | **Moved** from `USER_DATA_RENAME_MIGRATION.md` / `REBRAND_MIGRATION_TEST_PLAN.md`, with historical banners. Content untouched |
> | `USER_DATA_RENAME_MIGRATION.md`, `REBRAND_MIGRATION_TEST_PLAN.md` | Now redirect stubs, so no inbound reference breaks |
> | `TEST_INVENTORY.md`, `test-inventory.json` | Regenerated from a real run at `92cbd08` |
> | `FEATURE_INVENTORY.md`, `feature-inventory.{json,csv}` | 42 → 46 features; the four rebrand features were missing |
> | `KNOWN_LIMITATIONS.md` | Two stale entries corrected, four current ones added |
> | `NON_COMPLIANCE_REGISTER.md` | DIST-003 updated (the predicted drift really happened); RESYNC-001..004 opened |
> | `REQUIREMENTS_COMPLIANCE_SUMMARY.md` | Resync header; requirements explicitly **not** re-audited this phase |
> | `PROJECT_STATE.json`, `CONTINUATION.md` | Test counts, build status and limitations corrected; resync phase recorded |
>
> `AUDITED_SOURCE_COMMIT` below refers to the original index audit and is
> historical. The commit this resync verified against is
> `92cbd08bc3cd1d8ad0513391cbd7552b520f09fe`.

Map of every document in `Documentation/` (plus root-level legal/policy files), for later sessions and
the eventual external-audit ZIP manifest. Built by reading each file's title/opening and, for the audit
reports, their own stated session/date. AUDITED_SOURCE_COMMIT for this index: `b33c06b8d68b9b03316821c3f6cfb17252f35011`.

Columns: **Role**, **Source of truth** (current = describes present-day reality; historical = a record
of a past session, kept for provenance, not meant to be re-read as "still true"), **Status**,
**Superseded by**, **Audience** (public = safe for external audit ZIP as-is; internal = dev-process
notes, fine to include but not user-facing).

## Root-level

| File | Role | Source of truth | Status | Superseded by | Audience |
|---|---|---|---|---|---|
| `LICENSE` | Legal license grant + license-map pointer | current | active (fixed this session, see `REQUIREMENTS_DECISION_HISTORY.md`) | — | public |
| `README.md` | Project entry point | current | active | — | public |
| `PRIVACY.md` | Privacy statement | current | active | — | public |
| `SECURITY.md` | Security policy / vuln reporting | current | active | — | public |
| `CONTRIBUTING.md` | Contribution guide | current | active | — | public |
| `TRADEMARKS.md` | Trademark/branding terms | current | active | — | public |
| `GOVERNANCE.md` | Maintainer model, DCO | current | active | — | public |
| `SUPPORT.md` | Support channels | current | active | — | public |

## Core product / architecture docs (current)

| File | Role | Status | Audience |
|---|---|---|---|
| `ARCHITECTURE.md` | High-level architecture | current | public |
| `ARCHITECTURE_OVERVIEW.md` | Developer-facing architecture detail | current | internal/public |
| `BUILD_SYSTEM.md` | SwiftPM build mechanics | current | internal |
| `BUILD_AND_INSTALL.md` | Build+install combined guide | current | public |
| `DESIGN_SYSTEM.md` | Component/token system reference | current | internal |
| `TESTING.md` | How to run tests (`Scripts/test.sh`) | current | internal |
| `PERSISTENCE.md` | SQLite store design | current | internal |
| `MIGRATIONS.md` | DB migration approach | current | internal |
| `LOCALIZATION.md` | en/fr localization mechanics | current | internal |
| `SAFETYCORE.md` | `SafetyCore` module contract | current | internal |
| `SAFETY_MODEL.md` | High-level deletion-safety rules | current | public |
| `SCANCORE.md` | `ScanCore` engines | current | internal |
| `PROTECTION.md` | Integrity feature (rewritten this session — was ancien scanner externe-based) | current | public |
| `PROTECTION_LIMITATIONS.md` | Honest Integrity gaps (rewritten this session — was ancien scanner externe-based) | current | public |
| `LEGACY_SCANNER_DECISION.md` | Why ancien scanner externe was retired for Integrity | current | internal |
| `LEGACY_SCANNER_TEST_AUDIT.md` | 310→276 test-count audit for the ancien scanner externe removal, plus this session's added IntegrityCore test matrix | current | internal |
| `QUARANTINE.md` | Removed mechanism, kept as historical record | historical | internal |
| `COMPETITIVE_BENCHMARK.md` | CoreTend's own measured numbers vs. non-vérifié public claims about CleanMyMac/Disk Space Analyzer | current | public |
| `PRIVILEGED_HELPER.md` | Privileged-helper design (unshipped) | current | internal |
| `SMART_CARE.md` | Smart Care — retired, superseded by Dashboard | current | public |
| `QUARANTINE.md` | Quarantine mechanics | current | public |
| `RESTORE.md` | Restore/undo behavior (code-verified) | current | public |
| `EXCLUSIONS.md` | Scan-exclusion rules | current | public |
| `DATA_LOCATIONS.md` | Where the app stores data on disk | current | public |
| `THREAT_MODEL.md` | Condensed threat model | current | public |
| `PRODUCT_REQUIREMENTS.md` | Abridged product requirements | current, partially superseded | see `MASTER_REQUIREMENTS_BASELINE.md` for the fuller reconstruction | public |
| `FEATURE_MATRIX.md` | Feature x status matrix | current, cross-check against `FEATURE_INVENTORY.md` | public |
| `RELEASE_PROCESS_DRAFT.md` | Draft release process | current (still a draft) | internal |
| `TEST_PLAN.md` | Test planning notes | current | internal |

## Platform / compatibility

| File | Role | Status | Audience |
|---|---|---|---|
| `COMPATIBILITY.md` | Single entry point for platform support | current | public |
| `MACOS_VERSION_POLICY.md` | Why macOS 14.0 is the floor | current | public |
| `SUPPORTED_MACS.md` | Hardware support (arm64 only) | current | public |
| `API_AVAILABILITY_AUDIT.md` | API-floor audit backing MACOS_VERSION_POLICY | current | internal |

## Visual / design (current, session-2-and-3-audited for consistency, not re-mined this session)

| File | Role | Status | Audience |
|---|---|---|---|
| `VISUAL_DIRECTION.md` | "Orbital Ecology" design direction | current | public |
| `BRAND_SYSTEM.md` | Brand system spec | current | public |
| `DESIGN_TOKENS.md` | Token values | current | internal |
| `MOTION_SYSTEM.md` | Motion/animation rules | current | internal |
| `VISUAL_QA.md` | Per-screen QA checklist | current; 44-frame EN/FR light/dark matrix approved 2026-09-04 | internal |
| `VISUAL_AUDIT.md` | Baseline visual audit (v0.3.0) | historical baseline, still referenced | internal |
| `VISUAL_TOOLING.md` | `Scripts/capture.sh` tooling notes | current | internal |
| `ASSET_PIPELINE.md` | Brand asset generation | current | internal |
| `ASSET_PROVENANCE.md` | Asset origin/licensing | current | public |

## Distribution / release / website

| File | Role | Status | Audience |
|---|---|---|---|
| `INSTALLATION.md` | End-user install guide | current | public |
| `INSTALL_UNSIGNED.md` | Unsigned-build install specifics | current | public |
| `FIRST_LAUNCH.md` | First-launch walkthrough | current | public |
| `FULL_DISK_ACCESS.md` | FDA permission guide | current | public |
| `UNINSTALL.md` | Uninstall guide | current | public |
| `TROUBLESHOOTING.md` | User troubleshooting | current | public |
| `FAQ.md` | User FAQ | current | public |
| `CLEANUP_GUIDE.md` | Cleanup feature guide | current | public |
| `KNOWN_LIMITATIONS.md` | Standing, honestly-tracked limitations | current, actively maintained | public |
| `FIRST_PUBLIC_RELEASE_CHECKLIST.md` | Release gate checklist | current, gate not yet fully passed (see `HUMAN_BLOCKERS.md`) | internal |
| `PUBLIC_RELEASE_READINESS.md` | Readiness narrative | current | internal |
| `HUMAN_BLOCKERS.md` | Items only a human can resolve (identity, domain, legal entity) | current, still open | internal |
| `WEBSITE_ARCHITECTURE.md` | Website structure | current | internal |
| `WEBSITE_DEPLOYMENT.md` | Deployment plan (not yet deployed) | current | internal |
| `WEBSITE_PRIVACY.md` | Website privacy stance | current | public |
| `WEBSITE_SECURITY.md` | Website security stance | current | public |
| `REPOSITORY_SANITIZATION.md` | Pre-publication sanitization log | current | internal |
| `PUBLICATION_PLACEHOLDERS.md` | Tracked bracket-placeholders (URLs, contact, legal identity) | current, still has real placeholders | internal |
| `THIRD_PARTY.md` | Third-party license/dependency notices | current | public |
| `DEPENDENCIES.md` | Dependency audit (zero external SwiftPM deps) | current | public |

## Process / community

| File | Role | Status | Audience |
|---|---|---|---|
| `DECISIONS.md` | Architecture Decision Records (D1-D6) | current, append-only | public |
| `ROADMAP.md` | Forward-looking roadmap | current | public |
| `CHANGELOG.md` | Version history | current | public |
| `GOOD_FIRST_ISSUES.md` | Contributor onboarding | current | public |
| `RFC_TEMPLATE.md` | RFC template | current | public |
| `USER_GUIDE.md` | Full user guide | current | public |

## Audit reports (this multi-session effort — historical unless noted)

| File | Role | Source of truth | Status | Superseded by |
|---|---|---|---|---|
| `PROJECT_COMPLETE_AUDIT.md` | Master audit report, sections written across sessions 1-3 | mixed: §0-10 historical (session 1), §11-14 historical (session 2), §15-38 historical (session 3) | active document, edited this session to remove confusing "session 1 of N"/"pending session 2" language where later sessions resolved it (see file's own status banner) | this file + `MASTER_REQUIREMENTS_BASELINE.md` + `DOCUMENT_INDEX.md` (this reconciliation phase) |
| `AUDIT_COMMANDS.log` | Raw command transcript, session 1 | historical | active, commit ref fixed this session | — |
| `REPOSITORY_MAP.md` | Repo file-tree snapshot, session 1 | historical | active, commit ref fixed this session | — |
| `repository-statistics.json` | Repo stats snapshot, session 1 | historical | active, commit ref fixed this session | — |
| `ARCHITECTURE_INVENTORY.md` | Target/type inventory, session 1 | historical | active, commit ref fixed this session | — |
| `PROJECT_HISTORY_FROM_ZERO.md` | Git-log-derived chronology, session 1 | historical | active | — |
| `TEST_INVENTORY.md` + `test-inventory.json` | Test-suite inventory, session 1 (86/86) | current — re-verified this session, numbers still accurate | active, commit ref fixed this session | — |
| `project-state-audit.json` | Session-1 point-in-time JSON snapshot | historical (explicitly, via `historicalSnapshotNote` added this session) | active as a historical record | see `DOCUMENT_INDEX.md` / `PUBLIC_READINESS_SCORECARD.md` for current status |
| `FEATURE_INVENTORY.md` + `.json`/`.csv` | Feature-by-feature inventory, session 2 | current, with an explicit `IMPLEMENTED_UNVERIFIED` flag on 15 un-read view files | active | full traceability matrix (session 2 of this new phase) |
| `SECURITY_AUDIT_CURRENT.md` | Security audit, session 2 | current | active | — |
| `PRIVACY_AUDIT_CURRENT.md` | Privacy audit, session 2 | current | active | — |
| `LEGAL_AND_LICENSE_STATUS.md` | Legal/license audit, session 2 (found the LICENSE dead-link defect) | current | active, the defect it found is now fixed | see `REQUIREMENTS_DECISION_HISTORY.md` "Licensing stance" for the fix confirmation |
| `DISTRIBUTION_AUDIT.md` | Distribution deep-dive, session 3 | current | active | see this session's fresh `Scripts/test-release-manifest.sh` re-run for current manifest status |
| `WEBSITE_AUDIT.md` | Website audit, session 3 | current | active | — |
| `TECHNICAL_DEBT.md` | Technical debt inventory, sessions 1-3 | current | active | — |
| `PRODUCT_DEBT.md` | Product debt inventory, sessions 1-3 | current | active | — |
| `PUBLIC_READINESS_SCORECARD.md` | Readiness scorecard, session 3 | current | active | — |
| `AUDIT_EVIDENCE.md` | Load-bearing evidence appendix, session 3 | current | active | — |
| `NEXT_PHASE_RECOMMENDATIONS.md` | Recommendations from sessions 1-3 | historical (written before this reconciliation phase existed) | active, this phase (requirements reconciliation) is one of its recommendations, now underway | — |
| `PUBLICATION_AUDIT.md` | v0.6.0 "Open Source Foundation" publication audit | historical (superseded by v0.7.0 work) | historical | `PUBLIC_READINESS_SCORECARD.md` |
| `PUBLIC_READINESS_SCORECARD.md` | see above | | | |

## This reconciliation phase's own new documents (session 1)

| File | Role | Status | Audience |
|---|---|---|---|
| `MASTER_REQUIREMENTS_BASELINE.md` | Reconstructed requirements register with stable IDs | current, new this session | public |
| `REQUIREMENTS_DECISION_HISTORY.md` | Verified settled-decision history (Apple/product/architecture/data/site/licensing stances) | current, new this session | public |
| `DOCUMENT_INDEX.md` | This file | current, new this session | internal |

## This reconciliation phase's session 2-4 documents (requirements-compliance vocabulary)

| File | Role | Status | Audience |
|---|---|---|---|
| `MASTER_REQUIREMENTS_BASELINE.md` | 69-requirement sourced baseline (extended session 3) | current, source of truth | public |
| `REQUIREMENTS_TRACEABILITY_MATRIX.md` + `.json`/`.csv` | Per-requirement evidence, status, corrected session 4 (A11Y-003) | current, source of truth | internal |
| `REQUIREMENTS_COMPLIANCE_SUMMARY.md` | Rollup counts by priority/domain, updated session 4 | current, source of truth | public |
| `NON_COMPLIANCE_REGISTER.md` | Every non-clean finding, prioritized P0-P4, corrected session 4 | current | internal |
| `DEFERRED_REQUIREMENTS.md` | Requirements explicitly deferred, with rationale | current | internal |
| `REQUIREMENTS_VERIFICATION_EVIDENCE.md` | Supporting evidence detail for the matrix | current | internal |
| `MANUAL_ACCEPTANCE_TEST_PLAN.md` | Manual/interactive test steps for BLOCKED_ENVIRONMENT items | current | internal |
| `FINAL_COMPLIANCE_SCORECARD.md` | **New session 4.** Full MUST/SHOULD scoring per brief §23 formula, verdict MOSTLY_CONFORMING | current, source of truth | public |
| `public-readiness.json` | **New session 4.** Machine-readable twin of the scorecard above | current | internal |

## 0.8.1A — Brand Clearance & Workspace Migration Preflight (added this phase)

Non-destructive preflight only: no rename applied, no folder moved, no
domain changed. Every doc below is current, public-safe unless noted.

| File | Role | Source of truth | Audience |
|---|---|---|---|
| `PRE_REBRAND_BASELINE.md` | Canonical pre-rebrand snapshot (Git/build/identity/data-path facts) | current | internal |
| `BRAND_SEARCH_EVIDENCE.md` | Raw, dated MacClear conflict research | current | internal |
| `BRAND_NAME_CLEARANCE.md` + `brand-name-clearance.json` | MacClear verdict: CONFLICT_HIGH | current, source of truth | internal |
| `BRAND_CONFLICT_REGISTER.md` | Every conflict found, prioritized | current | internal |
| `BRAND_NAME_ALTERNATIVES.md` + `brand-name-alternatives.json` | 32 screened candidate names | current | internal |
| `BRAND_NAME_SHORTLIST.md` | Top 5 of the 32, no selection made | current | internal |
| `PORTFOLIO_REPOSITORY_INVENTORY.md` + `portfolio-repository-inventory.json` | Portfolio repo identification (read-only) | current | internal (contains paths only, no private content) |
| `WORKSPACE_TARGET_STRUCTURE.md`, `WORKSPACE_MIGRATION_PLAN.md`, `WORKSPACE_ROLLBACK_PLAN.md`, `workspace-migration-manifest.json` | Future `WEBSITE/` workspace design — nothing executed | current | internal |
| `PRODUCT_RENAME_INVENTORY.md` + `product-rename-inventory.json` | Every "CoreTend"/"CoreTend" reference, categorized by risk | current | internal |
| `PRODUCT_RENAME_PLAN.md`, `PRODUCT_RENAME_ROLLBACK.md` | Rename sequencing + rollback, nothing executed | current | internal |
| `CORETEND_DATA_MIGRATION_REPORT.md` | **Delivered-state** report on the local-data migration: shipped code, 20 tests, planned-vs-delivered scenario table, the one real execution on this one machine, and stated limits | current | public |
| `user-data-rename-migration.json` | Machine-readable migration record — `status: DELIVERED_AND_EXECUTED`, implementation map, real-execution journal, known gaps | current | internal |
| `RebrandHistory/PRE_IMPLEMENTATION_MIGRATION_DESIGN.md` | The migration design as written **before** any code existed. Opens by stating no migration code exists — true then, false now. Preserved verbatim | historical | internal |
| `RebrandHistory/PRE_IMPLEMENTATION_MIGRATION_TEST_PLAN.md` | The 15-scenario acceptance matrix written ahead of implementation. Preserved verbatim | historical | internal |
| `USER_DATA_RENAME_MIGRATION.md`, `REBRAND_MIGRATION_TEST_PLAN.md` | Redirect stubs only. Kept because `Sources/Persistence/LegacyDataMigration.swift` and several rename-phase docs reference these paths by name; leaving them avoids editing `Sources/`, which would break the artifacts' provenance | current (pointer) | internal |
| `CROSS_SITE_DESIGN_AUDIT.md`, `CROSS_SITE_DESIGN_LANGUAGE.md`, `cross-site-design-tokens.json`, `PORTFOLIO_PRODUCT_SITE_ALIGNMENT.md` | Read-only design comparison, portfolio vs product site | current | internal |
| `REBRAND_VISUAL_BRIEF.md`, `BRAND_ASSET_MATRIX.md`, `LOGO_MIGRATION_PLAN.md` | Logo/asset planning, no assets produced under any candidate name | current | internal |
| `Scripts/preflight-workspace-migration.sh` + `Scripts/test-preflight-workspace-migration.sh` | Non-destructive repo-state check + optional git-bundle backup | current, tested | internal (script) |
| `Scripts/check-brand-clearance.sh` + `Scripts/test-check-brand-clearance.sh` | Gate: blocks rename until every precondition is real | current, tested | internal (script) |
| `Scripts/check-workspace-migration-readiness.sh` + `Scripts/test-check-workspace-migration-readiness.sh` | Gate: blocks the actual workspace move until ready | current, tested | internal (script) |

## Notes on reconciliation performed this session

- Every audit-report file listed above with an old-commit reference (`b8266a29e7ebdbae1791c1c7afb887a8529763eb`,
  short form `b8266a2`) had that reference updated to the current AUDITED_SOURCE_COMMIT `b33c06b8d68b9b03316821c3f6cfb17252f35011`,
  **except** `PROJECT_HISTORY_FROM_ZERO.md:77`, where `b8266a2` is a genuine historical commit being
  discussed in prose ("pre-audit commits before `b8266a2`"), not a stale "current HEAD" claim — left
  unchanged deliberately.
- `PROJECT_COMPLETE_AUDIT.md`'s "session 1 of N" / "pending session 2" language (cover page, §4
  Verdict, §9 module inventory) was rewritten to either point at the session that actually resolved it,
  or — for the one genuinely still-open item (§9's full per-view API inventory) — kept honestly marked
  open rather than declared resolved.
- `project-state-audit.json` kept as a historical snapshot (its own `auditSession: 1` field is accurate
  history), with one new field added pointing readers at where current status actually lives.
